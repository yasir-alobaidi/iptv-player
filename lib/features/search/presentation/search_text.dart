/// Every phrase the search overlay shows, and which letters of a name it
/// sets in bold. Pure, so the rules are tested without a screen.
library;

import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/live_tv/domain/channel_name_tags.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/search/domain/search.dart';

/// The group headings, in the canvas's order.
const channelsHeading = 'CHANNELS';
const programmesHeading = 'ON TV NOW & UPCOMING';
const moviesHeading = 'MOVIES';
const seriesHeading = 'SERIES';

const searchHint = 'Search channels, shows, movies';

/// "7 results", in the query bar.
String resultCountLabel(int count) =>
    count == 1 ? '1 result' : '${formatCount(count)} results';

/// A channel row's second line: "118 · Evening Bulletin, until 8:30 PM".
/// [sameName] adds the category, for two channels that clean to one name
/// (decision 2); [sources] above one adds the source.
String channelHitLine(
  ChannelHit hit, {
  required NowNext? guide,
  required bool sameName,
  required int sources,
}) {
  final channel = hit.channel;
  final now = guide?.now;
  return [
    if (channel.number != null) '${channel.number}',
    if (sameName && hit.categoryName != null) hit.categoryName!,
    if (sources > 1) hit.sourceName,
    if (now != null) '${now.title}, until ${formatClock(now.end)}',
  ].join(' · ');
}

/// A programme row's second line: "Courtside · ends 10:55 PM" while it
/// is on, "Blue Water · Tomorrow, 9:30 PM" before.
String programmeHitLine(
  ProgrammeHit hit, {
  required DateTime now,
  required int sources,
}) {
  final programme = hit.programme;
  final when = hit.isOnAt(now)
      ? 'ends ${formatClock(programme.end)}'
      : '${formatRelativeDay(programme.start, now)}, '
            '${formatClock(programme.start)}';
  return [hit.channel.name, if (sources > 1) hit.sourceName, when].join(' · ');
}

/// A programme's title with its episode's, when the guide gives one:
/// "Continental Cup: Semi-final".
String programmeHitTitle(ProgrammeHit hit) {
  final subtitle = hit.programme.subtitle?.trim();
  return subtitle == null || subtitle.isEmpty
      ? hit.programme.title
      : '${hit.programme.title}: $subtitle';
}

/// "2024 · Drama · Resume at 1:12:40": the genre once its details were
/// fetched, else its category.
String movieHitLine(MovieHit hit, {required int sources}) {
  final movie = hit.movie;
  final watch = movie.watch;
  return [
    if (movie.year != null) '${movie.year}',
    ?(hit.genre ?? hit.categoryName),
    if (sources > 1) hit.sourceName,
    if (watch != null && watch.resumable)
      'Resume at ${formatPosition(watch.position)}',
  ].join(' · ');
}

/// "Series · 3 seasons · Crime": the seasons once its episodes were
/// fetched, the genre else the category.
String seriesHitLine(SeriesHit hit, {required int sources}) {
  final seasons = hit.seasons;
  return [
    'Series',
    if (seasons == 1) '1 season' else if (seasons != null) '$seasons seasons',
    ?(hit.series.genre ?? hit.categoryName),
    if (sources > 1) hit.sourceName,
  ].join(' · ');
}

/// "Show all in Live TV" and the like, at the end of a group with more.
/// Null for programmes: no screen lists the guide by text, and the five
/// soonest are the ones that matter.
String? showAllLabel(SearchGroupKind kind) => switch (kind) {
  SearchGroupKind.channels => 'Show all in Live TV',
  SearchGroupKind.programmes => null,
  SearchGroupKind.movies => 'Show all in Movies',
  SearchGroupKind.series => 'Show all in Series',
};

/// The four groups, in the overlay's order.
enum SearchGroupKind { channels, programmes, movies, series }

/// "No results for "harbour"".
String noResultsTitle(String text) => 'No results for "${text.trim()}"';

/// "2 hidden channels match." under no results (decision 8).
String hiddenMatchesLine(int count) => count == 1
    ? '1 hidden channel matches.'
    : '${formatCount(count)} hidden channels match.';

/// The body with no text and no recent search (sketch C).
const searchCoverage =
    'Channels, what’s on now and next, movies and series, from every '
    'source.';

/// The footer's recent searches: "Recent: tennis open · cup final".
String recentLine(List<String> recent) =>
    recent.isEmpty ? '' : 'Recent: ${recent.take(3).join(' · ')}';

/// Where in [name] the words typed are, to set in bold: each word where it
/// starts a word of [name], compared as the index compares them — case,
/// Latin accents and superscripts folded. Ranges are [start, end) in
/// [name]'s code units, in order, never overlapping.
List<(int, int)> highlightRanges(String name, List<String> words) {
  if (words.isEmpty || name.isEmpty) return const [];
  // The folded name, and for each folded unit the name's unit it came
  // from, so a match maps back.
  final folded = StringBuffer();
  final from = <int>[];
  for (var i = 0; i < name.length; i++) {
    final unit = name.codeUnitAt(i);
    final isPair =
        unit >= 0xd800 &&
        unit <= 0xdbff &&
        i + 1 < name.length &&
        (name.codeUnitAt(i + 1) & 0xfc00) == 0xdc00;
    final char = name.substring(i, isPair ? i + 2 : i + 1);
    final fold = _fold(char);
    folded.write(fold);
    for (var k = 0; k < fold.length; k++) {
      from.add(i);
    }
    if (isPair) i++;
  }
  final text = folded.toString();
  final ranges = <(int, int)>[];
  for (final word in words) {
    final key = _fold(word);
    if (key.isEmpty) continue;
    var at = text.indexOf(key);
    while (at >= 0) {
      if (at == 0 || !isWordAt(text, at - 1)) {
        final start = from[at];
        final last = from[at + key.length - 1];
        final end = last + _unitLength(name, last);
        ranges.add((start, end));
        break;
      }
      at = text.indexOf(key, at + 1);
    }
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && range.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, range.$2 > last.$2 ? range.$2 : last.$2));
    } else {
      merged.add(range);
    }
  }
  return merged;
}

String _fold(String text) => foldName(text.toLowerCase());

int _unitLength(String text, int at) {
  final unit = text.codeUnitAt(at);
  return unit >= 0xd800 &&
          unit <= 0xdbff &&
          at + 1 < text.length &&
          (text.codeUnitAt(at + 1) & 0xfc00) == 0xdc00
      ? 2
      : 1;
}
