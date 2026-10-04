import 'package:iptv_player/core/library/library_item.dart';
import 'package:meta/meta.dart';

/// What a file's name and folders say it is (docs/09 "NameParser").
@immutable
final class ParsedName {
  const new({
    required this.kind,
    required this.title,
    this.year,
    this.showTitle,
    this.season,
    this.episode,
    this.episodeEnd,
  });

  final LibraryKind kind;

  /// A movie's title, an episode's own (empty when the name has none), or
  /// an unsorted video's name.
  final String title;
  final int? year;
  final String? showTitle;
  final int? season;
  final int? episode;

  /// The last episode of a file holding several (`S02E04E05`).
  final int? episodeEnd;

  @override
  bool operator ==(Object other) =>
      other is ParsedName &&
      other.kind == kind &&
      other.title == title &&
      other.year == year &&
      other.showTitle == showTitle &&
      other.season == season &&
      other.episode == episode &&
      other.episodeEnd == episodeEnd;

  @override
  int get hashCode =>
      Object.hash(kind, title, year, showTitle, season, episode, episodeEnd);

  @override
  String toString() => switch (kind) {
    LibraryKind.movie => 'movie · $title${year == null ? '' : ' ($year)'}',
    LibraryKind.episode =>
      'episode · $showTitle · S$season E$episode'
          '${episodeEnd == null ? '' : '–$episodeEnd'}'
          '${title.isEmpty ? '' : ' · "$title"'}',
    LibraryKind.unsorted => 'unsorted · $title',
  };
}

/// [relPath] (folders and file, `/` between them, inside a library
/// folder) as a movie, an episode or an unsorted video (docs/09). Pure,
/// and never throws: a name it can't place is unsorted.
ParsedName parseVideoName(String relPath) {
  final parts = relPath.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return const ParsedName(kind: LibraryKind.unsorted, title: '');
  }
  final file = parts.last;
  final dot = file.lastIndexOf('.');
  final stem = dot > 0 ? file.substring(0, dot) : file;
  final folders = parts.sublist(0, parts.length - 1);

  return _episode(stem, folders) ??
      _movie(stem, folders) ??
      ParsedName(kind: LibraryKind.unsorted, title: _plain(stem));
}

// ---- Episodes.

/// `S02E04`, `s2e4`, `S02E04E05`, `S02E04-E05`, `S02E04-05`.
final _seasonEpisode = RegExp(
  r'(?:^|[\s._\-\[(])s(\d{1,2})[\s._]?e(\d{1,3})'
  r'(?:(?:[\s._]?-?[\s._]?e|-)(\d{1,3}))?(?=$|[\s._\-\])])',
  caseSensitive: false,
);

/// `2x04`, `02x04`.
final _crossed = RegExp(
  r'(?:^|[\s._\-\[(])(\d{1,2})x(\d{2,3})(?:-(\d{2,3}))?(?=$|[\s._\-\])])',
  caseSensitive: false,
);

/// `Season 2`, `Season 02`, `S02`, `Series 2`, `Saison 2`, `Staffel 2`,
/// `Temporada 2`; `Specials` is season 0.
final _seasonFolder = RegExp(
  r'^(?:season|series|saison|staffel|temporada|s)[\s._]*(\d{1,2})$',
  caseSensitive: false,
);

/// A file in a season folder: `04 - Title`, `E04 Title`, `Episode 4`.
final _numberedFile = RegExp(
  r'^(?:e|ep|episode)?[\s._]*(\d{1,3})(?:(?:[\s._]*-[\s._]*|[\s._]+)(.*))?$',
  caseSensitive: false,
);

/// `[Group] Show - 04 [1080p]`, `Show - 04`.
final _dashNumber = RegExp(r'^(.+?)\s+-\s+(\d{1,3})(?:v\d)?(?:\s+(.*))?$');

