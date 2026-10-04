import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/downloads/http_download.dart';
import 'package:iptv_player/data/downloads/isolate_download_runner.dart';
import 'package:logger/logger.dart';

const int sampleSize = 900 * 1024;
final Uint8List sample = Uint8List.fromList(
  List<int>.generate(sampleSize, (i) => (i * 31 + 3) % 253),
);

void main() {
  late Directory folder;
  late FakeProviderServer panel;
  late IsolateDownloadRunner runner;
  late MemoryOutput logged;

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    folder = Directory.systemTemp.createTempSync('download_runner_');
    final samples = Directory('${folder.path}/samples')..createSync();
    for (final name in vodSamples) {
      File('${samples.path}/$name').writeAsBytesSync(sample);
    }
    panel = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!.copyWith(maxConnections: 2),
        samplesDir: samples.path,
        ffmpegPath: 'ffmpeg',
        runDir: folder.path,
      ),
      port: 0,
    );
    logged = MemoryOutput(bufferSize: 1000);
    runner = IsolateDownloadRunner(
      processFolder: Directory('${folder.path}/processes'),
      log: AppLog(output: logged, secrets: SecretRegistry()),
      timings: const DownloadTimings(report: Duration(milliseconds: 50)),
    );
  });

  tearDown(() async {
    await runner.close();
    await panel.close();
    folder.deleteSync(recursive: true);
  });

  String part(int id) => '${folder.path}/d$id/movie.mp4.part';

  Future<DownloadNews> end(int id) => runner.news.firstWhere(
    (n) =>
        n.id == id &&
        (n is DownloadDone || n is DownloadHalted || n is DownloadFailedNews),
  );

  test('two downloads at once, each in its .part, the URL asked for on '
      'every connection', () async {
    var asked = 0;
    Future<DownloadUpstream?> upstream(String query) async {
      asked++;
      return DownloadUpstream(
        url: panel.url.resolve('/movie/test/test/100000.mp4$query').toString(),
        userAgent: 'IPTV Player test',
      );
    }

    final first = end(1);
    final second = end(2);
    await runner.start(
      DownloadOrder(id: 1, sourceId: 's', partPath: part(1)),
      upstream: () => upstream(''),
    );
    await runner.start(
      DownloadOrder(id: 2, sourceId: 's', partPath: part(2)),
      upstream: () => upstream('?throttle_kbps=4000'),
    );
    expect(await first, isA<DownloadDone>());
    expect(await second, isA<DownloadDone>());
    expect(File(part(1)).readAsBytesSync(), sample);
    expect(File(part(2)).readAsBytesSync(), sample);
    expect(asked, 2);
  });

  test('stopped mid-way: flushed and closed where it got to', () async {
    final moved = Completer<void>();
    final listening = runner.news.listen((n) {
      if (n is DownloadMoved && n.bytes > 50 * 1024 && !moved.isCompleted) {
        moved.complete();
      }
    });
    addTearDown(listening.cancel);
    final ended = end(5);
    await runner.start(
      DownloadOrder(id: 5, sourceId: 's', partPath: part(5)),
      upstream: () async => DownloadUpstream(
        url: panel.url
            .resolve('/movie/test/test/100000.mp4?throttle_kbps=1600')
            .toString(),
      ),
    );
    await moved.future;
    await runner.stop(5);
    final halted = await ended as DownloadHalted;
    expect(halted.bytes, greaterThan(50 * 1024));
    expect(halted.bytes, lessThan(sampleSize));
    expect(File(part(5)).readAsBytesSync(), sample.sublist(0, halted.bytes));
  });

  test('no URL from the app: unresolved', () async {
    final ended = end(9);
    await runner.start(
      DownloadOrder(id: 9, sourceId: 's', partPath: part(9)),
      upstream: () async => null,
    );
    expect((await ended as DownloadFailedNews).end, DownloadEnd.unresolved);
  });

  test('after close, a start does nothing and throws nothing', () async {
    await runner.close();
    await runner.start(
      DownloadOrder(id: 4, sourceId: 's', partPath: part(4)),
      upstream: () async => null,
    );
    expect(File(part(4)).existsSync(), isFalse);
  });
}
