import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'details_state.g.dart';

/// The movie a details page is about, as the grid row knows it; null when
/// the provider no longer has it.
@riverpod
Future<Result<MovieItem?>> movieItem(
  Ref ref,
  String sourceId,
  String remoteKey,
) => ref.watch(movieRepositoryProvider).byRemoteKey(sourceId, remoteKey);

@riverpod
Future<Result<SeriesItem?>> seriesItem(
  Ref ref,
  String sourceId,
  String remoteKey,
) => ref.watch(seriesRepositoryProvider).byRemoteKey(sourceId, remoteKey);

/// A movie's details as they arrive (decision 2), keyed by the title, not
/// its row, so a favorite toggled on the page doesn't start it over.
@riverpod
Stream<Details<MovieDetails>> movieDetails(
  Ref ref,
  String sourceId,
  String remoteKey,
) async* {
  final repository = ref.watch(movieRepositoryProvider);
  final found = await repository.byRemoteKey(sourceId, remoteKey);
  switch (found) {
    case Ok(value: final movie?):
      yield* repository.details(movie);
    case Ok(value: null):
      yield DetailsFailed(NotFoundFailure('movie $remoteKey'));
    case Err(:final failure):
      yield DetailsFailed(failure);
  }
}

@riverpod
Stream<Details<SeriesDetails>> seriesDetails(
  Ref ref,
  String sourceId,
  String remoteKey,
) async* {
  final repository = ref.watch(seriesRepositoryProvider);
  final found = await repository.byRemoteKey(sourceId, remoteKey);
  switch (found) {
    case Ok(value: final series?):
      yield* repository.details(series);
    case Ok(value: null):
      yield DetailsFailed(NotFoundFailure('series $remoteKey'));
    case Err(:final failure):
      yield DetailsFailed(failure);
  }
}

/// Where a movie or an episode was left, live.
@riverpod
Stream<WatchMark?> watchMark(Ref ref, VodRef title) =>
    ref.watch(watchProgressProvider).watch(title);

/// A series' episodes' marks, live, by the episode's remote key.
@riverpod
Stream<Map<String, WatchMark>> seriesMarks(
  Ref ref,
  String sourceId,
  String seriesKey,
) => ref.watch(watchProgressProvider).watchSeries(sourceId, seriesKey);
