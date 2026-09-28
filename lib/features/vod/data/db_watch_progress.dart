import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/vod/data/vod_rows.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

/// [WatchProgress] over `watch_history` (docs/02), keyed by source and
/// remote key so a re-sync or a re-fetched episode list loses nothing.
final class DbWatchProgress implements WatchProgress {
  new(this._db, {this._clock = DateTime.now});

  final AppDatabase _db;
  final DateTime Function() _clock;

  static UserItemType _type(VodRef ref) => switch (ref) {
    MovieRef() => UserItemType.movie,
    EpisodeRef() => UserItemType.episode,
  };

  @override
  Future<Result<void>> save(
    VodRef ref, {
    required Duration position,
    Duration? duration,
  }) => Result.guard(
    () => _db.watchHistoryDao.touch(
      _type(ref),
      ref.sourceId,
      ref.remoteKey,
      _clock(),
      positionMs: position.inMilliseconds,
      durationMs: duration?.inMilliseconds,
      completed: isComplete(position, duration),
      seriesKey: switch (ref) {
        EpisodeRef(:final seriesKey) => seriesKey,
        MovieRef() => null,
      },
      dismissed: false,
    ),
  );

  @override
  Future<Result<void>> setWatched(VodRef ref, {required bool watched}) =>
      Result.guard(() async {
        if (!watched) {
          await _db.watchHistoryDao.forget(
            _type(ref),
            ref.sourceId,
            ref.remoteKey,
          );
          return;
        }
        await _db.watchHistoryDao.touch(
          _type(ref),
          ref.sourceId,
          ref.remoteKey,
          _clock(),
          completed: true,
          seriesKey: switch (ref) {
            EpisodeRef(:final seriesKey) => seriesKey,
            MovieRef() => null,
          },
          dismissed: false,
        );
      });

  @override
  Stream<WatchMark?> watch(VodRef ref) => _db.watchHistoryDao
      .watchOne(_type(ref), ref.sourceId, ref.remoteKey)
      .map((row) => row == null ? null : markFromHistory(row));

  @override
  Stream<Map<String, WatchMark>> watchSeries(
    String sourceId,
    String seriesKey,
  ) => _db.watchHistoryDao
      .watchSeries(sourceId, seriesKey)
      .map(
        (rows) => {for (final row in rows) row.remoteKey: markFromHistory(row)},
      );

  @override
  Future<Result<void>> dismiss(ContinueItem item) => Result.guard(
    () => switch (item) {
      ContinueMovie(:final movie) => _db.watchHistoryDao.dismiss(
        UserItemType.movie,
        movie.sourceId,
        movie.remoteKey,
      ),
      ContinueEpisode(:final series) => _db.watchHistoryDao.dismissSeries(
        series.sourceId,
        series.remoteKey,
      ),
    },
  );

