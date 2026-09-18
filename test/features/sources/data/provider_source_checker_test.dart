import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/sources/data/provider_source_checker.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

Future<FakeProviderServer> _fakeProvider(String profile) async {
  final runDir = await Directory.systemTemp.createTemp('checker');
  addTearDown(() => runDir.delete(recursive: true));
  final server = await FakeProviderServer.start(
    state: FakeServerState(
      profile: fakeProfiles[profile]!,
      samplesDir: runDir.path,
      ffmpegPath: 'ffmpeg',
      runDir: runDir.path,
    ),
    port: 0,
  );
  addTearDown(server.close);
  return server;
}

SourceDraft _xtream(Uri server, {String password = 'test'}) => SourceDraft(
  type: SourceType.xtream,
  name: 'Fake',
  // As a user types it: no scheme, and a trailing slash.
  url: '${server.host}:${server.port}/',
  username: 'test',
  password: password,
);

void main() {
  // The Flutter test binding fakes HttpClient with 400s; these need
  // sockets.
  setUpAll(() => HttpOverrides.global = null);

  final checker = ProviderSourceChecker(previewEntries: 50);

  group('Xtream', () {
    test('signs in and reports the account', () async {
      final server = await _fakeProvider('default');

      final check = (await checker.check(_xtream(server.url))).valueOrNull!;

      expect(check.where, server.url.host);
      expect(check.account?.status, 'Active');
      expect(check.account?.maxConnections, isNotNull);
      expect(check.playlist, isNull);
    });

    test('a wrong password is an AuthFailure', () async {
      final server = await _fakeProvider('default');

      final result = await checker.check(
        _xtream(server.url, password: 'wrong'),
      );

      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('nothing listening is a NetworkFailure, quickly', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();

      final clock = Stopwatch()..start();
      final result = await checker.check(
        _xtream(Uri.parse('http://127.0.0.1:$port')),
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
      // No retries: the user is waiting.
      expect(clock.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('an incomplete draft is refused before any request', () async {
      final result = await checker.check(
        const SourceDraft(type: SourceType.xtream, name: '', url: 'x.test'),
      );
      expect(result.failureOrNull, isA<InvalidInputFailure>());
      expect(result.failureOrNull!.detail, 'username');
    });
  });

  group('M3U', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('checker_m3u');
      addTearDown(() => dir.delete(recursive: true));
    });

    String file(String name, String text) =>
        (File('${dir.path}/$name')..writeAsStringSync(text)).path;

    test('a small file is read whole', () async {
      final path = file('list.m3u', '''
#EXTM3U
#EXTINF:-1 group-title="UK",BBC One
http://tv.test/live/1.ts
#EXTINF:-1 group-title="Films",Heat
http://tv.test/movie/2.mkv
#EXTINF:-1 group-title="Series",Dark S01 E01
http://tv.test/series/3.mkv
''');

      final check = (await checker.check(
        SourceDraft(type: SourceType.m3uFile, name: 'x', url: path),
      )).valueOrNull!;

      expect(check.where, 'list.m3u');
      expect(check.playlist?.complete, isTrue);
      expect(check.playlist?.entries, 3);
      expect(check.playlist?.live, 1);
      expect(check.playlist?.movies, 1);
      expect(check.playlist?.episodes, 1);
      expect(check.playlist?.bytes, File(path).lengthSync());
    });

    test('a big file is only read to its first entries', () async {
      final lines = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 5000; i++) {
        lines
          ..writeln('#EXTINF:-1,Channel $i')
          ..writeln('http://tv.test/live/$i.ts');
      }
      final path = file('big.m3u', '$lines');

      final check = (await checker.check(
        SourceDraft(type: SourceType.m3uFile, name: 'x', url: path),
      )).valueOrNull!;

      expect(check.playlist?.complete, isFalse);
      expect(check.playlist?.entries, 50);
    });

    test('a file that is not a playlist is a ParseFailure', () async {
      final path = file('page.m3u', '<html><body>Not found</body></html>');

      final result = await checker.check(
        SourceDraft(type: SourceType.m3uFile, name: 'x', url: path),
      );

      expect(result.failureOrNull, isA<ParseFailure>());
    });

    test('a missing file is a NotFoundFailure', () async {
      final result = await checker.check(
        SourceDraft(
          type: SourceType.m3uFile,
          name: 'x',
          url: '${dir.path}/gone.m3u',
        ),
      );
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test("a link to the fake provider's get.php", () async {
      final server = await _fakeProvider('default');
      final url = server.url.replace(
        path: '/get.php',
        queryParameters: {
          'username': 'test',
          'password': 'test',
          'type': 'm3u_plus',
        },
      );

      final check = (await checker.check(
        SourceDraft(type: SourceType.m3uUrl, name: 'x', url: '$url'),
      )).valueOrNull!;

      expect(check.where, server.url.host);
      expect(check.playlist?.entries, greaterThan(0));
      expect(check.playlist?.bytes, isNull);
    });

    test('a link that answers 401 is an AuthFailure', () async {
      final server = await _fakeProvider('default');
      final url = server.url.replace(
        path: '/get.php',
        queryParameters: {'username': 'test', 'password': 'wrong'},
      );

      final result = await checker.check(
        SourceDraft(type: SourceType.m3uUrl, name: 'x', url: '$url'),
      );

      expect(result.failureOrNull, isA<AuthFailure>());
    });
  });
}
