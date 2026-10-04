import 'dart:async';
import 'dart:math' as math;

import 'package:iptv_player/core/downloads/download_paths.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_service.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:path/path.dart' as p;

const _tag = 'downloads';

/// docs/09's waits after a network failure: 2, 4, 8, 15, 30, 60 s, then
/// every 60 s.
const List<Duration> downloadRetryWaits = [
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(seconds: 60),
];

/// How the queue keeps time (tests shorten it).
final class DownloadQueueTimings {
  const new({
    this.retryWaits = downloadRetryWaits,
    this.giveUpAfter = const Duration(minutes: 30),
    this.comeBackAfter = const Duration(seconds: 10),
    this.limitWait = const Duration(seconds: 60),
  });

  final List<Duration> retryWaits;

  /// With no progress for this long, a download failing on the network
  /// has failed (docs/09).
  final Duration giveUpAfter;

  /// Downloads come back this long after playback and casts let a source
  /// go (Phase 8 decision 3).
  final Duration comeBackAfter;

  /// After the provider says its connections are in use (docs/09).
  final Duration limitWait;
}

/// What the disk keeps free besides the download itself (docs/09).
const int downloadSpaceMargin = 1 << 30;

/// How often a running download checks the space left (docs/09).
const int downloadSpaceCheckEvery = 256 << 20;

/// How often a running download's progress is written down (docs/09).
const int downloadSaveEvery = 8 << 20;

/// Why the queue stopped a download it had started.
enum _Stop { user, gaveWay, noSpace, account, cancel, removal, shutdown }

/// The download queue (docs/09 "DownloadQueue"): the order, how many run
/// at once, the connection rules, the errors and their waits, the disk
/// space, resuming at launch and pausing at quit. It decides; the
/// [DownloadRunner] moves the bytes (in its isolate) and the
/// [DownloadFinisher] verifies and files what arrived.
///
/// Downloads hold their source's connections through [SourceConnections]
/// and **give way** (Phase 8 decision 3): when the player or a cast needs
/// one, the newest download on that source stops at once, and downloads
/// come back [DownloadQueueTimings.comeBackAfter] after the source is
/// free again.
final class DownloadQueue implements DownloadService {
  new({
    required this._store,
    required this._titles,
    required this._runner,
    required this._finisher,
    required this._connections,
    required this._sleep,
    required this._settings,
    required this._log,
    required this._freeSpace,
    bool Function(String path)? fileExists,
    this._windows = false,
    this.timings = const DownloadQueueTimings(),
    DateTime Function()? now,
  }) : _exists = fileExists ?? ((_) => false),
       _now = now ?? DateTime.now;

  final DownloadStore _store;
  final DownloadTitles _titles;
  final DownloadRunner _runner;
  final DownloadFinisher _finisher;
  final SourceConnections _connections;
  final SleepInhibitor _sleep;
  final DownloadSettings Function() _settings;
  final AppLog _log;
  final int? Function(String path) _freeSpace;
  final bool Function(String path) _exists;
  final bool _windows;
  final DateTime Function() _now;
  final DownloadQueueTimings timings;

  final _tasks = <int, DownloadTask>{};
  final _runs = <int, _Run>{};
  final _waits = <int, Timer>{};
  final _changes = StreamController<List<DownloadTask>>.broadcast();
  final _notices = StreamController<DownloadNotice>.broadcast();

  /// The connections the source allows, from its last URL.
  final _limits = <String, int>{};

  /// When the progress of a download last moved.
  final _moved = <int, DateTime>{};

  /// Sources another holder (the player, a cast) has a connection at.
  final _busy = <String>{};

  /// Sources just let go by another holder: downloads wait until then.
  final _quietUntil = <String, DateTime>{};
  final _quietTimers = <String, Timer>{};

  /// Sources whose viewing has been told it paused a download.
  final _told = <String>{};

  /// Sources whose sign-in the provider refused: paused until resumed.
  final _refused = <String>{};

