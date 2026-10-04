/// Where the Library's pages live: inside its branch, so the nav rail
/// stays and Esc comes back to the Library (Phase 8 step 6). A title the
/// provider still lists opens its own page here too.
library;

import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// A movie of the library (sketch A).
String libraryMoviePath(LibraryItem item) => '/library/movie/${item.id}';

/// A show of the library (sketch B).
String libraryShowPath(String showKey) =>
    '/library/show/${Uri.encodeComponent(showKey)}';

/// A downloaded movie's page at its provider, opened from the Library.
String libraryProviderMoviePath(MovieItem movie) =>
    '/library/movies/${_part(movie.sourceId)}/${_part(movie.remoteKey)}';

/// A downloaded series' page at its provider, opened from the Library.
String libraryProviderSeriesPath(SeriesItem series) =>
    '/library/series/${_part(series.sourceId)}/${_part(series.remoteKey)}';

/// A page of the Library's: the shell draws no top bar there, as on a
/// title's page.
bool isLibraryPagePath(String path) {
  final segments = Uri.parse(path).pathSegments;
  return segments.length >= 3 && segments.first == 'library';
}

String _part(String value) => Uri.encodeComponent(value);
