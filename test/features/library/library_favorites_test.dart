import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/library/data/library_favorites.dart';

import '../vod/vod_test_support.dart';

void main() {
  late AppDatabase db;
  late LibraryFavorites favorites;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    favorites = LibraryFavorites(db, now: () => t0);
    await addSource(db, 'src');
  });

  LibraryItem item(String hash, {ProviderLink? provider}) => LibraryItem(
    id: 1,
    folderId: 1,
    relPath: 'a.mkv',
    sizeBytes: 1,
    modifiedAt: t0,
    quickHash: hash,
    kind: LibraryKind.movie,
    title: 'A',
    addedAt: t0,
    provider: provider,
  );

  Future<Set<String>> keys(UserItemType type) =>
      db.favoritesDao.watchKeys(type, 'src').first;

  test("a file of the user's own: a favorite by its quick hash, on and "
      'off', () async {
    final own = item('hash-lake');
    expect(await favorites.isFavorite(own), isFalse);

    await favorites.toggle(own);
    expect(await favorites.isFavorite(own), isTrue);
    expect(await favorites.watchLocalKeys().first, {'hash-lake'});
    final rows = await db.select(db.favorites).get();
    expect(rows.single.sourceId, isNull);

    await favorites.toggle(own);
    expect(await favorites.isFavorite(own), isFalse);
    expect(await db.select(db.favorites).get(), isEmpty);
  });

  test("a downloaded movie is the movie's favorite, the same one its "
      'page shows', () async {
    final download = item(
      'hash-film',
      provider: const ProviderLink(
        sourceId: 'src',
        type: VodType.movie,
        remoteKey: '100000',
      ),
    );
    await favorites.toggle(download);
    expect(await keys(UserItemType.movie), {'100000'});
    expect(await favorites.watchLocalKeys().first, isEmpty);

    // Starred on the provider's page: the download says so too.
    await favorites.toggle(download);
    await db.favoritesDao.add(UserItemType.movie, 'src', '100000', t0);
    expect(await favorites.isFavorite(download), isTrue);
  });

  test("a downloaded episode is its series' favorite; one whose series "
      "isn't known is a local file's", () async {
    final episode = item(
      'hash-ep',
      provider: const ProviderLink(
        sourceId: 'src',
        type: VodType.episode,
        remoteKey: '7201',
        seriesKey: '77',
      ),
    );
    await favorites.toggle(episode);
    expect(await keys(UserItemType.series), {'77'});
    expect(await keys(UserItemType.episode), isEmpty);

    final orphan = item(
      'hash-orphan',
      provider: const ProviderLink(
        sourceId: 'src',
        type: VodType.episode,
        remoteKey: '7202',
      ),
    );
    await favorites.toggle(orphan);
    expect(await favorites.watchLocalKeys().first, {'hash-orphan'});
  });
}
