import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';

part 'watch_history_dao.g.dart';

@DriftAccessor(tables: [WatchHistory])
class WatchHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$WatchHistoryDaoMixin {
  new(super.attachedDatabase);

  /// Records that [remoteKey] was just watched: a new row, or the old one
  /// with its time (and, for VOD, its position) moved on.
  Future<void> touch(
    UserItemType type,
    String sourceId,
    String remoteKey,
    DateTime at, {
    int? positionMs,
    int? durationMs,
    bool? completed,
  }) => into(watchHistory).insert(
    WatchHistoryCompanion.insert(
      itemType: type,
      sourceId: Value(sourceId),
      remoteKey: remoteKey,
      updatedAt: at,
      positionMs: Value.absentIfNull(positionMs),
      durationMs: Value.absentIfNull(durationMs),
      completed: Value.absentIfNull(completed),
    ),
    onConflict: DoUpdate(
      (old) => WatchHistoryCompanion(
        updatedAt: Value(at),
        positionMs: Value.absentIfNull(positionMs),
        durationMs: Value.absentIfNull(durationMs),
        completed: Value.absentIfNull(completed),
      ),
      target: [
        watchHistory.itemType,
        watchHistory.sourceId,
        watchHistory.remoteKey,
      ],
    ),
  );

  /// The most recently watched of [type] on [sourceId], newest first.
  Future<List<WatchHistoryRow>> recent(
    UserItemType type,
    String sourceId, {
    int limit = 20,
  }) =>
      (select(watchHistory)
            ..where(
              (t) => t.itemType.equalsValue(type) & t.sourceId.equals(sourceId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(limit))
          .get();
}
