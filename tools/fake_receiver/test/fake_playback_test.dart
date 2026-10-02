import 'dart:async';
import 'dart:io';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:test/test.dart';

import 'support/test_sender.dart';

/// The fake plays what it is told to (Phase 7 decision 8): it fetches HLS
/// and continuous streams the way the TV does and checks them with
/// ffprobe. Clips are made here with ffmpeg; without one the tests skip.
void main() {
  final tools = _Tools.find();
  final skip = tools == null ? 'no ffmpeg and ffprobe' : null;
  late Directory clips;
  late _Server server;

  setUpAll(() async {
    if (tools == null) return;
    clips = await Directory.systemTemp.createTemp('fake_playback');
    await tools.makeClips(clips);
  });

  tearDownAll(() async {
    if (tools != null) await clips.delete(recursive: true);
  });

  setUp(() async {
    if (tools == null) return;
    server = await _Server.start(clips);
  });

  tearDown(() async {
    if (tools != null) await server.close();
  });

  FakeWatch watch(
    _Recorder recorder,
    String path, {
    String type = 'application/x-mpegurl',
    Duration giveUp = const Duration(seconds: 3),
  }) => FakeWatch(
    url: server.url(path),
    contentType: type,
    playback: FakePlayback(
      ffprobe: tools!.ffprobe,
      giveUp: giveUp,
      endDelay: const Duration(milliseconds: 100),
    ),
    listener: recorder,
  )..start();

  group('HLS', () {
    test('starts at the live edge, checks each new segment, '
        'and asks like the TV', () async {
      server.playlist = _playlist(['a0', 'a1', 'a2', 'a3', 'a4', 'a5']);
      final recorder = _Recorder();
      final watching = watch(recorder, '/hls/index.m3u8');
      addTearDown(watching.cancel);
      final first = await recorder.firstCheck.future.timeout(_wait);
      expect(first.source, 'a3.ts');
      expect(first.videoCodec, 'h264');
      expect(first.height, 180);
      expect(first.audioCodec, 'aac');
      expect(first.audioChannels, 2);

      server.playlist = _playlist(['a1', 'a2', 'a3', 'a4', 'a5', 'a0'], at: 1);
      // Sequence 6 is the one new segment, whatever its name.
      await recorder.checkedCount(4).timeout(_wait);
      expect(
        [for (final c in recorder.checks) c.source],
        ['a3.ts', 'a4.ts', 'a5.ts', 'a0.ts'],
      );
      expect(server.origins, everyElement('https://www.gstatic.com'));
      expect(recorder.fetches, everyElement(_withCors));
    });

    test('marks a discontinuity, and finishes at the end of a list', () async {
      server.playlist = _playlist(
        ['a0', 'a1'],
        discontinuityBefore: 1,
        ended: true,
      );
      final recorder = _Recorder();
      watch(recorder, '/hls/index.m3u8');
      await recorder.ended.future.timeout(_wait);
      expect([for (final c in recorder.checks) c.discontinuity], [false, true]);
    });

    test('a playlist without CORS is dropped, as the browser would', () async {
      server
        ..playlist = _playlist(['a0', 'a1'])
        ..cors = false;
      final recorder = _Recorder();
      watch(recorder, '/hls/index.m3u8', giveUp: const Duration(seconds: 1));
      expect(
        await recorder.failure.future.timeout(_wait),
        contains('unreadable'),
      );
      expect(recorder.checks, isEmpty);
    });

    test('nothing new for three segments is a stall, until there is', () async {
      server.playlist = _playlist(['a0', 'a1']);
      final recorder = _Recorder();
      final watching = watch(recorder, '/hls/index.m3u8');
      addTearDown(watching.cancel);
      await recorder.firstCheck.future.timeout(_wait);
      expect(await recorder.stalls.first.timeout(_wait), isTrue);
      server.playlist = _playlist(['a1', 'a2'], at: 1);
      expect(await recorder.stalls.first.timeout(_wait), isFalse);
    });

    test('a playlist whose numbers go back fails', () async {
      server.playlist = _playlist(['a0', 'a1'], at: 10);
      final recorder = _Recorder();
      watch(recorder, '/hls/index.m3u8');
      await recorder.firstCheck.future.timeout(_wait);
      server.playlist = _playlist(['a0', 'a1']);
      expect(await recorder.failure.future.timeout(_wait), contains('back'));
    });

    test('a playlist that never answers fails', () async {
      final recorder = _Recorder();
      watch(recorder, '/hls/missing.m3u8', giveUp: const Duration(seconds: 1));
      expect(await recorder.failure.future.timeout(_wait), isNotNull);
      expect(recorder.fetches.first.status, 404);
    });
  }, skip: skip);

  group('continuous', () {
    test('reads from the start with Range, checks it, and finishes '
        'after its end', () async {
      final recorder = _Recorder();
      watch(recorder, '/stream.mp4', type: 'video/mp4');
      final check = await recorder.firstCheck.future.timeout(_wait);
      expect(check.videoCodec, 'h264');
      expect(check.audioCodec, 'aac');
      await recorder.ended.future.timeout(_wait);
      expect(server.ranges, ['bytes=0-']);
      expect(recorder.fetches.single.status, 200);
    });

    test('an error answer fails it', () async {
      final recorder = _Recorder();
      watch(recorder, '/missing.mp4', type: 'video/mp4');
      expect(await recorder.failure.future.timeout(_wait), 'HTTP 404');
    });
  }, skip: skip);

  group('through the receiver', () {
    late FakeReceiver receiver;
    late TestSender sender;

    Future<void> startReceiver(FakeDevice device) async {
      receiver = await FakeReceiver.start(
        device: device,
        pingEvery: null,
        playback: FakePlayback(
          ffprobe: tools!.ffprobe,
          refuseDelay: const Duration(milliseconds: 100),
        ),
      );
      sender = await TestSender.connect(receiver);
      addTearDown(() async {
        await sender.close();
        await receiver.close();
      });
    }

    Future<WireMessage> load(
      String transportId,
      String path, {
      String type = 'application/x-mpegurl',
    }) => sender.next(
      'MEDIA_STATUS',
      () => sender.send(transportId, nsMedia, {
        'type': 'LOAD',
        'requestId': 7,
        'media': {
          'contentId': '${server.url(path)}',
          'contentType': type,
          'streamType': 'LIVE',
        },
      }),
      (m) => _state(m) == 'PLAYING' || _state(m) == 'IDLE',
    );

    test('plays once the first segment checks out', () async {
      await startReceiver(FakeDevice.tv4k);
      server.playlist = _playlist(['a0', 'a1', 'a2']);
      // Its first answer is IDLE (LOADING); PLAYING follows the check.
      await load(await sender.launch(), '/hls/index.m3u8');
      await _until(() => receiver.playerState == 'PLAYING');
      expect(receiver.checks, isNotEmpty);
      expect(receiver.fetches.first.path, '/hls/index.m3u8');
    });

    test('an H.264-only device refuses HEVC with LOAD_FAILED', () async {
      await startReceiver(FakeDevice.chromecastHd);
      server.playlist = _playlist(['h0']);
      final transportId = await sender.launch();
      final failed = sender.next('LOAD_FAILED');
      unawaited(load(transportId, '/hls/index.m3u8'));
      expect((await failed).payload!['requestId'], 7);
      await _until(() => receiver.playerState == null);
    });

    test('a stream that is only a header plays nothing', () async {
      await startReceiver(FakeDevice.tv4k);
      final transportId = await sender.launch();
      final failed = sender.next('LOAD_FAILED');
      unawaited(load(transportId, '/head.mp4', type: 'video/mp4'));
      await failed;
      final check = receiver.checks.single;
      expect(check.videoCodec, 'h264');
      expect(check.hasVideo, isFalse);
    });

    test('a TV on a 1080p link refuses a taller picture', () async {
      await startReceiver(FakeDevice.tvOnHdLink);
      server.playlist = _playlist(['t0']);
      final transportId = await sender.launch();
      final failed = sender.next('LOAD_FAILED');
      unawaited(load(transportId, '/hls/index.m3u8'));
      await failed;
      expect(receiver.checks.single.height, 2160);
    });
  }, skip: skip);

  test('the device profiles', () {
    const hevc4k = FakeMediaCheck(
      source: 's',
      videoCodec: 'hevc',
      height: 2160,
      audioCodec: 'aac',
      videoPackets: 25,
      audioPackets: 47,
    );
    const h264Hd = FakeMediaCheck(
      source: 's',
      videoCodec: 'h264',
      height: 1080,
      videoPackets: 25,
    );
    const h264Uhd = FakeMediaCheck(
      source: 's',
      videoCodec: 'h264',
      height: 2160,
      videoPackets: 25,
    );
    const nothing = FakeMediaCheck(source: 's');
    const headerOnly = FakeMediaCheck(
      source: 's',
      videoCodec: 'hevc',
      height: 1080,
      audioCodec: 'aac',
    );
    expect(FakeDevice.tv4k.refuses(hevc4k), isNull);
    expect(FakeDevice.chromecastHd.refuses(hevc4k), 'HEVC');
    expect(FakeDevice.chromecastHd.refuses(h264Uhd), '2160p');
    expect(FakeDevice.chromecastHd.refuses(h264Hd), isNull);
    expect(FakeDevice.tvOnHdLink.refuses(hevc4k), '2160p');
    expect(FakeDevice.tvOnHdLink.refuses(h264Hd), isNull);
    expect(FakeDevice.tv4k.refuses(nothing), 'nothing to play');
    expect(FakeDevice.tv4k.refuses(headerOnly), 'nothing to play');
  });
}