  /// Worked out again whenever the history, the catalogue or its details
  /// change: the history says what was watched, the catalogue what it is.
  @override
  Stream<List<ContinueItem>> continueWatching({int limit = 20}) => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.watchHistory,
          _db.movies,
          _db.movieDetails,
          _db.series,
          _db.episodes,
          _db.favorites,
        },
      )
      .watch()
      .asyncMap((_) => _continueWatching(limit));

  Future<List<ContinueItem>> _continueWatching(int limit) async {
    final movies = await _movies(limit);
    final episodes = await _episodes(limit);
    return ([
      ...movies,
      ...episodes,
    ]..sort((a, b) => b.at.compareTo(a.at))).take(limit).toList();
  }

  /// Movies past a minute and short of 95 % (decision 5).
  Future<List<ContinueItem>> _movies(int limit) async {
    final rows = await _db
        .customSelect(
          'SELECT $movieColumns, d.backdrop_url AS backdrop '
          '$movieFrom LEFT JOIN movie_details d ON d.movie_id = m.id '
          "WHERE h.item_type = 'movie' AND h.completed = 0 "
          'AND h.dismissed = 0 AND h.position_ms >= ? '
          'ORDER BY h.updated_at DESC LIMIT ?',
          variables: [
            Variable.withInt(resumeAfter.inMilliseconds),
            Variable.withInt(limit),
          ],
          readsFrom: {_db.watchHistory, _db.movies, _db.movieDetails},
        )
        .get();
    return [
      for (final row in rows)
        if (movieFromRow(row) case final movie when movie.watch != null)
          ContinueMovie(
            movie: movie,
            mark: movie.watch!,
            at: movie.watch!.updatedAt,
            backdropUrl: row.readNullable<String>('backdrop'),
          ),
    ];
  }

  /// Per series, its newest episode that counts — one past a minute, or
  /// finished: the one in progress, or the one after it (decision 5). A
  /// series whose last watched episode was its last has nothing to
  /// continue.
  Future<List<ContinueItem>> _episodes(int limit) async {
    final latest = await _db
        .customSelect(
          'SELECT * FROM (SELECT h.*, ROW_NUMBER() OVER '
          '(PARTITION BY h.source_id, h.series_key '
          'ORDER BY h.updated_at DESC, h.id DESC) AS rn '
          'FROM watch_history h '
          "WHERE h.item_type = 'episode' AND h.dismissed = 0 "
          'AND h.series_key IS NOT NULL '
          'AND (h.completed = 1 OR h.position_ms >= ?)) '
          'WHERE rn = 1 ORDER BY updated_at DESC LIMIT ?',
          variables: [
            Variable.withInt(resumeAfter.inMilliseconds),
            Variable.withInt(limit),
          ],
          readsFrom: {_db.watchHistory},
        )
        .asyncMap(_db.watchHistory.mapFromRow)
        .get();
    final out = <ContinueItem>[];
    for (final history in latest) {
      final sourceId = history.sourceId;
      final seriesKey = history.seriesKey;
      if (sourceId == null || seriesKey == null) continue;
      final seriesRow = await _db
          .customSelect(
            'SELECT $seriesColumns $seriesFrom '
            'WHERE s.source_id = ? AND s.remote_key = ?',
            variables: [
              Variable.withString(sourceId),
              Variable.withString(seriesKey),
            ],
            readsFrom: {_db.series, _db.favorites},
          )
          .getSingleOrNull();
      if (seriesRow == null) continue;
      final series = seriesFromRow(seriesRow);
      final watched =
          await (_db.select(_db.episodes)..where(
                (t) =>
                    t.seriesId.equals(series.id) &
                    t.remoteKey.equals(history.remoteKey),
              ))
              .getSingleOrNull();
      if (watched == null) continue;
      final EpisodeRow? target;
      if (history.completed) {
        target =
            await (_db.select(_db.episodes)
                  ..where(
                    (t) =>
                        t.seriesId.equals(series.id) &
                        (t.season.isBiggerThanValue(watched.season) |
                            (t.season.equals(watched.season) &
                                t.episode.isBiggerThanValue(watched.episode))),
                  )
                  ..orderBy([
                    (t) => OrderingTerm.asc(t.season),
                    (t) => OrderingTerm.asc(t.episode),
                    (t) => OrderingTerm.asc(t.id),
                  ])
                  ..limit(1))
                .getSingleOrNull();
      } else {
        target = watched;
      }
      if (target == null) continue;
      // The next one may have been started for a few seconds already.
      final targetHistory = identical(target, watched)
          ? history
          : await _db.watchHistoryDao.find(
              UserItemType.episode,
              sourceId,
              target.remoteKey,
            );
      final mark = targetHistory == null
          ? null
          : markFromHistory(targetHistory);
      out.add(
        ContinueEpisode(
          series: series,
          episode: episodeFromRow(
            target,
            sourceId: sourceId,
            seriesKey: seriesKey,
          ),
          mark: mark != null && mark.resumable ? mark : null,
          at: history.updatedAt,
        ),
      );
    }
    return out;
  }
}
