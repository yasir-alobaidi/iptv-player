@Tags(['benchmark'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/relay/isolate_cast_relay.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../data/cast/relay/relay_rig.dart';

/// Phase 7 step 5's measurements (Linux; nothing is cast, nothing
/// shows), with the relay in its isolate as the app runs it, and the fake
/// panel and the "TV" in processes of their own, so neither weighs on
/// the isolate measured:
/// - the UI isolate's longest pause while HEVC 4K passes through the
///   relay (its proxy in, its continuous stream out): a 1 ms timer's
///   lateness, against the same without casting;
/// - the relay's processor for H.264 1080p50 copied into HLS: FFmpeg's,
///   and this whole process's (the proxy and the server run in it).
///
/// `flutter test --tags benchmark --run-skipped test/tools/cast_relay_measure_test.dart`
/// (`MEASURE_SECONDS=30` by default). The report goes to
/// `build/cast_measure/relay.txt`.
void main() {
  setUpAll(() => HttpOverrides.global = null);
  final binaries = relayBinaries();
  final skip =
      relaySkip(['hevc_2160p25_eac3', 'h264_1080p50_aac']) ??
      (Platform.isLinux ? null : 'Linux: /proc');
  final seconds =
      int.tryParse(Platform.environment['MEASURE_SECONDS'] ?? '') ?? 30;

  test(
    'the UI isolate while relaying 4K, and the processor for 1080p50 copy',
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
    () async {
      final report = StringBuffer();
      void say(String line) {
        report.writeln(line);
        // ignore: avoid_print, the measurement's report
        print(line);
      }

      final temp = Directory.systemTemp.createTempSync('relay_measure_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final panel = await _Panel.start(binaries!.ffmpeg, temp);
      addTearDown(panel.stop);
      final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
      final processes = Directory(p.join(temp.path, 'processes'));
      final relay = IsolateCastRelay(
        binaries: binaries,
        processFolder: processes,
        relayFolder: Directory(p.join(temp.path, 'relay')),
        log: log,
      );
      addTearDown(relay.close);
      say('FFmpeg: ${binaries.ffmpeg}; ${seconds}s each');

      CastUpstreamSource source(int channel) => CastUpstreamSource(
        sourceId: 'panel',
        live: true,
        resolve: () async => Ok(
          CastUpstream(
            url: '${panel.url}/live/test/test/$channel.ts',
            userAgent: 'VLC/3.0.20 LibVLC/3.0.20',
            maxConnections: 4,
          ),
        ),
      );

      Future<CastRelaySession> start(
        int channel,
        CastDelivery delivery,
        String videoCodec, {
        CastAudio audio = const CastAudioCopy(0),
      }) async {
        final started = await relay.start(
          CastRelayRequest(
            plan: CastPlan(
              delivery: delivery,
              video: const CastVideoCopy(),
              audio: audio,
              live: true,
              output: const CastOutput(),
            ),
            facts: StreamFacts(
              origin: StreamFactsOrigin.probe,
              video: VideoFacts(codec: videoCodec),
              audio: const [AudioFacts(index: 0, codec: 'aac')],
            ),
            source: source(channel),
            localAddress: '127.0.0.1',
          ),
        );
        final session = (started as CastRelayStarted).session;
        expect(
          await session.ready.timeout(const Duration(seconds: 30)),
          isNull,
        );
        return session;
      }

      // The baseline: nothing relayed.
      final idle = await _lateness(Duration(seconds: seconds));
      say(
        'UI isolate, idle: $idle; this process, without the timer: '
        '${await _processCpu(seconds)}',
      );

      // HEVC 4K + E-AC-3, continuous, read by a TV in its own process.
      final uhd = await start(
        6,
        CastDelivery.relayContinuous,
        'hevc',
        audio: const CastAudioToAac(0, AudioConversionReason.dolby),
      );
      final tv = await Process.start('curl', [
        '-s',
        '-o',
        '/dev/null',
        uhd.url,
      ]);
      await Future<void>.delayed(const Duration(seconds: 3));
      final busy = await _lateness(Duration(seconds: seconds));
      final ffmpeg4k = _relayPid(processes);
      final ffmpeg4kBefore = _cpu('/proc/$ffmpeg4k/stat');
      final process4k = await _processCpu(seconds);
      final ffmpeg4kCpu = _cpu('/proc/$ffmpeg4k/stat') - ffmpeg4kBefore;
      say(
        'UI isolate, relaying HEVC 4K: $busy; this process, without the '
        'timer: $process4k; FFmpeg (E-AC-3 → AAC) '
        '${_percent(ffmpeg4kCpu, seconds)}',
      );
      tv.kill();
      await tv.exitCode;
      await uhd.stop();

      // H.264 at 1080p, HLS, the picture copied; the TV an FFmpeg reading
      // it. The sound copied (AAC), then converted (AC-3 → AAC).
      for (final (channel, name, audio) in [
        (1, 'H.264 1080p50 + AAC, all copied', const CastAudioCopy(0)),
        (
          2,
          'H.264 1080p25 + AC-3 → AAC',
          const CastAudioToAac(0, AudioConversionReason.dolby),
        ),
      ]) {
        final hd = await start(
          channel,
          CastDelivery.relayHls,
          'h264',
          audio: audio,
        );
        final reader = await Process.start(binaries.ffmpeg, [
          ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
          ...['-i', hd.url, '-c', 'copy', '-f', 'null', '-'],
        ]);
        unawaited(reader.stderr.drain<void>());
        await Future<void>.delayed(const Duration(seconds: 5));
        final ffmpeg = _relayPid(processes);
        final ffmpegBefore = _cpu('/proc/$ffmpeg/stat');
        final selfBefore = _cpu('/proc/self/stat');
        final clock = Stopwatch()..start();
        await Future<void>.delayed(Duration(seconds: seconds));
        final wall = clock.elapsedMilliseconds / 1000;
        final ffmpegCpu = (_cpu('/proc/$ffmpeg/stat') - ffmpegBefore) / wall;
        final selfCpu = (_cpu('/proc/self/stat') - selfBefore) / wall;
        reader.kill();
        await reader.exitCode;
        await hd.stop();
        say(
          '$name, HLS: FFmpeg ${(ffmpegCpu * 100).toStringAsFixed(1)} % of '
          'one core; this process (proxy, server, the UI isolate) '
          '${(selfCpu * 100).toStringAsFixed(1)} %',
        );
      }

      final out = Directory('build/cast_measure')..createSync(recursive: true);
      File(p.join(out.path, 'relay.txt')).writeAsStringSync('$report');
    },
  );
}

/// How late a 1 ms timer fires, over [duration]: the longest wait and the
/// 99th percentile.
Future<String> _lateness(Duration duration) async {
  final gaps = <int>[];
  final clock = Stopwatch()..start();
  var last = clock.elapsedMicroseconds;
  final done = Completer<void>();
  final timer = Timer.periodic(const Duration(milliseconds: 1), (timer) {
    final now = clock.elapsedMicroseconds;
    gaps.add(now - last);
    last = now;
    if (clock.elapsed >= duration && !done.isCompleted) done.complete();
  });
  await done.future;
  timer.cancel();
  gaps.sort();
  final worst = gaps.last / 1000;
  final p99 = gaps[(gaps.length * 0.99).floor()] / 1000;
  return 'longest ${worst.toStringAsFixed(1)} ms, '
      '99th percentile ${p99.toStringAsFixed(2)} ms';
}

/// This process's processor over [seconds], as a share of one core.
Future<String> _processCpu(int seconds) async {
  final before = _cpu('/proc/self/stat');
  await Future<void>.delayed(Duration(seconds: seconds));
  return _percent(_cpu('/proc/self/stat') - before, seconds);
}

String _percent(double cpu, int seconds) =>
    '${(cpu / seconds * 100).toStringAsFixed(1)} % of one core';

/// Processor seconds (user + system) from a `/proc/<pid>/stat`.
double _cpu(String path) {
  final fields = File(path).readAsStringSync().split(') ').last.split(' ');
  // utime and stime: fields 14 and 15, 12 and 13 after the name.
  return (int.parse(fields[11]) + int.parse(fields[12])) / 100;
}

int _relayPid(Directory processes) {
  final file = processes.listSync().whereType<File>().firstWhere(
    (f) => p.basename(f.path).startsWith('relay-'),
  );
  return (jsonDecode(file.readAsStringSync()) as Map)['pid'] as int;
}

/// The fake panel in a process of its own.
final class _Panel {
  new _(this._process, this.url);

  static Future<_Panel> start(String ffmpeg, Directory temp) async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final process = await Process.start('dart', [
      'run',
      'tools/fake_provider/bin/server.dart',
      ...['--port', '$port', '--samples', samples.path, '--ffmpeg', ffmpeg],
      ...['--run-dir', p.join(temp.path, 'panel'), '--max-connections', '4'],
    ]);
    unawaited(process.stderr.drain<void>());
    final url = 'http://127.0.0.1:$port';
    // Read to its end: an unread pipe stops the panel once it fills.
    final up = Completer<void>();
    process.stdout.transform(utf8.decoder).listen((text) {
      if (text.contains('$port') && !up.isCompleted) up.complete();
    });
    await up.future.timeout(const Duration(minutes: 1));
    return _Panel._(process, url);
  }

  final Process _process;
  final String url;

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
  }
}
