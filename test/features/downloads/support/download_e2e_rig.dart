import 'dart:async';
import 'dart:io';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/downloads/db_download_store.dart';
import 'package:iptv_player/data/downloads/file_download_finisher.dart';
import 'package:iptv_player/data/downloads/http_download.dart';
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

/// Makes a real clip of [seconds] for the fake panel to serve: ffprobe
/// has to read what is downloaded.
Future<void> makeClip(
  FfmpegBinaries binaries,
  String path, {
  int seconds = 6,
}) async {
  final made = await Process.run(binaries.ffmpeg, [
    ...['-hide_banner', '-loglevel', 'error', '-y'],
    ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=$seconds'],
    ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=$seconds'],
    ...['-c:v', 'libx264', '-preset', 'ultrafast', '-g', '50'],
    ...['-c:a', 'aac', '-shortest', '-movflags', '+faststart'],
    path,
  ]);
  if (made.exitCode != 0) throw StateError('ffmpeg: ${made.stderr}');
}

/// Downloads end to end, real except the screens: the fake panel, the
/// downloads isolate, ffprobe, a database, the library.
final class DownloadE2E {
  new _({
    required this.temp,
    required this.panel,
    required this.db,
    required this.queue,
    required this.titles,
    required this.connections,
    required this.downloads,
    required this.supervisor,
  });

  static Future<DownloadE2E> start(
    FfmpegBinaries binaries, {
    required Directory temp,
    int maxConnections = 1,
    DownloadSettings settings = const DownloadSettings(),
    AppDatabase? database,
    Directory? samples,
  }) async {
    final sampleFolder = samples ?? Directory(p.join(temp.path, 'samples'))
      ..createSync(recursive: true);
    if (samples == null) {
      await makeClip(binaries, p.join(sampleFolder.path, vodSamples[0]));
      // Movie 100001 is damaged: bytes no player reads.
      File(p.join(sampleFolder.path, vodSamples[1]))
          .writeAsBytesSync(List.generate(300000, (i) => i * 7 % 256));
      File(p.join(sampleFolder.path, vodSamples[2])).writeAsBytesSync(
        File(p.join(sampleFolder.path, vodSamples[0])).readAsBytesSync(),
      );
    }
    final panel = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!.copyWith(
          maxConnections: maxConnections,
        ),
        samplesDir: sampleFolder.path,
        ffmpegPath: binaries.ffmpeg,
        runDir: p.join(temp.path, 'panel'),
      ),
      port: 0,
    );
    final db = database ?? AppDatabase.memory();
    await db
        .into(db.sources)
        .insertOnConflictUpdate(
          SourcesCompanion.insert(
            id: 'src',
            type: SourceType.xtream,
            name: 'Fake panel',
            url: panel.url.toString(),
            createdAt: DateTime.utc(2026, 10, 4),
            updatedAt: DateTime.utc(2026, 10, 4),
          ),
        );
    final downloads = p.join(temp.path, 'Videos', downloadFolderName);
    await registerDownloadFolder(
      db.libraryDao,
      downloads,
      now: DateTime.utc(2026, 10, 4),
    );
    final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
    final processes = Directory(p.join(temp.path, 'processes'));
    final supervisor = ProcessSupervisor(folder: processes, log: log);
    final poster = File(p.join(temp.path, 'poster-cache.jpg'))
      ..writeAsBytesSync([0xff, 0xd8, 0xff, 0xd9]);
    final titles = PanelTitles(
      panel,
      downloads,
      maxConnections: maxConnections,
    );
    final connections = SourceConnections();
    final queue = DownloadQueue(
      store: DbDownloadStore(db),
      titles: titles,
      runner: IsolateDownloadRunner(
        processFolder: processes,
        log: log,
        ffmpeg: binaries.ffmpeg,
        timings: const DownloadTimings(report: Duration(milliseconds: 50)),
      ),
      finisher: FileDownloadFinisher(
        db: db,
        probe: FfprobeStreamProbe(
          ffprobe: binaries.ffprobe,
          supervisor: supervisor,
          log: log,
        ),
        pictureFile: (_) async => poster.path,
        log: log,
      ),
      connections: connections,
      sleep: const NoSleepInhibitor(),
      settings: () => settings,
      log: log,
      freeSpace: freeBytes,
      fileExists: (path) => File(path).existsSync(),
      timings: const DownloadQueueTimings(
        retryWaits: [Duration(milliseconds: 200)],
        comeBackAfter: Duration(milliseconds: 500),
        limitWait: Duration(milliseconds: 500),
      ),
    );
    await queue.startUp();
    return DownloadE2E._(
      temp: temp,
      panel: panel,
      db: db,
      queue: queue,
      titles: titles,
      connections: connections,
      downloads: downloads,
      supervisor: supervisor,
    );
  }

  final Directory temp;
  final FakeProviderServer panel;
  final AppDatabase db;
  final DownloadQueue queue;
  final PanelTitles titles;
  final SourceConnections connections;

  /// The download folder.
  final String downloads;
  final ProcessSupervisor supervisor;

  Future<void> close({bool closeDb = true}) async {
    await queue.shutdown();
    await supervisor.stopAll();
    await panel.close();
    if (closeDb) await db.close();
  }

  /// Until [id] is in one of [states], or [within] passes.
  Future<DownloadTask> until(
    int id,
    Set<DownloadTaskState> states, {
    Duration within = const Duration(seconds: 30),
  }) => queue.tasks
      .map((list) => list.where((t) => t.id == id).firstOrNull)
      .firstWhere((t) => t != null && states.contains(t.state))
      .then((t) => t!)
      .timeout(within);

  static DownloadRequest movie(String key, {String title = 'Copper Hollow'}) =>
      DownloadRequest(
        sourceId: 'src',
        type: VodType.movie,
        remoteKey: key,
        title: title,
        year: 2025,
        artworkUrl: 'http://art.test/poster.jpg',
        extension: 'mp4',
      );
}

/// The fake panel's movies as download sources; [queries] adds faults
/// per title, changeable as a test goes.
final class PanelTitles implements DownloadTitles {
  new(this._panel, this._folder, {this.maxConnections = 1});

  final FakeProviderServer _panel;
  final String _folder;
  final int maxConnections;
  final queries = <String, String>{};
  int asked = 0;

  @override
  Future<DownloadSourceAnswer> source(DownloadTask task) async {
    asked++;
    final query = queries[task.remoteKey];
    final ext = task.remoteKey == '100000' ? 'mp4' : 'mkv';
    return DownloadSource(
      DownloadUpstream(
        url: _panel.url
            .resolve(
              '/movie/test/test/${task.remoteKey}.$ext${query == null ? '' : '?$query'}',
            )
            .toString(),
        userAgent: 'IPTV Player test',
      ),
      maxConnections: maxConnections,
    );
  }

  @override
  Future<String> folder() async => _folder;

  @override
  Future<bool> downloaded(DownloadRequest request) async => false;
}
