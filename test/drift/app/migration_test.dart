// `isNull` exists in both drift and matcher; the matcher is the one
// these tests mean.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/epg_tables.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

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
                name: 'Sky Sports Main Event',
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
}
