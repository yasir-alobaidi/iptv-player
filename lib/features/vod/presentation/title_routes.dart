/// Where a movie's or a series' details page lives: inside its branch
/// (`/movies/<source>/<key>`, `/series/<source>/<key>`), so the nav rail
/// stays and the branch comes back to it (Phase 5 step 5).
library;

import 'package:iptv_player/features/vod/domain/titles.dart';

String movieDetailsPath(MovieItem movie) =>
    '/movies/${_part(movie.sourceId)}/${_part(movie.remoteKey)}';

String seriesDetailsPath(SeriesItem series) =>
    '/series/${_part(series.sourceId)}/${_part(series.remoteKey)}';

/// A details page's location: the shell draws no top bar there (the canvas
/// draws none).
bool isTitleDetailsPath(String path) {
  final segments = Uri.parse(path).pathSegments;
  return segments.length == 3 &&
      (segments.first == 'movies' || segments.first == 'series');
}

String _part(String value) => Uri.encodeComponent(value);
