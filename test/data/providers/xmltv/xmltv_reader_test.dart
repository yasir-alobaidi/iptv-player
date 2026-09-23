import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/provider_http.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_reader.dart';

const _guide =
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<tv><channel id="one"><display-name>One</display-name></channel></tv>\n';

const _password = 'Pw-7f3a9c1e';
const _token = 'Tk9c2e81d4f00b';

/// A server that answers every request with [handle], and the requests it
/// saw.
Future<(String, List<HttpHeaders>)> _serve(
  Future<void> Function(HttpResponse r) handle, {
  String path = '/guide.xml',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  final seen = <HttpHeaders>[];
  server.listen((request) {
    seen.add(request.headers);
    unawaited(handle(request.response));
  });
  return ('http://127.0.0.1:${server.port}$path', seen);
}

/// Everything [body] yields, or the error it ends with.
Future<List<int>> _drain(XmltvBody body) async {
  final bytes = <int>[];
  await body.bytes.forEach(bytes.addAll);
  return bytes;
}

Future<XmltvBody> _open(XmltvInput input) async {
  final result = await openXmltv(
    input,
    idleTimeout: const Duration(milliseconds: 300),
  );
  final body = result.valueOrNull;
  expect(body, isNotNull, reason: '${result.failureOrNull}');
  addTearDown(body!.close);
  return body;
}

Future<AppFailure> _failure(XmltvInput input) async {
  final result = await openXmltv(
    input,
    idleTimeout: const Duration(milliseconds: 300),
  );
  expect(result.isOk, isFalse);
  return result.failureOrNull!;
}

void main() {
  // The Flutter test binding fakes HttpClient with 400s; this needs sockets.
  setUpAll(() => HttpOverrides.global = null);

  group('a file', () {
    test('is read whole, with its length', () async {
      final directory = await Directory.systemTemp.createTemp('xmltv_reader');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/guide.xml')
        ..writeAsStringSync(_guide);

      final body = await _open(XmltvFileInput(file.path));

      expect(body.length, utf8.encode(_guide).length);
      expect(utf8.decode(await _drain(body)), _guide);
      expect(body.bytesRead, body.length);
    });

    test('that does not exist is not found, not a crash', () async {
      final failure = await _failure(
        const XmltvFileInput('test_fixtures/xmltv/no_such_guide.xml'),
      );

      expect(failure, isA<NotFoundFailure>());
      expect(failure.detail, isNot(contains('no_such_guide')));
    });
  });

  group('over HTTP', () {
    test('the body, its length, the default user agent and gzip '
        'accepted', () async {
      final (url, seen) = await _serve(
        (r) =>
            (r
                  ..contentLength = utf8.encode(_guide).length
                  ..write(_guide))
                .close(),
      );

      final body = await _open(XmltvUrlInput(url));

      expect(utf8.decode(await _drain(body)), _guide);
      expect(body.length, utf8.encode(_guide).length);
      expect(body.bytesRead, body.length);
      expect(seen.single.value(HttpHeaders.userAgentHeader), defaultUserAgent);
      expect(seen.single.value(HttpHeaders.acceptEncodingHeader), 'gzip');
    });

    test("the source's own user agent", () async {
      final (url, seen) = await _serve((r) {
        r.write(_guide);
        return r.close();
      });

      final body = await _open(XmltvUrlInput(url, userAgent: 'Special/1.0'));
      await _drain(body);

      expect(seen.single.value(HttpHeaders.userAgentHeader), 'Special/1.0');
    });

    test('a length the server does not send is null', () async {
      final (url, _) = await _serve((r) {
        // Chunked: no Content-Length.
        r.write(_guide);
        return r.close();
      });

      final body = await _open(XmltvUrlInput(url));
      await _drain(body);

      expect(body.length, isNull);
      expect(body.bytesRead, utf8.encode(_guide).length);
    });

    test('Content-Encoding: gzip is undone once, and counted as it '
        'arrived', () async {
      final packed = gzip.encode(utf8.encode(_guide));
      final (url, _) = await _serve((r) {
        r.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        return (r
              ..contentLength = packed.length
              ..add(packed))
            .close();
      });

      final body = await _open(XmltvUrlInput(url));

      expect(utf8.decode(await _drain(body)), _guide);
      expect(body.length, packed.length);
      expect(body.bytesRead, packed.length);
    });

    test('a .xml.gz with no Content-Encoding is left for the parser to '
        'find', () async {
      final packed = gzip.encode(utf8.encode(_guide));
      final (url, _) = await _serve((r) {
        r.headers.contentType = ContentType.binary;
        r.add(packed);
        return r.close();
      }, path: '/guide.xml.gz');

      final body = await _open(XmltvUrlInput(url));

      // Still gzip: decoding it here too would unpack it twice.
      expect(await _drain(body), packed);
    });

    test('401 and 403 are auth failures, 404 not found, 500 a network '
        'failure — each with its status', () async {
      for (final (status, type) in [
        (401, isA<AuthFailure>()),
        (403, isA<AuthFailure>()),
        (404, isA<NotFoundFailure>()),
        (500, isA<NetworkFailure>()),
        (302, isA<NetworkFailure>()),
      ]) {
        final (url, _) = await _serve((r) {
          r.statusCode = status;
          if (status == 302) {
            // A redirect with nowhere to go.
            r.headers.set(HttpHeaders.locationHeader, '');
          }
          r.write('<html><body>$status</body></html>');
          return r.close();
        });

        final failure = await _failure(XmltvUrlInput(url));

        expect(failure, type, reason: '$status');
        if (status != 302) expect(failure.statusCode, status);
      }
    });

    test('a server that goes silent mid-guide times out', () async {
      final (url, _) = await _serve((r) async {
        r.write(_guide.substring(0, 20));
        await r.flush();
        // …and nothing more.
      });

      final body = await _open(XmltvUrlInput(url));

      await expectLater(_drain(body), throwsA(isA<TimeoutException>()));
    });

    test('a server that never answers times out', () async {
      final (url, _) = await _serve((r) async {
        // Accepted, and not a byte of an answer.
      });

      final failure = await _failure(XmltvUrlInput(url));

      expect(failure, isA<TimeoutFailure>());
    });

    test('not an http(s) URL is invalid input, and not quoted', () async {
      for (final url in [
        'ftp://epg.test/$_token/guide.xml',
        'http://[epg.test/$_token',
        'epg.test/$_token/guide.xml',
      ]) {
        final failure = await _failure(XmltvUrlInput(url));

        expect(failure, isA<InvalidInputFailure>(), reason: url);
        expect('$failure', isNot(contains(_token)), reason: url);
      }
    });
  });

  group('no failure carries a secret', () {
    void expectClean(Object text) {
      expect('$text', isNot(contains(_password)));
      expect('$text', isNot(contains(_token)));
      expect('$text', isNot(contains(Uri.encodeQueryComponent(_password))));
    }

    test('connection refused, for a password in the query and a token in '
        'the path', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();

      for (final url in [
        'http://127.0.0.1:$port/xmltv.php?username=viewer&password=$_password',
        'http://127.0.0.1:$port/epg/$_token/guide.xml',
      ]) {
        final failure = await _failure(XmltvUrlInput(url));

        expect(failure, isA<NetworkFailure>(), reason: url);
        expectClean(failure);
      }
    });

    test('a connection closed before the headers, whose error quotes the '
        'URL', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) {
        // Reads the request, then hangs up without a word.
        socket.listen((_) => socket.destroy());
      });
      final origin = 'http://127.0.0.1:${server.port}';

      for (final url in [
        '$origin/xmltv.php?username=viewer&password=$_password',
        '$origin/epg/$_token/guide.xml',
        '$origin/epg/$_token/guide.xml?sig=$_password',
        '$origin/p/$_token?password=p%40ss+w%26rd',
      ]) {
        final failure = await _failure(XmltvUrlInput(url));

        expect(failure, isA<NetworkFailure>(), reason: url);
        expectClean(failure);
        expect('$failure', isNot(contains('p%40ss')), reason: url);
        // Where it went is still said.
        expect('$failure', contains('127.0.0.1'), reason: url);
      }
    });

    test('an HTTP 500 from a URL with a password and a token', () async {
      final (url, _) = await _serve((r) {
        r.statusCode = 500;
        return r.close();
      }, path: '/epg/$_token/xmltv.php?username=viewer&password=$_password');

      final failure = await _failure(XmltvUrlInput(url));

      expect(failure, isA<NetworkFailure>());
      expect(failure.statusCode, 500);
      expectClean(failure);
    });

    test('the input prints its origin only', () {
      const input = XmltvUrlInput(
        'http://epg.test:8080/epg/$_token/guide.xml?password=$_password',
      );

      expect('$input', 'XmltvUrlInput(http://epg.test:8080/…)');
    });
  });

  group('hideUrl', () {
    const url =
        'http://epg.test:8080/get/$_token/guide.xml'
        '?username=viewer&password=p%40ss+w%26rd';

    test('replaces the URL with its origin, masked or not', () {
      for (final text in [
        'failed, uri = $url',
        'failed, uri = ${Uri.parse(url)}',
        // As AppFailure leaves it: the query masked, the path not.
        'failed, uri = ${redact(url)}',
      ]) {
        expect(
          hideUrl(text, url),
          'failed, uri = http://epg.test:8080/…',
          reason: text,
        );
      }
    });

    test('masks its pieces wherever else they turn up', () {
      final text = hideUrl(
        'redirected to /other/$_token/x and saw p@ss w&rd, p%40ss+w%26rd',
        url,
      );

      expect(text, isNot(contains(_token)));
      expect(text, isNot(contains('p@ss w&rd')));
      expect(text, isNot(contains('p%40ss')));
      expect(text, contains('redirected to /other/'));
    });

    test('leaves text without the URL alone', () {
      expect(
        hideUrl('TimeoutException: no data', url),
        'TimeoutException: '
        'no data',
      );
    });

    test('keeps the failure type and status', () {
      final failure = failureWithoutUrl(
        NetworkFailure('closed, uri = $url', 502),
        url,
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.statusCode, 502);
      expect(failure.detail, 'closed, uri = http://epg.test:8080/…');
    });
  });
}
