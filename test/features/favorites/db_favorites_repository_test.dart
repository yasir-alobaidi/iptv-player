import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/favorites/data/db_favorites_repository.dart';
import 'package:iptv_player/features/favorites/domain/favorites.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

void main() {
  late AppDatabase db;
  late DbChannelRepository channels;
  late DbFavoritesRepository favorites;
  var clock = DateTime.utc(2026, 9, 29, 12);

  setUp(() async {
    db = AppDatabase.memory();
    clock = DateTime.utc(2026, 9, 29, 12);
    channels = DbChannelRepository(db, clock: () => clock);
    favorites = DbFavoritesRepository(db, clock: () => clock);
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: 's',
            type: SourceType.xtream,
            name: 's',
            url: 'http://s.test',
            createdAt: clock,
            updatedAt: clock,
          ),
        );
    await db.channelsDao.upsertAll([
      for (final (i, name) in ['A', 'B', 'C', 'D', 'E', 'F'].indexed)
        ChannelsCompanion.insert(
          sourceId: 's',
          remoteKey: name,
          name: 'Channel $name',
          number: Value(i + 1),
        ),
    ]);
  });
  tearDown(() => db.close());

  Future<ChannelItem> channel(String key) async =>
      (await channels.byRemoteKey('s', key)).valueOrNull!;

  Future<void> star(String key) async {
    clock = clock.add(const Duration(minutes: 1));
    await channels.setFavorite(await channel(key), on: true);
  }

  Future<List<String>> list([
    ChannelFilter filter = const FavoriteChannels(),
  ]) async => [
    for (final c in (await channels.range(
      ChannelQuery(sourceId: 's', filter: filter),
      0,
      100,
    )).valueOrNull!)
      c.remoteKey,
  ];

  Future<List<FavoriteGroup>> groups() => favorites.watchGroups('s').first;

  Future<void> move(String key, int? group, int index) async {
    await favorites.moveChannel(
      await channel(key),
      groupId: group,
      index: index,
    );
  }

  test('F adds at the end, whatever the numbers say', () async {
    for (final key in ['C', 'A', 'E']) {
      await star(key);
    }
    expect(await list(), ['C', 'A', 'E']);
    // A-Z still sorts by name.
    final byName = await channels.range(
      const ChannelQuery(
        sourceId: 's',
        filter: FavoriteChannels(),
        sort: ChannelSort.name,
      ),
      0,
      10,
    );
    expect([for (final c in byName.valueOrNull!) c.remoteKey], ['A', 'C', 'E']);
  });

  test('moves within the list, and in and out of groups', () async {
    for (final key in ['A', 'B', 'C', 'D']) {
      await star(key);
    }
    await move('D', null, 0);
    expect(await list(), ['D', 'A', 'B', 'C']);

    final sports = (await favorites.createGroup('s', ' Sports ')).valueOrNull!;
    final news = (await favorites.createGroup('s', 'News')).valueOrNull!;
    await move('B', sports, 0);
    await move('C', sports, 0);
    await move('A', news, 5);
    // Groups in their order, then the favorites in no group.
    expect(await list(), ['C', 'B', 'A', 'D']);
    expect(await list(FavoriteGroupChannels(sports)), ['C', 'B']);
    expect(await list(FavoriteGroupChannels(news)), ['A']);
    expect((await channel('C')).favoriteGroupId, sports);

    await move('C', null, 1);
    expect(await list(FavoriteGroupChannels(sports)), ['B']);
    expect(await list(), ['B', 'A', 'D', 'C']);
  });

  test('a channel moved into a group becomes a favorite', () async {
    final group = (await favorites.createGroup('s', 'Kids')).valueOrNull!;
    await move('F', group, 0);
    expect((await channel('F')).isFavorite, isTrue);
    expect(await list(), ['F']);
  });

  test('groups: their order, counts, collapse, rename, delete', () async {
    for (final key in ['A', 'B', 'C']) {
      await star(key);
    }
    final a = (await favorites.createGroup('s', 'First')).valueOrNull!;
    final b = (await favorites.createGroup('s', 'Second')).valueOrNull!;
    await move('A', a, 0);
    await move('B', b, 0);
    await move('C', b, 1);
    expect(
      [for (final g in await groups()) (g.name, g.count)],
      [('First', 1), ('Second', 2)],
    );

    await favorites.moveGroup(b, 0);
    expect([for (final g in await groups()) g.name], ['Second', 'First']);
    expect(await list(), ['B', 'C', 'A']);

    await favorites.setCollapsed(b, collapsed: true);
    await favorites.renameGroup(a, ' Kids ');
    final now = await groups();
    expect(now.first.collapsed, isTrue);
    expect(now.last.name, 'Kids');

    // A hidden channel is not counted (decision 8).
    await channels.setHidden((await channel('C')).id, hidden: true);
    expect((await groups()).first.count, 1);
    await channels.setHidden((await channel('C')).id, hidden: false);

    await star('D');
    await favorites.deleteGroup(b);
    expect([for (final g in await groups()) g.name], ['Kids']);
    // Its channels stay favorites, after the ones in no group.
    expect(await list(), ['A', 'D', 'B', 'C']);
  });

  test('favorites from before v7, with no place, come after the placed '
      'ones by when they were added', () async {
    await star('A');
    Future<void> legacy(String key, int minutes) => db
        .into(db.favorites)
        .insert(
          FavoritesCompanion.insert(
            itemType: UserItemType.live,
            sourceId: const Value('s'),
            remoteKey: key,
            addedAt: DateTime.utc(2026, 9, 1, 0, minutes),
          ),
        );
    await legacy('E', 2);
    await legacy('D', 1);
    expect(await list(), ['A', 'D', 'E']);
    await star('B');
    expect(await list(), ['A', 'B', 'D', 'E']);
  });

  test('removing the source removes its groups', () async {
    await favorites.createGroup('s', 'Gone');
    await (db.delete(db.sources)..where((t) => t.id.equals('s'))).go();
    expect(await groups(), isEmpty);
  });
}
