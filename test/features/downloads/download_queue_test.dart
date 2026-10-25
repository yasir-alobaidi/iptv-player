import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/downloads/domain/download_queue.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:logger/logger.dart';

import 'support/queue_doubles.dart';

DownloadRequest episode(int number, {String series = 'S1', int season = 1}) =>
    DownloadRequest(
      sourceId: 'src',
      type: VodType.episode,
      remoteKey: '$series-$season-$number',
      title: 'Episode $number',
      seriesKey: series,
      showTitle: 'Show $series',
      season: season,
      episode: number,
      extension: 'mp4',
    );

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

      r.titles.refusesSignIn = true;
      r.say(DownloadFailedNews(c, DownloadEnd.auth, bytes: 0, status: 401));
      expect(r.titles.accountAsked, ['src']);
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

  test('a 401 while the account answers is the connection in use '
      "(the user's TV): it waits 60 s and tries again; nothing pauses", () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1'), movie('2')]);
      final [a, b] = [for (final t in r.latest) t.id];
      r.titles.accountWait = Completer<void>();
      r.say(DownloadFailedNews(a, DownloadEnd.auth, bytes: 500, status: 401));
      expect(r.state(a), DownloadTaskState.waitingForConnection);
      expect(r.runner.started.map((o) => o.id), [a], reason: 'not again yet');
      r.titles.accountWait!.complete();
      r.settle();
      expect(r.state(a), DownloadTaskState.waitingForConnection);
      expect(r.task(a).problem, DownloadProblem.connectionLimit);
      expect(r.state(b), DownloadTaskState.queued, reason: 'held, in order');
      expect(r.notices.whereType<DownloadsAccountRefused>(), isEmpty);
      async.elapse(const Duration(seconds: 61));
      expect(r.runner.started.map((o) => o.id), [a, a]);

      // Unknown (the panel's API down too): the same.
      r
        ..titles.refusesSignIn = null
        ..say(DownloadFailedNews(a, DownloadEnd.auth, bytes: 500, status: 401));
      expect(r.state(a), DownloadTaskState.waitingForConnection);
      expect(r.notices.whereType<DownloadsAccountRefused>(), isEmpty);
    });
  });

  test('the connection limit holds the queue in its order: the next one '
      'is not tried meanwhile, and the refused one goes first after 60 s', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1'), movie('2'), movie('3')]);
      final [a, b, _] = [for (final t in r.latest) t.id];
      r.say(DownloadFailedNews(a, DownloadEnd.connectionLimit, bytes: 0));
      async.elapse(const Duration(seconds: 59));
      expect(r.runner.started.map((o) => o.id), [a]);
      expect(r.state(b), DownloadTaskState.queued);
      async.elapse(const Duration(seconds: 2));
      expect(r.runner.started.map((o) => o.id), [a, a]);

      // Resume on one asks now.
      r.say(DownloadFailedNews(a, DownloadEnd.connectionLimit, bytes: 0));
      unawaited(r.queue.pause(a));
      r.settle();
      expect(r.runner.started.map((o) => o.id), [a, a], reason: 'still held');
      unawaited(r.queue.resume(b));
      r.settle();
      expect(r.runner.started.last.id, b);
    });
  });

  test('a refusal checked while the user pauses it: the pause stands', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1')]);
      final a = r.latest.single.id;
      r
        ..titles.accountWait = Completer<void>()
        ..titles.refusesSignIn = true
        ..say(DownloadFailedNews(a, DownloadEnd.auth, bytes: 0, status: 401));
      unawaited(r.queue.pause(a));
      r.settle();
      r.titles.accountWait!.complete();
      r.settle();
      expect(r.state(a), DownloadTaskState.paused);
      expect(r.notices.whereType<DownloadsAccountRefused>(), isEmpty);
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

  test("the queue's order is binding: one ahead that can start takes the "
      'place of one running behind it, which waits from its .part', () {
    fakeAsync((async) {
      final r = rig(async)
        ..runner.haltOnStop = true
        ..enqueue([movie('1'), movie('2'), movie('3'), movie('4')]);
      final [a, b, c, d] = [for (final t in r.latest) t.id];
      r.runs(a, bytes: 4000);

      // The user's E11 and E08: a paused, b starts; a resumed, b makes
      // way and waits, a goes on from where it was.
      unawaited(r.queue.pause(a));
      r.settle();
      expect(r.runner.started.last.id, b);
      r.runs(b, bytes: 2000);
      unawaited(r.queue.resume(a));
      r.settle();
      expect(r.runner.stopped.last, b);
      expect(r.state(b), DownloadTaskState.queued);
      expect(r.task(b).downloadedBytes, 2000);
      expect(r.runner.started.last.id, a);
      expect(r.runner.started.where((o) => o.id != d), hasLength(3));

      // Moved to the top: it starts now.
      unawaited(r.queue.move(c, 0));
      r.settle();
      expect(r.runner.stopped.last, a);
      expect(r.runner.started.last.id, c);
      expect(r.state(a), DownloadTaskState.queued);

      // A cancel while one makes way still cancels it.
      r.runner.haltOnStop = false;
      unawaited(r.queue.move(d, 0));
      r.settle();
      expect(r.runner.stopped.last, c);
      unawaited(r.queue.cancel(c));
      r
        ..settle()
        ..say(DownloadHalted(c, bytes: 10));
      expect(r.latest.map((t) => t.id), isNot(contains(c)));
      expect(r.finisher.discarded, [c]);
      expect(r.runner.started.last.id, d);
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

  test('pause all with a runner that stops at once: what waited never '
      'starts', () {
    fakeAsync((async) {
      final r = rig(async)
        ..runner.haltOnStop = true
        ..enqueue([movie('1'), movie('2'), movie('3')]);
      final ids = [for (final t in r.latest) t.id];
      unawaited(r.queue.pauseAll());
      r.settle();
      expect(r.runner.started.map((o) => o.id), [ids.first]);
      expect(ids.map(r.state), everyElement(DownloadTaskState.paused));
    });
  });

  test("a series' episodes in their order: ones added later go before its "
      'later episodes not running; other titles join the end', () {
    fakeAsync((async) {
      final r = rig(async)
        ..enqueue([for (var n = 7; n <= 10; n++) episode(n)])
        ..enqueue([movie('m')]);
      final e7 = r.latest.first.id;
      expect(r.runner.started.single.id, e7);
      r.enqueue([episode(1), episode(2), episode(3), episode(1, series: 'S2')]);
      List<String> names() => [
        for (final t in r.latest)
          if (t.type == VodType.episode)
            '${t.seriesKey} E${t.episode}'
          else
            'movie',
      ];
      expect(names(), [
        'S1 E7',
        'S1 E1',
        'S1 E2',
        'S1 E3',
        'S1 E8',
        'S1 E9',
        'S1 E10',
        'movie',
        'S2 E1',
      ]);
      // E7 goes on; E1 is next.
      r.say(DownloadDone(e7, bytes: 1, total: 1));
      expect(r.task(r.runner.started.last.id).episode, 1);

      // A later season's episode goes after the earlier season's.
      r.enqueue([episode(2, season: 2)]);
      expect(names().last, 'S1 E2');
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

  test('a file remade as MP4: the download keeps the name it ended with', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1', title: 'Copper Hollow')]);
      final id = r.latest.single.id;
      const mp4 =
          '$downloadFolder/Movies/Copper Hollow (2020)/Copper Hollow (2020).mp4';
      r.finisher.answer = const DownloadFinished(77, bytes: 10400, path: mp4);
      r
        ..runs(id)
        ..say(DownloadDone(id, bytes: 10000, total: 10000));
      expect(r.state(id), DownloadTaskState.completed);
      expect(r.task(id).targetPath, mp4);
      expect(r.task(id).totalBytes, 10400);
      expect(r.store.rows[id]!.targetPath, mp4);
    });
  });

  test('at launch: a download whose every byte is on disk is finished with '
      'no connection', () {
    fakeAsync((async) {
      final r = Rig(async)
        ..store.seed(DownloadTaskState.verifying, downloaded: 10000)
        ..finisher.wholeOnDisk.add(1);
      unawaited(r.queue.startUp());
      r.settle();
      expect(r.finisher.finished, [1]);
      expect(r.runner.started, isEmpty);
      expect(r.state(1), DownloadTaskState.completed);
      expect(r.task(1).libraryItemId, 77);
    });
  });

  test('a cancel while the file is being checked or remade: the work stops '
      'and the download goes', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1')]);
      final id = r.latest.single.id;
      r.finisher.working = Completer();
      r
        ..runs(id)
        ..say(DownloadDone(id, bytes: 10000, total: 10000));
      expect(r.state(id), DownloadTaskState.verifying);

      unawaited(r.queue.cancel(id));
      r.settle();
      expect(r.finisher.discarded, contains(id));
      expect(r.latest, isEmpty);
      expect(r.store.rows, isEmpty);
    });
  });

  test('at quit while the file is being remade: the work stops, and the '
      'download stays as it was for the next launch', () {
    fakeAsync((async) {
      final r = rig(async)..enqueue([movie('1')]);
      final id = r.latest.single.id;
      r.finisher.working = Completer();
      r
        ..runs(id)
        ..say(DownloadDone(id, bytes: 10000, total: 10000));
      expect(r.store.rows[id]!.state, DownloadTaskState.verifying);

      unawaited(r.queue.shutdown());
      r.settle();
      expect(r.finisher.closed, isTrue);
      expect(r.store.rows[id]!.state, DownloadTaskState.verifying);
      expect(r.store.rows[id]!.downloadedBytes, 10000);
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
