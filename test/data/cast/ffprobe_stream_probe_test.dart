import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffprobe_json.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'probe_fixtures.dart';

/// The bundled FFmpeg, else (for CI, which has only the system's) the
/// system's: the app itself never runs that one.
FfmpegBinaries? _tools() {
  final bundled = FfmpegBinaries.locate();
  if (bundled != null) return bundled;
  if (!Platform.isLinux) return null;
  const system = FfmpegBinaries(
    ffmpeg: '/usr/bin/ffmpeg',
    ffprobe: '/usr/bin/ffprobe',
  );
  return File(system.ffmpeg).existsSync() && File(system.ffprobe).existsSync()
      ? system
      : null;
}

const _samples = 'tools/media_samples/out';

void main() {
  final tools = _tools();
  final noTools = tools == null ? 'needs ffmpeg and ffprobe' : null;
  // The recordings are the bundled ffprobe's; an older one reads less
  // (the system's 4.4 gives an MP4 no field order).
  final bundled = FfmpegBinaries.locate() != null;

  test('what ffprobe is asked', () {
    expect(FfprobeStreamProbe.arguments('http://127.0.0.1:1/in/t'), [
      ...['-hide_banner', '-v', 'error'],
      ...['-analyzeduration', '2000000', '-probesize', '5000000'],
      ...['-print_format', 'json', '-show_format', '-show_streams'],
      ...['-i', 'http://127.0.0.1:1/in/t'],
    ]);
    // The User-Agent is an HTTP option: never for a file.
    expect(
      FfprobeStreamProbe.arguments('http://h/x', userAgent: 'VLC'),
      containsAllInOrder(['-user_agent', 'VLC', '-i']),
    );
    expect(
      FfprobeStreamProbe.arguments('/movies/a.mkv', userAgent: 'VLC'),
      isNot(contains('-user_agent')),
    );
    expect(
      FfprobeStreamProbe.arguments('http://h/x', userAgent: ''),
      isNot(contains('-user_agent')),
    );
  });

  test('a build without ffprobe probes nothing', () async {
    final result = await const UnavailableStreamProbe().probe('x');
    expect(
      (result as StreamProbeFailed).reason,
      StreamProbeFailure.couldNotStart,
    );
  });

  group('with ffprobe', skip: noTools, () {
    late Directory temp;
    late MemoryOutput output;
    late ProcessSupervisor supervisor;
    late String clip;
    late HttpServer server;
    final userAgents = <String?>[];

    setUpAll(() async {
      HttpOverrides.global = null;
      temp = Directory.systemTemp.createTempSync('probe_test_');
      // A 3 s clip of our own: CI's unit tests run before its samples.
      clip = p.join(temp.path, 'clip.ts');
      final made = await Process.run(tools!.ffmpeg, [
        ...['-hide_banner', '-loglevel', 'error', '-y'],
        ...['-f', 'lavfi', '-i', 'testsrc2=size=640x360:rate=25'],
        ...['-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000'],
        ...['-t', '3', '-c:v', 'libx264', '-preset', 'ultrafast'],
        ...['-c:a', 'aac', '-b:a', '96k', '-f', 'mpegts', clip],
      ]);
      expect(made.exitCode, 0, reason: '${made.stderr}');
      File(p.join(temp.path, 'subs.srt'))
          .writeAsStringSync('1\n00:00:01,000 --> 00:00:02,000\nHello\n\n');
      final bytes = File(clip).readAsBytesSync();

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
        ..listen((request) async {
          userAgents.add(request.headers.value('user-agent'));
          final response = request.response;
          switch (request.uri.path) {
            case '/live/someone/secret123/1.ts':
              await (response..statusCode = HttpStatus.unauthorized).close();
            case '/page':
              response
                ..headers.contentType = ContentType.html
                ..write('<html><body>Not a stream</body></html>');
              await response.close();
            case '/stall':
              // Headers, then nothing, ever: a panel that hangs.
              response
                ..headers.contentType = ContentType('video', 'mp2t')
                ..bufferOutput = false
                ..add(const [0x47]);
              await response.flush();
            case '/live.ts':
              // About twice its real pace, as a provider sends live.
              response.headers.contentType = ContentType('video', 'mp2t');
              response.bufferOutput = false;
              const chunk = 188 * 100;
              try {
                for (var at = 0; at < bytes.length; at += chunk) {
                  response.add(
                    bytes.sublist(at, (at + chunk).clamp(0, bytes.length)),
                  );
                  await response.flush();
                  await Future<void>.delayed(const Duration(milliseconds: 15));
                }
                await response.close();
              } on Object {
                // ffprobe had enough and left.
              }
            default:
              response.statusCode = HttpStatus.notFound;
              await response.close();
          }
        });
    });

    tearDownAll(() async {
      await server.close(force: true);
      temp.deleteSync(recursive: true);
    });

    setUp(() {
      output = MemoryOutput();
      userAgents.clear();
      supervisor = ProcessSupervisor(
        folder: Directory(p.join(temp.path, 'processes')),
        log: AppLog(output: output, secrets: SecretRegistry()),
        grace: const Duration(milliseconds: 500),
      );
    });

    tearDown(() async {
      await supervisor.stopAll();
    });

    FfprobeStreamProbe probe({Duration timeout = const Duration(seconds: 8)}) =>
        FfprobeStreamProbe(
          ffprobe: tools!.ffprobe,
          supervisor: supervisor,
          log: AppLog(output: output, secrets: SecretRegistry()),
          timeout: timeout,
        );

    String url(String path) => 'http://127.0.0.1:${server.port}$path';

    List<String> logLines() => [for (final e in output.buffer) ...e.lines];

    void expectNoProcessLeft() {
      expect(supervisor.runningCount, 0);
      final folder = supervisor.folder;
      expect(
        folder.existsSync() ? folder.listSync() : const <FileSystemEntity>[],
        isEmpty,
      );
    }

    test('a file', () async {
      final result = await probe().probe(clip);
      final facts = (result as StreamProbed).facts;
      expect(facts.origin, StreamFactsOrigin.probe);
      expect(facts.container, MediaContainer.mpegTs);
      expect(facts.video?.codec, 'h264');
      expect(facts.video?.height, 360);
      expect(facts.video?.fps, 25);
      expect(facts.audio.single.codec, 'aac');
      expectNoProcessLeft();
      expect(logLines().join('\n'), contains('mpegTs, h264 360p, aac'));
    });

    test('a live stream over HTTP, with the User-Agent sent', () async {
      final watch = Stopwatch()..start();
      final result = await probe().probe(
        url('/live.ts'),
        userAgent: 'TestAgent/1.0',
      );
      final facts = (result as StreamProbed).facts;
      expect(facts.video?.codec, 'h264');
      expect(facts.audio.single.codec, 'aac');
      expect(userAgents, contains('TestAgent/1.0'));
      expect(watch.elapsed, lessThan(const Duration(seconds: 8)));
      expectNoProcessLeft();
    });

    test(
      'a stream that never comes: the timeout, and no ffprobe left',
      () async {
        final watch = Stopwatch()..start();
        final result = await probe(timeout: const Duration(seconds: 1))
            .probe(url('/stall'));
        expect(
          (result as StreamProbeFailed).reason,
          StreamProbeFailure.timedOut,
        );
        expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
        expectNoProcessLeft();
      },
    );

    test("a refusal names the status, never the URL's credentials", () async {
      final result = await probe().probe(url('/live/someone/secret123/1.ts'));
      final failed = result as StreamProbeFailed;
      expect(failed.reason, StreamProbeFailure.unreadable);
      expect(failed.detail, contains('401'));
      expect(failed.detail, isNot(contains('secret123')));
      expect(logLines().join('\n'), isNot(contains('secret123')));
      expectNoProcessLeft();
    });

    test('a page that is not a stream is unreadable', () async {
      final result = await probe().probe(url('/page'));
      expect(
        (result as StreamProbeFailed).reason,
        StreamProbeFailure.unreadable,
      );
    });

    test('subtitles alone are no streams to cast', () async {
      final result = await probe().probe(p.join(temp.path, 'subs.srt'));
      expect(
        (result as StreamProbeFailed).reason,
        StreamProbeFailure.noStreams,
      );
    });

    test('an ffprobe that is not there could not start', () async {
      final missing = FfprobeStreamProbe(
        ffprobe: p.join(temp.path, 'ffprobe'),
        supervisor: supervisor,
        log: AppLog(output: output, secrets: SecretRegistry()),
      );
      final result = await missing.probe(clip);
      expect(
        (result as StreamProbeFailed).reason,
        StreamProbeFailure.couldNotStart,
      );
    });

    group('every media sample, as recorded', () {
      final names = [
        ...liveSampleNames,
        'vod_h264_aac_10min',
        'vod_h264_ac3_10min',
        'vod_hevc_eac3_subs',
      ];
      String? file(String name) {
        final folder = Directory(_samples);
        if (!folder.existsSync()) return null;
        for (final entry in folder.listSync()) {
          final base = p.basenameWithoutExtension(entry.path);
          if (base == name && !entry.path.endsWith('.srt')) return entry.path;
        }
        return null;
      }

      for (final name in names) {
        test(
          name,
          skip: !bundled
              ? 'needs the bundled ffprobe'
              : file(name) == null
              ? 'needs $_samples/$name'
              : null,
          () async {
            final result = await probe().probe(file(name)!);
            final facts = (result as StreamProbed).facts;
            final recorded = readFfprobeJson(probeFixture(name))!;
            // Lengths differ between this laptop's samples and CI's.
            expect(
              facts.video,
              recorded.video?.copyWith(bitRate: facts.video?.bitRate),
            );
            expect(facts.container, recorded.container);
            expect(
              facts.audio.map((a) => (a.codec, a.channels, a.language)),
              recorded.audio.map((a) => (a.codec, a.channels, a.language)),
            );
          },
        );
      }
    });
  });
}
