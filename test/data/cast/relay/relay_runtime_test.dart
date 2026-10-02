import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/relay/relay_job.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/cast/relay/relay_runtime.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// The relay's sessions and their supervisor (docs/04 "Supervisor"),
/// with a scripted FFmpeg behind the real process supervisor: the test
/// writes its segments, its standard output and its words, and ends it.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late Directory temp;
  late RelayRuntime runtime;
  late List<_Ffmpeg> ffmpegs;
  late List<(String, RelaySessionEvent)> events;
  late MemoryOutput logged;
  late _Provider provider;
  late ProcessSupervisor supervisor;
  ProcessException? launchError;

  const timings = RelayTimings(
    firstSegment: Duration(milliseconds: 800),
    stallFloor: Duration(milliseconds: 500),
    quiet: Duration(milliseconds: 500),
    poll: Duration(milliseconds: 40),
    budget: 3,
    budgetWindow: Duration(seconds: 5),
    restartDelays: [Duration(milliseconds: 10)],
    refusalMemory: Duration(seconds: 3),
  );

  RelayJob job({
    RelayOutput output = RelayOutput.hls,
    bool transcode = false,
  }) => RelayJob(
    ffmpeg: '/app/ffmpeg/ffmpeg',
    output: output,
    live: true,
    outputArgs: const ['-map', '0:V:0', '-c:v', 'copy'],
    transcode: transcode,
    // The stall rule is max(3 × this, the floor): the floor alone here.
    segmentSeconds: 0,
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('relay_runtime');
    provider = await _Provider.start();
    ffmpegs = [];
    events = [];
    logged = MemoryOutput();
    launchError = null;
    final log = AppLog(output: logged, secrets: SecretRegistry());
    var pids = 900000;
    supervisor = ProcessSupervisor(
      folder: Directory(p.join(temp.path, 'processes')),
      log: log,
      grace: const Duration(milliseconds: 300),
      launcher: (executable, arguments, {environment}) async {
        if (launchError case final error?) throw error;
        final ffmpeg = _Ffmpeg(pids++, arguments);
        ffmpegs.add(ffmpeg);
        return ffmpeg;
      },
    );
    runtime = await RelayRuntime.open(
      supervisor: supervisor,
      folder: Directory(p.join(temp.path, 'relay', '1234')),
      log: log,
      timings: timings,
      proxyTimings: const RelayProxyTimings(
        limitRetries: [],
        networkRetries: [],
      ),
      resolve: (id) async => RelayResolved(
        upstream: RelayUpstream(
          url: provider.url('/live/user/secret/1.ts'),
          maxConnections: 1,
        ),
      ),
      emit: (id, event) => events.add((id, event)),
    );
  });

  tearDown(() async {
    await runtime.shutdown();
    await provider.close();
    await temp.delete(recursive: true);
  });

  Future<String> start({String id = 's1', RelayJob? relayJob}) async {
    final answer = await runtime.start(
      sessionId: id,
      inputId: '$id/input',
      sourceId: 'src',
      job: relayJob ?? job(),
      localAddress: '127.0.0.1',
    );
    expect(answer.failure, isNull);
    return answer.url!;
  }

  Future<T> next<T extends RelaySessionEvent>([String id = 's1']) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    var seen = 0;
    while (DateTime.now().isBefore(deadline)) {
      for (final (session, event) in events.skip(seen)) {
        seen++;
        if (session == id && event is T) {
          events.remove((session, event));
          return event;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final saw = [
      for (final (_, e) in events)
        if (e is RelayFailed) e.failure else e,
    ];
    throw TimeoutException('no $T for $id; saw $saw');
  }

  List<T> all<T extends RelaySessionEvent>() => [
    for (final (_, event) in events)
      if (event is T) event,
  ];

  Iterable<String> logLines() => logged.buffer.expand((event) => event.lines);

  group('HLS', () {
    test('ready once the playlist lists 2 segments; served; FFmpeg as '
        '"relay" under its PID file', () async {
      final url = await start();
      final ffmpeg = ffmpegs.single;
      expect(ffmpeg.arguments, containsAllInOrder(['-i', anything]));
      expect(ffmpeg.input, startsWith('http://127.0.0.1:'));
      expect(ffmpeg.appends, isFalse);
      expect(supervisor.runningCount, 1);
      expect(
        Directory(p.join(temp.path, 'processes')).listSync().single.path,
        endsWith('relay-${ffmpeg.pid}.pid'),
      );
      ffmpeg.segment();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(all<RelayReady>(), isEmpty);
      ffmpeg.segment();
      await next<RelayReady>();
      final answer = await _get(url);
      expect(answer.status, 200);
      expect(answer.body, contains('seg00001.ts'));
      await next<RelayFetched>();
    });

    test("FFmpeg's input, as it describes it", () async {
      await start();
      ffmpegs.single
        ..say("[info] Input #0, mpegts, from 'http://127.0.0.1:1/in/x':")
        ..say(
          '[info]   Stream #0:0[0x100]: Video: h264 (High), '
          'yuv420p(progressive), 1920x1080, 50 fps',
        )
        ..say('[info] Stream mapping:');
      final opened = await next<RelayOpened>();
      expect(opened.report.video!.height, 1080);
    });

    test('a stall restarts FFmpeg behind the same URL, its playlist '
        'continued; the stuck one is killed at once', () async {
      final url = await start();
      final first = ffmpegs.single
        ..ignoresSigterm = true
        ..segment()
        ..segment();
      await next<RelayReady>();
      final restarted = await next<RelayRestarted>();
      expect(restarted.reason, RelayRestartReason.stalled);
      expect(restarted.count, 1);
      expect(first.signals, [ProcessSignal.sigkill]);
      await _until(() => ffmpegs.length == 2);
      final second = ffmpegs.last;
      expect(second.appends, isTrue);
      expect(second.folder, first.folder);
      second.segment();
      expect((await _get(url)).body, contains('#EXT-X-DISCONTINUITY'));
      expect(logLines().any((l) => l.contains('restarting FFmpeg')), isTrue);
    });

    test('no first segment in time: restarted', () async {
      await start();
      final restarted = await next<RelayRestarted>();
      expect(restarted.reason, RelayRestartReason.noFirstSegment);
      await _until(() => ffmpegs.length == 2);
      expect(ffmpegs.last.appends, isFalse, reason: 'nothing to continue');
    });

    test('an FFmpeg that ends after its first segments: restarted', () async {
      await start();
      ffmpegs.single
        ..segment()
        ..exit(1);
      final restarted = await next<RelayRestarted>();
      expect(restarted.reason, RelayRestartReason.exited);
      await _until(() => ffmpegs.length == 2);
    });

    test('an FFmpeg that ends before any output, twice: failed, with its '
        'words for Details', () async {
      await start();
      ffmpegs.single
        ..say('[http @ 0x55] [error] HTTP error 500 Internal Server Error')
        ..exit(1);
      await next<RelayRestarted>();
      await _until(() => ffmpegs.length == 2);
      ffmpegs.last
        ..say('[in#0 @ 0x55] [fatal] Error opening input')
        ..exit(1);
      final failed = await next<RelayFailed>();
      expect(failed.failure.kind, RelayFailureKind.ffmpegFailed);
      expect(failed.failure.detail, contains('Error opening input'));
      expect(failed.failure.detail, contains('http: HTTP error 500'));
    });

    test(
      'a re-encode that ends before any output blames the encoder',
      () async {
        await start(relayJob: job(transcode: true));
        ffmpegs.single
          ..say('[h264_nvenc @ 0x55] [error] No capable devices found')
          ..exit(1);
        final failed = await next<RelayFailed>();
        expect(failed.failure.kind, RelayFailureKind.encoderFailed);
        expect(failed.failure.detail, contains('No capable devices found'));
        expect(ffmpegs, hasLength(1), reason: 'not restarted');
      },
    );

    test('the budget: the restart past it fails the session', () async {
      await start();
      for (var i = 1; i <= timings.budget; i++) {
        ffmpegs.last
          ..segment()
          ..exit(1);
        expect((await next<RelayRestarted>()).count, i);
        await _until(() => ffmpegs.length == i + 1);
      }
      ffmpegs.last
        ..segment()
        ..exit(1);
      final failed = await next<RelayFailed>();
      expect(failed.failure.kind, RelayFailureKind.restartBudget);
      expect(failed.failure.detail, startsWith('3 restarts within 5 s'));
    });

    test(
      "a provider's refusal fails it, with the status and the words",
      () async {
        provider.answer = (401, 'Unauthorized');
        await start();
        final ffmpeg = ffmpegs.single;
        expect((await _get(ffmpeg.input)).status, 401);
        ffmpeg.exit(1);
        final failed = await next<RelayFailed>();
        expect(failed.failure.kind, RelayFailureKind.providerRefused);
        expect(failed.failure.status, 401);
        expect(failed.failure.body, 'Unauthorized');
      },
    );

    test('a provider that does not answer is tried again', () async {
      await provider.close();
      await start();
      final ffmpeg = ffmpegs.single;
      expect((await _get(ffmpeg.input)).status, 502);
      ffmpeg
        ..segment()
        ..exit(1);
      expect((await next<RelayRestarted>()).reason, RelayRestartReason.exited);
    });

    test('a stream that appears mid-way is told', () async {
      await start();
      ffmpegs.single.say(
        '[in#0/mpegts @ 0x55] [warning] New video stream with index 2 at '
        'pos:5531712 and DTS:7.1s',
      );
      await next<RelayStreamsChanged>();
    });

    test('renewed: a new URL, the old one gone, ready again', () async {
      final url = await start();
      ffmpegs.single
        ..segment()
        ..segment();
      await next<RelayReady>();
      final renewed = await runtime.renew('s1');
      expect(renewed.url, isNot(url));
      expect((await _get(url)).status, 404);
      expect(ffmpegs.first.exited, isTrue);
      ffmpegs.last
        ..segment()
        ..segment();
      await next<RelayReady>();
      expect((await _get(renewed.url!)).status, 200);
    });

    test('FFmpeg that cannot start: not started', () async {
      launchError = const ProcessException('/app/ffmpeg/ffmpeg', [], 'gone');
      final answer = await runtime.start(
        sessionId: 's1',
        inputId: 's1/input',
        sourceId: 'src',
        job: job(),
        localAddress: '127.0.0.1',
      );
      expect(answer.failure!.kind, RelayFailureKind.couldNotStart);
      expect(answer.failure!.detail, contains('FFmpeg could not start'));
    });

    test('stopped: FFmpeg ended, its URL and folder gone', () async {
      final url = await start();
      final ffmpeg = ffmpegs.single..segment();
      final folder = Directory(ffmpeg.folder!);
      expect(folder.existsSync(), isTrue);
      await runtime.stop('s1');
      expect(ffmpeg.exited, isTrue);
      expect(ffmpeg.signals.first, ProcessSignal.sigterm);
      expect(folder.existsSync(), isFalse);
      expect(supervisor.runningCount, 0);
      expect(Directory(p.join(temp.path, 'processes')).listSync(), isEmpty);
      // Its server closed with its last session; another may have the
      // port by now (tests run side by side), but never this URL.
      final status = await _get(url)
          .then<int?>((a) => a.status, onError: (Object _) => null);
      expect(status, anyOf(isNull, 404));
    });

    test("FFmpeg's warnings are logged, at most 10 a minute", () async {
      await start();
      for (var i = 0; i < 30; i++) {
        ffmpegs.single.say('[mpegts @ 0x55] [warning] Packet corrupt $i');
      }
      ffmpegs.single.say('[info] not logged');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final lines = logLines().where((l) => l.contains('Packet corrupt'));
      expect(lines, hasLength(10));
      expect(lines.first, contains('s1: FFmpeg: mpegts: Packet corrupt 0'));
      expect(logLines().any((l) => l.contains('not logged')), isFalse);
    });
  });

  group('continuous', () {
    RelayJob continuous({bool transcode = false}) =>
        job(output: RelayOutput.continuous, transcode: transcode);

    test('ready at once; FFmpeg starts with the TV and its output is '
        'the answer; its end, a clean end', () async {
      final url = await start(relayJob: continuous());
      await next<RelayReady>();
      expect(ffmpegs, isEmpty, reason: 'nothing until the TV asks');
      final reading = _read(url);
      await _until(() => ffmpegs.isNotEmpty);
      final ffmpeg = ffmpegs.single;
      expect(ffmpeg.arguments.last, 'pipe:1');
      ffmpeg
        ..send(List.filled(1000, 1))
        ..exit(0);
      final read = await reading;
      expect(read.status, 200);
      expect(read.bytes, 1000);
      expect(read.cut, isFalse);
      expect(read.headers.contentType?.mimeType, 'video/mp4');
      expect(read.headers.value('cache-control'), 'no-cache');
      final ended = await next<RelayEnded>();
      expect(ended.reason, RelayEndReason.finished);
      await next<RelayFetched>();
    });

    test('FFmpeg quiet too long: stopped, and the stream ends', () async {
      final url = await start(relayJob: continuous());
      final reading = _read(url);
      await _until(() => ffmpegs.isNotEmpty);
      ffmpegs.single.send([1, 2, 3]);
      expect((await reading).bytes, 3);
      expect((await next<RelayEnded>()).reason, RelayEndReason.quiet);
      expect(ffmpegs.single.exited, isTrue);
    });

    test('the TV leaving stops its FFmpeg (ADR-010)', () async {
      final url = await start(relayJob: continuous());
      final client = HttpClient();
      final response = await (await client.getUrl(Uri.parse(url))).close();
      await _until(() => ffmpegs.isNotEmpty);
      final ffmpeg = ffmpegs.single;
      final got = response.listen((_) {}, onError: (Object _) {});
      ffmpeg.send([1]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      client.close(force: true);
      await got.cancel();
      // A write meets the closed connection.
      for (var i = 0; i < 20 && !ffmpeg.exited; i++) {
        ffmpeg.send(List.filled(65536, 1));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect((await next<RelayEnded>()).reason, RelayEndReason.tvLeft);
      expect(ffmpeg.exited, isTrue);
    });

    test('a second request takes over: one FFmpeg per session', () async {
      final url = await start(relayJob: continuous());
      final first = _read(url);
      await _until(() => ffmpegs.length == 1);
      ffmpegs.first.send([1]);
      final second = _read(url);
      await _until(() => ffmpegs.length == 2);
      expect(ffmpegs.first.exited, isTrue);
      await first;
      ffmpegs.last
        ..send([1, 2])
        ..exit(0);
      expect((await second).bytes, 2);
      await next<RelayEnded>();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(all<RelayEnded>(), isEmpty, reason: 'the first said nothing');
    });

    test('HEAD starts nothing', () async {
      final url = await start(relayJob: continuous());
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final head = await (await client.headUrl(Uri.parse(url))).close();
      expect(head.statusCode, 200);
      expect(head.headers.contentType?.mimeType, 'video/mp4');
      expect(ffmpegs, isEmpty);
    });

    test('renewed: a new URL, counted against the budget', () async {
      var url = await start(relayJob: continuous());
      for (var i = 0; i < timings.budget; i++) {
        final renewed = await runtime.renew('s1');
        expect(renewed.url, isNot(url));
        expect((await _get(url)).status, 404);
        url = renewed.url!;
      }
      final spent = await runtime.renew('s1');
      expect(spent.failure!.kind, RelayFailureKind.restartBudget);
      expect(
        (await next<RelayFailed>()).failure.kind,
        RelayFailureKind.restartBudget,
      );
      final over = await runtime.renew('s1');
      expect(over.failure!.kind, RelayFailureKind.couldNotStart);
    });

    test('nothing sent and a refusal: failed with it', () async {
      provider.answer = (404, '');
      final url = await start(relayJob: continuous());
      final reading = _read(url);
      await _until(() => ffmpegs.isNotEmpty);
      expect((await _get(ffmpegs.single.input)).status, 404);
      ffmpegs.single.exit(1);
      await reading;
      final failed = await next<RelayFailed>();
      expect(failed.failure.kind, RelayFailureKind.providerRefused);
      expect(failed.failure.status, 404);
    });

    test('a re-encode that sends nothing blames the encoder', () async {
      final url = await start(relayJob: continuous(transcode: true));
      final reading = _read(url);
      await _until(() => ffmpegs.isNotEmpty);
      ffmpegs.single.exit(1);
      await reading;
      expect(
        (await next<RelayFailed>()).failure.kind,
        RelayFailureKind.encoderFailed,
      );
    });
  });

  test('shut down: every session, FFmpeg and folder gone', () async {
    await start();
    await start(
      id: 's2',
      relayJob: job(output: RelayOutput.continuous),
    );
    ffmpegs.single.segment();
    await runtime.shutdown();
    expect(ffmpegs.every((f) => f.exited), isTrue);
    expect(Directory(p.join(temp.path, 'relay', '1234')).existsSync(), isFalse);
    expect(supervisor.runningCount, 0);
  });
}

/// FFmpeg, as the test scripts it.
final class _Ffmpeg implements Process {
  new(this.pid, this.arguments);

  @override
  final int pid;
  final List<String> arguments;
  final _out = StreamController<List<int>>();
  final _err = StreamController<List<int>>();
  final _exit = Completer<int>();
  final signals = <ProcessSignal>[];
  bool ignoresSigterm = false;
  int _segments = 0;

  String get input => arguments[arguments.indexOf('-i') + 1];

  bool get appends => arguments.any((a) => a.contains('append_list'));

  String? get folder {
    final at = arguments.indexOf('-hls_segment_filename');
    return at < 0 ? null : p.dirname(arguments[at + 1]);
  }

  bool get exited => _exit.isCompleted;

  /// One more segment, and the playlist naming it, as FFmpeg writes them
  /// (continued after a restart).
  void segment() {
    final dir = folder!;
    final playlist = File(p.join(dir, 'index.m3u8'));
    final lines = playlist.existsSync()
        ? playlist.readAsStringSync()
        : '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXT-X-MEDIA-SEQUENCE:0\n';
    final count = RegExp(r'seg\d+\.ts').allMatches(lines).length;
    final name = 'seg${'$count'.padLeft(5, '0')}.ts';
    File(p.join(dir, name)).writeAsBytesSync(List.filled(188, 71));
    final discontinuity = appends && _segments == 0
        ? '#EXT-X-DISCONTINUITY\n'
        : '';
    playlist.writeAsStringSync('$lines$discontinuity#EXTINF:2.0,\n$name\n');
    _segments++;
  }

  void say(String line) => _err.add(utf8.encode('$line\n'));

  void send(List<int> bytes) {
    if (!_out.isClosed) _out.add(bytes);
  }

  void exit(int code) => unawaited(_end(code));

  Future<void> _end(int code) async {
    if (_exit.isCompleted) return;
    _exit.complete(code);
    await Future.wait([_out.close(), _err.close()]);
  }

  @override
  Stream<List<int>> get stdout => _out.stream;

  @override
  Stream<List<int>> get stderr => _err.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  IOSink get stdin => throw UnsupportedError('no stdin');

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    if (signal == ProcessSignal.sigterm && ignoresSigterm) return true;
    exit(signal == ProcessSignal.sigkill ? -9 : -15);
    return true;
  }
}

/// The provider behind the proxy: a status and words, or a stream.
final class _Provider {
  new _(this._server) {
    _server.listen((request) async {
      final (status, words) = answer;
      request.response
        ..statusCode = status
        ..write(words);
      await request.response.close();
    });
  }

  static Future<_Provider> start() async =>
      _Provider._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  (int, String) answer = (200, 'ts');

  late final int _port = _server.port;

  /// Still the same after [close]: a provider that stopped answering.
  String url(String path) => 'http://127.0.0.1:$_port$path';

  Future<void> close() async {
    // Read now: a closed server has no port.
    expect(_port, isPositive);
    await _server.close(force: true);
  }
}

final class _Answer {
  const new(this.status, this.body);

  final int status;
  final String body;
}

Future<_Answer> _get(String url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    return _Answer(
      response.statusCode,
      await response.transform(const Utf8Decoder(allowMalformed: true)).join(),
    );
  } finally {
    client.close(force: true);
  }
}

final class _Read {
  const new(this.status, this.bytes, this.headers, {required this.cut});

  final int status;
  final int bytes;
  final HttpHeaders headers;
  final bool cut;
}

Future<_Read> _read(String url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    var bytes = 0;
    var cut = false;
    try {
      await for (final chunk in response) {
        bytes += chunk.length;
      }
    } on Object {
      cut = true;
    }
    return _Read(response.statusCode, bytes, response.headers, cut: cut);
  } finally {
    client.close(force: true);
  }
}

Future<void> _until(bool Function() test) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!test()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('until');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
