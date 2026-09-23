import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/sync/epg_importer.dart';
import 'package:iptv_player/data/sync/epg_match_service.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/domain/epg_match_summary.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

const _username = 'viewer';
const _password = 'Pw-7f3a9c1e';

/// The runs the service starts, finished (or stopped) by the test.
final class _Runs {
  final started = <(String, Completer<Result<EpgMatchSummary>>)>[];
  final stopped = <String>[];

  Future<Result<EpgMatchSummary>> call(String sourceId, Future<void> stop) {
    final run = Completer<Result<EpgMatchSummary>>();
    started.add((sourceId, run));
    unawaited(
      stop.then((_) {
        stopped.add(sourceId);
        if (!run.isCompleted) run.complete(Err(CancelledFailure('stopped')));
      }),
    );
    return run.future;
  }

  List<String> get sources => [for (final (id, _) in started) id];

  void finish(int index, Result<EpgMatchSummary> result) =>
      started[index].$2.complete(result);
}

EpgMatchSummary _summary(int channels, {int exact = 0}) => EpgMatchSummary(
  channels: channels,
  byRule: {if (exact > 0) GuideMatchRule.exactId: exact},
  guideChannels: exact,
);

/// A service over test-driven runs instead of the job, and its log.
({EpgMatchService service, _Runs runs, MemoryOutput log}) _service({
  EpgMatchRunner? runner,
}) {
  final runs = _Runs();
  final output = MemoryOutput();
  final log = AppLog(output: output, secrets: SecretRegistry());
  // Never queried: the runner stands in for the job.
  final db = AppDatabase.memory();
  final service = EpgMatchService(
    database: db,
    log: log,
    runner: runner ?? runs.call,
  );
  addTearDown(() async {
    await service.dispose();
    await log.close();
    await db.close();
  });
  return (service: service, runs: runs, log: output);
}

List<String> _lines(MemoryOutput output) => [
  for (final event in output.buffer) ...event.lines,
];

// ---------------------------------------------------------- end to end

/// The whole path against the fake provider: a real file database, the
/// sync engine with the match hook wired as the app wires it, the
/// importer with the service, and the match job in its own isolate.
final class _Env {
  new _(this.directory, this.db) : memory = MemoryOutput() {
    final secrets = SecretRegistry();
    log = AppLog(output: memory, secrets: secrets);
    sources = DbSourceRepository(
      database: db,
      store: InMemoryCredentialStore(),
      secrets: secrets,
      log: log,
    );
    guide = DbEpgRepository(db, clock: () => DateTime.now().toUtc());
    matches = EpgMatchService(database: db, log: log);
    engine = SyncEngine(
      database: db,
      sources: sources,
      log: log,
      batchSize: 100,
      onSynced: (id) => afterSync.add(matches.rematch(id)),
    );
    importer = EpgImporter(
      database: db,
      guide: guide,
      sources: sources,
      log: log,
      matches: matches,
      batchSize: 500,
    );
  }

  static Future<_Env> open() async {
    final directory = await Directory.systemTemp.createTemp('epg_matching');
    final db = AppDatabase(await openAppDatabase(directory));
    final env = _Env._(directory, db);
    addTearDown(env.close);
    return env;
  }

  final Directory directory;
  final AppDatabase db;
  final MemoryOutput memory;
  late final AppLog log;
  late final DbSourceRepository sources;
  late final DbEpgRepository guide;
  late final EpgMatchService matches;
  late final SyncEngine engine;
  late final EpgImporter importer;

  /// The rematches the sync hook started, in order.
  final afterSync = <Future<Result<EpgMatchSummary>>>[];

  List<String> get logLines => [for (final e in memory.buffer) ...e.lines];

  Future<String> add(SourceDraft draft) async {
    final added = await sources.add(draft);
    expect(added.isOk, isTrue, reason: '${added.failureOrNull}');
    return added.valueOrNull!.id;
  }

