import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/m3u/m3u_models.dart';
import 'package:iptv_player/data/providers/m3u/m3u_reader.dart';

const _password = 'Pw-7f3a9c1e';

Future<FakeProviderServer> _fakePanel(FakeProfile profile) async {
  final runDir = await Directory.systemTemp.createTemp('fake_provider');
  addTearDown(() => runDir.delete(recursive: true));
  final server = await FakeProviderServer.start(
    state: FakeServerState(
      profile: profile.copyWith(username: 'viewer', password: _password),
      samplesDir: runDir.path,
      ffmpegPath: 'ffmpeg',
      runDir: runDir.path,
    ),
    port: 0,
  );
  addTearDown(server.close);
  return server;
}

/// A server that answers every request with [handle].
Future<String> _serve(Future<void> Function(HttpResponse r) handle) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) => handle(request.response));
  return 'http://127.0.0.1:${server.port}/list.m3u';
}

Future<(List<M3uEntry>, Result<M3uSummary>)> _read(M3uInput input) async {
  final entries = <M3uEntry>[];
  final result = await readM3u(
    input,
    entries.add,
    idleTimeout: const Duration(milliseconds: 300),
  );
  return (entries, result);
}

void main() {
  // The Flutter test binding fakes HttpClient with 400s; this needs sockets.
  setUpAll(() => HttpOverrides.global = null);

  group('a file', () {
    test('is read and parsed', () async {
      final (entries, result) = await _read(
        const M3uFileInput('test_fixtures/m3u/clean.m3u'),
      );

      expect(result.valueOrNull!.entries, 5);
      expect(entries, hasLength(5));
    });

    test('that does not exist is not found, not a crash', () async {
      final (_, result) = await _read(
        const M3uFileInput('test_fixtures/m3u/missing.m3u'),
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('that is an HTML page is a parse failure', () async {
      final (_, result) = await _read(
        const M3uFileInput('test_fixtures/m3u/html_error.m3u'),
      );

      expect(result.failureOrNull, isA<ParseFailure>());
    });
  });

  group("the fake provider's get.php", () {
    String playlistUrl(FakeProviderServer server) =>
        '${server.url}/get.php?username=viewer&password=$_password'
        '&type=m3u_plus&output=ts';

    test('the whole catalogue, and the password in no stream URL', () async {
      final server = await _fakePanel(fakeProfiles['default']!);

      final (entries, result) = await _read(M3uUrlInput(playlistUrl(server)));

      final summary = result.valueOrNull!;
      expect(summary.live, 240);
      expect(summary.movies, 120);
      expect(summary.episodes, greaterThan(0));
      expect(summary.skipped, 0);
      for (final entry in entries) {
        expect(entry.streamUrl, isNot(contains(_password)));
      }
      expect(
        entries.first.streamUrl,
        endsWith('/live/{username}/{password}/1.ts'),
      );
      expect(summary.epgUrls.single, contains('/xmltv.php'));
      final episode = entries.firstWhere((e) => e.kind == M3uKind.episode);
      expect(episode.seriesName, isNotNull);
      expect(episode.season, isNotNull);
    });

    test('the quirky profile: every entry kept, every name clean', () async {
      final profile = fakeProfiles['quirky']!;
      final server = await _fakePanel(profile);

      final (entries, result) = await _read(M3uUrlInput(playlistUrl(server)));

      final summary = result.valueOrNull!;
      expect(summary.live, profile.liveCount);
      expect(summary.movies, profile.movieCount);
      expect(summary.skipped, 0);
      for (final entry in entries) {
        expect(entry.name, isNot(contains('\ufffd')));
        expect(entry.name, isNot(contains('&amp;')));
        expect(entry.name, isNot(matches(r'^\s|\s$|\s\s')));
      }
      expect(entries.where((e) => e.userAgent != null), isNotEmpty);
    });

    test('wrong credentials are an auth failure', () async {
      final server = await _fakePanel(fakeProfiles['default']!);

      final (_, result) = await _read(
        M3uUrlInput('${server.url}/get.php?username=viewer&password=wrong'),
      );

      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('the same playlist twice gives the same identities', () async {
      final server = await _fakePanel(fakeProfiles['default']!);

      final (first, _) = await _read(M3uUrlInput(playlistUrl(server)));
      final (second, _) = await _read(M3uUrlInput(playlistUrl(server)));

      expect(
        second.map((e) => e.identity).toList(),
        first.map((e) => e.identity).toList(),
      );
    });
  });

  group('over HTTP', () {
    final plain = File('test_fixtures/m3u/clean.m3u').readAsBytesSync();
    final gzipped = File('test_fixtures/m3u/clean.m3u.gz').readAsBytesSync();

    test('gzip with Content-Encoding is unpacked by the client', () async {
      final url = await _serve((r) {
        r.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        r.add(gzipped);
        return r.close();
      });

      final (entries, _) = await _read(M3uUrlInput(url));

      expect(entries, hasLength(5));
    });

    test('gzip without Content-Encoding is found by its bytes', () async {
      final url = await _serve((r) {
        r.headers.contentType = ContentType.binary;
        r.add(gzipped);
        return r.close();
      });

      final (entries, _) = await _read(M3uUrlInput(url));

      expect(entries, hasLength(5));
    });

    test('404 is not found; 500 a network failure', () async {
      for (final (status, type) in [
        (404, isA<NotFoundFailure>()),
        (500, isA<NetworkFailure>()),
      ]) {
        final url = await _serve((r) {
          r.statusCode = status;
          return r.close();
        });

        final (_, result) = await _read(M3uUrlInput(url));

        expect(result.failureOrNull, type, reason: '$status');
      }
    });

    test('a server that goes silent mid-playlist times out', () async {
      final url = await _serve((r) async {
        r.add(plain.sublist(0, 100));
        await r.flush();
        // …and nothing more.
      });

      final (_, result) = await _read(M3uUrlInput(url));

      expect(result.failureOrNull, isA<TimeoutFailure>());
    });

    test('the default User-Agent is sent, or the source’s own', () async {
      final agents = <String?>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        agents.add(request.headers.value(HttpHeaders.userAgentHeader));
        request.response.add(plain);
        await request.response.close();
      });
      final url = 'http://127.0.0.1:${server.port}/list.m3u';

      await _read(M3uUrlInput(url));
      await _read(M3uUrlInput(url, userAgent: 'MyBox/1.0'));

      expect(agents, ['VLC/3.0.20 LibVLC/3.0.20', 'MyBox/1.0']);
    });
  });
}
