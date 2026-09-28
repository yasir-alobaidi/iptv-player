/// Every phrase the Movies and Series screens say, in one place.
library;

import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/core/text/format.dart';

/// "movies" / "series", for the phrases below.
String titlesWord(CatalogueKind kind) =>
    kind == CatalogueKind.series ? 'series' : 'movies';

/// "8,021 movies", "1 movie", "1 series".
String titleCountLabel(CatalogueKind kind, int count) =>
    switch ((kind, count)) {
      (CatalogueKind.series, _) => '${formatCount(count)} series',
      (_, 1) => '1 movie',
      _ => '${formatCount(count)} movies',
    };

/// The grid's heading for what it shows.
String allTitlesHeading(CatalogueKind kind) =>
    kind == CatalogueKind.series ? 'All series' : 'All movies';

/// The picture's badge from a picture height: the panel's probe of the
/// file on a details page, the player's own in full screen.
String? pictureBadge(int? height) => switch (height) {
  null || <= 0 => null,
  >= 2000 => '4K',
  >= 1000 => 'FHD',
  >= 700 => 'HD',
  _ => 'SD',
};

/// The sound's badge: surround only; stereo needs none.
String? soundBadge(int? channels) => switch (channels) {
  null => null,
  >= 8 => '7.1',
  >= 6 => '5.1',
  _ => null,
};