  /// Syncs, then waits for the rematch the sync started.
  Future<EpgMatchSummary> sync(String sourceId) async {
    final synced = await engine.sync(sourceId);
    expect(synced.isOk, isTrue, reason: '${synced.failureOrNull}');
    final matched = await afterSync.removeLast();
    expect(matched.isOk, isTrue, reason: '${matched.failureOrNull}');
    return matched.valueOrNull!;
  }

  Future<void> import(String sourceId) async {
    final imported = await importer.importGuide(sourceId);
    expect(imported.isOk, isTrue, reason: '${imported.failureOrNull}');
  }

  /// remote key → (row id, name, guide id) for a source's channels.
  Future<Map<String, (int, String, String?)>> channels(String sourceId) async {
    final rows = await (db.select(
      db.channels,
    )..where((t) => t.sourceId.equals(sourceId))).get();
    return {
      for (final row in rows) row.remoteKey: (row.id, row.name, row.epgKey),
    };
  }

  /// channel id → (guide id, rule).
  Future<Map<int, (String, EpgMatchRule)>> matchesFor(String sourceId) async {
    final rows = await (db.select(
      db.epgMatches,
    )..where((t) => t.sourceId.equals(sourceId))).get();
    return {for (final row in rows) row.channelId: (row.xmltvId, row.rule)};
  }

  Future<void> close() async {
    await importer.dispose();
    await engine.dispose();
    await matches.dispose();
    await log.close();
    await db.close();
    await directory.delete(recursive: true);
  }
}

/// The fake provider in-process, with [liveCount] channels; every 9th
/// has no guide id, and the guide it serves has all the others.
Future<FakeProviderServer> _fakeProvider({int liveCount = 36}) async {
  final runDir = await Directory.systemTemp.createTemp('fake_provider');
  addTearDown(() => runDir.delete(recursive: true));
  final server = await FakeProviderServer.start(
    state: FakeServerState(
      profile: fakeProfiles['default']!.copyWith(
        liveCount: liveCount,
        movieCount: 10,
        seriesCount: 4,
        username: _username,
        password: _password,
      ),
      samplesDir: runDir.path,
      ffmpegPath: 'ffmpeg',
      runDir: runDir.path,
      epgDays: 1,
    ),
    port: 0,
  );
  addTearDown(server.close);
  return server;
}

SourceDraft _xtream(Object server, {String? epgUrl}) => SourceDraft(
  type: SourceType.xtream,
  name: 'Fake panel',
  url: '$server',
  username: _username,
  password: _password,
  epgUrl: epgUrl,
);

