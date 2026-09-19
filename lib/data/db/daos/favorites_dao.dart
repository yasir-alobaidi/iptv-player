import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';

part 'favorites_dao.g.dart';

@DriftAccessor(tables: [Favorites])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  new(super.attachedDatabase);

  /// Adds it, or does nothing when it is already a favorite.
  Future<void> add(
    UserItemType type,
    String sourceId,
    String remoteKey,
    DateTime at,
  ) => into(favorites).insert(
    FavoritesCompanion.insert(
      itemType: type,
      sourceId: Value(sourceId),
      remoteKey: remoteKey,
      addedAt: at,
    ),
    mode: InsertMode.insertOrIgnore,
  );

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
}