const _wait = Duration(seconds: 20);

String? _state(WireMessage m) =>
    ((m.payload?['status'] as List?)?.firstOrNull as Map?)?['playerState']
        as String?;

final Matcher _withCors = predicate<FakeFetch>((f) => f.cors, 'with CORS');

Future<void> _until(bool Function() test) async {
  final deadline = DateTime.now().add(_wait);
  while (!test()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('until');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// A media playlist naming [segments] (`a0` → `a0.ts`) from sequence [at].
String _playlist(
  List<String> segments, {
  int at = 0,
  int target = 1,
  int? discontinuityBefore,
  bool ended = false,
}) => [
  '#EXTM3U',
  '#EXT-X-VERSION:3',
  '#EXT-X-TARGETDURATION:$target',
  '#EXT-X-MEDIA-SEQUENCE:$at',
  for (final (i, name) in segments.indexed) ...[
    if (i == discontinuityBefore) '#EXT-X-DISCONTINUITY',
    '#EXTINF:1.000000,',
    '$name.ts',
  ],
  if (ended) '#EXT-X-ENDLIST',
  '',
].join('\n');

final class _Recorder implements FakeWatchListener {
  final firstCheck = Completer<FakeMediaCheck>();
  final ended = Completer<void>();
  final failure = Completer<String>();
  final checks = <FakeMediaCheck>[];
  final fetches = <FakeFetch>[];
  final _stalls = StreamController<bool>.broadcast();
  final _checked = StreamController<int>.broadcast();

  Stream<bool> get stalls => _stalls.stream;

  Future<void> checkedCount(int count) async {
    if (checks.length >= count) return;
    await _checked.stream.firstWhere((n) => n >= count);
  }

  @override
  void started(FakeMediaCheck check) {
    if (!firstCheck.isCompleted) firstCheck.complete(check);
  }

  @override
  void stalled({required bool stalled}) => _stalls.add(stalled);

  @override
  void finished() {
    if (!ended.isCompleted) ended.complete();
  }

  @override
  void failed(String reason) {
    if (!failure.isCompleted) failure.complete(reason);
  }

  @override
  void fetched(FakeFetch fetch) => fetches.add(fetch);

  @override
  void checked(FakeMediaCheck check) {
    checks.add(check);
    _checked.add(checks.length);
  }
}

/// A web server like the relay's, with switches.
final class _Server {
  new _(this._server, this._clips);

  static Future<_Server> start(Directory clips) async {
    final server = _Server._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      clips,
    );
    server._server.listen(server._serve);
    return server;
  }

  final HttpServer _server;
  final Directory _clips;
  String playlist = '';
  bool cors = true;
  final origins = <String?>[];
  final ranges = <String?>[];

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}$path');

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    origins.add(request.headers.value('origin'));
    if (cors) response.headers.set('Access-Control-Allow-Origin', '*');
    final path = request.uri.path;
    if (path == '/hls/index.m3u8') {
      response.write(playlist);
    } else if (path.startsWith('/hls/') && path.endsWith('.ts')) {
      final name = path.substring(5);
      final kind = name[0];
      await response.addStream(File('${_clips.path}/$kind.ts').openRead());
    } else if (path == '/stream.mp4' || path == '/head.mp4') {
      ranges.add(request.headers.value(HttpHeaders.rangeHeader));
      // Chunked and without a length, as the relay sends it.
      response.bufferOutput = false;
      await response.addStream(File('${_clips.path}$path').openRead());
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }

  Future<void> close() => _server.close(force: true);
}

