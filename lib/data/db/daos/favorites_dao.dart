import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';

part 'favorites_dao.g.dart';

/// The user's favorites, their order, and their groups of channels
/// (schema v7). Sync never touches either table.
///
/// **Order:** a favorite's `sort_order` is its place among the favorites
/// of its type and source in the same group (or in none); a group's is
/// its place among the source's groups. A favorite added goes to the end
/// of the ones in no group. A move numbers the list it lands in again
/// from 0, so the numbers stay small and unique; favorites from before
/// v7, with none, come after the numbered ones by when they were added.
@DriftAccessor(tables: [Favorites, FavoriteGroups])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  new(super.attachedDatabase);

  /// Adds it at the end of the favorites in no group, or does nothing
  /// when it is already a favorite.
  Future<void> add(
    UserItemType type,
    String sourceId,
    String remoteKey,
    DateTime at,
  ) => transaction(() async {
    final held = await _one(type, sourceId, remoteKey);
    if (held != null) return;
    await into(favorites).insert(
      FavoritesCompanion.insert(
        itemType: type,
        sourceId: Value(sourceId),
        remoteKey: remoteKey,
        addedAt: at,
        sortOrder: Value(await _nextPlace(type, sourceId, null)),
      ),
    );
  });

  Future<void> remove(UserItemType type, String sourceId, String remoteKey) =>
      (delete(favorites)..where(
            (t) =>
                t.itemType.equalsValue(type) &
                t.sourceId.equals(sourceId) &
                t.remoteKey.equals(remoteKey),
          ))
          .go();

  /// The remote keys of a source's favorites of [type].
  Stream<Set<String>> watchKeys(UserItemType type, String sourceId) =>
      (select(favorites)..where(
            (t) => t.itemType.equalsValue(type) & t.sourceId.equals(sourceId),
          ))
          .map((row) => row.remoteKey)
          .watch()
          .map((keys) => keys.toSet());

  /// Moves a favorite into [groupId] (null: no group) at [index] of that
  /// group's list, adding it as a favorite first when it isn't one. The
  /// list it lands in is numbered again; the one it left keeps its order.
  Future<void> move(
    UserItemType type,
    String sourceId,
    String remoteKey, {
    required int? groupId,
    required int index,
    required DateTime at,
  }) => transaction(() async {
    var moved = await _one(type, sourceId, remoteKey);
    if (moved == null) {
      await into(favorites).insert(
        FavoritesCompanion.insert(
          itemType: type,
          sourceId: Value(sourceId),
          remoteKey: remoteKey,
          addedAt: at,
        ),
      );
      moved = (await _one(type, sourceId, remoteKey))!;
    }
    final list = [
      for (final row in await _inGroup(type, sourceId, groupId))
        if (row.id != moved.id) row,
    ];
    list.insert(index.clamp(0, list.length), moved);
    await batch((b) {
      for (final (place, row) in list.indexed) {
        b.update(
          favorites,
          FavoritesCompanion(groupId: Value(groupId), sortOrder: Value(place)),
          where: (t) => t.id.equals(row.id),
        );
      }
    });
  });

  // Groups.

  /// A group at the end of the source's, empty. Returns its id.
  Future<int> createGroup(String sourceId, String name) =>
      transaction(() async {
        final last =
            await (selectOnly(favoriteGroups)
                  ..addColumns([favoriteGroups.sortOrder.max()])
                  ..where(favoriteGroups.sourceId.equals(sourceId)))
                .map((row) => row.read(favoriteGroups.sortOrder.max()))
                .getSingle();
        return await into(favoriteGroups).insert(
          FavoriteGroupsCompanion.insert(
            sourceId: sourceId,
            name: name,
            sortOrder: Value((last ?? -1) + 1),
          ),
        );
      });

  Future<void> renameGroup(int groupId, String name) =>
      (update(favoriteGroups)..where((t) => t.id.equals(groupId))).write(
        FavoriteGroupsCompanion(name: Value(name)),
      );

  Future<void> setCollapsed(int groupId, {required bool collapsed}) =>
      (update(favoriteGroups)..where((t) => t.id.equals(groupId))).write(
        FavoriteGroupsCompanion(collapsed: Value(collapsed)),
      );

  /// Puts the group at [index] of its source's, and numbers them again.
  Future<void> moveGroup(int groupId, int index) => transaction(() async {
    final group = await (select(
      favoriteGroups,
    )..where((t) => t.id.equals(groupId))).getSingleOrNull();
    if (group == null) return;
    final list = [
      for (final row in await _groups(group.sourceId))
        if (row.id != groupId) row,
    ];
    list.insert(index.clamp(0, list.length), group);
    await batch((b) {
      for (final (place, row) in list.indexed) {
        b.update(
          favoriteGroups,
          FavoriteGroupsCompanion(sortOrder: Value(place)),
          where: (t) => t.id.equals(row.id),
        );
      }
    });
  });

  /// Deletes the group. Its channels stay favorites, at the end of the
  /// ones in no group, in the order they had.
  Future<void> deleteGroup(int groupId) => transaction(() async {
    final group = await (select(
      favoriteGroups,
    )..where((t) => t.id.equals(groupId))).getSingleOrNull();
    if (group == null) return;
    final members =
        await (select(favorites)
              ..where((t) => t.groupId.equals(groupId))
              ..orderBy(_order))
            .get();
    var next = await _nextPlace(UserItemType.live, group.sourceId, null);
    await batch((b) {
      for (final row in members) {
        b.update(
          favorites,
          FavoritesCompanion(
            groupId: const Value(null),
            sortOrder: Value(next++),
          ),
          where: (t) => t.id.equals(row.id),
        );
      }
    });
    await (delete(favoriteGroups)..where((t) => t.id.equals(groupId))).go();
  });

  /// A source's groups, in their order.
  Stream<List<FavoriteGroupRow>> watchGroups(String sourceId) =>
      (select(favoriteGroups)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .watch();

  // Helpers.

  Future<FavoriteRow?> _one(
    UserItemType type,
    String sourceId,
    String remoteKey,
  ) =>
      (select(favorites)..where(
            (t) =>
                t.itemType.equalsValue(type) &
                t.sourceId.equals(sourceId) &
                t.remoteKey.equals(remoteKey),
          ))
          .getSingleOrNull();

  Future<List<FavoriteRow>> _inGroup(
    UserItemType type,
    String sourceId,
    int? groupId,
  ) =>
      (select(favorites)
            ..where(
              (t) =>
                  t.itemType.equalsValue(type) &
                  t.sourceId.equals(sourceId) &
                  (groupId == null
                      ? t.groupId.isNull()
                      : t.groupId.equals(groupId)),
            )
            ..orderBy(_order))
          .get();

  Future<List<FavoriteGroupRow>> _groups(String sourceId) =>
      (select(favoriteGroups)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .get();

  /// One more than the highest place in the list, 0 for an empty one.
  Future<int> _nextPlace(
    UserItemType type,
    String sourceId,
    int? groupId,
  ) async {
    final list = await _inGroup(type, sourceId, groupId);
    var next = 0;
    for (final row in list) {
      final place = row.sortOrder;
      if (place != null && place >= next) next = place + 1;
    }
    return next;
  }

  /// The favorites' order: placed ones by place, then the rest by when
  /// they were added.
  static final List<OrderClauseGenerator<$FavoritesTable>> _order = [
    (t) => OrderingTerm(expression: t.sortOrder.isNull()),
    (t) => OrderingTerm(expression: t.sortOrder),
    (t) => OrderingTerm(expression: t.addedAt),
    (t) => OrderingTerm(expression: t.id),
  ];

  // ---- A file of the user's own (Phase 8): no source, keyed by its
  // quick hash; one row each (the `favorites_local` index).

  Future<void> addLocal(String remoteKey, DateTime at) => transaction(() async {
    final held =
        await (select(favorites)..where(
              (t) =>
                  t.itemType.equalsValue(UserItemType.local) &
                  t.sourceId.isNull() &
                  t.remoteKey.equals(remoteKey),
            ))
            .getSingleOrNull();
    if (held != null) return;
    await into(favorites).insert(
      FavoritesCompanion.insert(
        itemType: UserItemType.local,
        remoteKey: remoteKey,
        addedAt: at,
      ),
    );
  });

  Future<void> removeLocal(String remoteKey) =>
      (delete(favorites)..where(
            (t) =>
                t.itemType.equalsValue(UserItemType.local) &
                t.sourceId.isNull() &
                t.remoteKey.equals(remoteKey),
          ))
          .go();

  /// The quick hashes of the local files that are favorites.
  Stream<Set<String>> watchLocalKeys() =>
      (select(favorites)..where(
            (t) =>
                t.itemType.equalsValue(UserItemType.local) &
                t.sourceId.isNull(),
          ))
          .map((row) => row.remoteKey)
          .watch()
          .map((keys) => keys.toSet());
}
