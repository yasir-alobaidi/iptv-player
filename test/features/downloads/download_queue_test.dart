import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/downloads/domain/download_queue.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:logger/logger.dart';

const downloadFolder = '/v/IPTV Player';

DownloadRequest movie(String key, {String source = 'src', String? title}) =>
    DownloadRequest(
      sourceId: source,
      type: VodType.movie,
      remoteKey: key,
      title: title ?? 'Movie $key',
      year: 2020,
      extension: 'mkv',
    );

/// Everything around the queue, scripted.
final class Rig {
  new(this.async, {DownloadSettings? settings, int? free})
    : settings = settings ?? const DownloadSettings(),
      freeBytes = free {
    queue = DownloadQueue(
      store: store,
      titles: titles,
      runner: runner,
      finisher: finisher,
      connections: connections,
      sleep: sleep,
      settings: () => this.settings,
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
      freeSpace: (_) => freeBytes,
      fileExists: files.contains,
      now: () => start.add(async.elapsed),
    );
    queue.notices.listen(notices.add);
    queue.tasks.listen((list) => latest = list);
  }

  final FakeAsync async;
  final start = DateTime.utc(2026, 10, 4, 12);
  final store = MemoryStore();
  final titles = ScriptedTitles();
  final runner = ScriptedRunner();
  final finisher = ScriptedFinisher();
  final connections = SourceConnections();
  final sleep = SleepLog();
  final files = <String>{};
  DownloadSettings settings;
  int? freeBytes;
  late final DownloadQueue queue;
  final notices = <DownloadNotice>[];
  List<DownloadTask> latest = const [];

  void settle() => async.flushMicrotasks();

  DownloadTask task(int id) => latest.firstWhere((t) => t.id == id);

  DownloadTaskState state(int id) => task(id).state;

  void enqueue(List<DownloadRequest> requests) {
    unawaited(queue.enqueue(requests));
    settle();
  }

  void say(DownloadNews news) {
    runner.say(news);
    settle();
  }

  /// [id] runs: opened, then [bytes] written.
  void runs(
    int id, {
    int bytes = 1000,
    int total = 10000,
    String etag = '"e1"',
  }) {
    say(DownloadOpened(id, bytes: 0, total: total, etag: etag));
    say(DownloadMoved(id, bytes: bytes, durable: 0));
  }
}

