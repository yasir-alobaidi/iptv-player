import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';

part 'watch_history_dao.g.dart';

/// What [WatchHistoryDao.prune] took away: channels, and films and
/// episodes.
typedef HistoryPruned = ({int channels, int titles});

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

  // ---- The tidy-up (ADR-031).

  /// Forgets what was watched long ago: channels last watched before
  /// [channelsBefore], finished films and episodes before
  /// [finishedBefore], and those never finished before [startedBefore];
  /// dismissed or not. Whatever their age, these stay:
  /// - each source's [channelsKept] newest channels: Last channel reads
  ///   the newest three after a fresh start;
  /// - each series' newest episode that counts (finished, or past
  ///   [countsFromMs]), and the newest of those still in Continue
  ///   watching: Continue watching and the series' "Continue S2 · E4"
  ///   both work out the next episode from it. Ties stay together.
  ///
  /// The user's own files (no source) are the library's: left alone.
  Future<HistoryPruned> prune({
    required DateTime channelsBefore,
    required DateTime finishedBefore,
    required DateTime startedBefore,
    required int countsFromMs,
    int channelsKept = 3,
  }) => transaction(() async {
    final channels = await customUpdate(
      "DELETE FROM watch_history WHERE item_type = 'live' "
      'AND source_id IS NOT NULL '
      'AND julianday(updated_at) < julianday(?1) '
      'AND id NOT IN (SELECT id FROM (SELECT id, ROW_NUMBER() OVER '
      '(PARTITION BY source_id ORDER BY updated_at DESC, id DESC) AS n '
      "FROM watch_history WHERE item_type = 'live' "
      'AND source_id IS NOT NULL) WHERE n <= ?2)',
      variables: [
        Variable.withDateTime(channelsBefore),
        Variable.withInt(channelsKept),
      ],
      updates: {watchHistory},
      updateKind: UpdateKind.delete,
    );
    // Ordered as Continue watching orders them (by the stored text), so
    // the row kept is the one it reads.
    final titles = await customUpdate(
      "DELETE FROM watch_history WHERE item_type IN ('movie', 'episode') "
      'AND source_id IS NOT NULL '
      'AND ((completed = 1 AND julianday(updated_at) < julianday(?1)) '
      'OR (completed = 0 AND julianday(updated_at) < julianday(?2))) '
      'AND id NOT IN (SELECT id FROM (SELECT id, dismissed, RANK() OVER '
      '(PARTITION BY source_id, series_key ORDER BY updated_at DESC) '
      'AS newest, RANK() OVER (PARTITION BY source_id, series_key, '
      'dismissed ORDER BY updated_at DESC) AS newest_here '
      "FROM watch_history WHERE item_type = 'episode' "
      'AND source_id IS NOT NULL AND series_key IS NOT NULL '
      'AND (completed = 1 OR position_ms >= ?3)) '
      'WHERE newest = 1 OR (dismissed = 0 AND newest_here = 1))',
      variables: [
        Variable.withDateTime(finishedBefore),
        Variable.withDateTime(startedBefore),
        Variable.withInt(countsFromMs),
      ],
      updates: {watchHistory},
      updateKind: UpdateKind.delete,
    );
    return (channels: channels, titles: titles);
  });

  /// Forgets every row of [types] (Settings → Data's Clear watch
  /// history), the user's own files' too. Returns how many went.
  Future<int> clear(Set<UserItemType> types) =>
      (delete(watchHistory)..where((t) => t.itemType.isInValues(types))).go();

  /// How many channels, and how many films, episodes and files of the
  /// user's own, have a row; again at every change.
  Stream<({int channels, int titles})> watchCounts() =>
      customSelect(
        "SELECT COALESCE(SUM(item_type = 'live'), 0) AS channels, "
        "COALESCE(SUM(item_type != 'live'), 0) AS titles "
        'FROM watch_history',
        readsFrom: {watchHistory},
      ).watchSingle().map(
        (row) => (
          channels: row.read<int>('channels'),
          titles: row.read<int>('titles'),
        ),
      );

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

  /// Every local file's row.
  Stream<List<WatchHistoryRow>> watchAllLocal() =>
      (select(watchHistory)..where(
            (t) =>
                t.itemType.equalsValue(UserItemType.local) &
                t.sourceId.isNull(),
          ))
          .watch();

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
