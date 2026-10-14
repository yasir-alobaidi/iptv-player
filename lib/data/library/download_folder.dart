import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/daos/library_dao.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';
import 'package:xdg_directories/xdg_directories.dart' as xdg;

/// The folder inside the system's Videos folder that downloads go to by
/// default (docs/09).
const String downloadFolderName = appName;

/// The default folder's name before the app had its own (ADR-018): where
/// it is already, downloads go on going there, and nothing is moved.
const earlierDownloadFolderName = 'IPTV Player';

/// What the library calls the download folder (the canvas: "Downloads ·
/// 38 videos · 42.3 GB").
const downloadFolderLabel = 'Downloads';

/// The system's Videos folder: the user's `XDG_VIDEOS_DIR` on Linux, the
/// Videos known folder on Windows, `~/Movies` on macOS, else `~/Videos`.
/// Never runs a process: `xdg-user-dir` would, so its file is read here.
Future<String> systemVideosFolder() async {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;
  if (Platform.isWindows) return _windowsVideos() ?? p.join(home, 'Videos');
  if (Platform.isMacOS) return p.join(home, 'Movies');
  try {
    final file = File(p.join(xdg.configHome.path, 'user-dirs.dirs'));
    final named = videosFromUserDirs(await file.readAsString(), home: home);
    if (named != null) return named;
  } on Object {
    // No file, or one that can't be read: the usual place.
  }
  return p.join(home, 'Videos');
}

/// `XDG_VIDEOS_DIR` from the text of `user-dirs.dirs`, with `$HOME`
/// expanded. Null when it isn't set, or is set to the home folder itself
/// (how xdg-user-dirs turns one off).
String? videosFromUserDirs(String contents, {required String home}) {
  final line = RegExp(
    r'^\s*XDG_VIDEOS_DIR\s*=\s*"?([^"\n]*)"?\s*$',
    multiLine: true,
  ).firstMatch(contents);
  final raw = line?.group(1)?.trim();
  if (raw == null || raw.isEmpty) return null;
  final path = raw.startsWith(r'$HOME')
      ? home + raw.substring(5)
      : raw.startsWith('/')
      ? raw
      : null;
  if (path == null) return null;
  // The file is Linux's: its paths are POSIX whatever system reads it.
  final normal = p.posix.normalize(path);
  return p.posix.equals(normal, p.posix.normalize(home)) ? null : normal;
}

/// The Videos known folder (which the user may have moved); null when
/// Windows won't say.
String? _windowsVideos() {
  final id = calloc<GUID>()
    ..ref.setGUID('{18989B1D-99B5-455B-841C-AB7C74E4DDFC}');
  try {
    final path = SHGetKnownFolderPath(id, KF_FLAG_DEFAULT, null);
    try {
      return path.toDartString();
    } finally {
      CoTaskMemFree(path);
    }
  } on Object {
    return null;
  } finally {
    calloc.free(id);
  }
}

/// Where new downloads go: the user's choice, else the system's Videos
/// folder + `Bijou` — or + `IPTV Player` where that folder already is,
/// so that the downloads made before the app's name stay in one place.
Future<String> downloadFolderPath({
  String? chosen,
  Future<String> Function() videos = systemVideosFolder,
}) async {
  if (chosen != null) return chosen;
  final folder = await videos();
  final earlier = p.join(folder, earlierDownloadFolderName);
  if (Directory(earlier).existsSync()) return earlier;
  return p.join(folder, downloadFolderName);
}

/// Makes [path] the library's download folder (docs/09): added the first
/// time, and the folder the library marks as such. The folder itself is
/// made by the first download, not here.
Future<Result<void>> registerDownloadFolder(
  LibraryDao dao,
  String path, {
  required DateTime now,
}) => Result.guard<void>(() async {
  await dao.makeDownloadFolder(path, label: downloadFolderLabel, at: now);
});
