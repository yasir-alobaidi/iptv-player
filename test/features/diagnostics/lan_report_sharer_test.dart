import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/diagnostics/data/lan_report_sharer.dart';
import 'package:iptv_player/features/diagnostics/domain/report_share.dart';
import 'package:logger/logger.dart';

/// ADR-059: the report served on this device's network address for a
/// phone, on loopback here.
void main() {
  const fileName = 'bijou-diagnostics-2026-10-26.txt';
  const text =
      'Bijou 0.1.0+343 · Android 12 · TCL 43V8C\n'
      'Recent warnings and errors: none\n';

  late MemoryOutput logged;
  late AppLog log;
  final offers = <ReportOffer>[];

  // Real connections: the test binding answers every HttpClient's request
  // with a 400 otherwise.
  setUpAll(() => HttpOverrides.global = null);

  setUp(() {
    logged = MemoryOutput();
    log = AppLog(output: logged, secrets: SecretRegistry());
  });

  tearDown(() async {
    for (final offer in offers) {
      await offer.close();
    }
    offers.clear();
  });

  String logText() =>
      [for (final event in logged.buffer) ...event.lines].join('\n');

  Future<ReportOffer> offer({
    String body = text,
    Duration lifetime = const Duration(minutes: 30),
  }) async {
    final sharer = LanReportSharer(
      log: log,
      findAddress: () async => InternetAddress.loopbackIPv4,
      lifetime: lifetime,
    );
    final result = await sharer.offer(body, fileName: fileName);
    final offer = (result as Ok<ReportOffer>).value;
    offers.add(offer);
    return offer;
  }

  Future<HttpClientResponse> request(Uri uri, {String method = 'GET'}) async {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.openUrl(method, uri);
    request.followRedirects = false;
    return await request.close();
  }

  Future<(int, String)> fetch(Uri uri, {String method = 'GET'}) async {
    final response = await request(uri, method: method);
    return (response.statusCode, await utf8.decodeStream(response));
  }

  String tokenOf(ReportOffer offer) => offer.address.pathSegments.first;

  group('the offer', () {
    test('is at this address, under a 10-character token a person can '
        'type', () async {
      final shared = await offer();
      final address = shared.address;
      expect(address.scheme, 'http');
      expect(address.host, '127.0.0.1');
      expect(address.port, greaterThan(0));
      expect(address.path, matches(RegExp(r'^/[a-z2-9]{10}/$')));
      expect(tokenOf(shared), isNot(matches(RegExp('[01ilo]'))));
      expect((await offer()).address, isNot(address));
    });

    test('the page: a Download link with the size, then the text', () async {
      final shared = await offer();
      final response = await request(shared.address);
      final page = await utf8.decodeStream(response);
      expect(response.statusCode, 200);
      expect(
        response.headers.contentType?.toString(),
        'text/html; charset=utf-8',
      );
      expect(response.headers.value('cache-control'), 'no-store');
      expect(page, contains('<meta name="viewport"'));
      expect(page, contains('<title>Bijou report</title>'));
      expect(page, contains('href="/${tokenOf(shared)}/$fileName"'));
      expect(page, contains('Download the report (1 KB)'));
      expect(page, contains('Bijou 0.1.0+343 · Android 12 · TCL 43V8C'));
      // The browser's own colors: none in the page (hard rule 9).
      expect(page, isNot(contains('color')));
    });

    test('the address without its slash goes to the page', () async {
      final shared = await offer();
      final response = await request(
        shared.address.replace(path: '/${tokenOf(shared)}'),
      );
      await response.drain<void>();
      expect(response.statusCode, HttpStatus.found);
      expect(response.headers.value('location'), '/${tokenOf(shared)}/');
    });

    test('the file: the exact text, as an attachment nobody caches', () async {
      final shared = await offer();
      final response = await request(shared.address.resolve(fileName));
      final bytes = await response.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      expect(response.statusCode, 200);
      expect(
        response.headers.contentType?.toString(),
        'text/plain; charset=utf-8',
      );
      expect(
        response.headers.value('content-disposition'),
        'attachment; filename="$fileName"',
      );
      expect(response.headers.value('cache-control'), 'no-store');
      expect(utf8.decode(bytes), text);
      expect(response.headers.contentLength, utf8.encode(text).length);
    });

    test("a long report (a TV's logcat) is the same, made away from the UI "
        'isolate', () async {
      final long = [
        for (var i = 0; i < 8000; i++) 'line $i: <tag> & "words" → ok',
      ].join('\n');
      expect(long.length, greaterThan(200000));
      final shared = await offer(body: long);
      final (_, file) = await fetch(shared.address.resolve(fileName));
      expect(file, long);
      final (_, page) = await fetch(shared.address);
      expect(page, contains('line 7999: &lt;tag&gt; &amp; "words" → ok'));
      final kilobytes = reportKilobytes(utf8.encode(long).length);
      expect(page, contains('Download the report ($kilobytes KB)'));
    });

    test('says so each time a phone downloads the file, not for the page or '
        'a HEAD', () async {
      final shared = await offer();
      var downloads = 0;
      shared.fetched.listen((_) => downloads++);
      await fetch(shared.address);
      final (head, _) = await fetch(
        shared.address.resolve(fileName),
        method: 'HEAD',
      );
      expect(head, 200);
      await pumpEventQueue();
      expect(downloads, 0);

      await fetch(shared.address.resolve(fileName));
      await fetch(shared.address.resolve(fileName));
      await pumpEventQueue();
      expect(downloads, 2);
      expect(logText(), contains('A phone downloaded the report'));
    });

    test('anything else is a 404 that names no token', () async {
      final shared = await offer();
      final token = tokenOf(shared);
      final root = shared.address.replace(path: '/');
      for (final uri in [
        root,
        root.replace(path: '/abcdefghjk/'),
        root.replace(path: '/abcdefghjk/$fileName'),
        root.replace(path: '/$token/other.txt'),
        root.replace(path: '/$token/$fileName/more'),
        root.replace(path: '/$fileName'),
      ]) {
        final (status, body) = await fetch(uri);
        expect(status, 404, reason: '$uri');
        expect(body, isNot(contains(token)), reason: '$uri');
      }
      for (final method in ['POST', 'PUT', 'DELETE', 'OPTIONS']) {
        final (status, body) = await fetch(shared.address, method: method);
        expect(status, 404, reason: method);
        expect(body, isNot(contains(token)), reason: method);
      }
    });

    test('the text is escaped in the page', () async {
      final shared = await offer(
        body: 'a <script>alert(1)</script> & "b" <b>bold</b>\n',
      );
      final (_, page) = await fetch(shared.address);
      expect(page, isNot(contains('<script>')));
      expect(page, isNot(contains('<b>')));
      expect(
        page,
        contains(
          'a &lt;script&gt;alert(1)&lt;/script&gt; &amp; "b" '
          '&lt;b&gt;bold&lt;/b&gt;',
        ),
      );
    });

    test('a file name that is unsafe in a path or a header is made '
        'safe', () async {
      final sharer = LanReportSharer(
        log: log,
        findAddress: () async => InternetAddress.loopbackIPv4,
      );
      final shared = (await sharer.offer(
        text,
        fileName: 'my "report"/x.txt',
      ) as Ok<ReportOffer>).value;
      offers.add(shared);
      final response = await request(
        shared.address.resolve('my--report--x.txt'),
      );
      await response.drain<void>();
      expect(response.statusCode, 200);
      expect(
        response.headers.value('content-disposition'),
        'attachment; filename="my--report--x.txt"',
      );
    });

    test('close() ends it: connections fail, the events end, a second '
        'close is nothing', () async {
      final shared = await offer();
      final done = Completer<void>();
      shared.fetched.listen(null, onDone: done.complete);
      await fetch(shared.address);

      await shared.close();
      await shared.close();
      await done.future.timeout(const Duration(seconds: 5));
      await expectLater(fetch(shared.address), throwsA(isA<IOException>()));
      expect(logText(), contains('Stopped offering the report'));
    });

    test('it closes itself when nobody closes it in time', () async {
      final shared = await offer(lifetime: const Duration(milliseconds: 50));
      final done = Completer<void>();
      shared.fetched.listen(null, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 5));
      await expectLater(fetch(shared.address), throwsA(isA<IOException>()));
      expect(logText(), contains('nobody closed it in time'));
    });

    test('the log has the port, never the token', () async {
      final shared = await offer();
      await fetch(shared.address.resolve(fileName));
      await shared.close();
      expect(
        logText(),
        contains('Offering the report on port ${shared.address.port}'),
      );
      expect(logText(), isNot(contains(tokenOf(shared))));
    });
  });

  group('no address a phone could reach', () {
    test('none found: Err(NetworkFailure)', () async {
      final sharer = LanReportSharer(log: log, findAddress: () async => null);
      final result = await sharer.offer(text, fileName: fileName);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('the interfaces not listed: Err(NetworkFailure)', () async {
      final sharer = LanReportSharer(
        log: log,
        findAddress: () async =>
            throw const SocketException('getifaddrs failed'),
      );
      final result = await sharer.offer(text, fileName: fileName);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test("an address that isn't this device's: Err(NetworkFailure)", () async {
      final sharer = LanReportSharer(
        log: log,
        // TEST-NET-1 (RFC 5737): never this machine's.
        findAddress: () async => InternetAddress('192.0.2.1'),
      );
      final result = await sharer.offer(text, fileName: fileName);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });

  group('chooseLanAddress', () {
    InternetAddress ip(String address) => InternetAddress(address);

    test('a private address before a public one', () {
      expect(
        chooseLanAddress([
          ('wlan0', ip('203.0.113.7')),
          ('rmnet0', ip('10.12.0.4')),
        ]),
        ip('10.12.0.4'),
      );
    });

    test('every private range', () {
      for (final address in ['10.0.0.2', '172.16.5.1', '172.31.0.9']) {
        expect(chooseLanAddress([('x', ip(address))]), ip(address));
      }
      expect(
        chooseLanAddress([('x', ip('172.32.0.1')), ('y', ip('192.168.1.50'))]),
        ip('192.168.1.50'),
      );
    });

    test('Wi-Fi or Ethernet before a VPN or a bridge', () {
      expect(
        chooseLanAddress([
          ('tun0', ip('10.8.0.2')),
          ('docker0', ip('172.17.0.1')),
          ('wlan0', ip('192.168.1.50')),
        ]),
        ip('192.168.1.50'),
      );
      expect(
        chooseLanAddress([
          ('docker0', ip('172.17.0.1')),
          ('eth0', ip('192.168.0.20')),
        ]),
        ip('192.168.0.20'),
      );
      expect(
        chooseLanAddress([
          ('virbr0', ip('192.168.122.1')),
          ('enp3s0', ip('192.168.1.20')),
        ]),
        ip('192.168.1.20'),
      );
    });

    test('link-local, loopback and IPv6 never', () {
      expect(
        chooseLanAddress([
          ('wlan0', ip('169.254.10.2')),
          ('lo', ip('127.0.0.1')),
          ('wlan0', ip('fe80::1')),
          ('wlan0', ip('fd00::5')),
        ]),
        isNull,
      );
      expect(
        chooseLanAddress([
          ('wlan0', ip('169.254.10.2')),
          ('tun0', ip('10.8.0.2')),
        ]),
        ip('10.8.0.2'),
      );
    });

    test('falls back to any other address; nothing is null', () {
      expect(
        chooseLanAddress([('ppp0', ip('203.0.113.7'))]),
        ip('203.0.113.7'),
      );
      expect(chooseLanAddress([]), isNull);
    });

    test('the first wins a tie', () {
      expect(
        chooseLanAddress([
          ('wlan0', ip('192.168.1.50')),
          ('eth0', ip('192.168.1.51')),
        ]),
        ip('192.168.1.50'),
      );
    });
  });

  test('reportFileName and reportKilobytes', () {
    expect(reportFileName(' bijou-diagnostics.txt '), 'bijou-diagnostics.txt');
    expect(reportFileName('a b/c"d.txt'), 'a-b-c-d.txt');
    expect(reportFileName(''), 'report.txt');
    expect(reportFileName('../x'), 'report.txt');
    expect(reportKilobytes(0), 1);
    expect(reportKilobytes(1536), 2);
    expect(reportKilobytes(48 * 1024), 48);
  });
}
