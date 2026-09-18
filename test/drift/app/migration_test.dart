// `isNull` exists in both drift and matcher; the matcher is the one
// these tests mean.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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
}