void main() {
  group('rematch', () {
    test('runs the match and answers with what it attached', () async {
      final (:service, :runs, :log) = _service();

      final matched = service.rematch('s1');
      expect(service.isMatching('s1'), isTrue);
      runs.finish(0, Ok(_summary(10, exact: 7)));

      expect((await matched).valueOrNull, _summary(10, exact: 7));
      await pumpEventQueue();
      expect(service.isMatching('s1'), isFalse);
      expect(runs.sources, ['s1']);
      final line = _lines(log).singleWhere((l) => l.contains('Guide match'));
      expect(line, contains('7 of 10 channels matched'));
      expect(line, contains('exactId 7'));
      expect(line, contains('manual 0'));
    });

    test('calls made during a run share exactly one follow-up run, which '
        'starts after they asked', () async {
      final (:service, :runs, log: _) = _service();
      final first = service.rematch('s1');
      final during = [for (var i = 0; i < 3; i++) service.rematch('s1')];
      final answered = <int>[];
      for (final (i, call) in during.indexed) {
        unawaited(call.then((_) => answered.add(i)));
      }
      await pumpEventQueue();
      expect(runs.started, hasLength(1));

      runs.finish(0, Ok(_summary(1)));
      expect((await first).valueOrNull, _summary(1));
      await pumpEventQueue();

      // The first run's result is not theirs: its inputs were read before
      // they asked.
      expect(answered, isEmpty);
      expect(runs.started, hasLength(2));
      runs.finish(1, Ok(_summary(2)));
      for (final call in during) {
        expect((await call).valueOrNull, _summary(2));
      }
      await pumpEventQueue();
      expect(runs.started, hasLength(2));
      expect(service.isMatching('s1'), isFalse);
    });

    test('a call during the follow-up queues the next one', () async {
      final (:service, :runs, log: _) = _service();
      final first = service.rematch('s1');
      final second = service.rematch('s1');
      runs.finish(0, Ok(_summary(1)));
      await first;
      await pumpEventQueue();

      final third = service.rematch('s1');
      runs.finish(1, Ok(_summary(2)));
      expect((await second).valueOrNull, _summary(2));
      await pumpEventQueue();
      expect(runs.started, hasLength(3));
      runs.finish(2, Ok(_summary(3)));
      expect((await third).valueOrNull, _summary(3));
    });

    test('sources run side by side, and never wait for each other', () async {
      final (:service, :runs, log: _) = _service();

      final one = service.rematch('s1');
      final two = service.rematch('s2');
      await pumpEventQueue();
      expect(runs.sources, ['s1', 's2']);

      runs.finish(1, Ok(_summary(2)));
      expect((await two).valueOrNull, _summary(2));
      expect(service.isMatching('s1'), isTrue);

      // s2 is idle again: a new call starts at once, s1 still running.
      final again = service.rematch('s2');
      await pumpEventQueue();
      expect(runs.sources, ['s1', 's2', 's2']);
      runs
        ..finish(2, Ok(_summary(4)))
        ..finish(0, Ok(_summary(1)));
      expect((await again).valueOrNull, _summary(4));
      expect((await one).valueOrNull, _summary(1));
    });

    test('a failed run answers its callers with the failure, logs it, and '
        'the follow-up still runs', () async {
      final (:service, :runs, :log) = _service();
      final first = service.rematch('s1');
      final second = service.rematch('s1');

      runs.finish(0, Err(StorageFailure('guide match: disk I/O error')));

      expect((await first).failureOrNull, isA<StorageFailure>());
      await pumpEventQueue();
      expect(runs.started, hasLength(2));
      runs.finish(1, Ok(_summary(3)));
      expect((await second).valueOrNull, _summary(3));
      expect(
        _lines(log).where((l) => l.contains('Guide match s1 failed')),
        hasLength(1),
      );
    });

    test('a runner that throws is a failure, not a crash', () async {
      var calls = 0;
      final (:service, runs: _, log: _) = _service(
        runner: (_, _) {
          calls++;
          throw StateError('boom');
        },
      );

      final result = await service.rematch('s1');

      expect(result.failureOrNull, isA<UnexpectedFailure>());
      await pumpEventQueue();
      expect(service.isMatching('s1'), isFalse);
      expect((await service.rematch('s1')).isOk, isFalse);
      expect(calls, 2);
    });

    test('dispose stops what runs, answers what waits, and refuses what '
        'comes after', () async {
      final (:service, :runs, :log) = _service();
      final running = service.rematch('s1');
      final queued = service.rematch('s1');
      final other = service.rematch('s2');

      await service.dispose();

      expect(runs.stopped, unorderedEquals(['s1', 's2']));
      expect((await running).failureOrNull, isA<CancelledFailure>());
      expect((await queued).failureOrNull, isA<CancelledFailure>());
      expect((await other).failureOrNull, isA<CancelledFailure>());
      await pumpEventQueue();
      // The follow-up never started.
      expect(runs.started, hasLength(2));
      expect(
        (await service.rematch('s1')).failureOrNull,
        isA<CancelledFailure>(),
      );
      expect(runs.started, hasLength(2));
      expect(_lines(log).where((l) => l.contains('cancelled')), hasLength(2));
    });
  });

  group('against the fake provider', () {
    // The Flutter test binding fakes HttpClient with 400s; these need
    // sockets.
    setUpAll(() => HttpOverrides.global = null);
    // The job's database sits beside the test's own in some runs.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    test('sync, then import: every channel with a guide id is matched to '
        'it exactly, and the log names none of them', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));

      // Before any guide: nothing to match, and nothing written.
      final beforeGuide = await env.sync(id);
      expect(beforeGuide.channels, 36);
      expect(beforeGuide.guideChannels, 0);
      expect(beforeGuide.matched, 0);
      expect(await env.matchesFor(id), isEmpty);

      await env.import(id);

      final channels = await env.channels(id);
      final matches = await env.matchesFor(id);
      final guided = [
        for (final (rowId, _, epgKey) in channels.values)
          if (epgKey != null && epgKey.isNotEmpty) (rowId, epgKey),
      ];
      expect(guided, hasLength(32));
      for (final (rowId, epgKey) in guided) {
        expect(matches[rowId], (epgKey, EpgMatchRule.exactId));
      }
      final coverage = (await env.guide.coverage(id)).valueOrNull!;
      expect(coverage.matchedChannels, matches.length);
      expect(coverage.totalChannels, 36);

      final logged = env.logLines.where((l) => l.contains('Guide match'));
      expect(logged, hasLength(2));
      for (final (_, name, epgKey) in channels.values) {
        for (final line in logged) {
          expect(line, isNot(contains(name)));
          if (epgKey != null) expect(line, isNot(contains(epgKey)));
        }
      }
    });

    test('a manual mapping survives a re-sync and a re-import', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));
      await env.sync(id);
      await env.import(id);
      final channels = await env.channels(id);
      final guided = [
        for (final MapEntry(key: remoteKey, value: (rowId, _, epgKey))
            in channels.entries)
          if (epgKey != null) (remoteKey, rowId, epgKey),
      ];
      final (remoteKey, rowId, ownId) = guided.first;
      // Another channel's guide: the matcher would never pick it.
      final elsewhere = guided.firstWhere((c) => c.$3 != ownId).$3;
      expect(
        (await env.guide.setMapping(
          sourceId: id,
          channelRemoteKey: remoteKey,
          xmltvId: elsewhere,
        )).isOk,
        isTrue,
      );

      final resynced = await env.sync(id);
      expect(resynced.of(GuideMatchRule.manual), 1);
      expect((await env.matchesFor(id))[rowId], (
        elsewhere,
        EpgMatchRule.manual,
      ));

      await env.import(id);
      final after = await env.matchesFor(id);
      expect(after[rowId], (elsewhere, EpgMatchRule.manual));
      // Its row id held through both, and the mapping is still the user's.
      expect((await env.channels(id))[remoteKey]!.$1, rowId);
      expect(
        (await env.guide.mappings(id)).valueOrNull!.single.xmltvId,
        elsewhere,
      );
    });

    test('a channel that arrives with a re-sync is matched by the rematch '
        'the sync starts', () async {
      final small = await _fakeProvider();
      final large = await _fakeProvider(liveCount: 45);
      final env = await _Env.open();
      // The guide knows all 45; the panel lists 36 of them at first.
      final draft = _xtream(
        small.url,
        epgUrl:
            '${large.url}/xmltv.php?username=$_username&password=$_password',
      );
      final id = await env.add(draft);
      await env.sync(id);
      await env.import(id);
      final before = await env.channels(id);
      expect(before, hasLength(36));

      expect(
        (await env.sources.update(
          id,
          draft.copyWith(url: '${large.url}'),
        )).isOk,
        isTrue,
      );
      final summary = await env.sync(id);

      final after = await env.channels(id);
      final arrived = {
        for (final MapEntry(:key, :value) in after.entries)
          if (!before.containsKey(key)) key: value,
      };
      expect(arrived, hasLength(9));
      final matches = await env.matchesFor(id);
      final guided = [
        for (final (rowId, _, epgKey) in arrived.values)
          if (epgKey != null) (rowId, epgKey),
      ];
      expect(guided, isNotEmpty);
      for (final (rowId, epgKey) in guided) {
        expect(matches[rowId], (epgKey, EpgMatchRule.exactId));
      }
      expect(summary.channels, 45);
      expect(summary.matched, matches.length);
    });
  });
}
