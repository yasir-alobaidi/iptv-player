import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/tables.dart';

/// What a favorite or a history entry points at. Keyed by
/// `(source_id, remote_key)`, never by a row id, so a re-sync (which can
/// renumber rows) and the M3U identity hash keep them attached (docs/02).
enum UserItemType { live, movie, series, episode, local }

/// The user's favorites (schema v4). Sync never touches it; removing the
/// source removes them.
@DataClassName('FavoriteRow')
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get itemType => textEnum<UserItemType>()();

  /// Null only for local library files (Phase 8).
  TextColumn get sourceId =>
      text().nullable().references(Sources, #id, onDelete: KeyAction.cascade)();

  TextColumn get remoteKey => text()();

  /// The user's group of favorite channels it is in (v7); null is none.
  /// Deleting the group leaves it a favorite, in no group.
  IntColumn get groupId => integer().nullable().references(
    FavoriteGroups,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Its place in the user's order; null sorts after every placed one,
  /// by [addedAt].
  IntColumn get sortOrder => integer().nullable()();

  DateTimeColumn get addedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {itemType, sourceId, remoteKey},
  ];
}

/// The user's groups of favorite channels, per source (v7; Phase 6
/// decision 6). A table rather than a name on each favorite: a new group
/// has no channel in it yet, and the groups have an order and a collapsed
/// state of their own.
@DataClassName('FavoriteGroupRow')
class FavoriteGroups extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();
}

/// What was watched and where it stopped (schema v4). Live channels keep
/// only [updatedAt]: the last-channel key and "recently watched" read it.
@DataClassName('WatchHistoryRow')
@TableIndex(name: 'watch_history_recent', columns: {#itemType, #updatedAt})
class WatchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get itemType => textEnum<UserItemType>()();

  TextColumn get sourceId =>
      text().nullable().references(Sources, #id, onDelete: KeyAction.cascade)();

  TextColumn get remoteKey => text()();

  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  IntColumn get durationMs => integer().nullable()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// An episode's series (its remote key), so Continue watching needs no
  /// join through the episode cache, which a re-fetch replaces (v6).
  TextColumn get seriesKey => text().nullable()();

  /// Taken out of Continue watching by the user; watching it again clears
  /// it (v6).
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {itemType, sourceId, remoteKey},
  ];
}