ParsedName? _episode(String stem, List<String> folders) {
  final withoutGroup = stem.replaceFirst(RegExp(r'^\s*\[[^\]]*\]\s*'), '');

  for (final pattern in [_seasonEpisode, _crossed]) {
    final match = pattern.firstMatch(withoutGroup);
    if (match == null) continue;
    final season = int.parse(match[1]!);
    final episode = int.parse(match[2]!);
    final end = match[3] == null ? null : int.parse(match[3]!);
    final before = withoutGroup.substring(0, match.start);
    final after = withoutGroup.substring(match.end);
    final show = _cleanTitle(before);
    return ParsedName(
      kind: LibraryKind.episode,
      title: _episodeTitle(after),
      showTitle: show.isNotEmpty ? show : _showFromFolders(folders),
      season: season,
      episode: episode,
      episodeEnd: end != null && end > episode ? end : null,
    );
  }

  // A numbered file in a season folder.
  if (folders.isNotEmpty) {
    final season = _seasonOf(folders.last);
    if (season != null) {
      final match = _numberedFile.firstMatch(_plain(withoutGroup));
      if (match != null) {
        final show = folders.length >= 2
            ? _cleanTitle(folders[folders.length - 2])
            : '';
        return ParsedName(
          kind: LibraryKind.episode,
          title: _episodeTitle(match[2] ?? ''),
          showTitle: show.isEmpty ? null : show,
          season: season,
          episode: int.parse(match[1]!),
        );
      }
    }
  }

  // `[Group] Show - 04`: an episode of season 1 when the name had a
  // group, or sits in a folder named after the show.
  final dashed = _dashNumber.firstMatch(withoutGroup.replaceAll('_', ' '));
  final hadGroup = withoutGroup != stem;
  if (dashed != null) {
    final show = _cleanTitle(dashed[1]!);
    final inShowFolder =
        folders.isNotEmpty && _same(_cleanTitle(folders.last), show);
    if (show.isNotEmpty && (hadGroup || inShowFolder)) {
      return ParsedName(
        kind: LibraryKind.episode,
        title: _episodeTitle(dashed[3] ?? ''),
        showTitle: show,
        season: 1,
        episode: int.parse(dashed[2]!),
      );
    }
  }
  return null;
}

int? _seasonOf(String folder) {
  final name = folder.trim();
  if (RegExp(r'^specials?$', caseSensitive: false).hasMatch(name)) return 0;
  final match = _seasonFolder.firstMatch(name);
  return match == null ? null : int.parse(match[1]!);
}

/// The show a file belongs to by its folders: the one above its season
/// folder, else its own.
String? _showFromFolders(List<String> folders) {
  if (folders.isEmpty) return null;
  final last = folders.last;
  final folder = _seasonOf(last) != null
      ? (folders.length >= 2 ? folders[folders.length - 2] : null)
      : last;
  if (folder == null) return null;
  final show = _cleanTitle(folder);
  return show.isEmpty ? null : show;
}

String _episodeTitle(String text) {
  final title = _cleanTitle(text, atStart: true);
  // A name's stand-in says nothing ("Episode 4").
  if (RegExp(r'^(episode|ep|e)\s*\d+$', caseSensitive: false).hasMatch(title)) {
    return '';
  }
  return title;
}

// ---- Movies.

final _year = RegExp(r'^(19\d\d|20\d\d)$');

ParsedName? _movie(String stem, List<String> folders) {
  final fromName = _movieFrom(stem);
  if (fromName != null) return fromName;
  // `Movie Title (2019)/movie.mkv`: the folder says.
  if (folders.isNotEmpty) {
    final fromFolder = _movieFrom(folders.last);
    if (fromFolder != null) return fromFolder;
  }
  return null;
}

/// A title and the year it ends with: `Title (2019)`, `Title [2019]`,
/// `Title.2019.mkv`, `Title 2019 1080p …`. The year is the last one before
/// the release tags, so `Blade Runner 2049 (2017)` is 2017, and `1917
/// (2019)` keeps its title. A bare year in a name with spaces and no tags
/// ("Birthday at the lake 2021") is a home video's, not a movie's.
ParsedName? _movieFrom(String text) {
  final tokens = _tokens(text);
  if (tokens.isEmpty) return null;
  final tagsAt = _firstTag(tokens);
  final head = tokens.sublist(0, tagsAt);
  final scene = !text.trim().contains(' ');
  final tagged = tagsAt < tokens.length;
  var yearAt = -1;
  for (var i = head.length - 1; i > 0; i--) {
    final token = head[i];
    if (_year.hasMatch(token.word)) {
      if (token.paren || scene || tagged) yearAt = i;
      break;
    }
  }
  if (yearAt < 0) return null;
  final title = _join(head.sublist(0, yearAt));
  if (title.isEmpty) return null;
  return ParsedName(
    kind: LibraryKind.movie,
    title: title,
    year: int.parse(head[yearAt].word),
  );
}

// ---- Words and tags.

/// A word of a name; whether brackets held it (a tag), or parentheses
/// (a year).
typedef _Token = ({String word, bool bracketed, bool paren});