void main() {
  Rig rig(FakeAsync async, {DownloadSettings? settings, int? free}) {
    final r = Rig(async, settings: settings, free: free);
    unawaited(r.queue.startUp());
    r.settle();
    return r;
  }

  test('a download from the queue to the library', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1', title: 'Copper Hollow')]);
      final id = r.latest.single.id;
      expect(r.state(id), DownloadTaskState.connecting);
      expect(
        r.task(id).targetPath,
        '$downloadFolder/Movies/Copper Hollow (2020)/Copper Hollow (2020).mkv',
      );
      final order = r.runner.started.single;
      expect(order.partPath, '${r.task(id).targetPath}.part');
      expect(order.maxConnections, 1);
      expect(r.connections.held('src'), 1);
      expect(r.sleep.log, ['hold Downloading']);

      r.say(
        DownloadOpened(
          id,
          bytes: 0,
          total: 10000,
          etag: '"e1"',
          lastModified: 'L',
        ),
      );
      expect(r.state(id), DownloadTaskState.downloading);
      expect(r.task(id).totalBytes, 10000);
      expect(r.task(id).etag, '"e1"');
      async.elapse(const Duration(seconds: 1));
      r.say(DownloadMoved(id, bytes: 5000, durable: 0));
      expect(r.task(id).downloadedBytes, 5000);
      expect(r.task(id).speed, greaterThan(0));
      expect(r.task(id).progress, 0.5);

      r.say(DownloadDone(id, bytes: 10000, total: 10000));
      expect(r.state(id), DownloadTaskState.completed);
      expect(r.task(id).libraryItemId, 77);
      expect(r.finisher.finished, [id]);
      expect(r.notices.whereType<DownloadFinishedNotice>().single.task.id, id);
      expect(r.connections.held('src'), 0);
      expect(r.sleep.log, ['hold Downloading', 'release']);
      expect(r.store.rows[id]!.state, DownloadTaskState.completed);
    });
  });

  test("one at a time by default, in the queue's order; a source never "
      'gets more than it allows', () {
    fakeAsync((async) {
      final r = rig(async)
        ..enqueue([movie('1'), movie('2'), movie('3', source: 'other')]);
      final [a, b, c] = [for (final t in r.latest) t.id];
      expect(r.runner.started.map((o) => o.id), [a]);
      expect(r.state(b), DownloadTaskState.queued);
      r.say(DownloadDone(a, bytes: 1, total: 1));
      expect(r.runner.started.map((o) => o.id), [a, b]);

      r
        ..settings = const DownloadSettings(atATime: 3)
        ..say(DownloadDone(b, bytes: 1, total: 1));
      expect(r.runner.started.map((o) => o.id), [a, b, c]);
    });

    fakeAsync((async) {
      final r = rig(async, settings: const DownloadSettings(atATime: 3))
        ..enqueue([movie('1'), movie('2'), movie('3')]);
      expect(r.runner.started, hasLength(1), reason: 'the source allows 1');
      r.titles.maxConnections = 2;
      final first = r.runner.started.single.id;
      r.say(DownloadDone(first, bytes: 1, total: 1));
      expect(r.runner.started, hasLength(3), reason: 'now 2 at once');
    });
  });

  test('the player needs the connection: the download gives way at once, '
      'and comes back 10 s after the player lets go', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1')]);
      final id = r.latest.single.id;
      r.runs(id, bytes: 4000);

      // The player asks for room.
      var room = false;
      unawaited(
        r.connections
            .room('src', limit: 1, holder: StreamHolder.player)
            .then((ok) => room = ok),
      );
      r.settle();
      expect(r.runner.stopped, [id]);
      r.say(DownloadHalted(id, bytes: 4000));
      expect(room, isTrue);
      expect(r.state(id), DownloadTaskState.waitingForConnection);
      expect(r.task(id).downloadedBytes, 4000);
      expect(r.notices.whereType<DownloadsWaitForPlayback>(), hasLength(1));
      expect(r.connections.held('src'), 0);

      r.connections.set('src', StreamHolder.player, 1);
      async.elapse(const Duration(minutes: 5));
      expect(r.runner.started, hasLength(1));

      // A zap: the player lets go and takes it again within 10 s.
      r.connections.set('src', StreamHolder.player, 0);
      async.elapse(const Duration(seconds: 5));
      r.connections.set('src', StreamHolder.player, 1);
      async.elapse(const Duration(seconds: 30));
      expect(r.runner.started, hasLength(1));

      r.connections.set('src', StreamHolder.player, 0);
      async.elapse(const Duration(seconds: 9));
      expect(r.runner.started, hasLength(1));
      async.elapse(const Duration(seconds: 2));
      expect(r.runner.started, hasLength(2));
      final again = r.runner.started.last;
      expect(again.etag, '"e1"', reason: 'resumes with If-Range');
      expect(r.state(id), DownloadTaskState.connecting);

      // A second viewing is told again.
      r.runs(id);
      unawaited(r.connections.room('src', limit: 1, holder: StreamHolder.cast));
      r
        ..settle()
        ..say(DownloadHalted(id, bytes: 1000));
      expect(r.notices.whereType<DownloadsWaitForPlayback>(), hasLength(2));
    });
  });

  test('queued while the player has the source: waits for the connection', () {
    fakeAsync((async) {
      final r = rig(async)
        ..connections.set('src', StreamHolder.player, 1)
        ..settle()
        ..enqueue([movie('1')]);
      final id = r.latest.single.id;
      expect(r.runner.started, isEmpty);
      expect(r.state(id), DownloadTaskState.waitingForConnection);
      r.connections.set('src', StreamHolder.player, 0);
      async.elapse(const Duration(seconds: 11));
      expect(r.runner.started.single.id, id);
    });
  });

  test('network failures: 2, 4, 8, 15, 30, 60 s, then every 60 s; failed '
      'after 30 min without progress', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1')]);
      final id = r.latest.single.id;
      final waits = <int>[];
      for (var i = 0; i < 8; i++) {
        final before = async.elapsed;
        r.say(DownloadFailedNews(id, DownloadEnd.network, bytes: 0));
        expect(r.state(id), DownloadTaskState.retrying);
        expect(r.task(id).problem, DownloadProblem.network);
        final started = r.runner.started.length;
        while (r.runner.started.length == started) {
          async.elapse(const Duration(seconds: 1));
        }
        waits.add((async.elapsed - before).inSeconds);
      }
      expect(waits, [2, 4, 8, 15, 30, 60, 60, 60]);

      // Progress resets the count; then 30 minutes of failures end it.
      r.runs(id, bytes: 3 << 20);
      var failedAt = Duration.zero;
      while (r.state(id) != DownloadTaskState.failed) {
        r.say(DownloadFailedNews(id, DownloadEnd.network, bytes: 3 << 20));
        if (r.state(id) == DownloadTaskState.failed) break;
        expect(r.task(id).attempts, lessThan(40));
        final started = r.runner.started.length;
        while (r.runner.started.length == started) {
          async.elapse(const Duration(seconds: 1));
        }
        failedAt = async.elapsed;
      }
      expect(r.task(id).problem, DownloadProblem.network);
      expect(failedAt, greaterThan(const Duration(minutes: 29)));
    });
  });

  test("the provider's answers: 404 fails, the limit waits 60 s, a refused "
      "sign-in pauses the source's downloads", () {
    fakeAsync((async) {
      final r = rig(async, settings: const DownloadSettings(atATime: 3))
        ..titles.maxConnections = 3
        ..enqueue([
          movie('1'),
          movie('2'),
          movie('3'),
          movie('4', source: 'b'),
        ]);
      final [a, b, c, d] = [for (final t in r.latest) t.id];

      r.say(DownloadFailedNews(a, DownloadEnd.notFound, bytes: 0, status: 404));
      expect(r.state(a), DownloadTaskState.failed);
      expect(r.task(a).problem, DownloadProblem.notFound);

      r.say(DownloadFailedNews(b, DownloadEnd.connectionLimit, bytes: 0));
      expect(r.state(b), DownloadTaskState.waitingForConnection);
      expect(r.task(b).problem, DownloadProblem.connectionLimit);
      final starts = r.runner.started.where((o) => o.id == b).length;
      async.elapse(const Duration(seconds: 59));
      expect(r.runner.started.where((o) => o.id == b), hasLength(starts));
      async.elapse(const Duration(seconds: 2));
      expect(r.runner.started.where((o) => o.id == b), hasLength(starts + 1));

      r.say(DownloadFailedNews(c, DownloadEnd.auth, bytes: 0, status: 401));
      expect(r.state(c), DownloadTaskState.paused);
      expect(r.task(c).problem, DownloadProblem.auth);
      expect(r.runner.stopped, contains(b), reason: "the source's others");
      r.say(DownloadHalted(b, bytes: 0));
      expect(r.state(b), DownloadTaskState.paused);
      expect(r.task(b).problem, DownloadProblem.auth);
      expect(
        r.notices.whereType<DownloadsAccountRefused>().single.sourceId,
        'src',
      );
      expect(
        r.state(d),
        isNot(DownloadTaskState.paused),
        reason: 'another source',
      );

      unawaited(r.queue.resume(c));
      r.settle();
      expect(r.state(c), DownloadTaskState.connecting);
    });
  });

  test(
    'a title gone from the catalogue fails; a keyring locked tries again',
    () {
      fakeAsync((async) {
        final r = rig(async, settings: const DownloadSettings(atATime: 2))
          ..titles.answers['1'] = const DownloadSourceGone('removed')
          ..titles.answers['2'] = const DownloadSourceUnavailable('locked')
          ..titles.maxConnections = 2
          ..enqueue([movie('1'), movie('2', source: 'b')]);
        final [a, b] = [for (final t in r.latest) t.id];
        expect(r.state(a), DownloadTaskState.failed);
        expect(r.task(a).problem, DownloadProblem.notFound);
        expect(r.state(b), DownloadTaskState.retrying);
        r.titles.answers.remove('2');
        async.elapse(const Duration(seconds: 3));
        expect(r.runner.started.single.id, b);
      });
    },
  );

  test('not enough disk space: everything pauses with a banner; Resume all '
      'tries again', () {
    fakeAsync((async) {
      final r = rig(async, free: 600 << 20)..enqueue([movie('1'), movie('2')]);
      final [a, b] = [for (final t in r.latest) t.id];
      expect(r.runner.started, isEmpty);
      expect(r.state(a), DownloadTaskState.paused);
      expect(r.task(a).problem, DownloadProblem.noSpace);
      expect(r.state(b), DownloadTaskState.paused);
      final need = r.notices.whereType<DownloadsNeedSpace>().single;
      expect(need.neededBytes, (1 << 30) - (600 << 20));

      r.freeBytes = 5 << 30;
      unawaited(r.queue.resumeAll());
      r.settle();
      expect(r.runner.started.single.id, a);

      // Checked again every 256 MB.
      r
        ..say(DownloadOpened(a, bytes: 0, total: 4 << 30))
        ..freeBytes = 100 << 20
        ..say(DownloadMoved(a, bytes: 300 << 20, durable: 0));
      expect(r.runner.stopped, [a]);
      r.say(DownloadHalted(a, bytes: 300 << 20));
      expect(r.state(a), DownloadTaskState.paused);
      expect(r.task(a).problem, DownloadProblem.noSpace);
    });
  });

  test('a damaged file fails and starts from nothing next time', () {
    fakeAsync((async) {
      final r = rig(async)
        ..finisher.answer = const DownloadDamaged('ffprobe read no length')
        ..enqueue([movie('1')]);
      final id = r.latest.single.id;
      r
        ..runs(id)
        ..say(DownloadDone(id, bytes: 10000, total: 10000));
      expect(r.state(id), DownloadTaskState.failed);
      expect(r.task(id).problem, DownloadProblem.damaged);
      expect(r.task(id).downloadedBytes, 0);
      expect(r.task(id).etag, isNull);
    });
  });

  test("the user's controls", () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1'), movie('2'), movie('3')]);
      final [a, b, c] = [for (final t in r.latest) t.id];
      r.runs(a);

      unawaited(r.queue.pause(a));
      r
        ..settle()
        ..say(DownloadHalted(a, bytes: 1000));
      expect(r.state(a), DownloadTaskState.paused);
      expect(r.runner.started.last.id, b, reason: 'the next one starts');

      unawaited(r.queue.move(c, 0));
      r.settle();
      expect([for (final t in r.latest) t.id], [c, a, b]);

      unawaited(r.queue.cancel(b));
      r
        ..settle()
        ..say(DownloadHalted(b, bytes: 10));
      expect(r.latest.map((t) => t.id), [c, a]);
      expect(r.finisher.discarded, [b]);
      expect(r.store.rows.containsKey(b), isFalse);

      expect(r.runner.started.last.id, c);
      r.say(DownloadDone(c, bytes: 1, total: 1));
      unawaited(r.queue.resume(a));
      r
        ..settle()
        ..say(DownloadDone(a, bytes: 1, total: 1));
      unawaited(r.queue.clearFinished());
      r.settle();
      expect(r.latest, isEmpty);
      expect(r.finisher.discarded, [b], reason: 'finished files stay');
    });
  });

  test('pause all and resume all', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1'), movie('2')]);
      final [a, b] = [for (final t in r.latest) t.id];
      unawaited(r.queue.pauseAll());
      r
        ..settle()
        ..say(DownloadHalted(a, bytes: 0));
      expect(
        [r.state(a), r.state(b)],
        [DownloadTaskState.paused, DownloadTaskState.paused],
      );
      unawaited(r.queue.resumeAll());
      r.settle();
      expect(r.state(a), DownloadTaskState.connecting);
      expect(r.state(b), DownloadTaskState.queued);
    });
  });

  test(
    'enqueue: once per title, a free name, nothing already in the library',
    () {
      fakeAsync((async) {
        final r = rig(async)
          ..files.add('$downloadFolder/Movies/Dup (2020)/Dup (2020).mkv')
          ..titles.inLibrary.add('9')
          ..enqueue([movie('1', title: 'Dup'), movie('1'), movie('9')]);
        expect(r.latest, hasLength(1));
        expect(
          r.latest.single.targetPath,
          '$downloadFolder/Movies/Dup (2020)/Dup (2020) (2).mkv',
        );
        final id = r.latest.single.id;
        r
          ..say(DownloadFailedNews(id, DownloadEnd.notFound, bytes: 0))
          ..enqueue([movie('1')]);
        expect(r.state(id), DownloadTaskState.connecting, reason: 'retried');
      });
    },
  );

  test('at launch: what was running resumes from its .part; with resuming '
      'off it waits paused', () {
    for (final resume in [true, false]) {
      fakeAsync((async) {
        final r = Rig(async, settings: DownloadSettings(resumeOnLaunch: resume))
          ..store.seed(DownloadTaskState.downloading, downloaded: 10)
          ..store.seed(DownloadTaskState.paused)
          ..store.seed(DownloadTaskState.completed)
          ..finisher.partSizes[1] = 4096;
        unawaited(r.queue.startUp());
        r.settle();
        expect(r.task(1).downloadedBytes, 4096);
        expect(
          r.state(1),
          resume ? DownloadTaskState.connecting : DownloadTaskState.paused,
        );
        expect(r.state(2), DownloadTaskState.paused);
        expect(r.state(3), DownloadTaskState.completed);
      });
    }
  });

  test('at quit: running downloads stop and stay as they were for the next '
      'launch', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1')]);
      final id = r.latest.single.id;
      r
        ..runs(id, bytes: 7000)
        ..runner.haltOnStop = true;
      unawaited(r.queue.shutdown());
      r.settle();
      expect(r.runner.stopped, [id]);
      expect(r.runner.closed, isTrue);
      expect(r.store.rows[id]!.state, DownloadTaskState.downloading);
      expect(r.store.rows[id]!.downloadedBytes, 7000);
      expect(r.connections.held('src'), 0);
      expect(r.sleep.log.last, 'release');
    });
  });

  test('the speed limit and the validators reach the runner', () {
    fakeAsync((async) {
      final r = rig(
        async,
        settings: const DownloadSettings(speedLimit: DownloadSpeedLimit.mbps10),
      )..enqueue([movie('1')]);
      expect(r.runner.started.single.bytesPerSecond, 1250000);
    });
  });
}

// ---- The fakes.

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

  @override
  Future<DownloadFinish> finish(DownloadTask task) async {
    finished.add(task.id);
    return answer;
  }

  @override
  Future<void> discard(DownloadTask task) async => discarded.add(task.id);

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
