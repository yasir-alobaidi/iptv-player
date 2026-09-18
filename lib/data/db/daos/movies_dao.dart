import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';

part 'movies_dao.g.dart';

@DriftAccessor(tables: [Movies, MovieDetails])
class MoviesDao extends DatabaseAccessor<AppDatabase> with _$MoviesDaoMixin {
  new(super.attachedDatabase);

  /// See `ChannelsDao.upsertAll`. Movies have no user-owned columns yet,
  /// but the row id must survive: `movie_details` hangs off it.
  Future<void> upsertAll(List<MoviesCompanion> rows) => batch(
    (b) => b.insertAll(
      movies,
      rows,
      onConflict: DoUpdate<$MoviesTable, MovieRow>.withExcluded(
        (old, excluded) => MoviesCompanion.custom(
          categoryId: excluded.categoryId,
          name: excluded.name,
          posterUrl: excluded.posterUrl,
          rating: excluded.rating,
          year: excluded.year,
          ext: excluded.ext,
          streamUrl: excluded.streamUrl,
          extrasJson: excluded.extrasJson,
          addedAt: excluded.addedAt,
          position: excluded.position,
          seenRun: excluded.seenRun,
        ),
        target: [movies.sourceId, movies.remoteKey],
      ),
    ),
  );

  /// Deletes the source's movies that sync run [runId] did not see, and
  /// their details with them.
  Future<int> sweep(String sourceId, int runId) =>
      (delete(movies)..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                (t.seenRun.isNull() | t.seenRun.equals(runId).not()),
          ))
          .go();

  Future<int> countFor(String sourceId) {
    final total = movies.id.count();
    return (selectOnly(movies)
          ..addColumns([total])
          ..where(movies.sourceId.equals(sourceId)))
        .map((row) => row.read(total) ?? 0)
        .getSingle();
  }

  Future<MovieRow?> byRemoteKey(String sourceId, String remoteKey) =>
      (select(movies)..where(
            (t) => t.sourceId.equals(sourceId) & t.remoteKey.equals(remoteKey),
          ))
          .getSingleOrNull();

  Future<MovieDetailsRow?> detailsFor(int movieId) => (select(
    movieDetails,
  )..where((t) => t.movieId.equals(movieId))).getSingleOrNull();

  Future<void> saveDetails(MovieDetailsCompanion details) =>
      into(movieDetails).insertOnConflictUpdate(details);
}
