import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/favorites/domain/favorites.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// [FavoritesRepository] over `favorites` and `favorite_groups`.
final class DbFavoritesRepository implements FavoritesRepository {
  new(this._db, {this._clock = DateTime.now});

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Stream<List<FavoriteGroup>> watchGroups(String sourceId) => _db
      .customSelect(
        'SELECT g.id, g.source_id, g.name, g.collapsed, '
        '(SELECT COUNT(*) FROM favorites f JOIN channels c '
        'ON c.source_id = f.source_id AND c.remote_key = f.remote_key '
        "WHERE f.group_id = g.id AND f.item_type = 'live' "
        'AND c.is_hidden = 0) AS n '
        'FROM favorite_groups g WHERE g.source_id = ? '
        'ORDER BY g.sort_order, g.id',
        variables: [Variable.withString(sourceId)],
        readsFrom: {_db.favoriteGroups, _db.favorites, _db.channels},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            FavoriteGroup(
              id: row.read<int>('id'),
              sourceId: row.read<String>('source_id'),
              name: row.read<String>('name'),
              collapsed: row.read<bool>('collapsed'),
              count: row.read<int>('n'),
            ),
        ],
      );

  @override
  Future<Result<int>> createGroup(String sourceId, String name) =>
      Result.guard(() => _db.favoritesDao.createGroup(sourceId, name.trim()));

  @override
  Future<Result<void>> renameGroup(int groupId, String name) =>
      Result.guard(() => _db.favoritesDao.renameGroup(groupId, name.trim()));

  @override
  Future<Result<void>> moveGroup(int groupId, int index) =>
      Result.guard(() => _db.favoritesDao.moveGroup(groupId, index));

  @override
  Future<Result<void>> deleteGroup(int groupId) =>
      Result.guard(() => _db.favoritesDao.deleteGroup(groupId));

  @override
  Future<Result<void>> setCollapsed(int groupId, {required bool collapsed}) =>
      Result.guard(
        () => _db.favoritesDao.setCollapsed(groupId, collapsed: collapsed),
      );

  @override
  Future<Result<void>> moveChannel(
    ChannelItem channel, {
    required int? groupId,
    required int index,
  }) => Result.guard(
    () => _db.favoritesDao.move(
      UserItemType.live,
      channel.sourceId,
      channel.remoteKey,
      groupId: groupId,
      index: index,
      at: _clock(),
    ),
  );
}
