import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

void main() {
  late AppDatabase db;
  final t0 = DateTime.utc(2026, 9, 19, 12);

  setUp(() async {
    db = AppDatabase.memory();
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: 'src-1',
            type: SourceType.xtream,
            name: 'Northwind',
            url: 'http://n.test',
            createdAt: t0,
            updatedAt: t0,
          ),
        );
  });
  tearDown(() => db.close());

  test('a favorite is added once, watched, and removed', () async {
    final keys = <Set<String>>[];
    final watching = db.favoritesDao
        .watchKeys(UserItemType.live, 'src-1')
        .listen(keys.add);
    addTearDown(watching.cancel);

    await db.favoritesDao.add(UserItemType.live, 'src-1', '101', t0);
    await db.favoritesDao.add(UserItemType.live, 'src-1', '101', t0);
    await db.favoritesDao.add(UserItemType.movie, 'src-1', '101', t0);
    await pumpEventQueue();
    expect(keys.last, {'101'});

    await db.favoritesDao.remove(UserItemType.live, 'src-1', '101');
    await pumpEventQueue();
    expect(keys.last, isEmpty);
    expect(await db.select(db.favorites).get(), hasLength(1));
  });

  test('history keeps one row per item, newest first', () async {
    final dao = db.watchHistoryDao;
    await dao.touch(UserItemType.live, 'src-1', '101', t0);
    await dao.touch(UserItemType.live, 'src-1', '102', t0.add(_minute));
    await dao.touch(UserItemType.live, 'src-1', '101', t0.add(_minute * 2));

    final recent = await dao.recent(UserItemType.live, 'src-1');

    expect(recent.map((r) => r.remoteKey), ['101', '102']);
    expect(recent.first.updatedAt, t0.add(_minute * 2));
  });

  test('VOD history keeps the position a later touch leaves out', () async {
    final dao = db.watchHistoryDao;
    await dao.touch(
      UserItemType.movie,
      'src-1',
      '9',
      t0,
      positionMs: 60000,
      durationMs: 5400000,
    );
    await dao.touch(UserItemType.movie, 'src-1', '9', t0.add(_minute));

    final row = (await dao.recent(UserItemType.movie, 'src-1')).single;
    expect(row.positionMs, 60000);
    expect(row.durationMs, 5400000);
  });

  test('removing the source removes its favorites and history', () async {
    await db.favoritesDao.add(UserItemType.live, 'src-1', '101', t0);
    await db.watchHistoryDao.touch(UserItemType.live, 'src-1', '101', t0);

    await (db.delete(db.sources)..where((s) => s.id.equals('src-1'))).go();

    expect(await db.select(db.favorites).get(), isEmpty);
    expect(await db.select(db.watchHistory).get(), isEmpty);
  });
}

const _minute = Duration(minutes: 1);
