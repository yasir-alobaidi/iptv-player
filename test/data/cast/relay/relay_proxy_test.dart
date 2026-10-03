import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:logger/logger.dart';

/// The relay's loopback proxy (Phase 7 decision 3) against scripted
/// providers: FFmpeg's side is an `HttpClient`, as FFmpeg's own HTTP
/// reads it (a cut is an error, a clean end is done).
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late _Provider provider;
  late RelayProxy proxy;
  late MemoryOutput logged;
  late List<RelayProxyEvent> events;
  late Map<String, RelayUpstream? Function()> upstreams;
  late Map<String, int> resolved;

  const timings = RelayProxyTimings(
    // Over 2 s: Windows refuses a closed loopback port only after about
    // 2 s (it sends the SYN again), which a shorter wait calls a timeout.
    connect: Duration(seconds: 5),
    idle: Duration(milliseconds: 600),
    slotWait: Duration(milliseconds: 800),
    resolve: Duration(seconds: 2),
    limitRetries: [Duration(milliseconds: 100), Duration(milliseconds: 100)],
    networkRetries: [Duration(milliseconds: 50), Duration(milliseconds: 50)],
    hlsLinger: Duration(milliseconds: 300),
  );

  setUp(() async {
    provider = await _Provider.start();
    logged = MemoryOutput();
    events = [];
    upstreams = {};
    resolved = {};
    proxy = await RelayProxy.start(
      resolve: (id) async {
        resolved[id] = (resolved[id] ?? 0) + 1;
        final upstream = upstreams[id]?.call();
        return upstream == null
            ? const RelayResolved(failure: 'Source s1 is locked')
            : RelayResolved(upstream: upstream);
      },
      log: AppLog(output: logged, secrets: SecretRegistry()),
      onEvent: events.add,
      timings: timings,
    );
  });

  tearDown(() async {
    await proxy.shutdown();
    await provider.close();
  });

  /// A live channel of [provider] at [path], with the panel's own
  /// credentials in it.
  String openLive(
    String id,
    String path, {
    int maxConnections = 1,
    String source = 's1',
    bool hls = false,
    bool live = true,
  }) {
    upstreams[id] = () => RelayUpstream(
      url: provider.url('/live/user/secret/$path'),
      userAgent: 'Panel-Agent/1.0',
      maxConnections: maxConnections,
      hls: hls,
    );
    return proxy.open(id, sourceId: source, live: live);
  }

  Iterable<String> logLines() => logged.buffer.expand((event) => event.lines);

  List<RelayProxyRefused> refusals() =>
      events.whereType<RelayProxyRefused>().toList();

  List<int> connections([String source = 's1']) => [
    for (final event in events.whereType<RelayProxyConnections>())
      if (event.sourceId == source) event.open,
  ];

  group('a live channel', () {
    test("passes the body on, with the source's User-Agent, and never "
        "sends FFmpeg's Range for a live edge", () async {
      provider.handler = (request) async {
        request.response.headers.contentType = ContentType('video', 'mp2t');
        request.response.add(List.filled(1000, 7));
        await request.response.close();
      };
      final url = openLive('in1', '1.ts');
      final read = await _read(url, range: 'bytes=500-');
      expect(read.status, 200);
      expect(read.bytes, 1000);
      expect(read.type, 'video/mp2t');
      expect(provider.agents.single, 'Panel-Agent/1.0');
      expect(provider.ranges.single, isNull);
      expect(resolved['in1'], 1);
    });

    test('an end, clean or not, is a cut: FFmpeg reconnects, and the '
        'URL is built again', () async {
      provider.handler = (request) async {
        request.response.add(List.filled(5000, 1));
        await request.response.close();
      };
      final url = openLive('in1', '1.ts');
      final first = await _read(url);
      expect(first.bytes, 5000);
      expect(first.cut, isTrue, reason: 'no clean end for a live stream');
      final second = await _read(url);
      expect(second.cut, isTrue);
      expect(resolved['in1'], 2, reason: 'every connection asks again');
      expect(
        logLines().where((l) => l.contains('FFmpeg reconnects')),
        hasLength(2),
      );
    });

    test('a stall is cut once it goes quiet', () async {
      final hold = Completer<void>();
      provider.handler = (request) async {
        request.response
          ..bufferOutput = false
          ..add(List.filled(100, 1));
        await request.response.flush();
        await hold.future;
      };
      addTearDown(hold.complete);
      final clock = Stopwatch()..start();
      final read = await _read(openLive('in1', '1.ts'));
      expect(read.cut, isTrue);
      expect(read.bytes, 100);
      expect(clock.elapsed, greaterThan(timings.idle));
      expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
      expect(logLines().any((l) => l.contains('went quiet')), isTrue);
    });

    test('FFmpeg leaving closes the provider connection at once', () async {
      // A raw provider: its socket sees the proxy close it, which a
      // server's response with a write in flight may never report.
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(raw.close);
      final closed = Completer<void>();
      raw.listen((socket) {
        final feed = Timer.periodic(const Duration(milliseconds: 20), (_) {
          socket.add(List.filled(1000, 1));
        });
        void gone() {
          feed.cancel();
          socket.destroy();
          if (!closed.isCompleted) closed.complete();
        }

        socket
          ..listen((_) {}, onDone: gone, onError: (Object _) => gone())
          ..add(
            utf8.encode('HTTP/1.1 200 OK\r\ncontent-type: video/mp2t\r\n\r\n'),
          );
      });
      upstreams['in1'] = () => RelayUpstream(
        url: 'http://127.0.0.1:${raw.port}/live/user/secret/1.ts',
        maxConnections: 1,
      );
      final client = HttpClient();
      final reading = await _keepReading(
        client,
        proxy.open('in1', sourceId: 's1', live: true),
      );
      client.close(force: true);
      await reading.cancel();
      await closed.future.timeout(const Duration(seconds: 10));
      await _until(() => connections().lastOrNull == 0);
      expect(connections(), [1, 0]);
    });
  });

  group('a file', () {
    test('Range passes both ways, and a whole answer ends cleanly', () async {
      provider.handler = (request) async {
        final response = request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set('Content-Range', 'bytes 100-199/1000')
          ..headers.set('Accept-Ranges', 'bytes')
          ..contentLength = 100
          ..add(List.filled(100, 2));
        await response.close();
      };
      final url = openLive('in1', 'movie.mkv', live: false);
      final read = await _read(url, range: 'bytes=100-199');
      expect(provider.ranges.single, 'bytes=100-199');
      expect(read.status, 206);
      expect(read.headers.value('content-range'), 'bytes 100-199/1000');
      expect(read.headers.value('accept-ranges'), 'bytes');
      expect(read.bytes, 100);
      expect(read.cut, isFalse);
    });

    test('an answer cut short is cut short for FFmpeg too, '
        'which reconnects with Range', () async {
      provider.handler = (request) async {
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket
          ..add(
            utf8.encode(
              'HTTP/1.1 200 OK\r\ncontent-length: 1000\r\n'
              'content-type: video/x-matroska\r\n\r\n',
            ),
          )
          ..add(List.filled(300, 3));
        await socket.flush();
        socket.destroy();
      };
      final read = await _read(openLive('in1', 'movie.mkv', live: false));
      expect(read.cut, isTrue);
      expect(read.bytes, 300);
    });
  });

  group('a file, FFmpeg holding back', () {
    test('FFmpeg that stops reading (its output waits on the TV) is waited '
        'for: no quiet cut, however long', () async {
      const chunk = 1 << 20;
      provider.handler = (request) async {
        final response = request.response..contentLength = 32 * chunk;
        for (var i = 0; i < 32; i++) {
          response.add(Uint8List(chunk));
        }
        await response.close();
      };
      final url = Uri.parse(openLive('in1', 'movie.mkv', live: false));
      // FFmpeg, blocked on its output: it asks, then reads nothing.
      final ffmpeg = await Socket.connect(url.host, url.port);
      addTearDown(ffmpeg.destroy);
      ffmpeg.write(
        'GET ${url.path}${url.hasQuery ? '?${url.query}' : ''} HTTP/1.1\r\n'
        'Host: ${url.host}\r\n\r\n',
      );
      await ffmpeg.flush();
      var got = 0;
      final done = Completer<void>();
      final reading = ffmpeg.listen(
        (bytes) => got += bytes.length,
        onDone: done.complete,
        onError: (Object _) => done.complete(),
      )..pause();
      addTearDown(reading.cancel);
      await Future<void>.delayed(timings.idle * 3);
      reading.resume();
      await done.future.timeout(const Duration(seconds: 10));
      expect(got, greaterThan(32 * chunk), reason: 'the whole file, headed');
    });
  });

  group('refusals', () {
    test('an error answer is passed on and reported, words and all', () async {
      provider.handler = (request) async {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..write('Unauthorized for /live/user/secret/1.ts\n');
        await request.response.close();
      };
      final read = await _read(openLive('in1', '1.ts'));
      expect(read.status, 401);
      final refusal = refusals().single;
      expect(refusal.inputId, 'in1');
      expect(refusal.refusal.kind, RelayRefusalKind.refused);
      expect(refusal.refusal.status, 401);
      expect(refusal.refusal.body, startsWith('Unauthorized'));
      expect(refusal.refusal.body, isNot(contains('secret')));
      expect(resolved['in1'], 1, reason: 'a 401 is not retried');
      expect(connections(), [1, 0]);
    });

    test('a full account is tried again: the panel may not have noticed '
        'the connection just closed', () async {
      var refusing = 2;
      provider.handler = (request) async {
        if (refusing-- > 0) {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..write('MAX_CONNECTIONS_REACHED\n');
        } else {
          request.response.add(List.filled(10, 1));
        }
        await request.response.close();
      };
      final read = await _read(openLive('in1', '1.ts'));
      expect(read.status, 200);
      expect(provider.agents, hasLength(3));
      expect(resolved['in1'], 3);
      expect(refusals(), isEmpty);
    });

    test('a full account that stays full is reported as such', () async {
      provider.handler = (request) async {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('MAX_CONNECTIONS_REACHED\n');
        await request.response.close();
      };
      final read = await _read(openLive('in1', '1.ts'));
      expect(read.status, 403);
      expect(provider.agents, hasLength(1 + timings.limitRetries.length));
      expect(refusals().single.refusal.body, 'MAX_CONNECTIONS_REACHED');
    });

    test(
      'nothing answering: tried again, then a 502 and "unreachable"',
      () async {
        final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = dead.port;
        await dead.close();
        upstreams['in1'] = () => RelayUpstream(
          url: 'http://127.0.0.1:$port/live/user/secret/1.ts',
          maxConnections: 1,
        );
        final read = await _read(proxy.open('in1', sourceId: 's1', live: true));
        expect(read.status, 502);
        expect(resolved['in1'], 1 + timings.networkRetries.length);
        final refusal = refusals().single.refusal;
        expect(refusal.kind, RelayRefusalKind.unreachable);
        expect(refusal.detail, startsWith('no connection'));
        expect(logLines().join('\n'), isNot(contains('secret')));
      },
    );

    test('a stream whose URL cannot be built', () async {
      final url = proxy.open('in1', sourceId: 's1', live: true);
      final read = await _read(url);
      expect(read.status, 502);
      final refusal = refusals().single.refusal;
      expect(refusal.kind, RelayRefusalKind.unresolved);
      expect(refusal.detail, 'Source s1 is locked');
      expect(connections(), isEmpty, reason: 'nothing was opened');
    });
  });

  group('redirects', () {
    test('followed; an expiring one fresh on every connection', () async {
      var issued = 0;
      provider.handler = (request) async {
        if (request.uri.queryParameters['token'] case final token?) {
          // Only the newest token works.
          if (token != '$issued') {
            request.response
              ..statusCode = HttpStatus.forbidden
              ..write('TOKEN_EXPIRED');
          } else {
            request.response.add(List.filled(10, 1));
          }
        } else {
          issued++;
          await request.response.redirect(
            request.requestedUri.replace(queryParameters: {'token': '$issued'}),
          );
          return;
        }
        await request.response.close();
      };
      final url = openLive('in1', '1.ts');
      for (var i = 0; i < 3; i++) {
        final read = await _read(url);
        expect(read.status, 200);
        expect(read.bytes, 10);
      }
      expect(issued, 3);
      expect(refusals(), isEmpty);
    });
  });

  group("a provider's HLS", () {
    test(
      'its playlists are rewritten so segments come through the proxy',
      () async {
        provider.handler = (request) async {
          final path = request.uri.path;
          if (path.endsWith('index.m3u8')) {
            request.response
              ..headers.contentType = ContentType('application', 'x-mpegurl')
              ..write(
                '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXT-X-MEDIA-SEQUENCE:7\n'
                '#EXTINF:2,\nseg7.ts\n#EXTINF:2,\n/hls/1/seg8.ts?k=1\n',
              );
          } else {
            request.response.write('segment $path');
          }
          await request.response.close();
        };
        final url = openLive('in1', 'index.m3u8', hls: true);
        final playlist = await _text(url);
        final segments = [
          for (final line in LineSplitter.split(playlist))
            if (line.isNotEmpty && !line.startsWith('#')) line,
        ];
        expect(segments, hasLength(2));
        for (final segment in segments) {
          expect(segment, startsWith('$url/'));
        }
        expect(playlist, isNot(contains('secret')));
        expect(await _text(segments[0]), 'segment /live/user/secret/seg7.ts');
        expect(await _text(segments[1]), 'segment /hls/1/seg8.ts');
        // A refresh keeps the URL it has: the app is asked once.
        await _text(url);
        expect(resolved['in1'], 1);
      },
    );

    test('its playlist and segments are one connection, kept between '
        'requests a moment', () async {
      provider.handler = (request) async {
        request.response.write(
          request.uri.path.endsWith('.m3u8')
              ? '#EXTM3U\n#EXTINF:2,\nseg.ts\n'
              : 'x',
        );
        await request.response.close();
      };
      final url = openLive('in1', 'index.m3u8', hls: true);
      final playlist = await _text(url);
      final segment = LineSplitter.split(playlist).last;
      await _text(segment);
      await _text(url);
      expect(connections(), [1]);
      await _until(() => connections().length == 2);
      expect(connections(), [1, 0]);
    });

    test('a segment the playlist never named is a 404', () async {
      provider.handler = (request) async {
        request.response.write('#EXTM3U\n');
        await request.response.close();
      };
      final url = openLive('in1', 'index.m3u8', hls: true);
      await _text(url);
      expect((await _read('$url/99')).status, 404);
      expect((await _read('$url/not-a-number')).status, 404);
    });
  });

  group('connections', () {
    test(
      "a one-connection source: a second input waits for the first's",
      () async {
        provider.handler = (request) async {
          if (request.uri.path.contains('probe')) {
            return await _endless(request);
          }
          request.response.add([1]);
          await request.response.close();
        };
        final probe = openLive('probe', 'probe.ts');
        final relay = openLive('relay', 'relay.ts');
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final probing = await _keepReading(client, probe);
        expect(connections(), [1]);
        final relaying = _read(relay);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(provider.paths, ['/live/user/secret/probe.ts']);
        // The probe ends: ffprobe has what it needs.
        client.close(force: true);
        await probing.cancel();
        await relaying;
        expect(provider.paths.last, '/live/user/secret/relay.ts');
        expect(connections(), [1, 0, 1, 0]);
      },
    );

    test('none coming free in time: a 503, and the reason', () async {
      // A probe that goes on reading.
      provider.handler = _endless;
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final probing = await _keepReading(client, openLive('probe', 'probe.ts'));
      addTearDown(probing.cancel);
      final read = await _read(openLive('relay', 'relay.ts'));
      expect(read.status, 503);
      expect(refusals().single.refusal.kind, RelayRefusalKind.connectionsInUse);
    });

    test(
      'a source that allows two lets two in; another source has its own',
      () async {
        provider.handler = (request) async {
          request.response.add([1]);
          await request.response.close();
        };
        await Future.wait([
          _read(openLive('a', 'a.ts', maxConnections: 2)),
          _read(openLive('b', 'b.ts', maxConnections: 2)),
          _read(openLive('c', 'c.ts', source: 's2')),
        ]);
        expect(connections().reduce((a, b) => a > b ? a : b), 2);
        expect(connections('s2'), [1, 0]);
      },
    );
  });

  group('inputs', () {
    test('an unknown token, or another method, is a 404', () async {
      expect(
        (await _read('http://127.0.0.1:${proxy.port}/in/nope')).status,
        404,
      );
      expect((await _read('http://127.0.0.1:${proxy.port}/')).status, 404);
      final url = openLive('in1', '1.ts');
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final post = await (await client.postUrl(Uri.parse(url))).close();
      expect(post.statusCode, 404);
    });

    test('closing an input cuts what it reads, and its URL is gone', () async {
      provider.handler = _endless;
      final url = openLive('in1', '1.ts');
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final response = await (await client.getUrl(Uri.parse(url))).close();
      final first = Completer<void>();
      final cut = Completer<bool>();
      response.listen(
        (_) => first.isCompleted ? null : first.complete(),
        onError: (Object _) => cut.complete(true),
        onDone: () => cut.isCompleted ? null : cut.complete(false),
      );
      await first.future;
      proxy.close('in1');
      expect(await cut.future, isTrue, reason: 'a cut, not an end');
      await _until(() => connections().length == 2);
      expect(connections(), [1, 0]);
      expect((await _read(url)).status, 404);
    });

    test('tokens are 128 random bits', () {
      final tokens = {for (var i = 0; i < 1000; i++) newRelayToken()};
      expect(tokens, hasLength(1000));
      expect(tokens.every(RegExp(r'^[0-9a-f]{32}$').hasMatch), isTrue);
    });
  });

  test('the log never carries a credential', () async {
    provider.handler = (request) async {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('no /live/user/secret/1.ts here');
      await request.response.close();
    };
    await _read(openLive('in1', '1.ts'));
    final log = logLines().join('\n');
    expect(log, contains('HTTP 404'));
    expect(log, isNot(contains('secret')));
    expect(log, isNot(contains('/user/')));
  });
}

