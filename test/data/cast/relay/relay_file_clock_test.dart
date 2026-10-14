import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/relay/isolate_cast_relay.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'relay_rig.dart';

/// A relayed file on its own clock (docs/04 "The TV's own bar"), with the
/// real FFmpeg in the relay's isolate: what the TV's demuxer finds in the
/// stream (ffprobe reading it from a pipe, as a TV reads a stream it
/// can't seek in) is the file's length, and the file's time where the
/// stream begins. The Bedroom TV showed the bug this guards: a film's
/// length on the TV was what it had read so far, growing as it played.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  final binaries = relayBinaries();
  late Directory temp;
  late String film;
  late IsolateCastRelay relay;

  setUpAll(() async {
    if (binaries == null) return;
    temp = await Directory.systemTemp.createTemp('relay_file_clock');
    film = p.join(temp.path, 'film.mkv');
    // 30 s, a key frame every 4 s, Dolby sound: the relay copies the
    // picture and converts the sound, as it does for most films.
    final made = await Process.run(binaries.ffmpeg, [
      ...['-hide_banner', '-loglevel', 'error', '-y'],
      ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25'],
      ...['-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000'],
      ...['-t', '30', '-c:v', 'libx264', '-preset', 'ultrafast'],
      ...['-g', '100', '-c:a', 'ac3', '-b:a', '128k', film],
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
  });

  tearDownAll(() async {
    if (binaries == null) return;
    await temp.delete(recursive: true);
  });

  setUp(() {
    relay = IsolateCastRelay(
      binaries: binaries!,
      processFolder: Directory(p.join(temp.path, 'processes')),
      relayFolder: Directory(p.join(temp.path, 'relay')),
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
    );
  });

  tearDown(() => relay.close());

  Future<CastRelaySession> start({
    Duration? startAt,
    CastTimeline? timeline,
  }) async {
    final started = await relay.start(
      CastRelayRequest(
        plan: const CastPlan(
          delivery: CastDelivery.relayContinuous,
          video: CastVideoCopy(),
          audio: CastAudioToAac(0, AudioConversionReason.dolby),
          live: false,
          output: CastOutput(),
        ),
        facts: const StreamFacts(
          origin: StreamFactsOrigin.probe,
          video: VideoFacts(codec: 'h264'),
          audio: [AudioFacts(index: 0, codec: 'ac3')],
          duration: Duration(seconds: 30),
        ),
        source: CastUpstreamSource(
          sourceId: 'library',
          live: false,
          file: film,
          resolve: () async => Err(NotFoundFailure('a file')),
        ),
        localAddress: '127.0.0.1',
        startAt: startAt,
        timeline: timeline,
      ),
    );
    final session = (started as CastRelayStarted).session;
    expect(await session.ready, isNull);
    return session;
  }

  test(
    'from 13 s: the TV reads a stream 30 s long that begins at 12 s, the '
    'key frame before 13 s; renewed from 21 s, one that begins at 20 s',
    () async {
      final session = await start(
        startAt: const Duration(seconds: 13),
        timeline: const CastTimeline(
          start: Duration(seconds: 12),
          length: Duration(seconds: 30),
        ),
      );
      var read = await _tvReads(session.url, binaries!);
      expect(read.duration, closeTo(30, 0.05));
      expect(read.start, closeTo(12, 0.05));
      expect(read.firstPicture, closeTo(12, 0.05));

      expect(
        await session.renew(
          startAt: const Duration(seconds: 21),
          timeline: const CastTimeline(
            start: Duration(seconds: 20),
            length: Duration(seconds: 30),
          ),
        ),
        isNull,
      );
      read = await _tvReads(session.url, binaries);
      expect(read.duration, closeTo(30, 0.05));
      expect(read.start, closeTo(20, 0.05));
    },
    skip: binaries == null ? 'no FFmpeg' : null,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    "without the file's clock (FFmpeg's own, as before): no length, and "
    'the stream counts from 0 wherever it began',
    () async {
      final session = await start(startAt: const Duration(seconds: 13));
      final read = await _tvReads(session.url, binaries!);
      expect(read.duration, anyOf(isNull, isNot(closeTo(30, 1))));
      expect(read.start, closeTo(0, 0.05));
    },
    skip: binaries == null ? 'no FFmpeg' : null,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

/// What a TV's demuxer finds in the stream at [url]: fetched as the TV
/// fetches it, then read by ffprobe from a pipe.
Future<({double? duration, double? start, double? firstPicture})> _tvReads(
  String url,
  FfmpegBinaries binaries,
) async {
  final client = HttpClient();
  final bytes = BytesBuilder(copy: false);
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    expect(response.statusCode, 200);
    await response.forEach(bytes.add);
  } finally {
    client.close(force: true);
  }
  final probe = await Process.start(binaries.ffprobe, [
    ...['-v', 'error', '-of', 'json'],
    ...['-show_entries', 'format=duration,start_time:stream=start_time'],
    ...['-select_streams', 'v:0', 'pipe:0'],
  ]);
  final out = probe.stdout.transform(utf8.decoder).join();
  final err = probe.stderr.transform(utf8.decoder).join();
  probe.stdin.add(bytes.takeBytes());
  try {
    await probe.stdin.close();
  } on Object {
    // ffprobe stops reading once it knows: the rest is not its concern.
  }
  expect(await probe.exitCode, 0, reason: await err);
  final json = jsonDecode(await out) as Map<String, Object?>;
  final format = json['format'] as Map<String, Object?>? ?? const {};
  final streams = json['streams'] as List<Object?>? ?? const [];
  double? number(Object? value) =>
      value is String ? double.tryParse(value) : null;
  return (
    duration: number(format['duration']),
    start: number(format['start_time']),
    firstPicture: streams.isEmpty
        ? null
        : number((streams.first! as Map<String, Object?>)['start_time']),
  );
}
