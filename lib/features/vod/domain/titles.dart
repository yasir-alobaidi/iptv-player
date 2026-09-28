import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

part 'titles.freezed.dart';

/// How long a NEW badge stays on a title (docs/05's grid).
const newTitleFor = Duration(days: 7);

/// One movie as the grid, Home and the details page show it.
@freezed
abstract class MovieItem with _$MovieItem {
  const factory({
    /// The database row id: stable within a sync, not across them. User
    /// data is keyed by [sourceId] + [remoteKey].
    required int id,
    required String sourceId,
    required String remoteKey,
    required String name,
    String? posterUrl,

    /// Out of 10.
    double? rating,
    int? year,

    /// The container extension the stream URL needs (`mkv`).
    String? ext,
    int? categoryId,
    DateTime? addedAt,
    @Default(false) bool isFavorite,

    /// Where it was left, when it was ever played.
    WatchMark? watch,
  }) = _MovieItem;

  const new _();

  MovieRef get ref => MovieRef(sourceId, remoteKey);

  bool isNewAt(DateTime now) =>
      addedAt != null && now.difference(addedAt!) < newTitleFor;
}

/// `get_vod_info`, as the details page shows it. Every field can be
/// missing: a panel with no metadata, or an M3U source, has none.
@freezed
abstract class MovieDetails with _$MovieDetails {
  const factory({
    String? plot,
    String? cast,
    String? director,
    String? genre,
    Duration? runtime,
    String? backdropUrl,

    /// From the panel's probe of the file: 2160 is the 4K badge, 1080 FHD.
    int? videoHeight,

    /// 6 is the 5.1 badge.
    int? audioChannels,

    /// When it was fetched; null when there was nothing to fetch (M3U).
    DateTime? fetchedAt,
  }) = _MovieDetails;
}

@freezed
abstract class SeriesItem with _$SeriesItem {
  const factory({
    required int id,
    required String sourceId,
    required String remoteKey,
    required String name,
    String? posterUrl,
    double? rating,
    int? year,
    String? plot,
    String? genre,
    String? backdropUrl,
    int? categoryId,

    /// The provider's `last_modified`.
    DateTime? updatedAt,
    @Default(false) bool isFavorite,
  }) = _SeriesItem;

  const new _();

  bool isNewAt(DateTime now) =>
      updatedAt != null && now.difference(updatedAt!) < newTitleFor;
}

@freezed
abstract class EpisodeItem with _$EpisodeItem {
  const factory({
    required int id,
    required String sourceId,

    /// The series' remote key.
    required String seriesKey,
    required String remoteKey,
    required int season,
    required int episode,
    required String title,
    String? ext,
    Duration? duration,
    String? plot,
    String? stillUrl,
  }) = _EpisodeItem;

  const new _();

  EpisodeRef get ref => EpisodeRef(sourceId, remoteKey, seriesKey: seriesKey);
}

@freezed
abstract class Season with _$Season {
  const factory({required int number, required List<EpisodeItem> episodes}) =
      _Season;
}

/// `get_series_info` with the list row's own fields, as the details page
/// shows it: the seasons in order, each with its episodes in order.
@freezed
abstract class SeriesDetails with _$SeriesDetails {
  const factory({
    @Default(<Season>[]) List<Season> seasons,
    String? plot,
    String? cast,
    String? director,
    String? genre,
    String? backdropUrl,

    /// When the episodes were fetched; null for an M3U source, whose
    /// episodes came with the sync.
    DateTime? fetchedAt,
  }) = _SeriesDetails;

  const new _();

  int get episodeCount =>
      seasons.fold(0, (count, season) => count + season.episodes.length);
}

/// A source's movies, for a grid that can hold 30,000 posters: a count,
/// then the window on screen (hard rule 2). Nothing throws across this
/// boundary.
abstract interface class MovieRepository {
  /// How many movies [query] matches, again after every change to the
  /// movies, their categories, the favorites or what was watched.
  Stream<int> watchCount(TitleQuery query);

  /// [limit] movies from [offset], in [query]'s order.
  Future<Result<List<MovieItem>>> range(
    TitleQuery query,
    int offset,
    int limit,
  );

  Future<Result<MovieItem?>> byRemoteKey(String sourceId, String remoteKey);

  Future<Result<void>> setFavorite(MovieItem movie, {required bool on});

  /// [movie]'s details (Phase 5 decision 2): the database's copy at once,
  /// fetched from the provider the first time, and again behind the
  /// cached copy once it is a week old. Two pages asking at once share
  /// one request.
  Stream<Details<MovieDetails>> details(MovieItem movie);
}

abstract interface class SeriesRepository {
  Stream<int> watchCount(TitleQuery query);

  Future<Result<List<SeriesItem>>> range(
    TitleQuery query,
    int offset,
    int limit,
  );

  Future<Result<SeriesItem?>> byRemoteKey(String sourceId, String remoteKey);

  Future<Result<void>> setFavorite(SeriesItem series, {required bool on});

  /// [series]' seasons and episodes (decision 2): the database's copy at
  /// once, fetched the first time, and again behind it when the list's
  /// `last_modified` moved past the fetch or a day has gone by.
  Stream<Details<SeriesDetails>> details(SeriesItem series);

  /// The episode after [episode]: the next in its season, else the first
  /// of the next season; null after the last.
  Future<Result<EpisodeItem?>> episodeAfter(EpisodeItem episode);
}
