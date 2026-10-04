import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';

part 'watch_history_dao.g.dart';

@DriftAccessor(tables: [WatchHistory])
class WatchHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$WatchHistoryDaoMixin {
  new(super.attachedDatabase);

  /// Records that [remoteKey] was just watched: a new row, or the old one
  /// with its time (and, for VOD, its position) moved on. Only the values
  /// given are written.
  Future<void> touch(
    UserItemType type,
    String sourceId,
    String remoteKey,
    DateTime at, {
    int? positionMs,
    int? durationMs,
    bool? completed,
    String? seriesKey,
    bool? dismissed,
  }) => into(watchHistory).insert(
    WatchHistoryCompanion.insert(
      itemType: type,
      sourceId: Value(sourceId),
      remoteKey: remoteKey,
      updatedAt: at,
      positionMs: Value.absentIfNull(positionMs),
      durationMs: Value.absentIfNull(durationMs),
      completed: Value.absentIfNull(completed),
      seriesKey: Value.absentIfNull(seriesKey),
      dismissed: Value.absentIfNull(dismissed),
    ),
    onConflict: DoUpdate(
      (old) => WatchHistoryCompanion(
        updatedAt: Value(at),
        positionMs: Value.absentIfNull(positionMs),
        durationMs: Value.absentIfNull(durationMs),
        completed: Value.absentIfNull(completed),
        seriesKey: Value.absentIfNull(seriesKey),
        dismissed: Value.absentIfNull(dismissed),
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

  SimpleSelectStatement<$WatchHistoryTable, WatchHistoryRow> _one(
    UserItemType type,
    String sourceId,
    String remoteKey,
  ) => select(watchHistory)
    ..where(
      (t) =>
          t.itemType.equalsValue(type) &
          t.sourceId.equals(sourceId) &
          t.remoteKey.equals(remoteKey),
    );

  Future<WatchHistoryRow?> find(
    UserItemType type,
    String sourceId,
    String remoteKey,
  ) => _one(type, sourceId, remoteKey).getSingleOrNull();

  Stream<WatchHistoryRow?> watchOne(
    UserItemType type,
    String sourceId,
    String remoteKey,
  ) => _one(type, sourceId, remoteKey).watchSingleOrNull();

  /// A series' episodes that were ever played.
  Stream<List<WatchHistoryRow>> watchSeries(
    String sourceId,
    String seriesKey,
  ) =>
      (select(watchHistory)..where(
            (t) =>
                t.itemType.equalsValue(UserItemType.episode) &
                t.sourceId.equals(sourceId) &
                t.seriesKey.equals(seriesKey),
          ))
          .watch();

  /// Forgets that [remoteKey] was ever played ("Mark as unwatched").
  Future<int> forget(UserItemType type, String sourceId, String remoteKey) =>
      (delete(watchHistory)..where(
            (t) =>
                t.itemType.equalsValue(type) &
                t.sourceId.equals(sourceId) &
                t.remoteKey.equals(remoteKey),
          ))
          .go();

  /// Takes one title out of Continue watching.
  Future<int> dismiss(UserItemType type, String sourceId, String remoteKey) =>
      (update(watchHistory)..where(
            (t) =>
                t.itemType.equalsValue(type) &
                t.sourceId.equals(sourceId) &
                t.remoteKey.equals(remoteKey),
          ))
          .write(const WatchHistoryCompanion(dismissed: Value(true)));

  /// Takes a whole series out of Continue watching: every episode's row,
  /// or an older one would take the newest's place.
  Future<int> dismissSeries(String sourceId, String seriesKey) =>
      (update(watchHistory)..where(
            (t) =>
                t.itemType.equalsValue(UserItemType.episode) &
                t.sourceId.equals(sourceId) &
                t.seriesKey.equals(seriesKey),
          ))
          .write(const WatchHistoryCompanion(dismissed: Value(true)));

  // ---- A file of the user's own (Phase 8): no source, keyed by its
  // quick hash; one row each (the `watch_history_local` index).

  SimpleSelectStatement<$WatchHistoryTable, WatchHistoryRow> _local(
    String remoteKey,
  ) => select(watchHistory)
    ..where(
      (t) =>
          t.itemType.equalsValue(UserItemType.local) &
          t.sourceId.isNull() &
          t.remoteKey.equals(remoteKey),
    );

  /// [touch] for a local file.
  Future<void> touchLocal(
    String remoteKey,
    DateTime at, {
    int? positionMs,
    int? durationMs,
    bool? completed,
    bool? dismissed,
  }) => transaction(() async {
    final values = WatchHistoryCompanion(
      updatedAt: Value(at),
      positionMs: Value.absentIfNull(positionMs),
      durationMs: Value.absentIfNull(durationMs),
      completed: Value.absentIfNull(completed),
      dismissed: Value.absentIfNull(dismissed),
    );
    final row = await _local(remoteKey).getSingleOrNull();
    if (row == null) {
      await into(watchHistory).insert(
        values.copyWith(
          itemType: const Value(UserItemType.local),
          remoteKey: Value(remoteKey),
        ),
      );
    } else {
      await (update(
        watchHistory,
      )..where((t) => t.id.equals(row.id))).write(values);
    }
  });

  Stream<WatchHistoryRow?> watchLocal(String remoteKey) =>
      _local(remoteKey).watchSingleOrNull();

  Future<WatchHistoryRow?> findLocal(String remoteKey) =>
      _local(remoteKey).getSingleOrNull();

  Future<int> forgetLocal(String remoteKey) =>
      (delete(watchHistory)..where(
            (t) =>
                t.itemType.equalsValue(UserItemType.local) &
                t.sourceId.isNull() &
                t.remoteKey.equals(remoteKey),
          ))
          .go();

  Future<int> dismissLocal(String remoteKey) =>
      (update(watchHistory)..where(
            (t) =>
                t.itemType.equalsValue(UserItemType.local) &
                t.sourceId.isNull() &
                t.remoteKey.equals(remoteKey),
          ))
          .write(const WatchHistoryCompanion(dismissed: Value(true)));

  /// Local files watched and not dismissed, newest first.
  Future<List<WatchHistoryRow>> recentLocal({int limit = 20}) =>
      (select(watchHistory)
            ..where(
              (t) =>
                  t.itemType.equalsValue(UserItemType.local) &
                  t.sourceId.isNull() &
                  t.dismissed.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(limit))
          .get();
}
