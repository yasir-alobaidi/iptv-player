import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:path/path.dart' as p;

/// Where a download's file goes (docs/09 "File layout"), Plex/Jellyfin
/// style, so other apps can read the folder too:
///
/// ```text
/// <folder>/Movies/<Title> (<Year>)/<Title> (<Year>).<ext>
/// <folder>/Series/<Show>/Season 02/<Show> - S02E04 - <Episode title>.<ext>
/// ```
///
/// Every part follows [safeName]. On Windows ([windows]) the whole path is
/// kept to [windowsPathLimit] characters by shortening the title parts.
/// A name already taken is the caller's to step past ([freeName]).
String downloadTarget(
  String folder,
  DownloadRequest request, {
  bool windows = false,
}) {
  final context = windows ? p.windows : p.posix;
  final ext = _extension(request.extension);
  List<String> parts(int limit) {
    String name(String text) => safeName(text, limit: limit);
    switch (request.type) {
      case VodType.movie:
        final year = request.year;
        final title = name(request.title);
        final base = year == null ? title : '$title ($year)';
        return ['Movies', base, '$base.$ext'];
      case VodType.episode:
        final show = name(request.showTitle ?? request.title);
        final season = request.season ?? 1;
        final number = request.episode ?? 1;
        final code = 'S${_two(season)}E${_two(number)}';
        final episodeTitle = name(request.title);
        final file =
            request.showTitle == null ||
                episodeTitle.isEmpty ||
                _isPlaceholder(request.title, number)
            ? '$show - $code'
            : '$show - $code - $episodeTitle';
        return ['Series', show, 'Season ${_two(season)}', '$file.$ext'];
    }
  }

  var limit = maxNamePart;
  var path = context.joinAll([folder, ...parts(limit)]);
  while (windows && path.length > windowsPathLimit && limit > _shortest) {
    limit -= 8;
    path = context.joinAll([folder, ...parts(limit)]);
  }
  return path;
}

/// The longest a single part of a download's path may be (docs/09).
const maxNamePart = 120;

/// The longest a download's whole path may be on Windows (docs/09).
const windowsPathLimit = 240;

/// The shortest a title part is made to fit [windowsPathLimit].
const _shortest = 24;

/// [text] as a file or folder name every system takes (docs/09): no
/// character Windows refuses (`< > : " / \ | ? *`, control characters),
/// no trailing dots or spaces, no reserved name (CON, NUL, COM1 …), at
/// most [limit] characters, never empty.
String safeName(String text, {int limit = maxNamePart}) {
  var name = text
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final characters = name.runes.toList();
  if (characters.length > limit) {
    name = String.fromCharCodes(characters.take(limit)).trim();
  }
  name = name.replaceFirst(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) return 'Untitled';
  // Windows refuses a reserved name with any extension too ("NUL.txt").
  final dot = name.indexOf('.');
  final stem = dot < 0 ? name : name.substring(0, dot);
  if (_reserved.contains(stem.trim().toUpperCase())) {
    name = dot < 0 ? '${name}_' : '${stem}_${name.substring(dot)}';
  }
  return name;
}

/// [path], or the first of `<name> (2).<ext>`, `<name> (3).<ext>` … that
/// [taken] says is free (docs/09: a collision gets a number).
String freeName(String path, bool Function(String path) taken) {
  if (!taken(path)) return path;
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  final hasExtension = dot > slash + 1;
  final stem = hasExtension ? path.substring(0, dot) : path;
  final extension = hasExtension ? path.substring(dot) : '';
  for (var n = 2; ; n++) {
    final candidate = '$stem ($n)$extension';
    if (!taken(candidate)) return candidate;
  }
}

const _reserved = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

String _two(int n) => n.toString().padLeft(2, '0');

/// A panel's own stand-in title ("Episode 4", "E04") says nothing.
bool _isPlaceholder(String title, int number) {
  final t = title.trim().toLowerCase();
  return t.isEmpty ||
      t == 'episode $number' ||
      RegExp('^(e|ep|episode)\\s*0*$number\$').hasMatch(t);
}

/// A panel's container extension (`mkv`), or `mp4` when it sent none or
/// something that isn't one.
String _extension(String? extension) {
  final e = extension?.trim().toLowerCase().replaceFirst('.', '') ?? '';
  return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(e) ? e : 'mp4';
}
