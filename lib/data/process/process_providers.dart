import 'dart:io';

import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'process_providers.g.dart';

/// Where supervised processes keep their PID files. `bootstrap()` points
/// it into the app's own folder; this is the fallback when it has none.
@Riverpod(keepAlive: true)
Directory processFolder(Ref ref) =>
    Directory(p.join(Directory.systemTemp.path, 'iptv_player', 'processes'));

/// Every FFmpeg and ffprobe the app runs goes through this (hard rule 8);
/// they stop with it.
@Riverpod(keepAlive: true)
ProcessSupervisor processSupervisor(Ref ref) {
  final supervisor = ProcessSupervisor(
    folder: ref.watch(processFolderProvider),
    log: ref.watch(appLogProvider),
  );
  ref.onDispose(supervisor.stopAll);
  return supervisor;
}
