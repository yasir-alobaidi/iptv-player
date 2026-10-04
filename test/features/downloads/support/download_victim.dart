// Not a test: the process `download_kill_test.dart` starts and then kills
// with SIGKILL in the middle of a download, to prove a crash leaves no
// damaged file under a final name and the next launch resumes it. Plain
// Dart (`dart run`), like the queue, the runner and the database.
import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/downloads/db_download_store.dart';
import 'package:iptv_player/data/downloads/isolate_download_runner.dart';
import 'package:iptv_player/data/platform/disk_space.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/downloads/domain/download_queue.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:logger/logger.dart';

/// `dart run …/download_victim.dart DATABASE PROCESSES FOLDER URL FFMPEG
/// FFPROBE`: downloads movie 100000 from URL, printing `bytes N STATE` as
/// it goes; the test kills it part-way. It never gets to finishing, so it
/// has no finisher (whose ffprobe types bring Flutter in).
Future<void> main(List<String> args) async {
  final [database, processes, folder, url, ffmpeg, _] = args;
  final db = AppDatabase(await openAppDatabase(Directory(database)));
  final log = AppLog(output: _Silent(), secrets: SecretRegistry());
  final queue = DownloadQueue(
    store: DbDownloadStore(db),
    titles: _Titles(url, folder),
    runner: IsolateDownloadRunner(
      processFolder: Directory(processes),
      log: log,
      ffmpeg: ffmpeg,
    ),
    finisher: _NeverFinished(),
    connections: SourceConnections(),
    sleep: const NoSleepInhibitor(),
    settings: () => const DownloadSettings(),
    log: log,
    freeSpace: freeBytes,
    fileExists: (path) => File(path).existsSync(),
  );
  await queue.startUp();
  queue.tasks.listen((tasks) {
    for (final task in tasks) {
      stdout.writeln('bytes ${task.downloadedBytes} ${task.state.name}');
    }
  });
  await queue.enqueue([
    const DownloadRequest(
      sourceId: 'src',
      type: VodType.movie,
      remoteKey: '100000',
      title: 'Copper Hollow',
      year: 2025,
      extension: 'mp4',
    ),
  ]);
  // Until killed.
  await Completer<void>().future;
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

final class _NeverFinished implements DownloadFinisher {
  @override
  Future<DownloadFinish> finish(DownloadTask task) async =>
      const DownloadNotFinished('the victim never finishes');

  @override
  Future<void> discard(DownloadTask task) async {}

  @override
  Future<int> partSize(DownloadTask task) async {
    final part = File('${task.targetPath}.part');
    return part.existsSync() ? part.lengthSync() : 0;
  }
}

final class _Silent extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
