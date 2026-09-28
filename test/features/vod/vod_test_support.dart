import 'dart:async';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/vod/data/title_details_source.dart';

final t0 = DateTime.utc(2026, 9, 27, 20);

/// A [TitleDetailsSource] a test scripts: what it answers, whether it
/// waits for [gate], and how often it was asked.
final class ScriptedDetails implements TitleDetailsSource {
  bool xtream = true;
  int movieCalls = 0;
  int seriesCalls = 0;
  Result<XtreamMovieInfo> movieAnswer = const Ok(
    XtreamMovieInfo(plot: 'A storm strands a ferry.', runtimeMinutes: 118),
  );
  Result<XtreamSeriesInfo> seriesAnswer = const Ok(XtreamSeriesInfo());

  /// Holds every answer until completed.
  Completer<void>? gate;

  @override
  Future<bool> offers(String sourceId) async => xtream;

  @override
  Future<Result<XtreamMovieInfo>> movie(
    String sourceId,
    String remoteKey,
  ) async {
    movieCalls++;
    await gate?.future;
    return movieAnswer;
  }

  @override
  Future<Result<XtreamSeriesInfo>> series(
    String sourceId,
    String remoteKey,
  ) async {
    seriesCalls++;
    await gate?.future;
    return seriesAnswer;
  }
}

Future<void> addSource(AppDatabase db, String id) => db
    .into(db.sources)
    .insert(
      SourcesCompanion.insert(
        id: id,
        type: SourceType.xtream,
        name: id,
        url: 'http://$id.test',
        createdAt: t0,
        updatedAt: t0,
      ),
    );

Future<int> addCategory(
  AppDatabase db,
  String sourceId,
  CatalogueKind kind,
  String remoteKey,
  String name, {
  bool hidden = false,
}) => db
    .into(db.categories)
    .insert(
      CategoriesCompanion.insert(
        sourceId: sourceId,
        kind: kind,
        remoteKey: remoteKey,
        name: name,
        isHidden: Value(hidden),
      ),
    );

Future<int> addMovie(
  AppDatabase db,
  String remoteKey,
  String name, {
  String source = 'src',
  int? category,
  double? rating,
  DateTime? added,
  String ext = 'mkv',
  int? year,
}) => db
    .into(db.movies)
    .insert(
      MoviesCompanion.insert(
        sourceId: source,
        remoteKey: remoteKey,
        name: name,
        categoryId: Value(category),
        rating: Value(rating),
        addedAt: Value(added),
        ext: Value(ext),
        year: Value(year),
      ),
    );

Future<int> addSeries(
  AppDatabase db,
  String remoteKey,
  String name, {
  String source = 'src',
  int? category,
  double? rating,
  DateTime? updated,
}) => db
    .into(db.series)
    .insert(
      SeriesCompanion.insert(
        sourceId: source,
        remoteKey: remoteKey,
        name: name,
        categoryId: Value(category),
        rating: Value(rating),
        updatedAt: Value(updated),
      ),
    );

/// `(season, episode)` pairs as fetched episodes of [seriesId], keyed
/// `e<season>-<episode>`.
Future<void> addEpisodes(
  AppDatabase db,
  int seriesId,
  List<(int, int)> numbers, {
  DateTime? fetchedAt,
}) => db.seriesDao.replaceEpisodes(seriesId, [
  for (final (season, episode) in numbers)
    EpisodesCompanion.insert(
      seriesId: seriesId,
      remoteKey: 'e$season-$episode',
      season: season,
      episode: episode,
      title: 'Episode $episode',
      durationSeconds: const Value(3000),
    ),
], fetchedAt: fetchedAt ?? t0);
