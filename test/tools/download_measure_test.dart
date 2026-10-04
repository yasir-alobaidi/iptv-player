@Tags(['benchmark'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_provider/generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/downloads/isolate_download_runner.dart';
import 'package:iptv_player/data/platform/disk_space.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// docs/06's download budgets, measured: speed against curl on the same
/// URL (≥ 90 %), and the app's memory over a 4 GB download (≤ 30 MB
/// more). The fake panel runs in its own process, as the other budgets'
/// do; both clients write to the same drive. Skipped unless run with
/// `flutter test --tags benchmark --run-skipped
/// test/tools/download_measure_test.dart`. Needs about 7 GB free.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test('download speed against curl, and memory over 4 GB', () async {
    final temp = Directory.systemTemp.createTempSync('download_measure_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final free = freeBytes(temp.path) ?? 0;
    if (free < (7 << 30)) {
      markTestSkipped('needs 7 GB free in ${temp.path}, has ${free >> 20} MB');
      return;
    }
    final samples = Directory(p.join(temp.path, 'samples'))..createSync();
    for (final name in vodSamples) {
      File(p.join(samples.path, name))
          .writeAsBytesSync(List.generate(1 << 20, (i) => i * 7 % 256));
    }
    final panel = await _Panel.start(samples, temp);
    addTearDown(panel.stop);
    final runner = IsolateDownloadRunner(
      processFolder: Directory(p.join(temp.path, 'processes')),
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
    );
    addTearDown(runner.close);
    final report = StringBuffer('# Downloads, measured\n\n');

    // Speed, twice each, the better run of each: unthrottled over
    // loopback (Dart's HTTP stack's own ceiling), then at real network
    // rates through the panel's throttle.
    double best(List<double> runs) => runs.reduce((a, b) => a > b ? a : b);
    var round = 0;
    Future<(double, double)> compare(String query) async {
      final url = '${panel.url}/movie/test/test/100000.mp4?$query';
      final curl = <double>[];
      final ours = <double>[];
      for (var i = 0; i < 2; i++) {
        final out = File(p.join(temp.path, 'curl.bin'));
        final clock = Stopwatch()..start();
        final result = await Process.run('curl', ['-s', '-o', out.path, url]);
        clock.stop();
        expect(result.exitCode, 0, reason: '${result.stderr}');
        curl.add(out.lengthSync() / clock.elapsedMicroseconds * 1e6);
        out.deleteSync();

        final id = round++;
        final part = p.join(temp.path, 'ours-$id.part');
        final ended = runner.news.firstWhere(
          (n) => n.id == id && n is! DownloadMoved && n is! DownloadOpened,
        );
        final watch = Stopwatch()..start();
        await runner.start(
          DownloadOrder(id: id, sourceId: 's', partPath: part),
          upstream: () async => DownloadUpstream(url: url),
        );
        final news = await ended;
        watch.stop();
        expect(news, isA<DownloadDone>());
        ours.add(File(part).lengthSync() / watch.elapsedMicroseconds * 1e6);
        File(part).deleteSync();
      }
      return (best(curl), best(ours));
    }

    report.writeln('## Speed against curl, the same URL (budget ≥ 90 %)');
    final rates = [
      ('loopback, unthrottled, 2 GiB', 'size_mb=2048'),
      ('1 Gbps, 512 MiB', 'size_mb=512&throttle_kbps=1000000'),
      ('100 Mbps, 64 MiB', 'size_mb=64&throttle_kbps=100000'),
    ];
    final ratios = <String, double>{};
    for (final (name, query) in rates) {
      final (curl, ours) = await compare(query);
      final ratio = ours / curl;
      ratios[name] = ratio;
      report.writeln(
        '- $name: curl ${_mbps(curl)}, the app ${_mbps(ours)}: '
        '**${(ratio * 100).toStringAsFixed(1)} %**',
      );
    }
    report.writeln();

    // Memory: the app's process while 4 GiB come in, at a network's rate
    // (the budget) and over loopback (reported: its 4 MB chunks are a
    // 2 GB/s socket's, not a network's).
    Future<int> growthOver(String name, String query, int id) async {
      final baseline = _rss();
      var peak = baseline;
      final samples = <int>[];
      final sampler = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final now = _rss();
        samples.add(now);
        if (now > peak) peak = now;
      });
      final big = p.join(temp.path, 'big.part');
      final ended = runner.news.firstWhere(
        (n) => n.id == id && n is! DownloadMoved && n is! DownloadOpened,
      );
      final clock = Stopwatch()..start();
      await runner.start(
        DownloadOrder(id: id, sourceId: 's', partPath: big),
        upstream: () async => DownloadUpstream(
          url: '${panel.url}/movie/test/test/100000.mp4?size_mb=4096$query',
        ),
      );
      final news = await ended;
      clock.stop();
      sampler.cancel();
      expect(news, isA<DownloadDone>());
      expect(File(big).lengthSync(), 4096 << 20);
      final growth = peak - baseline;
      // Whether it grows with the file, or settles: each quarter's peak.
      final quarter = (samples.length / 4).ceil().clamp(1, 1 << 30);
      final quarters = [
        for (var i = 0; i < samples.length; i += quarter)
          (samples.skip(i).take(quarter).reduce((a, b) => a > b ? a : b) -
                  baseline) >>
              20,
      ];
      report
        ..writeln(
          "- $name: each quarter's peak over the start: "
          '${quarters.map((q) => '+$q MB').join(', ')}',
        )
        ..writeln(
          '- $name: RSS ${baseline >> 20} MB before, peak ${peak >> 20} MB: '
          '**+${(growth / (1 << 20)).toStringAsFixed(1)} MB**, '
          '${_mbps(File(big).lengthSync() / clock.elapsedMicroseconds * 1e6)}',
        );
      File(big).deleteSync();
      return growth;
    }

    report.writeln('## Memory over 4 GiB (budget ≤ 30 MB)');
    final growth = await growthOver('1 Gbps', '&throttle_kbps=1000000', 100);
    await growthOver('loopback, unthrottled', '', 101);

    final out = Directory('build/download_measure')
      ..createSync(recursive: true);
    File(p.join(out.path, 'report.md')).writeAsStringSync('$report');
    // The report is the point of this test.
    // ignore: avoid_print
    print(report);
    // At network rates; loopback measures Dart's HTTP stack, reported.
    expect(ratios['1 Gbps, 512 MiB'], greaterThanOrEqualTo(0.9));
    expect(ratios['100 Mbps, 64 MiB'], greaterThanOrEqualTo(0.9));
    expect(growth, lessThanOrEqualTo(30 << 20));
  }, timeout: const Timeout(Duration(minutes: 15)));
}

String _mbps(double bytesPerSecond) =>
    '${(bytesPerSecond / (1 << 20)).toStringAsFixed(0)} MB/s';

/// This process's resident memory, in bytes.
int _rss() {
  final line = File('/proc/self/status')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('VmRSS:'));
  return int.parse(RegExp(r'(\d+)').firstMatch(line)![1]!) * 1024;
}

final class _Panel {
  new _(this._process, this.url);

  static Future<_Panel> start(Directory samples, Directory temp) async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final process = await Process.start('dart', [
      'run',
      'tools/fake_provider/bin/server.dart',
      ...['--port', '$port', '--samples', samples.path],
      ...['--run-dir', p.join(temp.path, 'panel'), '--max-connections', '4'],
    ]);
    unawaited(process.stderr.drain<void>());
    final up = Completer<void>();
    process.stdout.transform(utf8.decoder).listen((text) {
      if (text.contains('$port') && !up.isCompleted) up.complete();
    });
    await up.future.timeout(const Duration(minutes: 1));
    return _Panel._(process, 'http://127.0.0.1:$port');
  }

  final Process _process;
  final String url;

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
  }
}