List<_Token> _tokens(String text) {
  final tokens = <_Token>[];
  // Dots and underscores part words only in a name without spaces (a
  // scene name): "Mr. Robinson's Garden" keeps its dot.
  final spaced = text.contains(' ');
  final pattern = spaced ? _spacedWords : _sceneWords;
  final split = spaced ? RegExp(r'\s+') : RegExp(r'[\s._]+');
  for (final match in pattern.allMatches(text)) {
    final bracketed = match[1] ?? match[2];
    final parenthesised = match[3];
    final plain = match[4];
    if (bracketed != null) {
      final inner = bracketed.trim();
      if (_year.hasMatch(inner)) {
        tokens.add((word: inner, bracketed: false, paren: true));
        continue;
      }
      for (final word in inner.split(split)) {
        if (word.isNotEmpty) {
          tokens.add((word: word, bracketed: true, paren: false));
        }
      }
    } else if (parenthesised != null) {
      final inner = parenthesised.trim();
      if (_year.hasMatch(inner)) {
        tokens.add((word: inner, bracketed: false, paren: true));
      } else {
        for (final word in inner.split(split)) {
          if (word.isNotEmpty) {
            tokens.add((word: word, bracketed: true, paren: false));
          }
        }
      }
    } else if (plain != null) {
      tokens.add((word: plain, bracketed: false, paren: false));
    }
  }
  return tokens;
}

// Brackets and braces hold tags; parentheses usually a year.
final _spacedWords = RegExp(
  r'\[([^\]]*)\]|\{([^}]*)\}|\(([^)]*)\)|([^\s\[\]{}()]+)',
);
final _sceneWords = RegExp(
  r'\[([^\]]*)\]|\{([^}]*)\}|\(([^)]*)\)|([^\s._\[\]{}()]+)',
);

/// Where the release tags begin: the first tag word, or the first word
/// brackets held after the title began. A title's first word is taken for
/// a tag only [atStart] (what follows an episode's code: `S01E01.720p`);
/// a movie may be called "Web".
int _firstTag(List<_Token> tokens, {bool atStart = false}) {
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if ((i > 0 || atStart) && (token.bracketed || _isTag(token.word))) {
      return i;
    }
  }
  return tokens.length;
}

final _tagWords = {
  // Resolution.
  '480p', '540p', '576p', '576i', '720p', '1080p', '1080i', '1440p', '2160p',
  '4320p', '4k', '8k', 'uhd', 'fhd', 'hd', 'sd',
  // Source.
  'bluray', 'blu-ray', 'bdrip', 'brrip', 'bdremux', 'remux', 'web-dl',
  'webdl', 'webrip', 'web', 'hdtv', 'pdtv', 'dvdrip', 'dvd', 'hdrip', 'hdcam',
  'cam', 'ts', 'amzn', 'nf', 'dsnp', 'hmax', 'atvp',
  // Codec.
  'x264', 'x265', 'h264', 'h265', 'h-264', 'h-265', 'h.264', 'h.265',
  'hevc', 'avc', 'xvid',
  'divx', 'av1', 'vp9', '10bit', '8bit', 'hdr', 'hdr10', 'hdr10+', 'dv',
  'dovi', 'sdr',
  // Audio.
  'dts', 'dts-hd', 'dtshd', 'dts-x', 'ac3', 'aac', 'aac2', 'eac3', 'ddp',
  'ddp5', 'dd5', 'dd', 'atmos', 'truehd', 'flac', 'mp3', 'opus', 'lpcm',
  // Releases.
  'proper', 'repack', 'extended', 'remastered', 'unrated', 'imax',
  'internal', 'limited', 'complete', 'multi', 'dubbed', 'subbed',
};

bool _isTag(String word) {
  final w = word.toLowerCase();
  if (_tagWords.contains(w)) return true;
  // `DDP5.1`, `DD5.1`, `AAC2.0`, `H.264` split on the dot: `DDP5`, `1`.
  if (RegExp(r'^(ddp?|aac|dts|eac3|ac3|atmos|truehd)\d').hasMatch(w)) {
    return true;
  }
  if (RegExp(r'^\d{3,4}[pi]$').hasMatch(w)) return true;
  // `x264-GRP`, `WEB-DL`, `HDTV-GRP`: a tag with the group after it.
  final dash = w.indexOf('-');
  if (dash > 0 && _tagWords.contains(w.substring(0, dash))) return true;
  return false;
}

/// Words before the tags, as a title: dots and underscores were spaces.
String _cleanTitle(String text, {bool atStart = false}) {
  final tokens = _tokens(text);
  return _join(tokens.sublist(0, _firstTag(tokens, atStart: atStart)));
}

String _join(List<_Token> tokens) => tokens
    .where((t) => !t.bracketed)
    .map((t) => t.word)
    .join(' ')
    .replaceAll(RegExp(r'\s*-\s*$'), '')
    .replaceAll(RegExp(r'^\s*-\s*'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// An unsorted video's name: scene dots and underscores as spaces only
/// when the name has no spaces of its own.
String _plain(String stem) {
  var name = stem.trim();
  if (!name.contains(' ')) {
    final dots = '.'.allMatches(name).length;
    if (dots >= 2) name = name.replaceAll('.', ' ');
    if (name.contains('_') && !name.startsWith(RegExp('(VID|IMG|MOV|PXL)_'))) {
      name = name.replaceAll('_', ' ');
    }
  }
  return name.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _same(String a, String b) =>
    a.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '') ==
    b.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
