import 'dart:io';

import 'package:path/path.dart' as p;

/// The bundled FFmpeg and ffprobe, the only ones the app runs (docs/04:
/// never the system's).
final class FfmpegBinaries {
  const new({required this.ffmpeg, required this.ffprobe, this.libva});

  final String ffmpeg;
  final String ffprobe;

  /// The folder with the libva the app bundles for FFmpeg on Linux
  /// (`tools/fetch_libva.sh`), or null. FFmpeg uses it only where this
  /// system's own is too old for it (ADR-014 step 4).
  final String? libva;

  /// The environment that makes FFmpeg load [libva]'s libva instead of the
  /// system's; empty when there is none.
  Map<String, String> libvaEnvironment([Map<String, String>? inherited]) {
    final folder = libva;
    if (folder == null) return const {};
    final before = (inherited ?? Platform.environment)['LD_LIBRARY_PATH'];
    return {
      'LD_LIBRARY_PATH': before == null || before.isEmpty
          ? folder
          : '$folder:$before',
    };
  }

  /// Where they are: the `ffmpeg/` folder beside the app's executable
  /// (where the Linux and Windows builds put them, and the Linux build its
  /// libva in `ffmpeg/libva/`), else a checkout's
  /// `third_party/ffmpeg/<platform>/` (and `third_party/libva/linux-x64/`),
  /// looked for from [workingDirectory] up (development and tests). Null
  /// when either is missing, or on Linux not executable.
  static FfmpegBinaries? locate({
    String? executable,
    String? workingDirectory,
    bool? windows,
  }) {
    final onWindows = windows ?? Platform.isWindows;
    final suffix = onWindows ? '.exe' : '';
    FfmpegBinaries? inFolder(String folder, String libvaFolder) {
      final ffmpeg = p.join(folder, 'ffmpeg$suffix');
      final ffprobe = p.join(folder, 'ffprobe$suffix');
      if (!_usable(ffmpeg, onWindows) || !_usable(ffprobe, onWindows)) {
        return null;
      }
      final hasLibva =
          !onWindows &&
          FileStat.statSync(p.join(libvaFolder, 'libva.so.2')).type ==
              FileSystemEntityType.file;
      return FfmpegBinaries(
        ffmpeg: ffmpeg,
        ffprobe: ffprobe,
        libva: hasLibva ? libvaFolder : null,
      );
    }

    final besideFolder = p.join(
      p.dirname(executable ?? Platform.resolvedExecutable),
      'ffmpeg',
    );
    final beside = inFolder(besideFolder, p.join(besideFolder, 'libva'));
    if (beside != null) return beside;
    final platform = onWindows ? 'windows-x64' : 'linux-x64';
    var folder = p.absolute(workingDirectory ?? Directory.current.path);
    for (var up = 0; up < 6; up++) {
      final third = p.join(folder, 'third_party');
      final found = inFolder(
        p.join(third, 'ffmpeg', platform),
        p.join(third, 'libva', 'linux-x64'),
      );
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
  String toString() =>
      'FfmpegBinaries($ffmpeg, $ffprobe${libva == null ? '' : ', $libva'})';
}
