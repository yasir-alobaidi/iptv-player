/// The Library's words (canvas `Library`, sketches B and C, docs/05).
library;

import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_media.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/core/text/languages.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart'
    show LibraryTab;
import 'package:path/path.dart' as p;

/// "2.1 GB", "186 GB", "640 MB": a whole number from 100 of a unit up, as
/// the canvas writes sizes.
String librarySize(int bytes) {
  const units = ['bytes', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes bytes';
  return '${size >= 100 ? size.round() : size.toStringAsFixed(1)} '
      '${units[unit]}';
}

String _plural(int count, String one, [String? many]) =>
    '${formatCount(count)} ${count == 1 ? one : many ?? '${one}s'}';

/// "42 movies · 186 GB on this computer"; nothing for none, which the
/// empty tab says in its own words.
String libraryCountLine(LibraryTab tab, LibraryCount count) {
  if (count.count == 0) return '';
  final what = switch (tab) {
    LibraryTab.movies => _plural(count.count, 'movie'),
    LibraryTab.series => _plural(count.count, 'show'),
    LibraryTab.videos => _plural(count.count, 'video'),
    LibraryTab.folders => _plural(count.count, 'folder'),
  };
  return '$what · ${librarySize(count.bytes)} on this computer';
}

/// The tabs, as the canvas names them.
String libraryTabLabel(LibraryTab tab) => switch (tab) {
  LibraryTab.movies => 'Movies',
  LibraryTab.series => 'Series',
  LibraryTab.videos => 'Videos',
  LibraryTab.folders => 'Folders',
};

/// The chips.
String libraryOriginLabel(LibraryOrigin origin) => switch (origin) {
  LibraryOrigin.all => 'All',
  LibraryOrigin.downloaded => 'Downloaded',
  LibraryOrigin.localFolders => 'Local folders',
};

const driveNotConnected = 'Drive not connected';

/// A movie's title on its card: a file of the user's own with its year,
/// "Paper Kites (2019)"; a download as its provider names it.
String libraryMovieTitle(LibraryItem item) =>
    !item.isDownload && item.year != null
    ? '${item.title} (${item.year})'
    : item.title;

/// The line under a movie: "Downloaded · 2.1 GB", its folder's name, or
/// that its drive isn't connected.
String libraryItemPlace(LibraryItem item, String? folderLabel) {
  if (!item.available) return driveNotConnected;
  if (item.isDownload) return 'Downloaded · ${librarySize(item.sizeBytes)}';
  return folderLabel ?? '';
}

/// The line under a show (sketch B): "3 seasons · Movies HDD", "2
/// episodes · Downloaded". One season says its episodes, which tell more.
String libraryShowLine(LibraryShow show, String? folderLabel) {
  if (!show.available) return driveNotConnected;
  final size = show.seasons > 1
      ? _plural(show.seasons, 'season')
      : _plural(show.episodes, 'episode');
  final place = show.downloaded ? 'Downloaded' : folderLabel;
  return place == null ? size : '$size · $place';
}

/// The line under a video (sketch C): "12 min · Home videos".
String libraryVideoLine(LibraryItem item, String? folderLabel) {
  if (!item.available) return driveNotConnected;
  return [
    if (item.duration case final length?) formatRuntime(length),
    ?folderLabel,
  ].join(' · ');
}

/// "Episode 4" for an episode whose name gave no title (sketch B).
String libraryEpisodeTitle(LibraryItem item) {
  final title = item.title.trim();
  if (title.isNotEmpty &&
      title.toLowerCase() != item.showTitle?.toLowerCase()) {
    return title;
  }
  return item.episode == null ? 'Episode' : 'Episode ${item.episode}';
}

/// A folder's row under its path (canvas `Settings · Downloads and
/// library`): "Downloads · 38 videos · 42.3 GB", "Movies HDD · 1,204
/// videos · scanned 5 min ago", "USB drive · not connected · its 64 videos
/// stay listed for 30 days".
String folderLine(
  LibraryFolder folder,
  LibraryFolderTotals? totals,
  DateTime now,
) {
  final videos = totals?.items ?? 0;
  final count = _plural(videos, 'video');
  if (!folder.isAvailable) {
    final listed = videos == 1
        ? 'its video stays listed'
        : 'its $count stay listed';
    return '${folder.label} · not connected · $listed for 30 days';
  }
  if (folder.isDownloadFolder) {
    return '${folder.label} · $count · ${librarySize(totals?.bytes ?? 0)}';
  }
  final scanned = switch (folder.lastScanAt) {
    final at? => 'scanned ${formatAgo(at, now)}',
    null => 'not scanned yet',
  };
  return '${folder.label} · $count · $scanned';
}

/// A folder's path as the canvas writes it: `~/Videos/IPTV Player` under
/// the home folder.
String displayFolderPath(String path, String? home) {
  if (home == null || home.isEmpty) return path;
  if (p.equals(path, home)) return '~';
  if (!p.isWithin(home, path)) return path;
  return p.join('~', p.relative(path, from: home));
}

/// Beside the count while a scan runs: "Scanning · 1,204 found".
String libraryScanLine(int found) =>
    found == 0 ? 'Scanning' : 'Scanning · ${formatCount(found)} found';

/// The first run, before anything is in the library (docs/05).
const libraryFirstRunTitle = 'Add a folder with your own movies and shows';
const libraryFirstRunMessage = 'Press D on a movie or episode to download it.';

/// What an empty tab says: what would be here, and how it gets here.
({String title, String message}) libraryEmptyText(
  LibraryTab tab,
  LibraryOrigin origin,
) => switch ((tab, origin)) {
  (LibraryTab.movies, LibraryOrigin.downloaded) => (
    title: 'No downloaded movies',
    message: 'Press D on a movie to download it.',
  ),
  (LibraryTab.movies, LibraryOrigin.localFolders) => (
    title: 'No movies in your folders',
    message: 'Add a folder with your own movies.',
  ),
  (LibraryTab.movies, _) => (
    title: 'No movies here yet',
    message:
        'Add a folder with your own movies, or press D on a movie to '
        'download it.',
  ),
  (LibraryTab.series, LibraryOrigin.downloaded) => (
    title: 'No downloaded episodes',
    message: 'Press D on an episode to download it.',
  ),
  (LibraryTab.series, LibraryOrigin.localFolders) => (
    title: 'No shows in your folders',
    message: 'Add a folder with your own shows.',
  ),
  (LibraryTab.series, _) => (
    title: 'No shows here yet',
    message:
        'Add a folder with your own shows, or press D on an episode '
        'to download it.',
  ),
  _ => (
    title: 'No other videos',
    message:
        "Videos in your folders that aren't a movie or an episode "
        'show here.',
  ),
};

/// The drive of the folder called [folderLabel] is away: why Enter didn't
/// play.
String driveAwayNotice(String? folderLabel) => folderLabel == null
    ? "Its drive isn't connected. Connect it to play this."
    : "$folderLabel isn't connected. Connect its drive to play this.";

/// What a library page says its video is, over the title.
String libraryKindWord(LibraryKind kind) => switch (kind) {
  LibraryKind.movie => 'Movie',
  LibraryKind.episode => 'Episode',
  LibraryKind.unsorted => 'Video',
};

/// Where a video is, on its page (sketch A): "Movies HDD · Paper Kites
/// (2019)/Paper Kites (2019).mkv · 2.1 GB"; "Downloaded" where the folder
/// would be for a download; and that its drive is away.
String libraryFileLine(LibraryItem item, String? folderLabel) => [
  if (!item.available) driveNotConnected,
  if (item.isDownload) 'Downloaded' else ?folderLabel,
  item.relPath,
  librarySize(item.sizeBytes),
].join(' · ');

/// The subtitles a video comes with (sketch A: "English · English
/// (forced)"): the files beside it, then the tracks inside it, each
/// language once.
List<String> librarySubtitleNames(LibraryItem item) {
  String name(String? language, String? title, {required bool forced}) {
    final base = switch (language) {
      final code? when code.isNotEmpty && code != 'und' => languageName(code),
      _ => title ?? 'Unknown',
    };
    return forced ? '$base (forced)' : base;
  }

  return {
    for (final file in item.subtitles)
      name(file.language, null, forced: file.forced),
    for (final track in item.media?.subtitles ?? const <LibrarySubtitle>[])
      name(track.language, track.title, forced: track.forced),
  }.toList();
}

/// "S2 · E3" beside an episode's title (sketch B); what is known of it.
String libraryEpisodeNumber(LibraryItem item) => [
  if (item.season case final season?) 'S$season',
  if (item.episode case final episode?)
    if (item.episodeEnd case final end? when end != episode)
      'E$episode–$end'
    else
      'E$episode',
].join(' · ');

/// Continue's label on a show's page: "Continue S2 · E4".
String libraryContinueLabel(String verb, LibraryItem episode) {
  final number = libraryEpisodeNumber(episode);
  return number.isEmpty ? verb : '$verb $number';
}
