// Plain Dart, like the relay it cleans up after.
import 'dart:io';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';

/// The launch sweep's second half (docs/04 "On app start"): the relay
/// keeps a run's sessions in `<root>/<the app's pid>`, and a folder whose
/// run is gone is deleted with every segment in it. A folder of another
/// copy of the app that still runs is left alone, as the process sweep
/// leaves its FFmpegs; so is this run's own. Runs after the process
/// sweep, so no FFmpeg still writes into what it deletes. Answers how
/// many it deleted; never throws.
Future<int> sweepRelayFolders(
  Directory root, {
  required AppLog log,
  ProcessImage? image,
  String? executable,
}) async {
  final imageOf = image ?? processImage;
  final ours = executable ?? Platform.resolvedExecutable;
  final List<FileSystemEntity> entries;
  try {
    if (!root.existsSync()) return 0;
    entries = root.listSync();
  } on FileSystemException catch (error) {
    log.warning('relay', 'Could not sweep ${root.path}', error: error);
    return 0;
  }
  var deleted = 0;
  for (final entry in entries) {
    if (entry is! Directory) continue;
    final owner = int.tryParse(
      entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => ''),
    );
    if (owner == null || owner == pid) continue;
    final running = imageOf(owner);
    if (running != null && samePath(running, ours)) continue;
    try {
      entry.deleteSync(recursive: true);
      deleted++;
    } on FileSystemException catch (error) {
      log.warning('relay', 'Could not delete ${entry.path}', error: error);
    }
  }
  if (deleted > 0) {
    log.info('relay', 'Deleted $deleted relay folder(s) from earlier runs');
  }
  return deleted;
}
