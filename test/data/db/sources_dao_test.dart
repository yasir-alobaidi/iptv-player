// `isNull` exists in both drift and matcher; the matcher is the one
// these tests mean.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/tables.dart';

SourcesCompanion _source(
  String id, {
  String name = 'Provider',
  int sortOrder = 0,
  SourceType type = SourceType.xtream,
}) {
  final now = DateTime.utc(2026, 9, 16);
  return SourcesCompanion.insert(
    id: id,
    type: type,
    name: name,
    url: 'http://example.test:8080',
    sortOrder: Value(sortOrder),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.memory());
  tearDown(() => database.close());

  test('stores a source and reads it back by id', () async {
    await database.sourcesDao.upsert(_source('s1', name: 'Home'));

    final row = await database.sourcesDao.byId('s1');

    expect(row?.name, 'Home');
    expect(row?.type, SourceType.xtream);
  });

  test('the defaults match the spec', () async {
    await database.sourcesDao.upsert(_source('s1'));

    final row = await database.sourcesDao.byId('s1');

    expect(row?.liveFormat, LiveFormat.ts);
    expect(row?.refreshHours, 12);
    expect(row?.epgOffsetMinutes, 0);
    expect(row?.maxConnectionsOverride, isNull);
  });

  test('holds no credential columns; only the secure-storage key', () async {
    final columns = database.sources.$columns.map((c) => c.name).toSet();

    expect(columns, contains('credential_ref'));
    expect(columns, isNot(contains('password')));
  });

  test('all() is ordered by sort order', () async {
    await database.sourcesDao.upsert(_source('b', sortOrder: 2));
    await database.sourcesDao.upsert(_source('a', sortOrder: 1));

    final rows = await database.sourcesDao.all();

    expect(rows.map((r) => r.id), ['a', 'b']);
  });

  test('upserting the same id replaces the row', () async {
    await database.sourcesDao.upsert(_source('s1', name: 'Old'));
    await database.sourcesDao.upsert(_source('s1', name: 'New'));

    expect(await database.sourcesDao.count(), 1);
    expect((await database.sourcesDao.byId('s1'))?.name, 'New');
  });

  test('patch changes only the columns it sets', () async {
    await database.sourcesDao.upsert(_source('s1', name: 'Home'));

    await database.sourcesDao.patch(
      's1',
      const SourcesCompanion(refreshHours: Value(6)),
    );

    final row = await database.sourcesDao.byId('s1');
    expect(row?.refreshHours, 6);
    expect(row?.name, 'Home');
  });

  test('markSynced records when the sync finished', () async {
    await database.sourcesDao.upsert(_source('s1'));
    final at = DateTime.utc(2026, 9, 16, 12, 30);

    await database.sourcesDao.markSynced('s1', at);

    final stored = (await database.sourcesDao.byId('s1'))?.lastSyncedAt;
    // Stored as ISO-8601 text, so it comes back as the same UTC instant
    // rather than as a local-time copy of it (ADR-008).
    expect(stored, at);
    expect(stored?.isUtc, isTrue);
  });

  test('remove deletes the row', () async {
    await database.sourcesDao.upsert(_source('s1'));

    await database.sourcesDao.remove('s1');

    expect(await database.sourcesDao.count(), 0);
  });

  test('watchAll emits after every change', () async {
    final counts = <int>[];
    final subscription = database.sourcesDao.watchAll().listen(
      (rows) => counts.add(rows.length),
    );
    // The first query runs asynchronously, so the empty list only
    // arrives once the event queue has drained.
    await pumpEventQueue();

    await database.sourcesDao.upsert(_source('a'));
    await pumpEventQueue();
    await database.sourcesDao.upsert(_source('b', sortOrder: 1));
    await pumpEventQueue();
    await subscription.cancel();

    expect(counts, [0, 1, 2]);
  });
}
