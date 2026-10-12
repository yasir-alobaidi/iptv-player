import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/cast_file_jobs.dart';
import 'package:iptv_player/data/cast/relay/relay_folders.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'relay/relay_rig.dart' show relayBinaries;

/// Phase 8's exit, with a real kill: a separate process
/// (`support/cast_helpers_victim.dart`) runs what a cast runs beside the
/// relay for a file on this computer — the MP4 for the TV's own seeks and
/// the file's subtitles as WebVTT — and gets SIGKILL part-way.
///
/// Unlike the relay's FFmpeg, these read a file and write a file: nothing
/// of theirs ends with the app, so they run on after it. The next
/// launch's sweep must kill them, and leave no PID file and none of what
/// they wrote.
void main() {
  final binaries = relayBinaries();
  final skip = _whyNot() ?? (binaries == null ? 'needs FFmpeg' : null);

  test(
    "killed while a cast's MP4 and subtitles are made: they outlive the "
    "app, and the next launch's sweep kills them and deletes what they "
    'wrote',
    () async {
      final temp = await Directory.systemTemp.createTemp('cast_kill');
      addTearDown(() => temp.delete(recursive: true));
      final processes = Directory(p.join(temp.path, 'processes'));
      final relayRoot = Directory(p.join(temp.path, 'relay'));

      // A two-minute film with a subtitle track of its own.
      String at(int cue, int second) => '00:0${cue ~/ 6}:${cue % 6}$second,000';
      final words = File(p.join(temp.path, 'words.srt'))
        ..writeAsStringSync(
          [
            for (var i = 0; i < 12; i++)
              '${i + 1}\n${at(i, 0)} --> ${at(i, 5)}\nLine ${i + 1}\n',
          ].join('\n'),
        );
      final film = p.join(temp.path, 'Film.mkv');
      final made = await Process.run(binaries!.ffmpeg, [
        ...['-hide_banner', '-v', 'error', '-nostdin', '-y'],
        ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=120'],
        ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=120'],
        ...['-i', words.path],
        ...['-map', '0:v', '-map', '1:a', '-map', '2:s'],
        ...['-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p'],
        ...['-c:a', 'ac3', '-c:s', 'subrip', film],
      ]);
      expect(made.exitCode, 0, reason: '${made.stderr}');

      final victim = await Process.start('dart', [
        'run',
        'test/data/cast/support/cast_helpers_victim.dart',
        binaries.ffmpeg,
        processes.path,
        relayRoot.path,
        film,
      ]);
      addTearDown(() => victim.kill(ProcessSignal.sigkill));
      final errors = StringBuffer();
      unawaited(victim.stderr.transform(utf8.decoder).forEach(errors.write));
      await victim.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => line == 'ready')
          .timeout(
            const Duration(minutes: 1),
            onTimeout: () => fail('the victim never started: $errors'),
          );

      Map<String, int> running() => {
        for (final file in processes.listSync().whereType<File>())
          p.basename(file.path).replaceFirst(RegExp(r'-\d+\.pid$'), ''):
              (jsonDecode(file.readAsStringSync()) as Map)['pid'] as int,
      };
      final pids = running();
      expect(pids.keys, unorderedEquals([castMp4Owner, castSubtitlesOwner]));
      addTearDown(() {
        for (final pid in pids.values) {
          Process.killPid(pid, ProcessSignal.sigkill);
        }
      });
      expect(pids.values.every(_alive), isTrue);
      final run = relayRoot.listSync().single as Directory;
      expect(
        File(p.join(run.path, 'mp4-1', 'media.mp4.part')).existsSync(),
        isTrue,
      );

      victim.kill(ProcessSignal.sigkill);
      expect(await victim.exitCode, anyOf(-9, 137), reason: '$errors');

      // Nothing ties them to the app: they are still at it.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
        pids.values.every(_alive),
        isTrue,
        reason: 'expected to outlive the app (they read and write files)',
      );

      // The next launch, as `bootstrap()` sweeps: processes, then folders.
      final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
      final killed = await ProcessSupervisor(
        folder: processes,
        log: log,
      ).sweep();
      expect(killed, 2);
      expect(pids.values.any(_alive), isFalse, reason: 'FFmpeg left running');
      expect(processes.listSync(), isEmpty, reason: 'no PID file');
      expect(await sweepRelayFolders(relayRoot, log: log), 1);
      expect(relayRoot.listSync(), isEmpty, reason: 'the half-made MP4');
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Whether [pid] runs: its `/proc` entry, which goes once it is reaped.
/// A zombie (ended, not yet reaped) counts as gone.
bool _alive(int pid) {
  try {
    final status = File('/proc/$pid/status').readAsStringSync();
    return !RegExp(r'^State:\s+Z', multiLine: true).hasMatch(status);
  } on FileSystemException {
    return false;
  }
}

/// A kill needs POSIX signals, `/proc`, and a `dart` to run the victim.
String? _whyNot() {
  if (!Platform.isLinux) return 'SIGKILL and /proc: Linux';
  try {
    final version = Process.runSync('dart', ['--version']);
    if (version.exitCode != 0) return 'no working `dart` on PATH';
  } on ProcessException {
    return 'no `dart` on PATH';
  }
  return null;
}
