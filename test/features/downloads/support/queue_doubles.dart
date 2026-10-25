import 'dart:async';

import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';

// The download queue's surroundings, scripted: what `DownloadQueue` is
// built on in its own tests and in tests that need a real queue.

const downloadFolder = '/v/IPTV Player';

final class MemoryStore implements DownloadStore {
  final rows = <int, DownloadTask>{};
  var _next = 1;

  void seed(DownloadTaskState state, {int downloaded = 0}) {
    final id = _next++;
    rows[id] = DownloadTask(
      id: id,
      sourceId: 'src',
      type: VodType.movie,
      remoteKey: '$id',
      title: 'Seeded $id',
      targetPath: '$downloadFolder/Movies/S$id/S$id.mkv',
      state: state,
      downloadedBytes: downloaded,
      sortOrder: id,
      createdAt: DateTime.utc(2026),
    );
  }

  @override
  Future<List<DownloadTask>> all() async =>
      [...rows.values]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Future<DownloadTask?> add(
    DownloadRequest request, {
    required String targetPath,
    required DateTime at,
  }) async {
    if (rows.values.any(
      (t) =>
          t.sourceId == request.sourceId &&
          t.type == request.type &&
          t.remoteKey == request.remoteKey,
    )) {
      return null;
    }
    final id = _next++;
    final top = rows.values.fold(
      -1,
      (m, t) => t.sortOrder > m ? t.sortOrder : m,
    );
    return rows[id] = DownloadTask(
      id: id,
      sourceId: request.sourceId,
      type: request.type,
      remoteKey: request.remoteKey,
      title: request.title,
      year: request.year,
      seriesKey: request.seriesKey,
      showTitle: request.showTitle,
      season: request.season,
      episode: request.episode,
      targetPath: targetPath,
      state: DownloadTaskState.queued,
      downloadedBytes: 0,
      sortOrder: top + 1,
      createdAt: at,
    );
  }

  @override
  Future<void> save(DownloadTask task) async {
    if (rows.containsKey(task.id)) rows[task.id] = task.copyWith(speed: null);
  }

  @override
  Future<void> remove(int id) async => rows.remove(id);

  @override
  Future<List<DownloadTask>> move(int id, int index) async {
    final order = await all();
    final moving = order.firstWhere((t) => t.id == id);
    order
      ..remove(moving)
      ..insert(index.clamp(0, order.length), moving);
    for (final (i, task) in order.indexed) {
      rows[task.id] = task.copyWith(sortOrder: i);
    }
    return await all();
  }
}

final class ScriptedTitles implements DownloadTitles {
  int maxConnections = 1;
  final answers = <String, DownloadSourceAnswer>{};
  final inLibrary = <String>{};

  /// What the account says after a refusal; held while [accountWait] is
  /// set.
  bool? refusesSignIn = false;
  Completer<void>? accountWait;
  final accountAsked = <String>[];

  @override
  Future<bool?> signInRefused(String sourceId) async {
    accountAsked.add(sourceId);
    await accountWait?.future;
    return refusesSignIn;
  }

  @override
  Future<DownloadSourceAnswer> source(DownloadTask task) async =>
      answers[task.remoteKey] ??
      DownloadSource(
        DownloadUpstream(
          url: 'http://panel.test/movie/u/p/${task.remoteKey}.mkv',
        ),
        maxConnections: maxConnections,
      );

  @override
  Future<String> folder() async => downloadFolder;

  @override
  Future<bool> downloaded(DownloadRequest request) async =>
      inLibrary.contains(request.remoteKey);
}

final class ScriptedRunner implements DownloadRunner {
  final _news = StreamController<DownloadNews>.broadcast(sync: true);
  final started = <DownloadOrder>[];
  final stopped = <int>[];
  bool closed = false;

  /// At quit, a stopped download says it halted at its last bytes.
  bool haltOnStop = false;
  final _bytes = <int, int>{};

  @override
  Stream<DownloadNews> get news => _news.stream;

  void say(DownloadNews news) {
    if (news is DownloadMoved) _bytes[news.id] = news.bytes;
    _news.add(news);
  }

  @override
  Future<void> start(
    DownloadOrder order, {
    required Future<DownloadUpstream?> Function() upstream,
  }) async => started.add(order);

  @override
  Future<void> stop(int id) async {
    stopped.add(id);
    if (haltOnStop) say(DownloadHalted(id, bytes: _bytes[id] ?? 0));
  }

  @override
  Future<void> close() async => closed = true;
}

final class ScriptedFinisher implements DownloadFinisher {
  DownloadFinish answer = const DownloadFinished(77, bytes: 10000);
  final finished = <int>[];
  final discarded = <int>[];
  final partSizes = <int, int>{};

  /// The downloads whose every byte is on disk already.
  final wholeOnDisk = <int>{};

  /// When set, a finish waits for it (the MP4 being made); a discard or
  /// a close completes it as stopped.
  Completer<DownloadFinish>? working;
  bool closed = false;

  @override
  Future<DownloadFinish> finish(DownloadTask task) async {
    finished.add(task.id);
    return await working?.future ?? answer;
  }

  @override
  Future<bool> whole(DownloadTask task) async => wholeOnDisk.contains(task.id);

  @override
  Future<void> discard(DownloadTask task) async {
    discarded.add(task.id);
    _stop();
  }

  @override
  Future<void> close() async {
    closed = true;
    _stop();
  }

  void _stop() {
    final busy = working;
    if (busy != null && !busy.isCompleted) {
      busy.complete(const DownloadFinishStopped());
    }
  }

  @override
  Future<int> partSize(DownloadTask task) async => partSizes[task.id] ?? 0;
}

final class SleepLog implements SleepInhibitor {
  final log = <String>[];

  @override
  Future<bool> hold(String why) async {
    log.add('hold $why');
    return true;
  }

  @override
  Future<void> release() async => log.add('release');
}
