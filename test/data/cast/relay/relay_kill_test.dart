import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/relay/relay_folders.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'relay_rig.dart';

/// Phase 7's exit criterion 2, with a real kill: a separate process
/// (`support/relay_victim.dart`) runs the relay, as the app does, with
/// FFmpeg relaying a channel of the fake panel, and gets SIGKILL. Its
/// FFmpeg must end by itself — its input was the dead app's proxy, or its
/// output the dead app's pipe — and the next launch's sweep must leave no
/// process, PID file or folder.
void main() {
  setUpAll(() => HttpOverrides.global = null);
  final skip = _whyNot() ?? relaySkip(['h264_1080p50_aac']);

  for (final output in ['hls', 'continuous']) {
    test(
      'killed while relaying ($output): FFmpeg ends by itself, the sweep '
      'leaves nothing',
      () async {
        final binaries = relayBinaries()!;
        final temp = await Directory.systemTemp.createTemp('relay_kill');
        addTearDown(() => temp.delete(recursive: true));
        final panel = await FakeProviderServer.start(
          state: FakeServerState(
            profile: fakeProfiles['default']!,
            samplesDir: samples.path,
            ffmpegPath: binaries.ffmpeg,
            runDir: p.join(temp.path, 'panel'),
          ),
          port: 0,
        );
        addTearDown(panel.close);
        final processes = Directory(p.join(temp.path, 'processes'));
        final relayRoot = Directory(p.join(temp.path, 'relay'));

        final victim = await Process.start('dart', [
          'run',
          'test/data/cast/relay/support/relay_victim.dart',
          binaries.ffmpeg,
          processes.path,
          relayRoot.path,
          '${panel.url}/live/test/test/1.ts',
          output,
        ]);
        addTearDown(() => victim.kill(ProcessSignal.sigkill));
        final errors = StringBuffer();
        unawaited(victim.stderr.transform(utf8.decoder).forEach(errors.write));
        final ready = await victim.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere((line) => line.startsWith('ready'))
            .timeout(const Duration(minutes: 1));

        // A continuous stream's FFmpeg starts with the TV's request.
        StreamSubscription<List<int>>? tv;
        if (output == 'continuous') {
          final client = HttpClient();
          addTearDown(() => client.close(force: true));
          final response = await (await client.getUrl(
            Uri.parse(ready.split(' ').last),
          )).close();
          final first = Completer<void>();
          tv = response.listen(
            (_) => first.isCompleted ? null : first.complete(),
            onError: (Object _) {},
          );
          await first.future.timeout(const Duration(seconds: 20));
        }

        final pids = [
          for (final file in processes.listSync().whereType<File>())
            if (p.basename(file.path).startsWith('relay-'))
              (jsonDecode(file.readAsStringSync()) as Map)['pid'] as int,
        ];
        expect(pids, hasLength(1), reason: 'the relay runs FFmpeg');
        final ffmpeg = pids.single;
        expect(_alive(ffmpeg), isTrue);
        // HLS writes its segments in a folder; a continuous stream none.
        final folders = output == 'hls' ? 1 : 0;
        expect(_list(relayRoot), hasLength(folders));

        victim.kill(ProcessSignal.sigkill);
        expect(await victim.exitCode, anyOf(-9, 137), reason: '$errors');

        final clock = Stopwatch()..start();
        while (_alive(ffmpeg) && clock.elapsed < const Duration(seconds: 30)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          _alive(ffmpeg),
          isFalse,
          reason: 'FFmpeg must end by itself, the app gone',
        );
        // ignore: avoid_print — the measurement, for ADR-014.
        print(
          '$output: FFmpeg ended ${clock.elapsedMilliseconds} ms after '
          'the kill',
        );
        await tv?.cancel();

        // The next launch.
        final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
        final killed = await ProcessSupervisor(
          folder: processes,
          log: log,
        ).sweep();
        expect(killed, 0, reason: 'nothing left to kill');
        expect(processes.listSync(), isEmpty, reason: 'no PID file');
        expect(await sweepRelayFolders(relayRoot, log: log), folders);
        expect(_list(relayRoot), isEmpty, reason: 'no folder');
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

List<FileSystemEntity> _list(Directory folder) =>
    folder.existsSync() ? folder.listSync() : const [];

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
