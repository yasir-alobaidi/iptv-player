import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/features/sources/data/db_category_repository.dart';

final _now = DateTime.utc(2026, 9, 18, 9);

void main() {
  late AppDatabase db;
  late DbCategoryRepository repository;
  late Map<String, int> ids;

  setUp(() async {
    db = AppDatabase.memory();
    repository = DbCategoryRepository(db);
    await db.sourcesDao.upsert(
      SourcesCompanion.insert(
        id: 's1',
        type: SourceType.xtream,
        name: 'Northwind',
        url: 'http://line.test',
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await db.categoriesDao.upsertAll([
      for (final (i, name) in ['UK | Sports', 'UK | News', 'Music'].indexed)
        CategoriesCompanion.insert(
          sourceId: 's1',
          kind: CatalogueKind.live,
          remoteKey: '$i',
          name: name,
          position: Value(i),
        ),
      CategoriesCompanion.insert(
        sourceId: 's1',
        kind: CatalogueKind.movie,
        remoteKey: '9',
        name: 'Action',
      ),
    ]);
    ids = await db.categoriesDao.idsByRemoteKey('s1', CatalogueKind.live);
    await db.channelsDao.upsertAll([
      for (var i = 0; i < 5; i++)
        ChannelsCompanion.insert(
          sourceId: 's1',
          remoteKey: 'c$i',
          name: 'Channel $i',
          categoryId: Value(i < 3 ? ids['0'] : (i == 3 ? ids['1'] : null)),
        ),
    ]);
    await db.categoriesDao.rename(ids['2']!, 'My music');
  });
  tearDown(() => db.close());

  test('lists categories in order with their counts and renames', () async {
    final list = await repository.watch('s1', CatalogueKind.live).first;

    expect(
      [for (final c in list.categories) c.name],
      ['UK | Sports', 'UK | News', 'My music'],
    );
    expect([for (final c in list.categories) c.itemCount], [3, 1, 0]);
    expect(list.uncategorized, 1);
    expect(list.categories.every((c) => !c.isHidden), isTrue);
  });

  test('each write shows up in the stream', () async {
    final lists = repository.watch('s1', CatalogueKind.live);
    final seen = <List<bool>>[];
    final sub = lists.listen(
      (l) => seen.add([for (final c in l.categories) c.isHidden]),
    );
    await pumpEventQueue();

    expect(
      await repository.setHidden(ids['0']!, hidden: true),
      isA<Ok<void>>(),
    );
    await pumpEventQueue();
    await repository.setHiddenMany([ids['1']!, ids['2']!], hidden: true);
    await pumpEventQueue();
    await repository.setAllHidden('s1', CatalogueKind.live, hidden: false);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [
      [false, false, false],
      [true, false, false],
      [true, true, true],
      [false, false, false],
    ]);
    // Only live categories were touched.
    final movies = await repository.watch('s1', CatalogueKind.movie).first;
    expect(movies.categories.single.isHidden, isFalse);
  });

  test('a write to a closed database is a StorageFailure', () async {
    await db.close();
    final result = await repository.setHidden(1, hidden: true);
    expect(result.failureOrNull, isA<StorageFailure>());
    // setUp's tearDown closes it again; a second close is harmless.
    db = AppDatabase.memory();
  });
}
