import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Folders the app owns: its data under the platform's application
/// support directory, and what can be fetched again under its cache
/// directory ([cacheRoot]; under [root] when none is given).
final class AppPaths {
  const new(this.root, {this.cacheDirectory, this.logDirectory});

  final Directory root;

  /// The platform's cache directory, when it gave one.
  final Directory? cacheDirectory;

  /// Where the log goes when not under [root] (Android's, below).
  final Directory? logDirectory;

  static Future<AppPaths> resolve() async => AppPaths(
    await getApplicationSupportDirectory(),
    cacheDirectory: await getApplicationCacheDirectory(),
    logDirectory: Platform.isAndroid ? await _androidLogs() : null,
  );

  /// On Android [root] is out of adb's reach in a release build, and
  /// logcat keeps a TV's last few minutes only (its decoder fills it): the
  /// log goes to the app's own folder on shared storage, which adb reads
  /// and other apps can't (ADR-027).
  static Future<Directory?> _androidLogs() async {
    try {
      final files = await getExternalStorageDirectory();
      return files == null ? null : Directory(p.join(files.path, 'logs'));
    } on Object {
      return null;
    }
  }

  Directory get cacheRoot =>
      cacheDirectory ?? Directory(p.join(root.path, 'cache'));

  Directory get logs => logDirectory ?? Directory(p.join(root.path, 'logs'));

  /// Posters, logos, backdrops and stills (Phase 5 decision 6).
  Directory get artwork => Directory(p.join(cacheRoot.path, 'artwork'));

  /// The PID files of the FFmpeg and ffprobe the app runs (hard rule 8).
  Directory get processes => Directory(p.join(root.path, 'processes'));

  /// Casting's own files: the encoders found (Phase 7 step 4).
  Directory get cast => Directory(p.join(root.path, 'cast'));

  /// The relay's sessions: HLS segments for the TV (Phase 7 step 5).
  Directory get relay => Directory(p.join(cacheRoot.path, 'relay'));

  /// Library videos' frames, by quick hash (Phase 8 step 4).
  Directory get thumbnails =>
      Directory(p.join(cacheRoot.path, 'library', 'thumbnails'));
}
