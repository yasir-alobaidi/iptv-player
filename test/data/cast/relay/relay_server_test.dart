import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/relay/relay_server.dart';
import 'package:logger/logger.dart';

/// The server the TV fetches from (docs/04 "Relay HTTP server"): its
/// routes, CORS on every answer, MIME types, `no-cache`, Range, and a 404
/// for anything else.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late Directory folder;
  late RelayServer server;
  late List<String> fetched;
  final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('relay_server');
    File('${folder.path}/index.m3u8')
        .writeAsStringSync('#EXTM3U\n#EXTINF:2,\nseg00000.ts\n');
    File('${folder.path}/seg00000.ts').writeAsBytesSync(List.filled(188, 71));
    File('${folder.path}/movie.mp4')
        .writeAsBytesSync([for (var i = 0; i < 1000; i++) i % 256]);
    fetched = [];
    server = await RelayServer.bind(
      '127.0.0.1',
      log: log,
      onFetched: fetched.add,
    );
  });

  tearDown(() async {
    await server.close();
    await folder.delete(recursive: true);
  });

  test("binds in docs/04's ports, on the address it was given", () {
    expect(server.port, inInclusiveRange(relayFirstPort, relayLastPort));
    expect(server.address, '127.0.0.1');
    expect(server.origin, 'http://127.0.0.1:${server.port}');
  });

  test('a port in use: the next one', () async {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(taken.close);
    final next = await RelayServer.bind(
      '127.0.0.1',
      log: log,
      first: taken.port,
      last: taken.port + 4,
    );
    addTearDown(next.close);
    expect(next.port, greaterThan(taken.port));
  });

  test('every port in use: a clear error', () async {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(taken.close);
    await expectLater(
      RelayServer.bind(
        '127.0.0.1',
        log: log,
        first: taken.port,
        last: taken.port,
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test(
    "an address that isn't this computer's: at once, not 100 tries",
    () async {
      final clock = Stopwatch()..start();
      // TEST-NET-1 (RFC 5737): never a local address.
      await expectLater(
        RelayServer.bind('192.0.2.7', log: log),
        throwsA(isA<SocketException>()),
      );
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    },
  );

  test('an IPv6 address in brackets', () async {
    final RelayServer six;
    try {
      six = await RelayServer.bind('::1', log: log);
    } on SocketException {
      markTestSkipped('no IPv6 loopback here');
      return;
    }
    addTearDown(six.close);
    expect(six.origin, 'http://[::1]:${six.port}');
  });

  group('HLS', () {
    test('the playlist: its MIME type, no-cache, CORS', () async {
      final url = server.serveHls(folder);
      expect(url, matches(RegExp(r'/r/[0-9a-f]{32}/index\.m3u8$')));
      final answer = await _get(url);
      expect(answer.status, 200);
      expect(answer.header('content-type'), 'application/vnd.apple.mpegurl');
      expect(answer.header('cache-control'), 'no-cache');
      _expectCors(answer);
      expect(utf8.decode(answer.body), startsWith('#EXTM3U'));
    });

    test('a segment: video/mp2t, cached as the TV likes', () async {
      final url = server
          .serveHls(folder)
          .replaceFirst('index.m3u8', 'seg00000.ts');
      final answer = await _get(url);
      expect(answer.status, 200);
      expect(answer.header('content-type'), 'video/mp2t');
      expect(answer.header('cache-control'), isNull);
      expect(answer.body, hasLength(188));
      _expectCors(answer);
    });

    test('HEAD: the length, no body', () async {
      final answer = await _get(server.serveHls(folder), method: 'HEAD');
      expect(answer.status, 200);
      expect(answer.header('content-length'), isNotNull);
      expect(answer.body, isEmpty);
    });

    test('a segment not written yet, or gone, is a 404', () async {
      final url = server
          .serveHls(folder)
          .replaceFirst('index.m3u8', 'seg00009.ts');
      expect((await _get(url)).status, 404);
    });

    test('nothing but its own segment names', () async {
      final base = server.serveHls(folder).replaceFirst('/index.m3u8', '');
      File('${folder.path}/secret.txt').writeAsStringSync('no');
      for (final name in [
        'secret.txt',
        '..%2Fsecret.txt',
        'index.m3u8.bak',
        '.ts',
        '${'a' * 65}.ts',
      ]) {
        expect((await _get('$base/$name')).status, 404, reason: name);
      }
      expect((await _get('$base/x/seg00000.ts')).status, 404);
    });
  });

  group('a continuous stream', () {
    test('its handler answers, under the CORS headers', () async {
      final url = server.serveStream((request) async {
        request.response
          ..headers.contentType = ContentType('video', 'mp4')
          ..write('fragments');
        await request.response.close();
      });
      expect(url, matches(RegExp(r'/p/[0-9a-f]{32}/stream\.mp4$')));
      final answer = await _get(url);
      expect(utf8.decode(answer.body), 'fragments');
      _expectCors(answer);
      expect(
        (await _get(url.replaceFirst('stream.mp4', 'other.mp4'))).status,
        404,
      );
    });
  });

  group('a file', () {
    late String url;

    setUp(() => url = server.serveFile(File('${folder.path}/movie.mp4')));

    test('whole, with Accept-Ranges', () async {
      expect(url, matches(RegExp(r'/f/[0-9a-f]{32}/media\.mp4$')));
      final answer = await _get(url);
      expect(answer.status, 200);
      expect(answer.header('accept-ranges'), 'bytes');
      expect(answer.header('content-type'), 'video/mp4');
      expect(answer.body, hasLength(1000));
    });

    for (final (range, start, end) in [
      ('bytes=100-199', 100, 199),
      ('bytes=900-', 900, 999),
      ('bytes=-50', 950, 999),
      ('bytes=990-5000', 990, 999),
    ]) {
      test(range, () async {
        final answer = await _get(url, range: range);
        expect(answer.status, 206);
        expect(answer.header('content-range'), 'bytes $start-$end/1000');
        expect(answer.body, [for (var i = start; i <= end; i++) i % 256]);
      });
    }

    for (final range in ['bytes=1000-', 'bytes=5-2', 'bytes=-', 'items=0-1']) {
      test('$range cannot be satisfied', () async {
        final answer = await _get(url, range: range);
        expect(answer.status, 416);
        expect(answer.header('content-range'), 'bytes */1000');
      });
    }

    test('HEAD', () async {
      final answer = await _get(url, method: 'HEAD');
      expect(answer.header('content-length'), '1000');
      expect(answer.body, isEmpty);
    });
  });

  test('OPTIONS anywhere: 204 and the CORS headers', () async {
    final answer = await _get('${server.origin}/anything', method: 'OPTIONS');
    expect(answer.status, 204);
    _expectCors(answer);
  });

  test('anything else is a 404, with CORS', () async {
    final hls = server.serveHls(folder);
    final token = RelayServer.tokenOf(hls)!;
    for (final path in [
      '/',
      '/r',
      '/r/$token',
      '/r/0123456789abcdef0123456789abcdef/index.m3u8',
      '/p/$token/stream.mp4',
      '/f/$token/index.m3u8',
      '/r/$token/index.m3u8/more',
      '/in/$token',
    ]) {
      final answer = await _get('${server.origin}$path');
      expect(answer.status, 404, reason: path);
      _expectCors(answer);
    }
    expect((await _get(hls, method: 'POST')).status, 404);
    expect((await _get(hls, method: 'DELETE')).status, 404);
  });

  test('tells of the first fetch of each URL, once', () async {
    final hls = server.serveHls(folder);
    final file = server.serveFile(File('${folder.path}/movie.mp4'));
    await _get(hls);
    await _get(hls);
    await _get(file);
    expect(fetched, [RelayServer.tokenOf(hls), RelayServer.tokenOf(file)]);
  });

  test('a removed URL answers 404 from then on', () async {
    final hls = server.serveHls(folder);
    expect(server.isEmpty, isFalse);
    server.remove(RelayServer.tokenOf(hls)!);
    expect(server.isEmpty, isTrue);
    expect((await _get(hls)).status, 404);
  });

  test('tokens are never reused, and each URL has its own', () {
    final urls = {for (var i = 0; i < 200; i++) server.serveHls(folder)};
    expect(urls, hasLength(200));
    expect(RelayServer.tokenOf('http://h/r/abc/index.m3u8'), 'abc');
    expect(RelayServer.tokenOf('http://h/r/abc'), isNull);
  });

  test("docs/04's MIME types", () {
    expect(relayMimeType('index.m3u8'), 'application/vnd.apple.mpegurl');
    expect(relayMimeType('seg.TS'), 'video/mp2t');
    expect(relayMimeType('seg.m4s'), 'video/iso.segment');
    for (final name in ['a.mp4', 'a.m4v', 'a.mov']) {
      expect(relayMimeType(name), 'video/mp4');
    }
    expect(relayMimeType('a.webm'), 'video/webm');
    expect(relayMimeType('a.vtt'), 'text/vtt');
    expect(relayMimeType('poster.jpg'), 'image/jpeg');
    expect(relayMimeType('a.mkv'), 'application/octet-stream');
  });
}

void _expectCors(_Answer answer) {
  expect(answer.header('access-control-allow-origin'), '*');
  expect(answer.header('access-control-allow-headers'), '*');
  expect(answer.header('access-control-allow-methods'), 'GET, HEAD, OPTIONS');
}

final class _Answer {
  const new(this.status, this.headers, this.body);

  final int status;
  final HttpHeaders headers;
  final List<int> body;

  String? header(String name) => headers.value(name);
}

/// As the TV asks: with its Origin.
Future<_Answer> _get(String url, {String method = 'GET', String? range}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse(url));
    request.headers.set('Origin', 'https://www.gstatic.com');
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
    final body = <int>[];
    await response.forEach(body.addAll);
    return _Answer(response.statusCode, response.headers, body);
  } finally {
    client.close(force: true);
  }
}
