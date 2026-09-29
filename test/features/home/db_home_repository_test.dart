import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/home/data/db_home_repository.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/vod/data/db_movie_repository.dart';
import 'package:iptv_player/features/vod/data/db_series_repository.dart';

import 'home_fakes.dart';

void main() {
  late HomeFakes home;
  late DbHomeRepository rows;

  setUp(() async {
    home = HomeFakes();
    await home.seed();
    final db = home.db;
    rows = DbHomeRepository(
      db,
      channels: DbChannelRepository(db, clock: () => home.now),
      movies: DbMovieRepository(db, home.vod.details, clock: () => home.now),
      series: DbSeriesRepository(db, home.vod.details, clock: () => home.now),
    );
  });
  tearDown(() => home.db.close());

  test('favorite channels, again when a favorite is added', () async {
    final seen = <List<String>>[];
    final listening = rows
        .favoriteChannels('src-1')
        .listen((list) => seen.add([for (final c in list) c.name]));
    await pumpEventQueue();
    await home.db.favoritesDao.add(UserItemType.live, 'src-1', '203', home.now);
    await pumpEventQueue();
    await listening.cancel();

    expect(seen.first, ['Arena Sports 1']);
    expect(seen.last, ['Arena Sports 1', 'Velocity Motors']);
  });

  test('favorite channels follow the order the user set, groups first '
      '(Phase 6 decision 7)', () async {
    final db = home.db;
    await db.favoritesDao.add(UserItemType.live, 'src-1', '203', home.now);
    await db.favoritesDao.add(UserItemType.live, 'src-1', '202', home.now);
    final group = await db.favoritesDao.createGroup('src-1', 'Motors');
    await db.favoritesDao.move(
      UserItemType.live,
      'src-1',
      '202',
      groupId: group,
      index: 0,
      at: home.now,
    );
    await db.favoritesDao.move(
      UserItemType.live,
      'src-1',
      '201',
      groupId: null,
      index: 5,
      at: home.now,
    );

    final list = await rows.favoriteChannels('src-1').first;
    expect([for (final c in list) c.remoteKey], ['202', '203', '201']);
  });

  test('recently watched channels: newest first; hidden and gone ones '
      'left out', () async {
    Future<void> watched(String key, int minutesAgo) =>
        home.db.watchHistoryDao.touch(
          UserItemType.live,
          'src-1',
          key,
          home.now.subtract(Duration(minutes: minutesAgo)),
        );
    await watched('201', 30);
    await watched('203', 10);
    await watched('202', 20);
    await watched('999', 5);
    await home.db.customStatement(
      "UPDATE channels SET is_hidden = 1 WHERE remote_key = '202'",
    );

    final recent = await rows.recentChannels('src-1').first;
    expect(
      [for (final c in recent) c.name],
      ['Velocity Motors', 'Arena Sports 1'],
    );
  });

  test('recently watched channels: a hidden category takes its channels '
      'out, but not its favorites, at once (decision 8)', () async {
    await home.db.watchHistoryDao.touch(
      UserItemType.live,
      'src-1',
      '203',
      home.now.subtract(const Duration(minutes: 10)),
    );
    await home.db.watchHistoryDao.touch(
      UserItemType.live,
      'src-1',
      '201',
      home.now.subtract(const Duration(minutes: 20)),
    );
    final seen = <List<String>>[];
    final listening = rows
        .recentChannels('src-1')
        .listen((list) => seen.add([for (final c in list) c.remoteKey]));
    await pumpEventQueue();
    expect(seen.last, ['203', '201']);

    final sports = await (home.db.select(
      home.db.categories,
    )..where((c) => c.name.equals('Sports'))).getSingle();
    await home.db.categoriesDao.setHidden(sports.id, hidden: true);
    await pumpEventQueue();
    // 201 is a favorite: the more specific choice.
    expect(seen.last, ['201']);
    await listening.cancel();
  });

  test('recently added movies and series come newest first', () async {
    final movies = await rows.recentMovies('src-1').first;
    // 503 is in a hidden category.
    expect([for (final m in movies) m.remoteKey], ['501', '502', '504']);
    final series = await rows.recentSeries('src-1').first;
    expect([for (final s in series) s.name], ['Glass Tide']);
  });

  test('watched anything: false, then true on any source', () async {
    final seen = <bool>[];
    final listening = rows.watchedAnything().listen(seen.add);
    await pumpEventQueue();
    await home.db.watchHistoryDao.touch(
      UserItemType.movie,
      'src-1',
      '501',
      home.now,
      positionMs: 1000,
      durationMs: 5000,
      completed: false,
    );
    await pumpEventQueue();
    await listening.cancel();

    expect(seen, [false, true]);
  });

  test("a failure is the stream's error, not a throw", () async {
    await home.db.customStatement('DROP TABLE favorites');

    await expectLater(rows.favoriteChannels('src-1'), emitsError(anything));
  });
}
