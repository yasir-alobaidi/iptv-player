import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/vod.dart' show fakePaddingByte;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/downloads/db_download_store.dart';
import 'package:iptv_player/data/downloads/file_download_finisher.dart';
import 'package:iptv_player/data/downloads/isolate_download_runner.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/platform/disk_space.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/downloads/domain/download_queue.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../data/cast/relay/relay_rig.dart' show relayBinaries;
import 'support/download_e2e_rig.dart' show makeClip;

/// docs/08's Phase 8 exit: a download killed with SIGKILL leaves no
/// damaged file under a final name, the next launch resumes it, and no
/// FFmpeg is left running.
void main() {
  final binaries = relayBinaries();
  final whyNot = _whyNot(binaries);
  if (whyNot != null) {
    test('a download killed with SIGKILL', () {}, skip: whyNot);
    return;
  }
  late Directory temp;
  late FakeProviderServer panel;
  late String folder;
  late Directory database;
  late Directory processes;

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('download_kill_');
    final samples = Directory(p.join(temp.path, 'samples'))..createSync();
    await makeClip(binaries!, p.join(samples.path, vodSamples[0]));
    panel = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!.copyWith(maxConnections: 1),
        samplesDir: samples.path,
        ffmpegPath: binaries.ffmpeg,
        runDir: p.join(temp.path, 'panel'),
      ),
      port: 0,
    );
    folder = p.join(temp.path, 'Videos', downloadFolderName);
    database = Directory(p.join(temp.path, 'db'));
    processes = Directory(p.join(temp.path, 'processes'));
    final db = AppDatabase(await openAppDatabase(database));
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: 'src',
            type: SourceType.xtream,
            name: 'Fake panel',
            url: panel.url.toString(),
            createdAt: DateTime.utc(2026, 10, 4),
            updatedAt: DateTime.utc(2026, 10, 4),
          ),
        );
    await registerDownloadFolder(
      db.libraryDao,
      folder,
      now: DateTime.utc(2026),
    );
    await db.close();
  });

  tearDown(() async {
    await panel.close();
    temp.deleteSync(recursive: true);
  });

  String movieUrl(String query) =>
      panel.url.resolve('/movie/test/test/100000.mp4?$query').toString();

  String target() => p.join(
    folder,
    'Movies',
    'Copper Hollow (2025)',
    'Copper Hollow (2025).mp4',
  );

  test('killed part-way: nothing under the final name; the next launch '
      'resumes from the .part and finishes it whole', () async {
    const size = 40 << 20;
    await _runAndKill(
      [
        database.path,
        processes.path,
        folder,
        movieUrl('size_mb=40&throttle_kbps=80000'),
        binaries!.ffmpeg,
        binaries.ffprobe,
      ],
      killWhen: (line) {
        final match = RegExp(r'^bytes (\d+) downloading$').firstMatch(line);
        return match != null && int.parse(match[1]!) > (12 << 20);
      },
    );
    final part = File('${target()}.part');
    expect(File(target()).existsSync(), isFalse);
    final onDisk = part.lengthSync();
    expect(onDisk, greaterThan(12 << 20));
    expect(onDisk, lessThan(size));

    // The next launch.
    final db = AppDatabase(await openAppDatabase(database));
    addTearDown(db.close);
    final row = (await db.downloadsDao.all()).single;
    expect(row.state, DownloadTaskState.downloading);
    expect(row.downloadedBytes, inInclusiveRange(8 << 20, onDisk));
    final queue = _queue(db, processes, folder, movieUrl('size_mb=40'));
    addTearDown(queue.shutdown);
    await queue.startUp();
    final opened = Completer<int>();
    final done = queue.tasks
        .map((tasks) => tasks.single)
        .firstWhere((t) {
          if (t.state == DownloadTaskState.downloading && !opened.isCompleted) {
            opened.complete(t.downloadedBytes);
          }
          return t.state.isFinished;
        })
        .timeout(const Duration(seconds: 60));
    final finished = await done;
    expect(finished.state, DownloadTaskState.completed);
    expect(
      await opened.future,
      greaterThanOrEqualTo(onDisk - (1 << 20)),
      reason: 'it resumed, not restarted',
    );
    final bytes = File(target()).readAsBytesSync();
    expect(bytes, hasLength(size));
    final sample = File(p.join(temp.path, 'samples', vodSamples[0]))
        .readAsBytesSync();
    expect(bytes.sublist(0, sample.length), sample);
    for (final at in [
      sample.length,
      onDisk - 1,
      onDisk,
      onDisk + 1,
      size - 1,
    ]) {
      expect(bytes[at], fakePaddingByte(at), reason: '$at');
    }
    expect(part.existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test("a playlist's FFmpeg ends without its app, and the next launch's "
      'sweep leaves nothing', () async {
    await _runAndKill(
      [
        database.path,
        processes.path,
        folder,
        // The playlist comes late: FFmpeg is waiting on it when the kill
        // comes.
        movieUrl('vod_as_hls=1&slow_start_ms=20000'),
        binaries!.ffmpeg,
        binaries.ffprobe,
      ],
      killWhen: (_) =>
          processes.existsSync() &&
          processes.listSync().any(
            (f) => p.basename(f.path).startsWith('download-'),
          ),
    );
    final pidFiles = processes
        .listSync()
        .where((f) => p.basename(f.path).startsWith('download-'))
        .toList();
    expect(pidFiles, isNotEmpty);
    final pid = int.parse(
      p.basenameWithoutExtension(pidFiles.single.path).split('-').last,
    );
    // Its input was the killed app's proxy: it ends by itself.
    final clock = Stopwatch()..start();
    while (_running(pid) && clock.elapsed < const Duration(seconds: 20)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(_running(pid), isFalse, reason: 'FFmpeg $pid outlived its app');
    // The measurement docs/06 keeps beside the relay's.
    // ignore: avoid_print
    print('FFmpeg ended ${clock.elapsedMilliseconds} ms after its app');

    final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
    await ProcessSupervisor(folder: processes, log: log).sweep();
    expect(
      processes.listSync().where(
        (f) => p.basename(f.path).startsWith('download-'),
      ),
      isEmpty,
    );
    expect(File(target()).existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

DownloadQueue _queue(
  AppDatabase db,
  Directory processes,
  String folder,
  String url,
) {
  final binaries = relayBinaries()!;
  final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
  return DownloadQueue(
    store: DbDownloadStore(db),
    titles: _Titles(url, folder),
    runner: IsolateDownloadRunner(
      processFolder: processes,
      log: log,
      ffmpeg: binaries.ffmpeg,
    ),
    finisher: FileDownloadFinisher(
      db: db,
      probe: FfprobeStreamProbe(
        ffprobe: binaries.ffprobe,
        supervisor: ProcessSupervisor(folder: processes, log: log),
        log: log,
      ),
      pictureFile: (_) async => null,
      log: log,
    ),
    connections: SourceConnections(),
    sleep: const NoSleepInhibitor(),
    settings: () => const DownloadSettings(),
    log: log,
    freeSpace: freeBytes,
    fileExists: (path) => File(path).existsSync(),
  );
}

final class _Titles implements DownloadTitles {
  new(this._url, this._folder);

  final String _url;
  final String _folder;

  @override
  Future<DownloadSourceAnswer> source(DownloadTask task) async =>
      DownloadSource(DownloadUpstream(url: _url), maxConnections: 1);

  @override
  Future<String> folder() async => _folder;

  @override
  Future<bool> downloaded(DownloadRequest request) async => false;
}

/// Starts the victim and kills it once [killWhen] says so (checked on
/// every line it prints, and every 100 ms).
Future<void> _runAndKill(
  List<String> args, {
  required bool Function(String line) killWhen,
}) async {
  final process = await Process.start('dart', [
    'run',
    'test/features/downloads/support/download_victim.dart',
    ...args,
  ]);
  final killed = Completer<void>();
  void kill() {
    if (killed.isCompleted) return;
    process.kill(ProcessSignal.sigkill);
    killed.complete();
  }

  final output = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (killWhen(line)) kill();
      });
  final poll = Timer.periodic(const Duration(milliseconds: 100), (_) {
    if (killWhen('')) kill();
  });
  final errors = StringBuffer();
  unawaited(process.stderr.transform(utf8.decoder).forEach(errors.write));
  final code = await process.exitCode.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    },
  );
  poll.cancel();
  await output.cancel();
  expect(killed.isCompleted, isTrue, reason: 'stderr: $errors');
  expect(code, anyOf(-9, 137));
}

bool _running(int pid) =>
    Directory('/proc/$pid').existsSync() &&
    !File('/proc/$pid/stat').readAsStringSync().contains(') Z ');

String? _whyNot(FfmpegBinaries? binaries) {
  if (!Platform.isLinux) return 'SIGKILL and /proc: Linux';
  if (binaries == null) return 'needs FFmpeg';
  try {
    final version = Process.runSync('dart', ['--version']);
    if (version.exitCode != 0) return 'no working `dart` on PATH';
  } on ProcessException {
    return 'no `dart` on PATH';
  }
  return null;
}
