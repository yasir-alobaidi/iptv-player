// `isNull` and `isNotNull` exist in both drift and matcher; the matcher's
// are the ones these tests mean.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/watch_history_dao.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/data/db/user_tables.dart';

/// The tidy-up's DAO work (ADR-031): history by age with what Continue
/// watching and Last channel read kept, the run records cut to the
/// newest 30 a source with every row something still reads kept, and
/// the database's pages.
void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 17, 12);
  DateTime daysAgo(int days) => now.subtract(Duration(days: days));

  setUp(() async {
    db = AppDatabase.memory();
    for (final id in ['src-1', 'src-2']) {
      await db.sourcesDao.upsert(
        SourcesCompanion.insert(
          id: id,
          type: SourceType.xtream,
          name: id,
          url: 'http://$id.test',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  });
  tearDown(() => db.close());

  group('watch history: pruned by age', () {
    Future<void> channel(String key, int days, {String source = 'src-1'}) =>
        db.watchHistoryDao.touch(UserItemType.live, source, key, daysAgo(days));

    Future<void> title(
      UserItemType type,
      String key,
      int days, {
      bool completed = true,
      int positionMs = 30 * 60000,
      String? seriesKey,
      bool dismissed = false,
      String source = 'src-1',
    }) => db.watchHistoryDao.touch(
      type,
      source,
      key,
      daysAgo(days),
      positionMs: positionMs,
      durationMs: 45 * 60000,
      completed: completed,
      seriesKey: seriesKey,
      dismissed: dismissed,
    );

    Future<HistoryPruned> prune() => db.watchHistoryDao.prune(
      channelsBefore: daysAgo(90),
      finishedBefore: daysAgo(120),
      startedBefore: daysAgo(365),
      countsFromMs: 60000,
    );

    Future<Set<String>> left(UserItemType type) async => {
      for (final row in await (db.select(
        db.watchHistory,
      )..where((t) => t.itemType.equalsValue(type))).get())
        '${row.sourceId}/${row.remoteKey}',
    };

    test('a channel goes after 90 days; the newest three of each source '
        'stay whatever their age (Last channel reads them)', () async {
      for (final days in [1, 2, 3, 89, 91, 200]) {
        await channel('d$days', days);
      }
      // A source not watched for a long time keeps its last three.
      for (final days in [400, 500, 600, 700]) {
        await channel('d$days', days, source: 'src-2');
      }

      final pruned = await prune();

      expect(await left(UserItemType.live), {
        'src-1/d1',
        'src-1/d2',
        'src-1/d3',
        'src-1/d89',
        'src-2/d400',
        'src-2/d500',
        'src-2/d600',
      });
      expect(pruned.channels, 3);
      expect(pruned.titles, 0);
    });

    test('a finished film goes after 120 days, dismissed or not; one in '
        'progress after a year', () async {
      await title(UserItemType.movie, 'done-119', 119);
      await title(UserItemType.movie, 'done-121', 121);
      await title(UserItemType.movie, 'dismissed-121', 121, dismissed: true);
      await title(UserItemType.movie, 'started-200', 200, completed: false);
      await title(UserItemType.movie, 'started-364', 364, completed: false);
      await title(UserItemType.movie, 'started-366', 366, completed: false);
      await title(
        UserItemType.movie,
        'dismissed-366',
        366,
        completed: false,
        dismissed: true,
      );

      final pruned = await prune();

      expect(await left(UserItemType.movie), {
        'src-1/done-119',
        'src-1/started-200',
        'src-1/started-364',
      });
      expect(pruned.titles, 4);
    });

    test('a series keeps its newest episode that counts, however old, so '
        'its next episode is still the next; its older ones go', () async {
      for (final (i, days) in [400, 300, 200, 150].indexed) {
        await title(UserItemType.episode, 'e$i', days, seriesKey: 'glass-tide');
      }
      // A few seconds of the next one don't count: it is not the newest
      // that counts, and it is young.
      await title(
        UserItemType.episode,
        'e4',
        10,
        completed: false,
        positionMs: 12000,
        seriesKey: 'glass-tide',
      );
      // Another source's series of the same key is its own.
      await title(
        UserItemType.episode,
        'x1',
        400,
        seriesKey: 'glass-tide',
        source: 'src-2',
      );

      await prune();

      expect(await left(UserItemType.episode), {
        'src-1/e3',
        'src-1/e4',
        'src-2/x1',
      });
    });

    test('a dismissed series keeps its newest episode too, and one '
        'watched again after it keeps that one as well', () async {
      await title(
        UserItemType.episode,
        'a1',
        300,
        seriesKey: 'a',
        dismissed: true,
      );
      await title(
        UserItemType.episode,
        'a2',
        200,
        seriesKey: 'a',
        dismissed: true,
      );
      await title(UserItemType.episode, 'b1', 300, seriesKey: 'b');
      await title(
        UserItemType.episode,
        'b2',
        200,
        seriesKey: 'b',
        dismissed: true,
      );

      await prune();

      expect(await left(UserItemType.episode), {
        'src-1/a2',
        // The newest still in Continue watching, and the newest of all.
        'src-1/b1',
        'src-1/b2',
      });
    });

    test("the user's own files are the library's: left alone", () async {
      await db.watchHistoryDao.touchLocal(
        'hash-1',
        daysAgo(800),
        completed: true,
      );

      await prune();

      expect(await db.watchHistoryDao.findLocal('hash-1'), isNotNull);
    });

    test('Clear forgets the chosen kinds only, files of the library with '
        'the titles; favorites stay', () async {
      await channel('101', 1);
      await title(UserItemType.movie, 'm1', 1);
      await title(UserItemType.episode, 'e1', 1, seriesKey: 's');
      await db.watchHistoryDao.touchLocal('hash-1', now);
      await db.favoritesDao.add(UserItemType.live, 'src-1', '101', now);

      expect(await db.watchHistoryDao.clear({UserItemType.live}), 1);
      expect(await left(UserItemType.live), isEmpty);
      expect(await left(UserItemType.movie), isNotEmpty);

      expect(
        await db.watchHistoryDao.clear({
          UserItemType.movie,
          UserItemType.episode,
          UserItemType.local,
        }),
        3,
      );
      expect(await db.select(db.watchHistory).get(), isEmpty);
      expect(await db.select(db.favorites).get(), hasLength(1));
    });

    test('the counts follow the history', () async {
      final counts = <({int channels, int titles})>[];
      final watching = db.watchHistoryDao.watchCounts().listen(counts.add);
      addTearDown(watching.cancel);
      await pumpEventQueue();
      expect(counts.last, (channels: 0, titles: 0));

      await channel('101', 1);
      await channel('102', 1);
      await title(UserItemType.movie, 'm1', 1);
      await db.watchHistoryDao.touchLocal('hash-1', now);
      await pumpEventQueue();
      expect(counts.last, (channels: 2, titles: 2));

      await db.watchHistoryDao.clear({UserItemType.live});
      await pumpEventQueue();
      expect(counts.last, (channels: 0, titles: 2));
    });
  });

  group('sync runs', () {
    Future<int> run(
      String source, {
      SyncOutcome outcome = SyncOutcome.failed,
    }) async {
      final id = await db.syncRunsDao.start(source, now);
      if (outcome != SyncOutcome.running) {
        await db.syncRunsDao.finish(id, outcome: outcome, at: now);
      }
      return id;
    }

    Future<List<int>> ids(String source) async => [
      for (final row in await (db.select(
        db.syncRuns,
      )..where((t) => t.sourceId.equals(source))).get())
        row.id,
    ];

    test('each source keeps its newest 30, its last successful run (the '
        'next sync reads it) and any still running', () async {
      final succeeded = await run('src-1', outcome: SyncOutcome.succeeded);
      final running = await run('src-1', outcome: SyncOutcome.running);
      final old = [for (var i = 0; i < 5; i++) await run('src-1')];
      final newest = [for (var i = 0; i < 30; i++) await run('src-1')];
      final other = [for (var i = 0; i < 3; i++) await run('src-2')];

      final pruned = await db.syncRunsDao.prune(kept: 30);

      expect(pruned, 5);
      expect(await ids('src-1'), [succeeded, running, ...newest]);
      expect(await ids('src-2'), other);
      expect(old.toSet().intersection((await ids('src-1')).toSet()), isEmpty);
      expect(
        (await db.syncRunsDao.lastSucceeded('src-1', before: 1 << 30))?.id,
        succeeded,
      );
    });
  });

  group('guide imports', () {
    Future<int> import(
      String source, {
      SyncOutcome outcome = SyncOutcome.failed,
      bool live = false,
    }) async {
      final id = await db.epgDao.startImport(source, now);
      if (outcome != SyncOutcome.running) {
        await db.epgDao.finishImport(id, outcome: outcome, at: now);
      }
      if (live) {
        await (db.update(db.epgImports)..where((t) => t.id.equals(id))).write(
          const EpgImportsCompanion(isLive: Value(true)),
        );
      }
      return id;
    }

    Future<List<int>> ids(String source) async => [
      for (final row in await (db.select(
        db.epgImports,
      )..where((t) => t.sourceId.equals(source))).get())
        row.id,
    ];

    test('each source keeps its newest 30, the live one, and any an '
        'import still stages rows for', () async {
      final live = await import(
        'src-1',
        outcome: SyncOutcome.succeeded,
        live: true,
      );
      final staging = await import('src-1');
      await db.epgDao.stagePrograms([
        EpgProgramsStagingCompanion.insert(
          importRun: staging,
          epgChannelId: 'bbc1',
          startUtc: 0,
          endUtc: 1,
          title: 'News',
        ),
      ]);
      final channelsOnly = await import('src-1');
      await db.epgDao.stageChannels([
        EpgChannelsStagingCompanion.insert(
          importRun: channelsOnly,
          xmltvId: 'bbc1',
        ),
      ]);
      final running = await import('src-1', outcome: SyncOutcome.running);
      for (var i = 0; i < 4; i++) {
        await import('src-1');
      }
      final newest = [for (var i = 0; i < 30; i++) await import('src-1')];
      final other = [for (var i = 0; i < 2; i++) await import('src-2')];

      final pruned = await db.maintenanceDao.pruneGuideImports(kept: 30);

      expect(pruned, 4);
      expect(await ids('src-1'), [
        live,
        staging,
        channelsOnly,
        running,
        ...newest,
      ]);
      expect(await ids('src-2'), other);
      expect(await db.select(db.epgProgramsStaging).get(), hasLength(1));
      expect(await db.select(db.epgChannelsStaging).get(), hasLength(1));
    });
  });

  group('pages', () {
    test(
      "an in-memory database's pages, free ones counted, and no file",
      () async {
        await db.customStatement('CREATE TABLE filler (blob BLOB)');
        for (var i = 0; i < 64; i++) {
          await db.customStatement(
            'INSERT INTO filler VALUES (zeroblob(16384))',
          );
        }
        final full = await db.maintenanceDao.pages();
        expect(full.file, isNull);
        expect(full.freePages, 0);

        await db.customStatement('DELETE FROM filler');
        final emptied = await db.maintenanceDao.pages();
        expect(emptied.pages, full.pages);
        expect(emptied.freePages * emptied.pageSize, greaterThan(64 * 16384));

        await db.maintenanceDao.vacuum();
        await db.maintenanceDao.truncateLog();
        final compacted = await db.maintenanceDao.pages();
        expect(compacted.freePages, 0);
        expect(compacted.pages, lessThan(full.pages));
      },
    );
  });
}
