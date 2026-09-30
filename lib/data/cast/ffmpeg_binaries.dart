import 'dart:io';

import 'package:path/path.dart' as p;

/// The bundled FFmpeg and ffprobe, the only ones the app runs (docs/04:
/// never the system's).
final class FfmpegBinaries {
  const new({required this.ffmpeg, required this.ffprobe});

  final String ffmpeg;
  final String ffprobe;

  /// Where they are: the `ffmpeg/` folder beside the app's executable
  /// (where the Linux and Windows builds put them), else a checkout's
  /// `third_party/ffmpeg/<platform>/`, looked for from
  /// [workingDirectory] up (development and tests). Null when either is
  /// missing, or on Linux not executable.
  static FfmpegBinaries? locate({
    String? executable,
    String? workingDirectory,
    bool? windows,
  }) {
    final onWindows = windows ?? Platform.isWindows;
    final suffix = onWindows ? '.exe' : '';
    FfmpegBinaries? inFolder(String folder) {
      final binaries = FfmpegBinaries(
        ffmpeg: p.join(folder, 'ffmpeg$suffix'),
        ffprobe: p.join(folder, 'ffprobe$suffix'),
      );
      return _usable(binaries.ffmpeg, onWindows) &&
              _usable(binaries.ffprobe, onWindows)
          ? binaries
          : null;
    }

    final beside = inFolder(
      p.join(p.dirname(executable ?? Platform.resolvedExecutable), 'ffmpeg'),
    );
    if (beside != null) return beside;
    final platform = onWindows ? 'windows-x64' : 'linux-x64';
    var folder = p.absolute(workingDirectory ?? Directory.current.path);
    for (var up = 0; up < 6; up++) {
      final found = inFolder(p.join(folder, 'third_party', 'ffmpeg', platform));
      if (found != null) return found;
      final parent = p.dirname(folder);
      if (parent == folder) break;
      folder = parent;
    }
    return null;
  }

  static bool _usable(String path, bool windows) {
    final stat = FileStat.statSync(path);
    if (stat.type != FileSystemEntityType.file) return false;
    // Any execute bit; Windows has none to check.
    return windows || stat.mode & 0x49 != 0;
  }

  @override
  String toString() => 'FfmpegBinaries($ffmpeg, $ffprobe)';
}