final class _Read {
  const new(this.status, this.bytes, this.headers, {required this.cut});

  final int status;
  final int bytes;
  final HttpHeaders headers;

  /// The answer ended without a clean end: FFmpeg reconnects.
  final bool cut;

  String? get type => headers.contentType?.mimeType;
}

/// Reads [url] as FFmpeg would.
Future<_Read> _read(String url, {String? range}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
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

/// A live provider: a byte every 20 ms until the reader leaves.
Future<void> _endless(HttpRequest request) async {
  request.response.bufferOutput = false;
  while (true) {
    request.response.add([1]);
    await request.response.flush();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// Reads [url] without end, as FFmpeg does a live stream, once its first
/// bytes are in.
Future<StreamSubscription<List<int>>> _keepReading(
  HttpClient client,
  String url,
) async {
  final response = await (await client.getUrl(Uri.parse(url))).close();
  final first = Completer<void>();
  final reading = response.listen((_) {
    if (!first.isCompleted) first.complete();
  }, onError: (Object _) {});
  await first.future;
  return reading;
}

Future<String> _text(String url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

Future<void> _until(bool Function() test) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!test()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('until');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// A provider whose answers each test writes.
final class _Provider {
  new _(this._server) {
    _server.listen((request) async {
      paths.add(request.uri.path);
      agents.add(request.headers.value(HttpHeaders.userAgentHeader));
      ranges.add(request.headers.value(HttpHeaders.rangeHeader));
      try {
        await handler(request);
      } on Object {
        // The proxy left.
      }
    });
  }

  static Future<_Provider> start() async =>
      _Provider._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  /// Connections open to it now.
  int get open => _server.connectionsInfo().total;
  final paths = <String>[];
  final agents = <String?>[];
  final ranges = <String?>[];
  Future<void> Function(HttpRequest request) handler = (request) async {
    await request.response.close();
  };

  String url(String path) => 'http://127.0.0.1:${_server.port}$path';

  Future<void> close() => _server.close(force: true);
}
