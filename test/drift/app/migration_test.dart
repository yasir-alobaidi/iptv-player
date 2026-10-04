// `isNull` exists in both drift and matcher; the matcher is the one
// these tests mean.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/library_tables.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;
import 'generated/schema_v9.dart' as v9;

/// Every schema change adds a version, a migration, and a dump in
/// `drift_schemas/app/` (docs/02). `dart run drift_dev make-migrations`
/// writes the dump and `generated/`; this file is ours, and the tool
/// leaves it alone once it exists.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('every version migrates to every later one', () {
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final database = AppDatabase(schema.newConnection());
            addTearDown(database.close);

            await verifier.migrateAndValidate(database, toVersion);
          });
        }
      });
    }
  });

  test('the live schema matches the latest committed dump', () async {
    final connection = await verifier.startAt(GeneratedHelper.versions.last);
    final database = AppDatabase(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, GeneratedHelper.versions.last);
  });

  group('v1 → v2', () {
    const created = '2026-09-16T08:00:00.000Z';
    const source = v1.SourcesData(
      id: 'src-1',
      type: 'xtream',
      name: 'Northwind TV',
      url: 'http://northwind.test:8080',
      username: 'viewer',
      credentialRef: 'source.src-1',
      liveFormat: 'ts',
      epgOffsetMinutes: 30,
      refreshHours: 6,
      accountJson: '{"status":"Active"}',
      expiresAt: '2026-11-03T00:00:00.000Z',
      lastSyncedAt: '2026-09-17T21:00:00.000Z',
      sortOrder: 1,
      createdAt: created,
      updatedAt: created,
    );
    const setting = v1.SettingsData(
      key: 'window.bounds',
      valueJson: '{"width":1440,"height":900}',
      updatedAt: created,
    );

    test('keeps every source and setting a v1 database held', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(oldDb.sources, source)
            ..insert(oldDb.settings, setting);
        },
        validateItems: (newDb) async {
          final sources = await newDb.select(newDb.sources).get();
          final settings = await newDb.select(newDb.settings).get();

          expect(sources.map((s) => s.toJson()), [source.toJson()]);
          expect(settings.map((s) => s.toJson()), [setting.toJson()]);
        },
      );
    });

    test(
      'a migrated source takes a catalogue, and search indexes it',
      () async {
        final schema = await verifier.schemaAt(1);
        final old = v1.DatabaseAtV1(schema.newConnection());
        await old.into(old.sources).insert(source);
        await old.close();

        final database = AppDatabase(schema.newConnection());
        addTearDown(database.close);

        final categoryId = await database
            .into(database.categories)
            .insert(
              CategoriesCompanion.insert(
                sourceId: 'src-1',
                kind: CatalogueKind.live,
                remoteKey: '7',
                name: 'UK | Sports',
              ),
            );
        await database
            .into(database.channels)
            .insert(
              ChannelsCompanion.insert(
                sourceId: 'src-1',
                remoteKey: '101',
                name: 'UK: Sky Sports Main Event',
                // Sync writes it; the index holds the name shown (v7).
                cleanName: const Value('Sky Sports Main Event'),
                categoryId: Value(categoryId),
              ),
            );

        // The triggers are recreated after the upgrade rather than inside a
        // step (AppDatabase._recreateTriggers); this is the proof they ran.
        final hits = await database
            .customSelect(
              "SELECT rowid FROM channels_fts WHERE channels_fts MATCH 'spo*'",
            )
            .get();
        expect(hits, hasLength(1));

        await (database.delete(
          database.sources,
        )..where((t) => t.id.equals('src-1'))).go();
        expect(await database.select(database.channels).get(), isEmpty);
        expect(await database.select(database.categories).get(), isEmpty);
      },
    );
  });

  group('v2 → v3', () {
    const created = '2026-09-18T08:00:00.000Z';
    const source = v2.SourcesData(
      id: 'src-1',
      type: 'xtream',
      name: 'Northwind TV',
      url: 'http://northwind.test:8080',
      username: 'viewer',
      credentialRef: 'source.src-1',
      liveFormat: 'ts',
      epgOffsetMinutes: 0,
      refreshHours: 12,
      sortOrder: 0,
      createdAt: created,
      updatedAt: created,
    );
    const run = v2.SyncRunsData(
      id: 1,
      sourceId: 'src-1',
      startedAt: created,
      finishedAt: created,
      outcome: 'failed',
      failure: 'auth',
    );

    test('keeps every sync run, with no status for the old ones', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(oldDb.sources, source)
            ..insert(oldDb.syncRuns, run);
        },
        validateItems: (newDb) async {
          final runs = await newDb.select(newDb.syncRuns).get();

          expect(runs, hasLength(1));
          expect(runs.single.failure, 'auth');
          expect(runs.single.failureStatus, isNull);
          expect(runs.single.startedAt, created);
        },
      );
    });
  });

  group('v3 → v4', () {
    const created = '2026-09-19T08:00:00.000Z';
    const source = v3.SourcesData(
      id: 'src-1',
      type: 'xtream',
      name: 'Northwind TV',
      url: 'http://northwind.test:8080',
      liveFormat: 'ts',
      epgOffsetMinutes: 0,
      refreshHours: 12,
      sortOrder: 0,
      createdAt: created,
      updatedAt: created,
    );
    const channel = v3.ChannelsData(
      id: 1,
      sourceId: 'src-1',
      remoteKey: '101',
      position: 0,
      name: 'Arena Sports 1',
      archiveDays: 0,
      isHidden: 1,
    );

    test('keeps the catalogue and adds empty favorites and history', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(oldDb.sources, source)
            ..insert(oldDb.channels, channel);
        },
        validateItems: (newDb) async {
          final channels = await newDb.select(newDb.channels).get();
          expect(channels.single.name, 'Arena Sports 1');
          expect(channels.single.isHidden, 1);
          expect(await newDb.select(newDb.favorites).get(), isEmpty);
          expect(await newDb.select(newDb.watchHistory).get(), isEmpty);
        },
      );
    });
  });

  group('v4 → v5', () {
    const created = '2026-09-20T08:00:00.000Z';
    const source = v4.SourcesData(
      id: 'src-1',
      type: 'xtream',
      name: 'Northwind TV',
      url: 'http://northwind.test:8080',
      liveFormat: 'ts',
      epgOffsetMinutes: 0,
      refreshHours: 12,
      sortOrder: 0,
      createdAt: created,
      updatedAt: created,
    );
    const channel = v4.ChannelsData(
      id: 1,
      sourceId: 'src-1',
      remoteKey: '201',
      position: 0,
      name: 'Arena Sports 1',
      archiveDays: 0,
      isHidden: 0,
    );
    const favorite = v4.FavoritesData(
      id: 1,
      itemType: 'live',
      sourceId: 'src-1',
      remoteKey: '201',
      addedAt: created,
    );

    test('keeps the catalogue and adds an empty guide', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 4,
        newVersion: 5,
        createOld: v4.DatabaseAtV4.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(oldDb.sources, source)
            ..insert(oldDb.channels, channel)
            ..insert(oldDb.favorites, favorite);
        },
        validateItems: (newDb) async {
          expect(
            (await newDb.select(newDb.channels).get()).single.name,
            'Arena Sports 1',
          );
          expect(await newDb.select(newDb.favorites).get(), hasLength(1));
          expect(await newDb.select(newDb.epgImports).get(), isEmpty);
          expect(await newDb.select(newDb.epgChannels).get(), isEmpty);
          expect(await newDb.select(newDb.epgPrograms).get(), isEmpty);
          expect(await newDb.select(newDb.epgChannelsStaging).get(), isEmpty);
          expect(await newDb.select(newDb.epgProgramsStaging).get(), isEmpty);
          expect(await newDb.select(newDb.epgMappings).get(), isEmpty);
          expect(await newDb.select(newDb.epgMatches).get(), isEmpty);
        },
      );
    });

    test('a migrated database takes a guide, and search indexes it', () async {
      final schema = await verifier.schemaAt(4);
      final old = v4.DatabaseAtV4(schema.newConnection());
      await old.into(old.sources).insert(source);
      await old.close();

      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);

      // After the migration, so the catalogue's own index sees it: a row
      // written into a versioned schema is written without triggers.
      await database.channelsDao.upsertAll([
        ChannelsCompanion.insert(
          sourceId: 'src-1',
          remoteKey: '201',
          name: 'Arena Sports 1',
        ),
      ]);
      final channelId = (await database.channelsDao.byRemoteKey(
        'src-1',
        '201',
      ))!.id;

      final start = DateTime.utc(2026, 9, 20, 20);
      final run = await database.epgDao.startImport('src-1', start);
      await database.epgDao.stageChannels([
        EpgChannelsStagingCompanion.insert(
          importRun: run,
          xmltvId: 'arena.sports',
          displayName: const Value('Arena Sports 1'),
        ),
      ]);
      await database.epgDao.stagePrograms([
        EpgProgramsStagingCompanion.insert(
          importRun: run,
          epgChannelId: 'arena.sports',
          startUtc: start.millisecondsSinceEpoch,
          endUtc: start.add(const Duration(hours: 2)).millisecondsSinceEpoch,
          title: 'Continental Cup',
        ),
      ]);
      await database.epgDao.swapIn(
        sourceId: 'src-1',
        importRun: run,
        at: start,
        countsJson: (totals) => '{"programmes":${totals.programs}}',
      );
      await database
          .into(database.epgMatches)
          .insert(
            EpgMatchesCompanion.insert(
              channelId: Value(channelId),
              sourceId: 'src-1',
              xmltvId: 'arena.sports',
              rule: EpgMatchRule.exactId,
            ),
          );

      // The triggers are recreated after the upgrade rather than inside a
      // step (AppDatabase._recreateTriggers); this is the proof they ran
      // for the new index too.
      final hits = await database
          .customSelect(
            "SELECT rowid FROM programs_fts WHERE programs_fts MATCH 'cont*'",
          )
          .get();
      expect(hits, hasLength(1));

      await (database.delete(
        database.sources,
      )..where((t) => t.id.equals('src-1'))).go();
      expect(await database.select(database.epgPrograms).get(), isEmpty);
      expect(await database.select(database.epgImports).get(), isEmpty);
      expect(await database.select(database.epgMatches).get(), isEmpty);
    });
  });
  group('v5 → v6', () {
    const created = '2026-09-27T08:00:00.000Z';
    const source = v5.SourcesData(
      id: 'src-1',
      type: 'xtream',
      name: 'Northwind TV',
      url: 'http://northwind.test:8080',
      liveFormat: 'ts',
      epgOffsetMinutes: 0,
      refreshHours: 12,
      sortOrder: 0,
      createdAt: created,
      updatedAt: created,
    );
    const movie = v5.MoviesData(
      id: 1,
      sourceId: 'src-1',
      remoteKey: '501',
      position: 0,
      name: 'The Quiet Harbor',
    );
    const details = v5.MovieDetailsData(
      movieId: 1,
      plot: 'A storm strands a ferry.',
      runtimeMinutes: 118,
      fetchedAt: created,
    );
    const show = v5.SeriesData(
      id: 1,
      sourceId: 'src-1',
      remoteKey: '77',
      position: 0,
      name: 'Glass Tide',
      plot: 'A harbor inspector follows the tide logs.',
    );
    const watched = v5.WatchHistoryData(
      id: 1,
      itemType: 'movie',
      sourceId: 'src-1',
      remoteKey: '501',
      positionMs: 4360000,
      durationMs: 7080000,
      completed: 0,
      updatedAt: created,
    );

    test('keeps movies, series, details and history; the new columns start '
        'empty', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 5,
        newVersion: 6,
        createOld: v5.DatabaseAtV5.new,
        createNew: v6.DatabaseAtV6.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(oldDb.sources, source)
            ..insert(oldDb.movies, movie)
            ..insert(oldDb.movieDetails, details)
            ..insert(oldDb.series, show)
            ..insert(oldDb.watchHistory, watched);
        },
        validateItems: (newDb) async {
          final series = (await newDb.select(newDb.series).get()).single;
          expect(series.plot, 'A harbor inspector follows the tide logs.');
          expect(series.genre, isNull);
          expect(series.castNames, isNull);
          expect(series.director, isNull);
          expect(series.backdropUrl, isNull);

          final movieDetails =
              (await newDb.select(newDb.movieDetails).get()).single;
          expect(movieDetails.runtimeMinutes, 118);
          expect(movieDetails.videoHeight, isNull);
          expect(movieDetails.audioChannels, isNull);

          final history = (await newDb.select(newDb.watchHistory).get()).single;
          expect(history.positionMs, 4360000);
          expect(history.seriesKey, isNull);
          expect(history.dismissed, 0);
        },
      );
    });
  });

  group('v6 → v7', () {
    const created = '2026-09-29T08:00:00.000Z';
    const source = v6.SourcesData(
      id: 'src-1',
      type: 'xtream',
      name: 'Northwind TV',
      url: 'http://northwind.test:8080',
      liveFormat: 'ts',
      epgOffsetMinutes: 0,
      refreshHours: 12,
      sortOrder: 0,
      createdAt: created,
      updatedAt: created,
    );
    const renamed = v6.ChannelsData(
      id: 1,
      sourceId: 'src-1',
      remoteKey: '101',
      position: 0,
      name: 'UK: Harbor City Local HD',
      displayName: 'My Local',
      archiveDays: 0,
      isHidden: 0,
    );
    const hidden = v6.ChannelsData(
      id: 2,
      sourceId: 'src-1',
      remoteKey: '102',
      position: 1,
      name: 'UK: Arena Sports 1 FHD',
      archiveDays: 0,
      isHidden: 1,
    );
    const favorite = v6.FavoritesData(
      id: 1,
      itemType: 'live',
      sourceId: 'src-1',
      remoteKey: '102',
      addedAt: created,
    );

    test('keeps channels and favorites; names wait for the fill, and no '
        'favorite is in a group', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 6,
        newVersion: 7,
        createOld: v6.DatabaseAtV6.new,
        createNew: v7.DatabaseAtV7.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(oldDb.sources, source)
            ..insert(oldDb.channels, renamed)
            ..insert(oldDb.channels, hidden)
            ..insert(oldDb.favorites, favorite);
        },
        validateItems: (newDb) async {
          final channels = await (newDb.select(
            newDb.channels,
          )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
          expect(
            [for (final c in channels) c.name],
            ['UK: Harbor City Local HD', 'UK: Arena Sports 1 FHD'],
          );
          expect(channels.first.displayName, 'My Local');
          expect(channels.last.isHidden, 1);
          expect([for (final c in channels) c.cleanName], [null, null]);
          expect([for (final c in channels) c.quality], [null, null]);

          final favorites = await newDb.select(newDb.favorites).get();
          expect(favorites.single.remoteKey, '102');
          expect(favorites.single.addedAt, created);
          expect(favorites.single.groupId, isNull);
          expect(await newDb.select(newDb.favoriteGroups).get(), isEmpty);
        },
      );
    });

    test('the index holds renames at once, and cleaned names as they are '
        'filled', () async {
      final schema = await verifier.schemaAt(6);
      final old = v6.DatabaseAtV6(schema.newConnection());
      await old.into(old.sources).insert(source);
      await old.into(old.channels).insert(renamed);
      await old.into(old.channels).insert(hidden);
      await old.close();

      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);

      Future<List<int>> find(String query) async => [
        for (final row
            in await database
                .customSelect(
                  'SELECT rowid FROM channels_fts WHERE channels_fts MATCH ? '
                  'ORDER BY rowid',
                  variables: [Variable.withString(query)],
                )
                .get())
          row.read<int>('rowid'),
      ];

      // The rebuild in the step: the rename, and no provider name.
      expect(await find('"my"*'), [1]);
      expect(await find('"uk"*'), isEmpty);
      expect(await find('"arena"*'), isEmpty);

      // What the fill writes, through the triggers recreated after the
      // upgrade.
      await (database.update(
        database.channels,
      )..where((t) => t.id.equals(2))).write(
        const ChannelsCompanion(
          cleanName: Value('Arena Sports 1'),
          quality: Value('fhd'),
        ),
      );
      expect(await find('"arena"*'), [2]);
      expect(await find('"fhd"*'), isEmpty);
      await database.customStatement(
        'INSERT INTO channels_fts(channels_fts, rank) '
        "VALUES ('integrity-check', 1)",
      );

      // A group's channels stay favorites when it goes.
      final group = await database
          .into(database.favoriteGroups)
          .insert(
            FavoriteGroupsCompanion.insert(sourceId: 'src-1', name: 'Sports'),
          );
      await database
          .into(database.favorites)
          .insert(
            FavoritesCompanion.insert(
              itemType: UserItemType.live,
              sourceId: const Value('src-1'),
              remoteKey: '102',
              groupId: Value(group),
              addedAt: DateTime.utc(2026, 9, 29),
            ),
          );
      await (database.delete(
        database.favoriteGroups,
      )..where((t) => t.id.equals(group))).go();
      final kept = await database.select(database.favorites).get();
      expect(kept.single.groupId, isNull);

      // And removing the source removes its groups.
      await database
          .into(database.favoriteGroups)
          .insert(
            FavoriteGroupsCompanion.insert(sourceId: 'src-1', name: 'News'),
          );
      await (database.delete(
        database.sources,
      )..where((t) => t.id.equals('src-1'))).go();
      expect(await database.select(database.favoriteGroups).get(), isEmpty);
    });
  });

  group('v7 → v8', () {
    const created = '2026-09-29T08:00:00.000Z';
    const source = v7.SourcesData(
      id: 'src-1',
      type: 'xtream',
      name: 'Northwind TV',
      url: 'http://northwind.test:8080',
      liveFormat: 'ts',
      epgOffsetMinutes: 0,
      refreshHours: 12,
      sortOrder: 0,
      createdAt: created,
      updatedAt: created,
    );

    test('keeps the sources and adds an empty cast_devices', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 7,
        newVersion: 8,
        createOld: v7.DatabaseAtV7.new,
        createNew: v8.DatabaseAtV8.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(oldDb.sources, source),
        validateItems: (newDb) async {
          expect((await newDb.select(newDb.sources).get()).single.id, 'src-1');
          expect(await newDb.select(newDb.castDevices).get(), isEmpty);
        },
      );
    });

    test('a migrated database keeps a device with its defaults', () async {
      final schema = await verifier.schemaAt(7);
      final old = v7.DatabaseAtV7(schema.newConnection());
      await old.into(old.sources).insert(source);
      await old.close();

      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);
      await database.castDevicesDao.upsertSeen(
        id: 'aaaa',
        name: 'Living Room TV',
        host: '192.168.1.60',
        port: castPort,
        manual: true,
      );
      final row = (await database.castDevicesDao.byId('aaaa'))!;
      expect(row.lastPort, 8009);
      expect(row.isManual, isTrue);
      expect(row.hevcSupport, HevcSupport.auto);
      expect(row.learnedJson, isNull);
      expect(row.lastUsedAt, isNull);
    });
  });

  group('v8 → v9', () {
    const created = '2026-10-04T08:00:00.000Z';
    const source = v8.SourcesData(
      id: 'src-1',
      type: 'xtream',
      name: 'Northwind TV',
      url: 'http://northwind.test:8080',
      liveFormat: 'ts',
      epgOffsetMinutes: 0,
      refreshHours: 12,
      sortOrder: 0,
      createdAt: created,
      updatedAt: created,
    );
    const favorite = v8.FavoritesData(
      id: 1,
      itemType: 'movie',
      sourceId: 'src-1',
      remoteKey: '100000',
      addedAt: created,
    );
    const watched = v8.WatchHistoryData(
      id: 1,
      itemType: 'movie',
      sourceId: 'src-1',
      remoteKey: '100000',
      positionMs: 42000,
      completed: 0,
      dismissed: 0,
      updatedAt: created,
    );

    test('keeps sources, favorites and history; adds an empty library and '
        'queue', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 8,
        newVersion: 9,
        createOld: v8.DatabaseAtV8.new,
        createNew: v9.DatabaseAtV9.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(oldDb.sources, source)
            ..insert(oldDb.favorites, favorite)
            ..insert(oldDb.watchHistory, watched);
        },
        validateItems: (newDb) async {
          expect((await newDb.select(newDb.sources).get()).single.id, 'src-1');
          expect(
            (await newDb.select(newDb.favorites).get()).single.remoteKey,
            '100000',
          );
          expect(
            (await newDb.select(newDb.watchHistory).get()).single.positionMs,
            42000,
          );
          expect(await newDb.select(newDb.libraryFolders).get(), isEmpty);
          expect(await newDb.select(newDb.libraryItems).get(), isEmpty);
          expect(await newDb.select(newDb.downloads).get(), isEmpty);
        },
      );
    });

    test('a local file left with two history rows keeps the newest, and '
        'gets no third', () async {
      final schema = await verifier.schemaAt(8);
      final old = v8.DatabaseAtV8(schema.newConnection());
      for (final (id, position) in [(1, 1000), (2, 2000)]) {
        await old
            .into(old.watchHistory)
            .insert(
              v8.WatchHistoryData(
                id: id,
                itemType: 'local',
                remoteKey: 'hash-1',
                positionMs: position,
                completed: 0,
                dismissed: 0,
                updatedAt: created,
              ),
            );
      }
      await old.close();

      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);
      final rows = await database.select(database.watchHistory).get();
      expect([for (final row in rows) row.positionMs], [2000]);
      await expectLater(
        database
            .into(database.watchHistory)
            .insert(
              WatchHistoryCompanion.insert(
                itemType: UserItemType.local,
                remoteKey: 'hash-1',
                updatedAt: DateTime.utc(2026, 10, 4),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a migrated database indexes library items for search', () async {
      final schema = await verifier.schemaAt(8);
      final old = v8.DatabaseAtV8(schema.newConnection());
      await old.into(old.sources).insert(source);
      await old.close();

      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);
      final dao = database.libraryDao;
      final folder = await dao.makeDownloadFolder(
        '/home/me/Videos/IPTV Player',
        label: 'IPTV Player',
        at: DateTime.utc(2026, 10, 4),
      );
      await dao.insertItem(
        LibraryItemsCompanion.insert(
          folderId: folder.id,
          relPath: 'Movies/Paper Kites (2019)/Paper Kites (2019).mkv',
          sizeBytes: 2100000000,
          mtime: 1759564800000,
          quickHash: 'hash-1',
          kind: LibraryKind.movie,
          title: 'Paper Kites',
          addedAt: DateTime.utc(2026, 10, 4),
        ),
      );
      expect(
        [for (final row in await dao.search('kit*')) row.title],
        ['Paper Kites'],
      );
    });
  });
}
