import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/features/vod/data/title_details_source.dart';
import 'package:iptv_player/features/vod/data/vod_rows.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// A movie's details are fetched again, behind the cached copy, once they
/// are this old (Phase 5 decision 2).
const movieDetailsFreshFor = Duration(days: 7);

/// [MovieRepository] over `movies`, `movie_details`, the favorites and the
/// history, with `get_vod_info` fetched on a page's first open.
final class DbMovieRepository implements MovieRepository {
  new(this._db, this._details, {this._clock = DateTime.now});

  final AppDatabase _db;
  final TitleDetailsSource _details;
  final DateTime Function() _clock;

  /// One fetch per movie at a time; a second page joins it.
  final _fetching = <(String, String), Future<Result<MovieDetails?>>>{};

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    _db.movies,
    _db.categories,
    _db.favorites,
    _db.watchHistory,
  };

  @override
  Stream<int> watchCount(TitleQuery query) {
    final (where, variables) = titleWhere(query, 'm');
    final from = titleFilterFrom(
      query,
      table: 'movies',
      alias: 'm',
      favoriteType: 'movie',
    );
    // Reads the history too, though the count doesn't: a change there is
    // what tells the grid to read its window again.
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
  Future<Result<List<MovieItem>>> range(
    TitleQuery query,
    int offset,
    int limit,
  ) => Result.guard(() async {
    final (_, variables) = titleWhere(query, 'm');
    final rows = await _db
        .customSelect(
          titleWindow(
            query,
            table: 'movies',
            alias: 'm',
            favoriteType: 'movie',
            columns: movieColumns,
            joins: movieJoins,
            added: 'added_at',
          ),
          variables: [
            ...variables,
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
          readsFrom: _tables,
        )
        .get();
    return [for (final row in rows) movieFromRow(row)];
  });

  @override
  Future<Result<MovieItem?>> byRemoteKey(String sourceId, String remoteKey) =>
      Result.guard(() async {
        final row = await _db
            .customSelect(
              'SELECT $movieColumns $movieFrom '
              'WHERE m.source_id = ? AND m.remote_key = ?',
              variables: [
                Variable.withString(sourceId),
                Variable.withString(remoteKey),
              ],
              readsFrom: _tables,
            )
            .getSingleOrNull();
        return row == null ? null : movieFromRow(row);
      });

  @override
  Future<Result<void>> setFavorite(MovieItem movie, {required bool on}) =>
      Result.guard(
        () => on
            ? _db.favoritesDao.add(
                UserItemType.movie,
                movie.sourceId,
                movie.remoteKey,
                _clock(),
              )
            : _db.favoritesDao.remove(
                UserItemType.movie,
                movie.sourceId,
                movie.remoteKey,
              ),
      );

  @override
  Stream<Details<MovieDetails>> details(MovieItem movie) async* {
    final stored = await Result.guard(() => _db.moviesDao.detailsFor(movie.id));
    if (stored case Err(:final failure)) {
      yield DetailsFailed(failure);
      return;
    }
    final cached = switch (stored.valueOrNull) {
      final row? => _fromRow(row),
      null => null,
    };
    final fetchedAt = cached?.fetchedAt;
    if (fetchedAt != null &&
        _clock().difference(fetchedAt) < movieDetailsFreshFor) {
      yield DetailsReady(cached!);
      return;
    }
    if (!await _details.offers(movie.sourceId)) {
      // M3U: what the playlist gave is all there is.
      yield DetailsReady(cached ?? const MovieDetails());
      return;
    }
    yield cached == null
        ? const DetailsLoading()
        : DetailsReady(cached, refreshing: true);
    final fetched = await _fetch(movie);
    switch (fetched) {
      case Ok(:final value):
        yield DetailsReady(value ?? cached ?? const MovieDetails());
      case Err(:final failure):
        // A failed refresh keeps the cache, and says nothing.
        yield cached == null ? DetailsFailed(failure) : DetailsReady(cached);
    }
  }

  Future<Result<MovieDetails?>> _fetch(MovieItem movie) {
    final key = (movie.sourceId, movie.remoteKey);
    // Not `remove`: it returns this future, which would wait for itself.
    return _fetching[key] ??= _fetchAndStore(movie)
        .whenComplete(() => _fetching.removeWhere((k, _) => k == key));
  }

  Future<Result<MovieDetails?>> _fetchAndStore(MovieItem movie) async {
    final answer = await _details.movie(movie.sourceId, movie.remoteKey);
    if (answer case Err(:final failure)) return Err(failure);
    final info = answer.valueOrNull!;
    final at = _clock();
    final details = _fromInfo(info, fetchedAt: at);
    // Stored by the row id the list gave; a movie a sync removed in the
    // meantime has nothing to store under, and still gets its page.
    await Result.guard(
      () => _db.moviesDao.saveDetails(
        MovieDetailsCompanion.insert(
          movieId: Value(movie.id),
          plot: Value(info.plot),
          castNames: Value(info.cast),
          director: Value(info.director),
          genre: Value(info.genre),
          runtimeMinutes: Value(info.runtimeMinutes),
          backdropUrl: Value(info.backdropUrl),
          videoHeight: Value(info.videoHeight),
          audioChannels: Value(info.audioChannels),
          fetchedAt: at,
        ),
      ),
    );
    return Ok(details);
  }

  static MovieDetails _fromInfo(
    XtreamMovieInfo info, {
    required DateTime fetchedAt,
  }) => MovieDetails(
    plot: info.plot,
    cast: info.cast,
    director: info.director,
    genre: info.genre,
    runtime: info.runtimeMinutes == null
        ? null
        : Duration(minutes: info.runtimeMinutes!),
    backdropUrl: info.backdropUrl,
    videoHeight: info.videoHeight,
    audioChannels: info.audioChannels,
    fetchedAt: fetchedAt,
  );

  static MovieDetails _fromRow(MovieDetailsRow row) => MovieDetails(
    plot: row.plot,
    cast: row.castNames,
    director: row.director,
    genre: row.genre,
    runtime: row.runtimeMinutes == null
        ? null
        : Duration(minutes: row.runtimeMinutes!),
    backdropUrl: row.backdropUrl,
    videoHeight: row.videoHeight,
    audioChannels: row.audioChannels,
    fetchedAt: row.fetchedAt,
  );
}
