import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';

part 'series_dao.g.dart';

@DriftAccessor(tables: [Series, Episodes])
class SeriesDao extends DatabaseAccessor<AppDatabase> with _$SeriesDaoMixin {
  new(super.attachedDatabase);

  /// See `ChannelsDao.upsertAll`. The row id must survive: the episodes
  /// hang off it. `episodes_fetched_at` is not rewritten; a changed
  /// `updated_at` is what tells the details page the episodes are stale.
  Future<void> upsertAll(List<SeriesCompanion> rows) => batch(
    (b) => b.insertAll(
      series,
      rows,
      onConflict: DoUpdate<$SeriesTable, SeriesRow>.withExcluded(
        (old, excluded) => SeriesCompanion.custom(
          categoryId: excluded.categoryId,
          name: excluded.name,
          posterUrl: excluded.posterUrl,
          rating: excluded.rating,
          year: excluded.year,
          plot: excluded.plot,
          updatedAt: excluded.updatedAt,
          position: excluded.position,
          seenRun: excluded.seenRun,
        ),
        target: [series.sourceId, series.remoteKey],
      ),
    ),
  );

  /// Deletes the source's series that sync run [runId] did not see, and
  /// their episodes with them.
  Future<int> sweep(String sourceId, int runId) =>
      (delete(series)..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                (t.seenRun.isNull() | t.seenRun.equals(runId).not()),
          ))
          .go();

  Future<int> countFor(String sourceId) {
    final total = series.id.count();
    return (selectOnly(series)
          ..addColumns([total])
          ..where(series.sourceId.equals(sourceId)))
        .map((row) => row.read(total) ?? 0)
        .getSingle();
  }

  /// Remote key → row id for [remoteKeys] (those the source has), for
  /// filing the episodes an M3U sync upserts right after their series.
  Future<Map<String, int>> idsByRemoteKey(
    String sourceId,
    Iterable<String> remoteKeys,
  ) async {
    final query = selectOnly(series)
      ..addColumns([series.remoteKey, series.id])
      ..where(
        series.sourceId.equals(sourceId) & series.remoteKey.isIn(remoteKeys),
      );
    return {
      for (final row in await query.get())
        row.read(series.remoteKey)!: row.read(series.id)!,
    };
  }

  /// M3U only: episodes arrive with the playlist, so they are upserted and
  /// swept like every other item. One batch is one transaction. Xtream
  /// episodes use [replaceEpisodes] instead.
  Future<void> upsertEpisodes(List<EpisodesCompanion> rows) => batch(
    (b) => b.insertAll(
      episodes,
      rows,
      onConflict: DoUpdate<$EpisodesTable, EpisodeRow>.withExcluded(
        (old, excluded) => EpisodesCompanion.custom(
          season: excluded.season,
          episode: excluded.episode,
          title: excluded.title,
          ext: excluded.ext,
          durationSeconds: excluded.durationSeconds,
          plot: excluded.plot,
          stillUrl: excluded.stillUrl,
          streamUrl: excluded.streamUrl,
          extrasJson: excluded.extrasJson,
          seenRun: excluded.seenRun,
        ),
        target: [episodes.seriesId, episodes.remoteKey],
      ),
    ),
  );

  /// M3U only: deletes the source's episodes that sync run [runId] did
  /// not see. Never call it for an Xtream source — its fetched episodes
  /// carry no run and would all go.
  Future<int> sweepEpisodes(String sourceId, int runId) => customUpdate(
    'DELETE FROM episodes '
    'WHERE series_id IN (SELECT id FROM series WHERE source_id = ?) '
    'AND (seen_run IS NULL OR seen_run != ?)',
    variables: [Variable.withString(sourceId), Variable.withInt(runId)],
    updates: {episodes},
    updateKind: UpdateKind.delete,
  );

  Future<int> episodeCountFor(String sourceId) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM episodes '
      'WHERE series_id IN (SELECT id FROM series WHERE source_id = ?)',
      variables: [Variable.withString(sourceId)],
      readsFrom: {episodes, series},
    ).getSingle();
    return row.read<int>('n');
  }

  Future<SeriesRow?> byRemoteKey(String sourceId, String remoteKey) =>
      (select(series)..where(
            (t) => t.sourceId.equals(sourceId) & t.remoteKey.equals(remoteKey),
          ))
          .getSingleOrNull();

  /// In season, then episode order.
  Future<List<EpisodeRow>> episodesOf(int seriesId) =>
      (select(episodes)
            ..where((t) => t.seriesId.equals(seriesId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.season),
              (t) => OrderingTerm.asc(t.episode),
            ]))
          .get();

  /// Replaces the series' episodes with a fresh `get_series_info` answer,
  /// all or nothing. Watch history is keyed by the episode's remote key,
  /// not its row id, so replacing rows loses nothing.
  Future<void> replaceEpisodes(
    int seriesId,
    List<EpisodesCompanion> rows, {
    required DateTime fetchedAt,
  }) => transaction(() async {
    await (delete(episodes)..where((t) => t.seriesId.equals(seriesId))).go();
    await batch((b) => b.insertAll(episodes, rows));
    await (update(series)..where((t) => t.id.equals(seriesId))).write(
      SeriesCompanion(episodesFetchedAt: Value(fetchedAt)),
    );
  });
}
