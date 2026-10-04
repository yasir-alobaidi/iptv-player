import 'dart:async';
import 'dart:io';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/downloads/hls_download.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';

import '../cast/relay/relay_rig.dart' show relayBinaries;

const movie = '/movie/test/test/100000.mp4';

void main() {
  final binaries = relayBinaries();
  if (binaries == null || Platform.isWindows) {
    test('HLS downloads', () {}, skip: 'needs FFmpeg (Linux)');
    return;
  }
  late Directory folder;
  late FakeProviderServer panel;
  late RelayProxy proxy;
  late ProcessSupervisor supervisor;
  late AppLog log;
  late String query;
  final events = <RelayProxyEvent>[];
  HlsDownload? current;

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    folder = Directory.systemTemp.createTempSync('hls_download_');
    final samples = Directory('${folder.path}/samples')..createSync();
    // A real 9-second clip under the MP4's name: the panel cuts it into
    // segments.
    final made = await Process.run(binaries.ffmpeg, [
      ...['-hide_banner', '-loglevel', 'error', '-y'],
      ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=9'],
      ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=9'],
      ...['-c:v', 'libx264', '-preset', 'ultrafast', '-g', '50'],
      ...['-c:a', 'aac', '-shortest'],
      '${samples.path}/${vodSamples.first}',
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    panel = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!.copyWith(maxConnections: 1),
        samplesDir: samples.path,
        ffmpegPath: binaries.ffmpeg,
        runDir: '${folder.path}/panel',
      ),
      port: 0,
    );
    log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
    query = 'vod_as_hls=1';
    events.clear();
    proxy = await RelayProxy.start(
      log: log,
      resolve: (inputId) async => RelayResolved(
        upstream: RelayUpstream(
          url: panel.url.resolve('$movie?$query').toString(),
          hls: true,
          maxConnections: 1,
        ),
      ),
      onEvent: (event) {
        events.add(event);
        current?.onProxy(event);
      },
    );
    supervisor = ProcessSupervisor(
      folder: Directory('${folder.path}/processes'),
      log: log,
    );
  });

  tearDown(() async {
    current = null;
    await supervisor.stopAll();
    await proxy.shutdown();
    await panel.close();
    folder.deleteSync(recursive: true);
  });

  String part() => '${folder.path}/Movies/A/A.mp4.part';

  Future<List<DownloadNews>> save({
    void Function(HlsDownload download, DownloadNews news)? watch,
  }) async {
    final news = <DownloadNews>[];
    late HlsDownload download;
    download = HlsDownload(
      DownloadOrder(id: 3, sourceId: 'src', partPath: part()),
      (item) {
        news.add(item);
        watch?.call(download, item);
      },
      proxy: proxy,
      supervisor: supervisor,
      ffmpeg: binaries.ffmpeg,
      log: log,
    );
    current = download;
    await download.run();
    return news;
  }

  Future<double?> duration(String path) async {
    final probe = await Process.run(binaries.ffprobe, [
      ...['-v', 'error', '-show_entries', 'format=duration'],
      ...['-of', 'default=nw=1:nk=1', path],
    ]);
    return double.tryParse('${probe.stdout}'.trim());
  }

  test('the playlist saved as one Matroska file, through the proxy, with no '
      'PID file left', () async {
    // What an earlier attempt left is no resume: it goes.
    File(part())
      ..createSync(recursive: true)
      ..writeAsStringSync('half of an earlier try');
    final news = await save();
    expect(news.first, isA<DownloadOpened>());
    expect((news.first as DownloadOpened).hls, isTrue);
    final done = news.last as DownloadDone;
    expect(done.bytes, File(part()).lengthSync());
    expect(done.bytes, greaterThan(10000));
    expect(news.whereType<DownloadMoved>(), isNotEmpty);
    expect(await duration(part()), closeTo(9, 0.6));
    expect(Directory('${folder.path}/processes').listSync(), isEmpty);
    expect(panel.state.activeStreams, 0);
    // Every connection went through the proxy and was counted.
    expect(
      events.whereType<RelayProxyConnections>().map((e) => e.open),
      contains(1),
    );
  });

  test("the provider's refusal says why", () async {
    for (final (fault, end) in [
      ('http_status=404', DownloadEnd.notFound),
      ('http_status=401', DownloadEnd.auth),
      ('http_status=500', DownloadEnd.server),
    ]) {
      query = 'vod_as_hls=1&$fault';
      final news = await save();
      final failed = news.last as DownloadFailedNews;
      expect(failed.end, end, reason: fault);
      expect(failed.status, int.parse(fault.split('=').last), reason: fault);
    }
  });

  test('stopped: FFmpeg ends, and it says where the file got to', () async {
    // The playlist comes late, so FFmpeg is still waiting when it stops.
    query = 'vod_as_hls=1&slow_start_ms=4000';
    final news = await save(
      watch: (download, item) {
        if (item is DownloadOpened) {
          Timer(const Duration(milliseconds: 500), () {
            unawaited(download.stop());
          });
        }
      },
    );
    expect(news.last, isA<DownloadHalted>());
    expect(supervisor.runningCount, 0);
  });
}
