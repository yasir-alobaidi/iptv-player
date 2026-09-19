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

  /// A user-made group; null is the default list.
  TextColumn get groupName => text().nullable()();

  IntColumn get sortOrder => integer().nullable()();

  DateTimeColumn get addedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {itemType, sourceId, remoteKey},
  ];
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

  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {itemType, sourceId, remoteKey},
  ];
}
