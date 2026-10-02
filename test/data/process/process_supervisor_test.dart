import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// A process that runs until it is stopped, on either system.
(String, List<String>) sleeper() => Platform.isWindows
    ? (
        p.join(
          Platform.environment['SystemRoot'] ?? r'C:\Windows',
          'System32',
          'PING.EXE',
        ),
        ['-n', '60', '127.0.0.1'],
      )
    : ('/bin/sleep', ['60']);

const _posixOnly = 'needs a POSIX shell';

/// 2,000 lines on standard error.
const _longLog =
    r'i=0; while [ $i -lt 2000 ]; do '
    r'echo "line $i of the log" >&2; i=$((i+1)); done';

void main() {
  late Directory temp;
  late Directory folder;
  late MemoryOutput output;
  late ProcessSupervisor supervisor;
  final strays = <Process>[];

  setUp(() {
    temp = Directory.systemTemp.createTempSync('supervisor_test_');
    folder = Directory(p.join(temp.path, 'processes'));
    output = MemoryOutput();
    supervisor = ProcessSupervisor(
      folder: folder,
      log: AppLog(output: output, secrets: SecretRegistry()),
      grace: const Duration(milliseconds: 300),
    );
  });

  tearDown(() async {
    await supervisor.stopAll();
    for (final process in strays) {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    strays.clear();
    temp.deleteSync(recursive: true);
  });

  List<File> pidFiles() => folder.existsSync()
      ? folder.listSync().whereType<File>().toList()
      : const [];

  Future<SupervisedProcess> startSleeper({Duration? timeout}) {
    final (executable, arguments) = sleeper();
    return supervisor.start(
      executable,
      arguments,
      owner: 'test',
      timeout: timeout,
    );
  }

  /// A sleeper the supervisor didn't start: a leftover of an earlier run.
  Future<Process> stray() async {
    final (executable, arguments) = sleeper();
    final process = await Process.start(executable, arguments);
    strays.add(process);
    return process;
  }

  void writeRecord(String name, Map<String, Object?> record) {
    folder.createSync(recursive: true);
    File(p.join(folder.path, name)).writeAsStringSync(jsonEncode(record));
  }

  group('a supervised process', () {
    test('has a PID file while it runs, and none once stopped', () async {
      final process = await startSleeper();
      final files = pidFiles();
      expect(files, hasLength(1));
      expect(p.basename(files.single.path), 'test-${process.pid}.pid');
      final record =
          jsonDecode(files.single.readAsStringSync()) as Map<String, Object?>;
      expect(record['pid'], process.pid);
      expect(record['executable'], sleeper().$1);
      expect(record['owner'], 'test');
      expect(record['app_pid'], pid);
      expect(supervisor.runningCount, 1);

      await process.stop();
      expect(process.exited, isTrue);
      expect(process.timedOut, isFalse);
      expect(pidFiles(), isEmpty);
      expect(supervisor.runningCount, 0);
    });

    test('is stopped at its timeout', () async {
      final watch = Stopwatch()..start();
      final process = await startSleeper(
        timeout: const Duration(milliseconds: 300),
      );
      await process.exitCode.timeout(const Duration(seconds: 5));
      expect(process.timedOut, isTrue);
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(pidFiles(), isEmpty);
      final lines = [for (final e in output.buffer) ...e.lines];
      expect(lines.join('\n'), contains('ran past 300 ms'));
    });

    test('one that ignores SIGTERM gets SIGKILL after the grace', () async {
      final process = await supervisor.start('/bin/sh', [
        '-c',
        'trap "" TERM; exec /bin/sleep 60',
      ], owner: 'stubborn');
      // Let the shell set its trap before it is asked to stop.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final watch = Stopwatch()..start();
      await process.stop().timeout(const Duration(seconds: 5));
      expect(
        watch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 250)),
      );
      expect(await process.exitCode, -ProcessSignal.sigkill.signalNumber);
      expect(pidFiles(), isEmpty);
    }, skip: Platform.isWindows ? _posixOnly : false);

    test('stop twice, or after it ended, is fine', () async {
      final process = await startSleeper();
      await Future.wait([process.stop(), process.stop()]);
      await process.stop();
      expect(process.exited, isTrue);
    });

    test('stopAll stops every one (the app quits)', () async {
      final a = await startSleeper();
      final b = await startSleeper();
      expect(pidFiles(), hasLength(2));
      await supervisor.stopAll();
      expect(a.exited && b.exited, isTrue);
      expect(pidFiles(), isEmpty);
    });

    test('an executable that is not there throws', () async {
      expect(
        supervisor.start(p.join(temp.path, 'nothing'), [], owner: 'test'),
        throwsA(isA<ProcessException>()),
      );
    });

    test('no PID file, no process: it is killed and start throws', () async {
      // The folder's place is taken by a file.
      File(folder.path).writeAsStringSync('in the way');
      Process? started;
      final strict = ProcessSupervisor(
        folder: folder,
        log: AppLog(output: output, secrets: SecretRegistry()),
        launcher: (executable, arguments, {environment}) async =>
            started = await Process.start(executable, arguments),
      );
      final (executable, arguments) = sleeper();
      await expectLater(
        strict.start(executable, arguments, owner: 'test'),
        throwsA(
          isA<ProcessException>().having(
            (e) => e.message,
            'message',
            contains('no PID file'),
          ),
        ),
      );
      await started!.exitCode.timeout(const Duration(seconds: 5));
      expect(strict.runningCount, 0);
    });
  });

  group('run', () {
    test('gathers the exit code and what it printed', () async {
      final run = await supervisor.run(
        '/bin/sh',
        ['-c', 'echo out; echo err >&2; exit 3'],
        owner: 'test',
        timeout: const Duration(seconds: 10),
      );
      expect(run.startError, isNull);
      expect(run.exitCode, 3);
      expect(utf8.decode(run.stdout), 'out\n');
      expect(run.stderr, 'err\n');
      expect(run.timedOut, isFalse);
      expect(run.overflowed, isFalse);
      expect(pidFiles(), isEmpty);
    }, skip: Platform.isWindows ? _posixOnly : false);

    test("the environment it is given adds to the app's", () async {
      final run = await supervisor.run(
        '/bin/sh',
        ['-c', r'echo "$SUPERVISOR_TEST_VALUE ${PATH:+and the path}"'],
        owner: 'test',
        timeout: const Duration(seconds: 10),
        environment: {'SUPERVISOR_TEST_VALUE': 'given'},
      );
      expect(utf8.decode(run.stdout), 'given and the path\n');
    }, skip: Platform.isWindows ? _posixOnly : false);

    test('keeps the end of a long standard error', () async {
      final run = await supervisor.run(
        '/bin/sh',
        ['-c', _longLog],
        owner: 'test',
        timeout: const Duration(seconds: 20),
      );
      expect(run.stderr.length, lessThanOrEqualTo(8 << 10));
      expect(run.stderr, endsWith('line 1999 of the log\n'));
    }, skip: Platform.isWindows ? _posixOnly : false);

    test('stops what prints more than it may', () async {
      final run = await supervisor.run(
        '/usr/bin/yes',
        const [],
        owner: 'test',
        timeout: const Duration(seconds: 10),
        maxOutput: 1000,
      );
      expect(run.overflowed, isTrue);
      expect(run.stdout.length, lessThanOrEqualTo(1000));
      expect(pidFiles(), isEmpty);
    }, skip: Platform.isWindows ? _posixOnly : false);

    test('a timeout ends it, and says so', () async {
      final (executable, arguments) = sleeper();
      final run = await supervisor.run(
        executable,
        arguments,
        owner: 'test',
        timeout: const Duration(milliseconds: 300),
      );
      expect(run.timedOut, isTrue);
      expect(pidFiles(), isEmpty);
    });

    test('one that cannot start answers why, never throws', () async {
      final run = await supervisor.run(
        p.join(temp.path, 'nothing'),
        const [],
        owner: 'test',
        timeout: const Duration(seconds: 1),
      );
      expect(run.exitCode, isNull);
      expect(run.startError, isNotNull);
    });
  });

  group('the launch sweep', () {
    test('kills a leftover of ours and deletes its file', () async {
      final leftover = await stray();
      writeRecord('ffmpeg-${leftover.pid}.pid', {
        'pid': leftover.pid,
        'executable': sleeper().$1,
        'owner': 'relay',
        'app_pid': 1 << 30,
        'app_executable': '/gone/iptv_player',
      });
      expect(await supervisor.sweep(), 1);
      await leftover.exitCode.timeout(const Duration(seconds: 5));
      expect(pidFiles(), isEmpty);
      final lines = [for (final e in output.buffer) ...e.lines];
      expect(
        lines.join('\n'),
        contains('Stopped a leftover relay (pid ${leftover.pid})'),
      );
    });

    test('leaves a process that now runs something else', () async {
      final other = await stray();
      writeRecord('ffmpeg-${other.pid}.pid', {
        'pid': other.pid,
        'executable': p.join(temp.path, 'ffmpeg'),
        'owner': 'relay',
      });
      expect(await supervisor.sweep(), 0);
      expect(pidFiles(), isEmpty);
      // Still running.
      expect(
        await other.exitCode.timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => -1,
        ),
        -1,
      );
    });

    test('leaves what another copy of the app still runs', () async {
      final process = await stray();
      final app = await stray();
      writeRecord('ffmpeg-${process.pid}.pid', {
        'pid': process.pid,
        'executable': sleeper().$1,
        'owner': 'relay',
        'app_pid': app.pid,
        'app_executable': sleeper().$1,
      });
      expect(await supervisor.sweep(), 0);
      expect(pidFiles(), hasLength(1));
    });

    test('leaves its own running processes and their files', () async {
      final mine = await startSleeper();
      expect(await supervisor.sweep(), 0);
      expect(mine.exited, isFalse);
      expect(pidFiles(), hasLength(1));
    });

    test('deletes files of processes long gone, and junk', () async {
      writeRecord('ffprobe-999.pid', {
        'pid': 1 << 30,
        'executable': sleeper().$1,
      });
      folder.createSync(recursive: true);
      for (final junk in ['{', '[]', '{"pid":"1"}', '{"pid":5}', '']) {
        File(p.join(folder.path, 'junk-${junk.hashCode}.pid'))
            .writeAsStringSync(junk);
      }
      final keep = File(p.join(folder.path, 'notes.txt'))
        ..writeAsStringSync('not a PID file');
      expect(await supervisor.sweep(), 0);
      expect(pidFiles().map((f) => f.path), [keep.path]);
    });

    test('no folder yet is nothing to do', () async {
      expect(await supervisor.sweep(), 0);
    });

    test('a kill that fails is not counted', () async {
      final unkillable = ProcessSupervisor(
        folder: folder,
        log: AppLog(output: output, secrets: SecretRegistry()),
        image: (_) => '/opt/app/ffmpeg',
        kill: (_) => false,
      );
      writeRecord('relay-42.pid', {'pid': 42, 'executable': '/opt/app/ffmpeg'});
      expect(await unkillable.sweep(), 0);
      expect(pidFiles(), isEmpty);
    });
  });

  group('which executable a process runs', () {
    test('a running one is known; a gone one is not', () async {
      final process = await stray();
      final image = processImage(process.pid);
      expect(image, isNotNull);
      expect(samePath(image!, sleeper().$1), isTrue);
      expect(processImage(1 << 30), isNull);
    });

    test('links are followed, and a replaced executable still matches', () {
      final target = File(p.join(temp.path, 'ffmpeg'))..writeAsStringSync('');
      final link = Link(p.join(temp.path, 'ffmpeg-link'))
        ..createSync(target.path);
      expect(samePath(link.path, target.path), isTrue);
      expect(samePath('${target.path} (deleted)', target.path), isTrue);
      expect(samePath(target.path, p.join(temp.path, 'ffprobe')), isFalse);
      expect(
        samePath(p.join(temp.path, 'a', '..', 'ffmpeg'), target.path),
        isTrue,
      );
    }, skip: Platform.isWindows ? 'links need rights on Windows' : false);
  });
}