/// ffmpeg and ffprobe: the repository's bundled ones, else the system's.
final class _Tools {
  const new(this.ffmpeg, this.ffprobe);

  final String ffmpeg;
  final String ffprobe;

  /// `FFMPEG_DIR` picks one (CI's is the system's 4.4).
  static _Tools? find() {
    for (final folder in [
      ?Platform.environment['FFMPEG_DIR'],
      '../../third_party/ffmpeg/linux-x64',
      '/usr/bin',
      '/usr/local/bin',
    ]) {
      final ffmpeg = File('$folder/ffmpeg');
      final ffprobe = File('$folder/ffprobe');
      if (ffmpeg.existsSync() && ffprobe.existsSync()) {
        return _Tools(ffmpeg.path, ffprobe.path);
      }
    }
    return null;
  }

  /// `a.ts` H.264 180p + AAC; `h.ts` HEVC; `t.ts` a 2160-tall picture;
  /// `stream.mp4` fragmented, as the relay's continuous stream; `head.mp4`
  /// its header alone.
  Future<void> makeClips(Directory folder) async {
    Future<void> make(List<String> args) async {
      final result = await Process.run(ffmpeg, [
        ...['-hide_banner', '-loglevel', 'error', '-y'],
        ...args,
      ]);
      if (result.exitCode != 0) throw StateError('${result.stderr}');
    }

    const sound = ['-f', 'lavfi', '-i', 'sine=frequency=440:duration=1'];
    await make([
      ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=1'],
      ...sound,
      ...['-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac'],
      ...['-ac', '2', '-f', 'mpegts', '${folder.path}/a.ts'],
    ]);
    await make([
      ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=1'],
      ...sound,
      ...['-c:v', 'libx265', '-preset', 'ultrafast', '-c:a', 'aac'],
      ...['-ac', '2', '-f', 'mpegts', '${folder.path}/h.ts'],
    ]);
    await make([
      ...['-f', 'lavfi', '-i', 'testsrc2=size=128x2160:rate=25:duration=0.4'],
      ...['-c:v', 'libx264', '-preset', 'ultrafast'],
      ...['-f', 'mpegts', '${folder.path}/t.ts'],
    ]);
    await make([
      ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=3'],
      ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=3'],
      ...['-c:v', 'libx264', '-preset', 'ultrafast', '-g', '25'],
      ...['-c:a', 'aac', '-ac', '2', '-f', 'mp4'],
      ...['-movflags', 'frag_keyframe+empty_moov+default_base_moof'],
      '${folder.path}/stream.mp4',
    ]);
    // Its header and no fragment: streams named, nothing to play.
    await make([
      ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=1'],
      ...['-c:v', 'libx264', '-preset', 'ultrafast', '-t', '0'],
      ...['-f', 'mp4'],
      ...['-movflags', 'frag_keyframe+empty_moov+default_base_moof'],
      '${folder.path}/head.mp4',
    ]);
  }
}
