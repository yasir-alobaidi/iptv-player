import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';

const _password = 'Pw-7f3a9c1e';

/// A one-off HTTP server whose answers each test scripts.
final class _Panel {
  new _(this._server);

  static Future<_Panel> start(
    FutureOr<void> Function(HttpRequest request, _Panel panel) handle,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final panel = _Panel._(server);
    server.listen((request) async {
      panel.requests.add(request.uri);
      panel.agents.add(request.headers.value(HttpHeaders.userAgentHeader));
      panel._inFlight++;
      if (panel._inFlight > panel.maxInFlight) {
        panel.maxInFlight = panel._inFlight;
      }
      try {
        await handle(request, panel);
      } finally {
        panel._inFlight--;
      }
    });
    return panel;
  }

  final HttpServer _server;
  final requests = <Uri>[];
  final agents = <String?>[];
  int maxInFlight = 0;
  int _inFlight = 0;

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);
}

Future<void> _json(HttpRequest request, Object? body, {int status = 200}) {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  return request.response.close();
}

const Map<String, Object?> _account = {
  'user_info': {'auth': 1, 'status': 'Active', 'password': _password},
};

void main() {
  late List<Duration> waits;
  late List<_Panel> panels;

  XtreamClient clientFor(_Panel panel, {String? userAgent}) => XtreamClient(
    server: panel.url,
    username: 'viewer',
    password: _password,
    userAgent: userAgent,
    delay: (duration) async => waits.add(duration),
  );

  Future<_Panel> panel(
    FutureOr<void> Function(HttpRequest request, _Panel panel) handle,
  ) async {
    final started = await _Panel.start(handle);
    panels.add(started);
    return started;
  }

  // The Flutter test binding answers every HTTP request with a 400 so
  // widget tests can't reach the network; these tests need real sockets.
  setUpAll(() => HttpOverrides.global = null);

  setUp(() {
    waits = [];
    panels = [];
  });
  tearDown(() async {
    for (final p in panels) {
      await p.close();
    }
  });

  test('builds player_api.php from the server, credentials in the '
      'query', () async {
    final p = await panel((r, _) => _json(r, _account));

    await clientFor(p).account();

    final uri = p.requests.single;
    expect(uri.path, '/player_api.php');
    expect(uri.queryParameters, {'username': 'viewer', 'password': _password});
  });

  test('a server with a base path keeps it', () async {
    final p = await panel((r, _) => _json(r, const <Object>[]));
    final client = XtreamClient(
      server: '${p.url}/iptv/',
      username: 'u',
      password: 'p',
    );

    await client.liveCategories();

    expect(p.requests.single.path, '/iptv/player_api.php');
    expect(p.requests.single.queryParameters['action'], 'get_live_categories');
  });

  test('sends the default User-Agent, or the source’s own', () async {
    final p = await panel((r, _) => _json(r, _account));

    await clientFor(p).account();
    await clientFor(p, userAgent: 'MyBox/1.0').account();

    expect(p.agents, [defaultUserAgent, 'MyBox/1.0']);
  });

  test('a category filter rides along, and "" is never sent', () async {
    final p = await panel((r, _) => _json(r, const <Object>[]));
    final client = clientFor(p);

    await client.liveStreams(categoryId: '7');
    await client.liveStreams();

    expect(p.requests[0].queryParameters['category_id'], '7');
    expect(p.requests[1].queryParameters.containsKey('category_id'), isFalse);
  });

  group('failures', () {
    test('auth 0 with a 200 is an auth failure', () async {
      final p = await panel(
        (r, _) => _json(r, const {
          'user_info': {'auth': 0},
        }),
      );

      final result = await clientFor(p).account();

      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('401 and 403 are auth failures, 404 is not found, without '
        'retrying', () async {
      for (final (status, type) in [
        (401, isA<AuthFailure>()),
        (403, isA<AuthFailure>()),
        (404, isA<NotFoundFailure>()),
      ]) {
        final p = await panel((r, _) => _json(r, const {}, status: status));

        final result = await clientFor(p).liveCategories();

        expect(result.failureOrNull, type, reason: '$status');
        expect(p.requests, hasLength(1), reason: '$status');
      }
    });

    test('an empty 404 is a refused sign-in; an error page is not found '
        '(a real panel, 2026-09-19)', () async {
      for (final (body, type) in [
        ('', isA<AuthFailure>()),
        ('\r\n', isA<AuthFailure>()),
        (_nginx404, isA<NotFoundFailure>()),
      ]) {
        final p = await panel((r, _) {
          r.response
            ..statusCode = 404
            ..write(body);
          return r.response.close();
        });

        final result = await clientFor(p).account(retry: false);

        expect(result.failureOrNull, type, reason: jsonEncode(body));
        // Either way the user can see the server answered 404.
        expect(result.failureOrNull!.statusCode, 404);
        expect(p.requests, hasLength(1));
      }
    });

    test('a 200 that is not JSON is a parse failure', () async {
      final p = await panel((r, _) {
        r.response
          ..headers.contentType = ContentType.html
          ..write('<html><title>502 Bad Gateway</title></html>');
        return r.response.close();
      });

      final result = await clientFor(p).liveStreams();

      expect(result.failureOrNull, isA<ParseFailure>());
    });

    test('a refused connection fails fast as a network failure', () async {
      final p = await panel((r, _) => _json(r, _account));
      final url = p.url;
      await p.close();

      final result = await XtreamClient(
        server: url,
        username: 'u',
        password: _password,
        delay: (d) async => waits.add(d),
      ).account();

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(waits, isEmpty, reason: 'nothing to retry');
    });

    test('failure detail never carries the password', () async {
      final p = await panel((r, _) => _json(r, const {}, status: 500));

      final result = await clientFor(p).liveStreams();

      expect(result.failureOrNull.toString(), isNot(contains(_password)));
    });
  });

  group('retries', () {
    test('429 then 200: backs off, honouring Retry-After', () async {
      var calls = 0;
      final p = await panel((r, _) {
        if (++calls == 1) {
          r.response.headers.set(HttpHeaders.retryAfterHeader, '7');
          return _json(r, const {}, status: 429);
        }
        return _json(r, const [
          {'category_id': '1', 'category_name': 'News'},
        ]);
      });

      final result = await clientFor(p).liveCategories();

      expect(result.valueOrNull!.items.single.name, 'News');
      expect(waits, [const Duration(seconds: 7)]);
    });

    test('Retry-After is capped at 30 s', () async {
      var calls = 0;
      final p = await panel((r, _) {
        if (++calls == 1) {
          r.response.headers.set(HttpHeaders.retryAfterHeader, '3600');
          return _json(r, const {}, status: 503);
        }
        return _json(r, const <Object>[]);
      });

      await clientFor(p).liveCategories();

      expect(waits, [const Duration(seconds: 30)]);
    });

    test('5xx every time: gives up after three attempts with growing '
        'waits', () async {
      final p = await panel((r, _) => _json(r, const {}, status: 502));

      final result = await clientFor(p).liveStreams();

      expect(p.requests, hasLength(3));
      final failure = result.failureOrNull;
      expect(failure, isA<NetworkFailure>());
      expect((failure! as NetworkFailure).statusCode, 502);
      expect(waits, hasLength(2));
      expect(waits[0].inMilliseconds, inInclusiveRange(800, 1200));
      expect(waits[1].inMilliseconds, inInclusiveRange(1600, 2400));
    });

    test('the onboarding check does not retry', () async {
      final p = await panel((r, _) => _json(r, const {}, status: 503));

      await clientFor(p).account(retry: false);

      expect(p.requests, hasLength(1));
    });

    test('a body cut off mid-transfer is retried; its error never shows '
        'the password', () async {
      // A raw socket, because HttpServer can't hang up mid-body for real:
      // a detached socket stays open and the client just times out.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      var connections = 0;
      server.listen((socket) async {
        await socket.first;
        final full = ++connections > 4;
        final body = full
            ? '[{"category_id":"1","category_name":"News"}]'
            : '[{"category_id":"1",';
        socket.add(
          utf8.encode(
            'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n'
            'Content-Length: ${full ? utf8.encode(body).length : 100000}'
            '\r\nConnection: close\r\n\r\n$body',
          ),
        );
        await socket.flush();
        socket.destroy();
      });
      final client = XtreamClient(
        server: 'http://127.0.0.1:${server.port}',
        username: 'viewer',
        password: _password,
        delay: (d) async => waits.add(d),
      );

      final failed = await client.liveCategories();
      final waitsWhileFailing = waits.length;
      final recovered = await client.liveCategories();

      // Three attempts, every one cut off: the failure quotes dio's
      // "Connection closed … uri = …?password=…" with the password masked.
      expect(connections, 5);
      expect(failed.failureOrNull, isA<NetworkFailure>());
      expect(failed.failureOrNull.toString(), isNot(contains(_password)));
      expect(waitsWhileFailing, 2);
      // The next call: one more cut off, then a whole body.
      expect(recovered.valueOrNull?.items, hasLength(1));
    });
  });

  test('a panel that goes silent mid-body times out, and is '
      'retried', () async {
    final p = await panel((r, _) async {
      r.response
        ..contentLength = 100000
        ..add(utf8.encode('[{"category_id":"1",'));
      await r.response.flush();
      // Never finishes: the client's idle watchdog has to notice.
    });
    // The panel's forced close in tearDown hangs these up.
    final client = XtreamClient(
      server: p.url,
      username: 'viewer',
      password: _password,
      idleTimeout: const Duration(milliseconds: 200),
      delay: (d) async => waits.add(d),
    );

    final result = await client.liveCategories();

    expect(result.failureOrNull, isA<TimeoutFailure>());
    expect(p.requests, hasLength(3));
  });

  test('one request at a time, in the order they were asked for', () async {
    final p = await panel((r, _) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await _json(r, const <Object>[]);
    });
    final client = clientFor(p);

    await Future.wait([
      client.liveCategories(),
      client.movieCategories(),
      client.seriesCategories(),
      client.liveStreams(),
    ]);

    expect(p.maxInFlight, 1);
    expect(p.requests.map((u) => u.queryParameters['action']), [
      'get_live_categories',
      'get_vod_categories',
      'get_series_categories',
      'get_live_streams',
    ]);
  });

  test('a redirect is followed once and never remembered', () async {
    final target = await panel((r, _) => _json(r, _account));
    final origin = await panel((r, _) {
      final token = 'tok${r.uri.queryParameters['n'] ?? ''}';
      return r.response.redirect(
        Uri.parse('${target.url}${r.uri.path}?${r.uri.query}&token=$token'),
      );
    });
    final client = clientFor(origin);

    await client.account();
    await client.account();

    // Both requests started at the original server; the token-bearing
    // location was used once each and forgotten.
    expect(origin.requests, hasLength(2));
    expect(target.requests, hasLength(2));
  });

  test('cancelAll cancels the request in flight and those queued', () async {
    final release = Completer<void>();
    final p = await panel((r, _) async {
      await release.future;
      await _json(r, const <Object>[]);
    });
    final client = clientFor(p);

    final first = client.liveStreams();
    final second = client.movies();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    client.cancelAll();
    final third = client.liveCategories();
    release.complete();

    expect((await first).failureOrNull, isA<CancelledFailure>());
    expect((await second).failureOrNull, isA<CancelledFailure>());
    expect((await third).isOk, isTrue, reason: 'later calls run normally');
  });

  test('a big body is parsed off the UI isolate, with the same '
      'result', () async {
    final rows = [
      for (var i = 0; i < 5000; i++)
        {
          'num': '$i',
          'name': 'Channel &amp; $i',
          'stream_id': '$i',
          'stream_icon': 'http://logos.test/$i.png',
          'category_id': '${i % 20}',
        },
    ];
    final body = utf8.encode(jsonEncode(rows));
    expect(body.length, greaterThan(backgroundDecodeThreshold));
    final p = await panel((r, _) {
      r.response
        ..headers.contentType = ContentType.json
        ..add(body);
      return r.response.close();
    });

    final result = await clientFor(p).liveStreams();

    final items = result.valueOrNull!.items;
    expect(items, hasLength(5000));
    expect(items[4999].name, 'Channel & 4999');
  });
}

/// nginx's own 404 page, as a real panel's server sends it for a missing page.
const _nginx404 =
    '<html>\r\n<head><title>404 Not Found</title></head>\r\n<body>\r\n'
    '<center><h1>404 Not Found</h1></center>\r\n<hr><center>nginx</center>\r\n'
    '</body>\r\n</html>\r\n';
