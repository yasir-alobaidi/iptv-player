import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/features/vod/data/title_details_source.dart';
import 'package:iptv_player/features/vod/data/vod_rows.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// A series' episodes are fetched again, behind the cached ones, a day
/// after the last fetch even when `last_modified` never moved: some panels
/// never move it, and a running series gains an episode a week (Phase 5
/// decision 2).
const seriesEpisodesFreshFor = Duration(hours: 24);

/// [SeriesRepository] over `series`, `episodes` and the favorites, with
/// `get_series_info` fetched on a page's first open.
final class DbSeriesRepository implements SeriesRepository {
  new(this._db, this._details, {this._clock = DateTime.now});

  final AppDatabase _db;
  final TitleDetailsSource _details;
  final DateTime Function() _clock;

  final _fetching = <(String, String), Future<Result<void>>>{};

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    _db.series,
    _db.categories,
    _db.favorites,
  };

  @override
  Stream<int> watchCount(TitleQuery query) {
    final (where, variables) = titleWhere(query, 's');
    final from = titleFilterFrom(
      query,
      table: 'series',
      alias: 's',
      favoriteType: 'series',
    );
    return _db
        .customSelect(
          'SELECT COUNT(*) AS n $from $where',
          variables: variables,
          readsFrom: _tables,
        )
        .watchSingle()
        .map((row) => row.read<int>('n'));
  }

  @override
  Future<Result<List<SeriesItem>>> range(
    TitleQuery query,
    int offset,
    int limit,
  ) => Result.guard(() async {
    final (_, variables) = titleWhere(query, 's');
    final rows = await _db
        .customSelect(
          titleWindow(
            query,
            table: 'series',
            alias: 's',
            favoriteType: 'series',
            columns: seriesColumns,
            joins: seriesJoins,
            added: 'updated_at',
          ),
          variables: [
            ...variables,
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
          readsFrom: _tables,
        )
        .get();
    return [for (final row in rows) seriesFromRow(row)];
  });

  @override
  Future<Result<SeriesItem?>> byRemoteKey(String sourceId, String remoteKey) =>
      Result.guard(() async {
        final row = await _db
            .customSelect(
              'SELECT $seriesColumns $seriesFrom '
              'WHERE s.source_id = ? AND s.remote_key = ?',
              variables: [
                Variable.withString(sourceId),
                Variable.withString(remoteKey),
              ],
              readsFrom: _tables,
            )
            .getSingleOrNull();
        return row == null ? null : seriesFromRow(row);
      });

  @override
  Future<Result<void>> setFavorite(SeriesItem series, {required bool on}) =>
      Result.guard(
        () => on
            ? _db.favoritesDao.add(
                UserItemType.series,
                series.sourceId,
                series.remoteKey,
                _clock(),
              )
            : _db.favoritesDao.remove(
                UserItemType.series,
                series.sourceId,
                series.remoteKey,
              ),
      );

  @override
  Stream<Details<SeriesDetails>> details(SeriesItem series) async* {
    final stored = await _read(series);
    if (stored case Err(:final failure)) {
      yield DetailsFailed(failure);
      return;
    }
    final (row, cached) = stored.valueOrNull!;
    if (row == null) {
      yield DetailsFailed(NotFoundFailure('series ${series.remoteKey}'));
      return;
    }
    if (!await _details.offers(series.sourceId)) {
      // M3U: the episodes came with the sync.
      yield DetailsReady(cached);
      return;
    }
    final fetchedAt = row.episodesFetchedAt;
    final changed =
        fetchedAt != null &&
        row.updatedAt != null &&
        row.updatedAt!.isAfter(fetchedAt);
    final fresh =
        fetchedAt != null &&
        !changed &&
        _clock().difference(fetchedAt) < seriesEpisodesFreshFor;
    if (fresh) {
      yield DetailsReady(cached);
      return;
    }
    yield fetchedAt == null
        ? const DetailsLoading()
        : DetailsReady(cached, refreshing: true);
    final fetched = await _fetch(series, row.id);
    if (fetched case Err(:final failure)) {
      // A failed refresh keeps the cache, and says nothing.
      yield fetchedAt == null ? DetailsFailed(failure) : DetailsReady(cached);
      return;
    }
    final again = await _read(series);
    yield switch (again) {
      Ok(value: (_, final details)) => DetailsReady(details),
      Err(:final failure) => DetailsFailed(failure),
    };
  }

  @override
  Future<Result<EpisodeItem?>> episodeAfter(EpisodeItem episode) =>
      Result.guard(() async {
        final found = await _db
            .customSelect(
              'SELECT e.* FROM episodes e JOIN series s ON s.id = e.series_id '
              'WHERE s.source_id = ? AND s.remote_key = ? '
              'AND (e.season > ? OR (e.season = ? AND e.episode > ?)) '
              'ORDER BY e.season, e.episode, e.id LIMIT 1',
              variables: [
                Variable.withString(episode.sourceId),
                Variable.withString(episode.seriesKey),
                Variable.withInt(episode.season),
                Variable.withInt(episode.season),
                Variable.withInt(episode.episode),
              ],
              readsFrom: {_db.episodes, _db.series},
            )
            .asyncMap(_db.episodes.mapFromRow)
            .getSingleOrNull();
        return found == null
            ? null
            : episodeFromRow(
                found,
                sourceId: episode.sourceId,
                seriesKey: episode.seriesKey,
              );
      });

  /// The series' row and what the database has for its page.
  Future<Result<(SeriesRow?, SeriesDetails)>> _read(SeriesItem series) =>
      Result.guard(() async {
        final row = await _db.seriesDao.byRemoteKey(
          series.sourceId,
          series.remoteKey,
        );
        if (row == null) return (null, const SeriesDetails());
        final episodes = await _db.seriesDao.episodesOf(row.id);
        return (
          row,
          SeriesDetails(
            seasons: seasonsOf([
              for (final episode in episodes)
                episodeFromRow(
                  episode,
                  sourceId: row.sourceId,
                  seriesKey: row.remoteKey,
                ),
            ]),
            plot: row.plot,
            cast: row.castNames,
            director: row.director,
            genre: row.genre,
            backdropUrl: row.backdropUrl,
            fetchedAt: row.episodesFetchedAt,
          ),
        );
      });

  Future<Result<void>> _fetch(SeriesItem series, int rowId) {
    final key = (series.sourceId, series.remoteKey);
    // Not `remove`: it returns this future, which would wait for itself.
    return _fetching[key] ??= _fetchAndStore(
      series,
      rowId,
    ).whenComplete(() => _fetching.removeWhere((k, _) => k == key));
  }

  Future<Result<void>> _fetchAndStore(SeriesItem series, int rowId) async {
    final answer = await _details.series(series.sourceId, series.remoteKey);
    if (answer case Err(:final failure)) return Err(failure);
    final info = answer.valueOrNull!;
    return await Result.guard(
      () => _db.seriesDao.replaceEpisodes(
        rowId,
        [for (final episode in info.episodes) _episodeRow(rowId, episode)],
        fetchedAt: _clock(),
        details: SeriesCompanion(
          plot: Value.absentIfNull(info.plot),
          genre: Value.absentIfNull(info.genre),
          castNames: Value.absentIfNull(info.cast),
          director: Value.absentIfNull(info.director),
          backdropUrl: Value.absentIfNull(info.backdropUrl),
        ),
      ),
    );
  }

  static EpisodesCompanion _episodeRow(int seriesId, XtreamEpisode episode) =>
      EpisodesCompanion.insert(
        seriesId: seriesId,
        remoteKey: episode.id,
        season: episode.season,
        episode: episode.episode,
        title: episode.title,
        ext: Value(episode.ext),
        durationSeconds: Value(episode.durationSeconds),
        plot: Value(episode.plot),
        stillUrl: Value(episode.stillUrl),
      );
}