  bool _noSpace = false;
  bool _started = false;
  bool _closed = false;
  bool _sleepHeld = false;
  StreamSubscription<DownloadNews>? _news;
  StreamSubscription<void>? _connectionChanges;

  /// The queue in its order.
  List<DownloadTask> get current => [..._tasks.values]
    ..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });

  @override
  Stream<List<DownloadTask>> get tasks => Stream.multi((listener) {
    listener.add(current);
    final changes = _changes.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.onCancel = changes.cancel;
  });

  /// What the screens show beside the list: a toast, a banner.
  Stream<DownloadNotice> get notices => _notices.stream;

  /// Reads the queue and starts what is due (docs/09 "App lifecycle"):
  /// what was running when the app went goes back in the queue, from its
  /// `.part`'s size, or paused when resuming at launch is off.
  Future<void> startUp() async {
    if (_started || _closed) return;
    _started = true;
    _connections.giveWay(StreamHolder.download, _giveWay);
    _news = _runner.news.listen(_onNews);
    _connectionChanges = _connections.changes.listen((_) => _onConnections());
    final resume = _settings().resumeOnLaunch;
    for (final stored in await _store.all()) {
      var task = stored;
      if (!task.state.isFinished) {
        final size = await _finisher.partSize(task);
        final interrupted =
            task.state != DownloadTaskState.paused &&
            task.state != DownloadTaskState.queued;
        task = task.copyWith(
          downloadedBytes: size,
          state: interrupted
              ? (resume ? DownloadTaskState.queued : DownloadTaskState.paused)
              : task.state,
        );
        if (task != stored) _save(task);
      }
      _tasks[task.id] = task;
    }
    _onConnections();
    _emit();
    _pump();
  }

  /// Quitting (docs/09): every running download stops and flushes, kept
  /// as it was so the next launch resumes it.
  Future<void> shutdown() async {
    if (_closed) return;
    _closed = true;
    for (final timer in [..._waits.values, ..._quietTimers.values]) {
      timer.cancel();
    }
    final stopping = <Future<void>>[];
    for (final run in [..._runs.values]) {
      run.stop ??= _Stop.shutdown;
      if (run.started) stopping.add(_runner.stop(run.id));
    }
    await Future.wait(stopping)
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    unawaited(_news?.cancel());
    unawaited(_connectionChanges?.cancel());
    await _runner.close();
    for (final source in {for (final r in _runs.values) r.sourceId}) {
      _connections.set(source, StreamHolder.download, 0);
    }
    _runs.clear();
    await _releaseSleep();
    await _changes.close();
    await _notices.close();
  }

  // ---- What the screens ask.

  @override
  Future<Result<void>> enqueue(List<DownloadRequest> requests) => Result.guard(
    () async {
      final folder = await _titles.folder();
      final targets = {for (final t in _tasks.values) t.targetPath};
      for (final request in requests) {
        final queued = _tasks.values.where(
          (t) =>
              t.sourceId == request.sourceId &&
              t.type == request.type &&
              t.remoteKey == request.remoteKey,
        );
        if (queued.isNotEmpty) {
          final task = queued.first;
          if (task.state == DownloadTaskState.failed ||
              task.state == DownloadTaskState.canceled) {
            await retry(task.id);
          }
          continue;
        }
        if (await _titles.downloaded(request)) continue;
        final target = freeName(
          downloadTarget(folder, request, windows: _windows),
          (path) =>
              targets.contains(path) || _exists(path) || _exists('$path.part'),
        );
        final task = await _store.add(
          request,
          targetPath: target,
          at: _now().toUtc(),
        );
        if (task == null) continue;
        targets.add(target);
        _tasks[task.id] = task;
      }
      _onConnections();
      _emit();
      _pump();
    },
  );

  @override
  Future<void> pause(int taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.state.isFinished) return;
    if (_runs[taskId] case final run?) {
      await _stopRun(run, _Stop.user);
      return;
    }
    _cancelWait(taskId);
    _update(task.copyWith(state: DownloadTaskState.paused, speed: null));
  }

  @override
  Future<void> resume(int taskId) async {
    final task = _tasks[taskId];
    if (task == null || _runs.containsKey(taskId)) return;
    if (task.state == DownloadTaskState.completed) return;
    if (task.problem == DownloadProblem.auth) {
      _refused.remove(task.sourceId);
    }
    if (task.problem == DownloadProblem.noSpace) _noSpace = false;
    _cancelWait(taskId);
    _update(
      task.copyWith(
        state: DownloadTaskState.queued,
        problem: null,
        problemDetail: null,
        attempts: 0,
      ),
    );
    _moved.remove(taskId);
    _pump();
  }

  @override
  Future<void> retry(int taskId) => resume(taskId);

  @override
  Future<void> cancel(int taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (_runs[taskId] case final run?) {
      await _stopRun(run, _Stop.cancel);
      return;
    }
    await _drop(task, discard: true);
  }

  @override
  Future<void> remove(int taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (_runs[taskId] case final run?) {
      await _stopRun(run, _Stop.removal);
      return;
    }
    await _drop(task, discard: task.state != DownloadTaskState.completed);
  }

  @override
  Future<void> move(int taskId, int index) async {
    if (!_tasks.containsKey(taskId)) return;
    final ordered = await _store.move(taskId, index);
    for (final task in ordered) {
      final known = _tasks[task.id];
      if (known != null) {
        _tasks[task.id] = known.copyWith(sortOrder: task.sortOrder);
      }
    }
    _emit();
    _pump();
  }

  @override
  Future<void> pauseAll() async {
    for (final task in current) {
      if (!task.state.isFinished && task.state != DownloadTaskState.paused) {
        await pause(task.id);
      }
    }
  }

  @override
  Future<void> resumeAll() async {
    _noSpace = false;
    _refused.clear();
    for (final task in current) {
      if (task.state == DownloadTaskState.paused) await resume(task.id);
    }
    _pump();
  }

  @override
  Future<void> clearFinished() async {
    for (final task in current) {
      if (task.state == DownloadTaskState.completed) {
        await _drop(task, discard: false);
      }
    }
  }

  // ---- Running.

  /// Starts what is due, in the queue's order (docs/09: 1–3 at a time,
  /// never more than a source has free).
  void _pump() {
    if (!_started || _closed || _noSpace) return;
    final atATime = _settings().atATime;
    var running = _runs.length;
    for (final task in current) {
      if (running >= atATime) break;
      final state = task.state;
      if (state != DownloadTaskState.queued &&
          state != DownloadTaskState.waitingForConnection) {
        continue;
      }
      if (_waits.containsKey(task.id)) continue;
      if (_refused.contains(task.sourceId)) continue;
      if (!_room(task.sourceId)) {
        if (state == DownloadTaskState.queued && _taken(task.sourceId)) {
          _update(task.copyWith(state: DownloadTaskState.waitingForConnection));
        }
        continue;
      }
      running++;
      unawaited(_start(task));
    }
    if (_runs.isEmpty) unawaited(_releaseSleep());
  }

  /// Whether another download may open a connection at [sourceId] now.
  bool _room(String sourceId) {
    final quiet = _quietUntil[sourceId];
    if (quiet != null && _now().isBefore(quiet)) return false;
    final limit = _limits[sourceId] ?? 1;
    final others = _connections.held(sourceId, except: StreamHolder.download);
    return others + _runsAt(sourceId) < limit;
  }

  /// The player or a cast has [sourceId]'s connections, or just had them.
  bool _taken(String sourceId) {
    final quiet = _quietUntil[sourceId];
    return _connections.held(sourceId, except: StreamHolder.download) > 0 ||
        (quiet != null && _now().isBefore(quiet));
  }

  int _runsAt(String sourceId) =>
      _runs.values.where((r) => r.sourceId == sourceId).length;

  void _countHeld(String sourceId) =>
      _connections.set(sourceId, StreamHolder.download, _runsAt(sourceId));

  Future<void> _start(DownloadTask queued) async {
    final run = _Run(queued.id, queued.sourceId, _now());
    _runs[queued.id] = run;
    _countHeld(queued.sourceId);
    var task = _update(
      queued.copyWith(
        state: DownloadTaskState.connecting,
        problem: null,
        problemDetail: null,
        speed: null,
      ),
    );
    _moved.putIfAbsent(task.id, _now);
    if (_settings().keepAwake) unawaited(_holdSleep());

    // docs/09: the rest of the file + 1 GB, before it starts.
    final left = math.max(0, (task.totalBytes ?? 0) - task.downloadedBytes);
    if (!_enoughSpace(task, left)) {
      _endRun(run);
      return;
    }

    final answer = await _titles.source(task);
    task = _tasks[task.id] ?? task;
    if (run.stop != null || _closed) {
      _endRun(run);
      await _afterStop(run, task, bytes: task.downloadedBytes);
      return;
    }
    switch (answer) {
      case DownloadSourceGone(:final detail):
        _endRun(run);
        _update(
          task.copyWith(
            state: DownloadTaskState.failed,
            problem: DownloadProblem.notFound,
            problemDetail: detail,
          ),
        );
        _pump();
        return;
      case DownloadSourceUnavailable(:final detail):
        _endRun(run);
        _networkTrouble(task, DownloadProblem.network, detail);
        _pump();
        return;
      case DownloadSource(:final upstream, :final maxConnections):
        final learned = _limits[task.sourceId] != maxConnections;
        _limits[task.sourceId] = maxConnections;
        final others = _connections.held(
          task.sourceId,
          except: StreamHolder.download,
        );
        if (others + _runsAt(task.sourceId) > maxConnections) {
          _endRun(run);
          _update(task.copyWith(state: DownloadTaskState.waitingForConnection));
          _pump();
          return;
        }
        run
          ..started = true
          ..baseBytes = task.downloadedBytes;
        var first = true;
        await _runner.start(
          DownloadOrder(
            id: task.id,
            sourceId: task.sourceId,
            partPath: '${task.targetPath}.part',
            etag: task.etag,
            lastModified: task.lastModified,
            total: task.totalBytes,
            bytesPerSecond: _settings().speedLimit.bytesPerSecond,
            maxConnections: maxConnections,
          ),
          upstream: () async {
            if (first) {
              first = false;
              return upstream;
            }
            final again = await _titles.source(_tasks[task.id] ?? task);
            return again is DownloadSource ? again.upstream : null;
          },
        );
        // A source that allows more than was thought: more may start.
        if (learned) _pump();
    }
  }

  void _onNews(DownloadNews news) {
    final task = _tasks[news.id];
    final run = _runs[news.id];
    if (task == null) return;
    switch (news) {
      case DownloadOpened():
        _moved[task.id] = _now();
        _update(
          task.copyWith(
            state: DownloadTaskState.downloading,
            downloadedBytes: news.bytes,
            totalBytes: news.hls ? null : (news.total ?? task.totalBytes),
            etag: news.restarted || news.hls
                ? news.etag
                : news.etag ?? task.etag,
            lastModified: news.restarted || news.hls
                ? news.lastModified
                : news.lastModified ?? task.lastModified,
          ),
          save: true,
        );
      case DownloadMoved(:final bytes):
        if (run == null) return;
        final now = _now();
        final moved = bytes - run.lastBytes;
        final seconds = now.difference(run.lastAt).inMicroseconds / 1e6;
        if (moved > 0 && seconds > 0) {
          final rate = moved / seconds;
          run.speed = run.speed == null ? rate : run.speed! * 0.7 + rate * 0.3;
        }
        run
          ..lastBytes = bytes
          ..lastAt = now;
        if (moved > 0) _moved[task.id] = now;
        // Every 8 MB written (docs/09); the .part's size is what a launch
        // trusts, so this is the list's, between launches.
        final save = bytes - run.savedAt >= downloadSaveEvery;
        if (save) run.savedAt = bytes;
        final updated = _update(
          task.copyWith(
            state: DownloadTaskState.downloading,
            downloadedBytes: bytes,
            speed: run.speed,
            attempts: bytes - run.baseBytes > (1 << 20) ? 0 : task.attempts,
          ),
          save: save,
        );
        if (bytes - run.spaceAt >= downloadSpaceCheckEvery) {
          run.spaceAt = bytes;
          final left = math.max(0, (updated.totalBytes ?? 0) - bytes);
          _enoughSpace(updated, left);
        }
      case DownloadDone(:final bytes, :final total):
        if (run != null) _endRun(run);
        unawaited(_finish(task, bytes: bytes, total: total));
      case DownloadHalted(:final bytes):
        if (run != null) {
          _endRun(run);
          unawaited(_afterStop(run, task, bytes: bytes));
        }
      case DownloadFailedNews():
        if (run != null) _endRun(run);
        _failed(task, news, run);
        _pump();
    }
  }

  Future<void> _finish(
    DownloadTask done, {
    required int bytes,
    required int? total,
  }) async {
    var task = _update(
      done.copyWith(
        state: DownloadTaskState.verifying,
        downloadedBytes: bytes,
        totalBytes: total ?? done.totalBytes,
        speed: null,
      ),
      save: true,
    );
    final finish = await _finisher.finish(task);
    task = _tasks[task.id] ?? task;
    switch (finish) {
      case DownloadFinished(:final libraryItemId, :final bytes):
        task = _update(
          task.copyWith(
            state: DownloadTaskState.completed,
            downloadedBytes: bytes,
            totalBytes: bytes,
            libraryItemId: libraryItemId,
            completedAt: _now().toUtc(),
            problem: null,
            problemDetail: null,
          ),
          save: true,
        );
        _log.info(
          _tag,
          'Download ${task.id} finished (${task.downloadedBytes} B)',
        );
        _tell(DownloadFinishedNotice(task));
      case DownloadDamaged(:final detail):
        _log.warning(_tag, 'Download ${task.id} is damaged: $detail');
        _update(
          task.copyWith(
            state: DownloadTaskState.failed,
            problem: DownloadProblem.damaged,
            problemDetail: detail,
            downloadedBytes: 0,
            totalBytes: null,
            etag: null,
            lastModified: null,
          ),
          save: true,
        );
      case DownloadNotFinished(:final detail):
        _update(
          task.copyWith(
            state: DownloadTaskState.failed,
            problem: DownloadProblem.diskWrite,
            problemDetail: detail,
          ),
          save: true,
        );
    }
    _pump();
  }

  /// A run the queue stopped has said where it got to.
  Future<void> _afterStop(
    _Run run,
    DownloadTask task, {
    required int bytes,
  }) async {
    final at = task.copyWith(downloadedBytes: bytes, speed: null);
    switch (run.stop) {
      case null || _Stop.shutdown:
        // As it was: the next launch resumes it.
        _tasks[task.id] = at;
        _save(at);
      case _Stop.user:
        _update(at.copyWith(state: DownloadTaskState.paused), save: true);
      case _Stop.gaveWay:
        _update(
          at.copyWith(state: DownloadTaskState.waitingForConnection),
          save: true,
        );
      case _Stop.noSpace:
        _update(
          at.copyWith(
            state: DownloadTaskState.paused,
            problem: DownloadProblem.noSpace,
          ),
          save: true,
        );
      case _Stop.account:
        _update(
          at.copyWith(
            state: DownloadTaskState.paused,
            problem: DownloadProblem.auth,
          ),
          save: true,
        );
      case _Stop.cancel:
        await _drop(at, discard: true);
      case _Stop.removal:
        await _drop(at, discard: true);
    }
    _pump();
  }

  void _failed(DownloadTask task, DownloadFailedNews news, _Run? run) {
    final at = task.copyWith(
      downloadedBytes: news.bytes,
      speed: null,
      problemDetail: news.detail,
    );
    if (run?.stop case final stop? when stop != _Stop.shutdown) {
      // Stopped by the queue and failing on the way: as asked.
      unawaited(_afterStop(run!, at, bytes: news.bytes));
      return;
    }
    switch (news.end) {
      case DownloadEnd.network:
        _networkTrouble(at, DownloadProblem.network, news.detail);
      case DownloadEnd.server:
        _networkTrouble(at, DownloadProblem.server, news.detail);
      case DownloadEnd.auth:
        _refuse(at);
      case DownloadEnd.notFound || DownloadEnd.unresolved:
        _update(
          at.copyWith(
            state: DownloadTaskState.failed,
            problem: DownloadProblem.notFound,
          ),
          save: true,
        );
      case DownloadEnd.connectionLimit:
        _update(
          at.copyWith(
            state: DownloadTaskState.waitingForConnection,
            problem: DownloadProblem.connectionLimit,
          ),
          save: true,
        );
        _wait(at.id, timings.limitWait);
      case DownloadEnd.diskWrite:
        _update(
          at.copyWith(
            state: DownloadTaskState.failed,
            problem: DownloadProblem.diskWrite,
          ),
          save: true,
        );
    }
  }

  /// docs/09: tried again after 2, 4, 8, 15, 30, 60 s, then every 60 s;
  /// failed after 30 min without progress.
  void _networkTrouble(
    DownloadTask task,
    DownloadProblem problem,
    String? detail,
  ) {
    final since = _moved[task.id] ?? _now();
    if (_now().difference(since) >= timings.giveUpAfter) {
      _update(
        task.copyWith(
          state: DownloadTaskState.failed,
          problem: problem,
          problemDetail: detail,
        ),
        save: true,
      );
      return;
    }
    final attempts = task.attempts + 1;
    final waits = timings.retryWaits;
    _update(
      task.copyWith(
        state: DownloadTaskState.retrying,
        problem: problem,
        problemDetail: detail,
        attempts: attempts,
      ),
      save: true,
    );
    _wait(task.id, waits[math.min(attempts, waits.length) - 1]);
  }

  /// 401/403: the source's downloads pause, with the account message.
  void _refuse(DownloadTask task) {
    _refused.add(task.sourceId);
    _update(
      task.copyWith(
        state: DownloadTaskState.paused,
        problem: DownloadProblem.auth,
      ),
      save: true,
    );
    for (final other in current) {
      if (other.sourceId != task.sourceId || other.id == task.id) continue;
      if (_runs[other.id] case final run?) {
        unawaited(_stopRun(run, _Stop.account));
      } else if (other.state.isPending) {
        _cancelWait(other.id);
        _update(
          other.copyWith(
            state: DownloadTaskState.paused,
            problem: DownloadProblem.auth,
          ),
          save: true,
        );
      }
    }
    _tell(DownloadsAccountRefused(task.sourceId));
  }

  /// docs/09: short of the rest of [task] + 1 GB, every download pauses.
  bool _enoughSpace(DownloadTask task, int left) {
    final folder = p.dirname(task.targetPath);
    final free = _freeSpace(folder);
    final needed = left + downloadSpaceMargin;
    if (free == null || free >= needed) return true;
    _log.warning(_tag, 'Downloads pause: $free B free, $needed B needed');
    _noSpace = true;
    for (final other in current) {
      if (_runs[other.id] case final run?) {
        unawaited(_stopRun(run, _Stop.noSpace));
      } else if (other.state.isPending) {
        _cancelWait(other.id);
        _update(
          other.copyWith(
            state: DownloadTaskState.paused,
            problem: DownloadProblem.noSpace,
          ),
          save: true,
        );
      }
    }
    _tell(DownloadsNeedSpace(neededBytes: needed - free, folder: folder));
    return false;
  }

  /// Another holder wants a connection at [sourceId]: the newest download
  /// there lets go (Phase 8 decision 3).
  void _giveWay(String sourceId) {
    final runs =
        _runs.values
            .where((r) => r.sourceId == sourceId && r.stop == null)
            .toList()
          ..sort((a, b) => a.since.compareTo(b.since));
    if (runs.isEmpty) return;
    final newest = runs.last;
    _busy.add(sourceId);
    if (_told.add(sourceId)) {
      _tell(
        DownloadsWaitForPlayback(
          sourceId,
          maxConnections: _limits[sourceId] ?? 1,
        ),
      );
    }
    unawaited(_stopRun(newest, _Stop.gaveWay));
  }

  Future<void> _stopRun(_Run run, _Stop why) async {
    run.stop ??= why;
    if (run.started) {
      await _runner.stop(run.id);
      return;
    }
    // Still asking for its URL: it lets go now, and [_start] ends it.
    _endRun(run);
    final task = _tasks[run.id];
    if (task != null) await _afterStop(run, task, bytes: task.downloadedBytes);
  }

  void _endRun(_Run run) {
    if (!identical(_runs[run.id], run)) return;
    _runs.remove(run.id);
    _countHeld(run.sourceId);
    if (_runs.isEmpty) unawaited(_releaseSleep());
  }

  /// Another holder's connections changed: a source it let go becomes the
  /// downloads' again [DownloadQueueTimings.comeBackAfter] later.
  void _onConnections() {
    for (final sourceId in {
      ..._busy,
      ..._tasks.values.map((t) => t.sourceId),
    }) {
      final others = _connections.held(sourceId, except: StreamHolder.download);
      if (others > 0) {
        if (_busy.add(sourceId)) {
          _quietTimers.remove(sourceId)?.cancel();
          _quietUntil.remove(sourceId);
        }
      } else if (_busy.remove(sourceId)) {
        _quietUntil[sourceId] = _now().add(timings.comeBackAfter);
        _quietTimers[sourceId] = Timer(timings.comeBackAfter, () {
          _quietTimers.remove(sourceId);
          _quietUntil.remove(sourceId);
          _told.remove(sourceId);
          _pump();
        });
      }
    }
  }

  void _wait(int taskId, Duration wait) {
    _cancelWait(taskId);
    _waits[taskId] = Timer(wait, () {
      _waits.remove(taskId);
      final task = _tasks[taskId];
      if (task == null || !task.state.isPending) return;
      _update(task.copyWith(state: DownloadTaskState.queued));
      _pump();
    });
  }

  void _cancelWait(int taskId) => _waits.remove(taskId)?.cancel();

  Future<void> _drop(DownloadTask task, {required bool discard}) async {
    _cancelWait(task.id);
    _tasks.remove(task.id);
    _moved.remove(task.id);
    _emit();
    if (discard) await _finisher.discard(task);
    try {
      await _store.remove(task.id);
    } on Object catch (error) {
      _log.warning(_tag, 'Could not remove download ${task.id}', error: error);
    }
    _pump();
  }

  // ---- Keeping track.

  DownloadTask _update(DownloadTask task, {bool save = false}) {
    if (!_tasks.containsKey(task.id)) return task;
    _tasks[task.id] = task;
    if (save || task.state != DownloadTaskState.downloading) _save(task);
    _emit();
    return task;
  }

  void _save(DownloadTask task) => unawaited(
    _store.save(task).catchError((Object error) {
      _log.warning(_tag, 'Could not save download ${task.id}', error: error);
    }),
  );

  void _emit() {
    if (!_changes.isClosed) _changes.add(current);
  }

  void _tell(DownloadNotice notice) {
    if (!_notices.isClosed) _notices.add(notice);
  }

  Future<void> _holdSleep() async {
    if (_sleepHeld) return;
    _sleepHeld = true;
    await _sleep.hold('Downloading');
  }

  Future<void> _releaseSleep() async {
    if (!_sleepHeld) return;
    _sleepHeld = false;
    await _sleep.release();
  }
}

/// A download the queue started.
final class _Run {
  new(this.id, this.sourceId, this.since) : lastAt = since;

  final int id;
  final String sourceId;
  final DateTime since;

  /// Handed to the runner (not just asking for its URL).
  bool started = false;
  _Stop? stop;
  int baseBytes = 0;
  int lastBytes = 0;
  DateTime lastAt;
  double? speed;
  int savedAt = 0;
  int spaceAt = 0;
}
