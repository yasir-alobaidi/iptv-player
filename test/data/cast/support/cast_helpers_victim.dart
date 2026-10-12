// Not a test: the process `cast_helpers_kill_test.dart` starts and then
// kills with SIGKILL while it runs what a cast runs beside the relay for
// a file on this computer (Phase 8 decision 12): the MP4 the TV can seek
// in, and the file's own subtitles as WebVTT. Plain Dart (`dart run`): it
// starts the app's own commands (`cast_file_jobs.dart`) under the app's
// own supervisor, into the relay's folder for its run, as the app does.
import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/cast_file_jobs.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// `dart run …/cast_helpers_victim.dart ffmpeg processes relay-root
/// video`: starts both, prints `ready` once both write, then waits to be
/// killed. FFmpeg reads the film at its own pace (`-re`), so neither is
/// done when the kill comes.
Future<void> main(List<String> args) async {
  final [ffmpeg, processes, relayRoot, video] = args;
  final supervisor = ProcessSupervisor(
    folder: Directory(processes),
    log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
  );
  final run = Directory(p.join(relayRoot, '$pid'));
  final mp4 = Directory(p.join(run.path, 'mp4-1'))..createSync(recursive: true);
  final words = Directory(p.join(run.path, 'subtitles-1'))..createSync();
  List<String> paced(List<String> arguments) => [
    ...arguments.takeWhile((a) => a != '-i'),
    '-re',
    ...arguments.skipWhile((a) => a != '-i'),
  ];

  final part = File(p.join(mp4.path, 'media.mp4.part'));
  final started = [
    await supervisor.start(
      ffmpeg,
      paced(
        castMp4Arguments(
          video: video,
          // The relay's own for a film with its picture copied and its
          // sound converted.
          streams: const [
            ...['-map', '0:V:0', '-c:v', 'copy'],
            ...['-map', '0:a:0?', '-c:a', 'aac', '-b:a', '192k', '-ac', '2'],
          ],
          output: part.path,
        ),
      ),
      owner: castMp4Owner,
    ),
    await supervisor.start(
      ffmpeg,
      paced(
        castOwnSubtitlesArguments(
          video: video,
          tracks: const [0],
          output: (track) => p.join(words.path, 'own-$track.vtt'),
        ),
      ),
      owner: castSubtitlesOwner,
    ),
  ];
  for (final process in started) {
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
  }
  while (!part.existsSync()) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  stdout.writeln('ready');
  // Until the test kills it.
  await Completer<void>().future;
}
