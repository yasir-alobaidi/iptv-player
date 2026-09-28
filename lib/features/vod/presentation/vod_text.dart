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
