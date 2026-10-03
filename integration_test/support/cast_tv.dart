// The cast walk's TV and FFmpeg: the fake receiver on this computer,
// found by its address only, and FFmpeg bundled or else the system's.

import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/merged_cast_discovery.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/presentation/cast_shell_slots.dart';
import 'package:path/path.dart' as p;

/// The bundled FFmpeg and ffprobe, else the system's (CI installs 4.4);
/// `RELAY_FFMPEG_DIR` picks one, as for the relay's tests (`/usr/bin`:
/// as CI runs).
FfmpegBinaries? castBinaries() {
  final chosen = Platform.environment['RELAY_FFMPEG_DIR'];
  final bundled = chosen == null ? FfmpegBinaries.locate() : null;
  if (bundled != null) return bundled;
  for (final folder in [?chosen, '/usr/bin', '/usr/local/bin']) {
    final ffmpeg = File('$folder/ffmpeg');
    final ffprobe = File('$folder/ffprobe');
    if (ffmpeg.existsSync() && ffprobe.existsSync()) {
      return FfmpegBinaries(ffmpeg: ffmpeg.path, ffprobe: ffprobe.path);
    }
  }
  return null;
}

/// Casting as `bootstrap()` builds it, with [binaries] for FFmpeg and its
/// folders in [folder]; discovery runs on no network browser (CI has
/// none, and a walk must never find a real TV), so the only devices are
/// the ones added by address, which it still asks.
List<Override> castOverrides(FfmpegBinaries binaries, Directory folder) => [
  ...castShellOverrides,
  ffmpegBinariesProvider.overrideWithValue(binaries),
  processFolderProvider.overrideWithValue(
    Directory(p.join(folder.path, 'processes')),
  ),
  castFolderProvider.overrideWithValue(Directory(p.join(folder.path, 'cast'))),
  relayFolderProvider.overrideWithValue(
    Directory(p.join(folder.path, 'relay')),
  ),
  castDiscoveryProvider.overrideWith(
    (ref) => MergedCastDiscovery(
      browsers: const [],
      store: ref.watch(castDeviceStoreProvider),
      addressCheck: ref.watch(castAddressCheckProvider),
      log: ref.watch(appLogProvider),
    ),
  ),
];

/// The supervised processes still running: their PID files (hard rule 8).
List<File> runningProcesses(Directory folder) {
  final processes = Directory(p.join(folder.path, 'processes'));
  return processes.existsSync()
      ? processes.listSync().whereType<File>().toList()
      : const [];
}
