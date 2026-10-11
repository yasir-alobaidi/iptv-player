/// What Ctrl+K search finds (Phase 6 decision 3): channels, what is on
/// now and next, movies and series, from every source, and the library
/// on this computer (Phase 8), each group ranked and capped.
library;

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// Rows a group shows before "Show all".
const searchGroupSize = 5;

/// A channel search found, with what its row says beside the name.
@immutable
final class ChannelHit {
  const new({
    required this.channel,
    required this.sourceName,
    this.categoryName,
  });

  final ChannelItem channel;

  /// The source it comes from, for rows when there are several.
  final String sourceName;

  /// Its category's name as the user sees it; null when it has none.
  final String? categoryName;

  @override
  bool operator ==(Object other) =>
      other is ChannelHit &&
      other.channel == channel &&
      other.sourceName == sourceName &&
      other.categoryName == categoryName;

  @override
  int get hashCode => Object.hash(channel, sourceName, categoryName);

  @override
  String toString() => 'ChannelHit(${channel.name})';
}

/// A programme that hasn't finished, and the visible channel it is on. An
/// HD/SD pair sharing one guide id is one hit, on one of them.
@immutable
final class ProgrammeHit {
  const new({
    required this.programme,
    required this.channel,
    required this.sourceName,
  });

  final EpgProgramme programme;
  final ChannelItem channel;
  final String sourceName;

  bool isOnAt(DateTime now) =>
      !programme.start.isAfter(now) && programme.end.isAfter(now);

  @override
  bool operator ==(Object other) =>
      other is ProgrammeHit &&
      other.programme.id == programme.id &&
      other.channel == channel &&
      other.sourceName == sourceName;

  @override
  int get hashCode => Object.hash(programme.id, channel, sourceName);

  @override
  String toString() => 'ProgrammeHit(${programme.title} on ${channel.name})';
}

@immutable
final class MovieHit {
  const new({
    required this.movie,
    required this.sourceName,
    this.categoryName,
    this.genre,
  });

  final MovieItem movie;
  final String sourceName;
  final String? categoryName;

  /// From its details, once they were fetched.
  final String? genre;

  @override
  bool operator ==(Object other) =>
      other is MovieHit &&
      other.movie == movie &&
      other.sourceName == sourceName &&
      other.categoryName == categoryName &&
      other.genre == genre;

  @override
  int get hashCode => Object.hash(movie, sourceName, categoryName, genre);

  @override
  String toString() => 'MovieHit(${movie.name})';
}

@immutable
final class SeriesHit {
  const new({
    required this.series,
    required this.sourceName,
    this.categoryName,
    this.seasons,
  });

  final SeriesItem series;
  final String sourceName;
  final String? categoryName;

  /// How many seasons its episodes span, once they were fetched.
  final int? seasons;

  @override
  bool operator ==(Object other) =>
      other is SeriesHit &&
      other.series == series &&
      other.sourceName == sourceName &&
      other.categoryName == categoryName &&
      other.seasons == seasons;

  @override
  int get hashCode => Object.hash(series, sourceName, categoryName, seasons);

  @override
  String toString() => 'SeriesHit(${series.name})';
}

/// Something of the library (Phase 8 step 6): a video on this computer,
/// or a show of them.
///
/// **A title is found once.** A download its provider still lists is the
/// movie or the series MOVIES and SERIES find, with its page there; the
/// library group holds what they don't: the user's own files, a download
/// the provider dropped or the user hid the category of, and an episode
/// found by its own title.
@immutable
sealed class LibraryHit {
  const new({this.folderLabel});

  /// What the screens call its folder ("Home videos"); null for a show
  /// whose episodes are in several.
  final String? folderLabel;
}

/// A movie, a video, or an episode found by its own title.
final class LibraryItemHit extends LibraryHit {
  const new(this.item, {super.folderLabel});

  final LibraryItem item;

  @override
  bool operator ==(Object other) =>
      other is LibraryItemHit &&
      other.item == item &&
      other.folderLabel == folderLabel;

  @override
  int get hashCode => Object.hash(item, folderLabel);

  @override
  String toString() => 'LibraryItemHit(${item.title})';
}

/// A show found by its name: its episodes are one row.
final class LibraryShowHit extends LibraryHit {
  const new(this.show, {super.folderLabel});

  final LibraryShow show;

  @override
  bool operator ==(Object other) =>
      other is LibraryShowHit &&
      other.show == show &&
      other.folderLabel == folderLabel;

  @override
  int get hashCode => Object.hash(show, folderLabel);

  @override
  String toString() => 'LibraryShowHit(${show.title})';
}

/// One group's first [searchGroupSize] hits, best first, and whether
/// there were more.
@immutable
final class SearchGroup<T> {
  const new(this.hits, {this.hasMore = false});

  const new empty() : hits = const [], hasMore = false;

  final List<T> hits;
  final bool hasMore;

  bool get isEmpty => hits.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is SearchGroup<T> &&
      other.hasMore == hasMore &&
      listEquals(other.hits, hits);

  @override
  int get hashCode => Object.hash(Object.hashAll(hits), hasMore);
}

/// What one search found, in the canvas's five groups.
@immutable
final class SearchResults {
  const new({
    required this.text,
    this.channels = const SearchGroup.empty(),
    this.programmes = const SearchGroup.empty(),
    this.movies = const SearchGroup.empty(),
    this.series = const SearchGroup.empty(),
    this.library = const SearchGroup.empty(),
    this.hiddenChannels = 0,
    this.sourceCount = 1,
  });

  /// The text searched, as typed.
  final String text;
  final SearchGroup<ChannelHit> channels;
  final SearchGroup<ProgrammeHit> programmes;
  final SearchGroup<MovieHit> movies;
  final SearchGroup<SeriesHit> series;
  final SearchGroup<LibraryHit> library;

  /// Channels that match but are hidden (decision 8): counted only when
  /// no visible channel matched, for the empty state's "2 hidden channels
  /// match". 0 otherwise.
  final int hiddenChannels;

  /// How many sources there are: with two or more, rows name theirs.
  final int sourceCount;

  bool get isEmpty =>
      channels.isEmpty &&
      programmes.isEmpty &&
      movies.isEmpty &&
      series.isEmpty &&
      library.isEmpty;

  /// Hits shown, over every group.
  int get count =>
      channels.hits.length +
      programmes.hits.length +
      movies.hits.length +
      series.hits.length +
      library.hits.length;
}

/// Search over the catalogue, the guide and the library on this computer
/// (decision 3).
/// Everything runs as SQL on the database isolate; nothing throws across
/// this boundary, and no text makes a query fail.
abstract interface class SearchRepository {
  /// Every group for [text], the source [preferredSourceId] (the one being
  /// browsed) first in each. [now] decides what is on now and what has
  /// finished. Blank text finds nothing.
  Future<Result<SearchResults>> search(
    String text, {
    required DateTime now,
    String? preferredSourceId,
  });

  /// The last searches opened from, newest first ([recentSearchLimit]).
  Future<Result<List<String>>> recentSearches();

  /// Puts [text] first in the recent searches (once, however often it was
  /// searched), dropping the oldest past [recentSearchLimit].
  Future<Result<void>> rememberSearch(String text);

  Future<Result<void>> forgetSearch(String text);

  Future<Result<void>> clearRecentSearches();
}

/// Recent searches kept (decision 4).
const recentSearchLimit = 8;
