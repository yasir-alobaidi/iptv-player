import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/core/app_identity.dart';

/// Adds the licences of the programs the app runs or loads, which no
/// Dart package brings: FFmpeg and ffprobe (run as separate processes)
/// and mpv's library (the player). Called once from bootstrap; guarded
/// like the fonts'.
void registerToolLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final tool in toolLicenses) {
      final texts = [
        for (final asset in tool.assets) await rootBundle.loadString(asset),
      ];
      yield LicenseEntryWithLineBreaks([
        tool.name,
      ], [tool.notice, ...texts].join('\n\n'));
    }
  });
}

@visibleForTesting
void resetToolLicensesForTest() => _registered = false;

bool _registered = false;

/// A program the app uses, what it is used for and under which terms.
@immutable
final class ToolLicense {
  const new({required this.name, required this.notice, required this.assets});

  final String name;

  /// What the app does with it and which licence applies, in a few lines
  /// before the licence's own text.
  final String notice;

  /// The licence texts, as bundled assets.
  final List<String> assets;
}

const toolLicenses = [
  ToolLicense(
    name: 'FFmpeg',
    notice:
        '$appName runs the ffmpeg and ffprobe programs as separate '
        'processes, to read what a stream or a file holds, to convert it '
        'for a TV when casting, and to save downloads. They are the builds '
        'of the FFmpeg project (https://ffmpeg.org) published at '
        'https://github.com/BtbN/FFmpeg-Builds, in their GPL variant, '
        'which is licensed under the GNU General Public License, version 3 '
        'or later. Their source code is available from the FFmpeg '
        'project.',
    assets: ['assets/licenses/GPL-3.0.txt'],
  ),
  ToolLicense(
    name: 'mpv (libmpv)',
    notice:
        '$appName plays video with libmpv, the library of the mpv '
        'player (https://mpv.io). On Linux it loads the libmpv installed '
        'on your system, which distributions build under the GNU General '
        'Public License, version 2 or later. On Windows it uses the build '
        'that comes with the media_kit packages, under the GNU Lesser '
        'General Public License, version 2.1 or later. Both texts follow.',
    assets: ['assets/licenses/LGPL-2.1.txt', 'assets/licenses/GPL-2.0.txt'],
  ),
];
