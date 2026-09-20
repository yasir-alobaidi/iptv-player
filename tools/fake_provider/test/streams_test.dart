import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/streams.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

/// The ffmpeg tests need the bundled binary and the generated samples, which
/// a fresh clone does not have (tools/media_samples/generate.sh builds them).
/// The reason is computed once here and handed to `skip:`.
final String? mediaSkip = _mediaSkipReason();

final String _repoRoot = _findRepoRoot();
final String _ffmpegPath =
    '$_repoRoot/third_party/ffmpeg/'
    '${Platform.isWindows ? 'windows-x64/ffmpeg.exe' : 'linux-x64/ffmpeg'}';
final String _samplesDir = '$_repoRoot/tools/media_samples/out';

String _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/third_party').existsSync() &&
        Directory('${dir.path}/tools/media_samples').existsSync()) {
      return dir.path;
    }
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return Directory.current.path;
}

String? _mediaSkipReason() {
  if (!File(_ffmpegPath).existsSync()) return 'no bundled ffmpeg';
  if (!Directory(_samplesDir).existsSync()) return 'no $_samplesDir';
  for (final sample in liveSamples) {
    if (!File('$_samplesDir/$sample').existsSync()) {
      return 'missing sample $sample';
    }
  }
  return null;
}

void main() {
  late Directory runDir;
  late FakeServerState state;
  late StreamRelay relay;

  setUp(() {
    runDir = Directory.systemTemp.createTempSync('fake_provider_streams_');
    state = FakeServerState(
      profile: fakeProfiles['default']!,
      samplesDir: _samplesDir,
      ffmpegPath: _ffmpegPath,
      runDir: runDir.path,
    );
    relay = StreamRelay(state);
  });

  tearDown(() async {
    await relay.close();
    if (runDir.existsSync()) runDir.deleteSync(recursive: true);
  });

  Future<Response> get(String path) =>
      Future.value(relay.handler(Request('GET', Uri.parse('http://x$path'))));

  group('routing and limits', () {
    test('bad credentials are 401', () async {
      final response = await get('/live/test/wrong/1.ts');
      expect(response.statusCode, HttpStatus.unauthorized);
      expect(state.activeStreams, 0);
    });

    test('an unknown stream id is 404', () async {
      final response = await get('/live/test/test/999999.ts');
      expect(response.statusCode, HttpStatus.notFound);

      final notANumber = await get('/live/test/test/abc.ts');
      expect(notANumber.statusCode, HttpStatus.notFound);
      expect(state.activeStreams, 0);
    });

    test('a movie or series path is 501', () async {
      final movie = await get('/movie/test/test/100001.mp4');
      expect(movie.statusCode, HttpStatus.notImplemented);
      expect(await movie.readAsString(), contains('docs/06'));

      final series = await get('/series/test/test/300001.mkv');
      expect(series.statusCode, HttpStatus.notImplemented);
    });

    test('an extension other than .ts or .m3u8 is 501', () async {
      final response = await get('/live/test/test/1.mp4');
      expect(response.statusCode, HttpStatus.notImplemented);
      expect(await response.readAsString(), contains('.m3u8'));
    });

    test('max_connections is refused with a checkable body', () async {
      // The limit is checked before any work, so this needs no ffmpeg.
      state.activeStreams = state.maxConnections;
      final response = await get('/live/test/test/1.ts');
      expect(response.statusCode, HttpStatus.forbidden);
      expect(await response.readAsString(), contains(maxConnectionsBody));
      // Refusing must not change the count player_api.php reports.
      expect(state.activeStreams, state.maxConnections);
    });
  });

  group('stale process cleanup', () {
    test('drops a record whose process is gone', () async {
      final pidFile = File('${runDir.path}/pids/live_4194302.pid')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('4194302\n$_ffmpegPath\n/nope/loop.mkv\n');
      await relay.cleanStaleProcesses();
      expect(pidFile.existsSync(), isFalse);
    });

    test('does not signal a pid that is not our ffmpeg', () async {
      // This test process: alive, but its cmdline is dart, not our ffmpeg.
      final pidFile = File('${runDir.path}/pids/live_$pid.pid')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('$pid\n$_ffmpegPath\n/nope/loop.mkv\n');
      await relay.cleanStaleProcesses();
      expect(pidFile.existsSync(), isFalse);
      // Still here, so nothing was killed. `/proc/<pid>` is a directory, so
      // this goes through the same cmdline check the relay uses.
      expect(_isAlive(pid), isTrue);
    }, skip: Platform.isLinux ? null : 'needs /proc');

    test('ignores a truncated record', () async {
      final pidFile = File('${runDir.path}/pids/live_0.pid')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('not-a-pid');
      await relay.cleanStaleProcesses();
      expect(pidFile.existsSync(), isFalse);
    });
  });

  group('ffmpeg', () {
    test('serves mpegts and cleans up when the client disconnects', () async {
      final server = await shelf_io.serve(relay.handler, '127.0.0.1', 0);
      addTearDown(() => server.close(force: true));
      final client = HttpClient();

      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/live/test/test/1.ts'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'video/mp2t');

      var received = 0;
      final enough = Completer<void>();
      final subscription = response.listen(
        (chunk) {
          received += chunk.length;
          if (received >= 200 * 1024 && !enough.isCompleted) {
            enough.complete();
          }
        },
        onError: (Object _) {},
        onDone: () {
          if (!enough.isCompleted) enough.complete();
        },
        cancelOnError: true,
      );
      await enough.future.timeout(const Duration(seconds: 30));
      expect(received, greaterThanOrEqualTo(200 * 1024));
      expect(state.activeStreams, 1);

      // The MKV loop cache, not the .ts, is what ffmpeg reads.
      final sample = state.catalog.channelById(1)!.sample;
      final mkv = File(
        '${runDir.path}/loop_cache/'
        '${sample.substring(0, sample.lastIndexOf('.'))}.mkv',
      );
      expect(mkv.existsSync(), isTrue);
      expect(File('${mkv.path}.part').existsSync(), isFalse);

      final pids = _pidFiles(runDir);
      expect(pids, hasLength(1));
      final childPid = int.parse(pids.single.readAsLinesSync().first);

      await subscription.cancel();
      client.close(force: true);

      await _until(
        () => state.activeStreams == 0 && _pidFiles(runDir).isEmpty,
        'the stream to be reaped',
      );
      expect(_isAlive(childPid), isFalse);
    });

    test(
      'a client reset before the answer starts frees its slot',
      () async {
        // A player abandoning an attempt mid-reconnect. Before the relay
        // owned the socket, a reset that beat the response headers left
        // dart:io holding the body: it dropped every chunk and never
        // cancelled it, so ffmpeg and the slot stayed taken for good (the
        // 2026-09-19 soak). The first request for a sample waits on its
        // remux, which holds the answer back long enough to reset.
        final server = await shelf_io.serve(relay.handler, '127.0.0.1', 0);
        addTearDown(() => server.close(force: true));
        final socket = await Socket.connect('127.0.0.1', server.port);
        socket.write(
          'GET /live/test/test/1.ts HTTP/1.1\r\nHost: x\r\n'
          'Connection: close\r\n\r\n',
        );
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        _reset(socket);

        await _until(
          () =>
              File('${runDir.path}/loop_cache/h264_1080p50_aac.mkv')
                  .existsSync(),
          'the remux',
          timeout: const Duration(seconds: 30),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
        await _until(
          () => state.activeStreams == 0 && _pidFiles(runDir).isEmpty,
          'the slot to be freed',
        );
      },
      skip: mediaSkip ?? (Platform.isLinux ? null : 'SO_LINGER is Linux here'),
    );

    test('reuses the cached remux and never remuxes twice at once', () async {
      // Two concurrent requests for the same sample (default profile allows
      // two connections): one remux, one cached MKV, no .part left behind.
      final server = await shelf_io.serve(relay.handler, '127.0.0.1', 0);
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      Future<HttpClientResponse> open() async {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}/live/test/test/1.ts'),
        );
        return await request.close();
      }

      final responses = await Future.wait([open(), open()]);
      expect(responses.map((r) => r.statusCode), everyElement(HttpStatus.ok));
      expect(state.activeStreams, 2);
      for (final response in responses) {
        unawaited(response.drain<void>().catchError((Object _) {}));
      }

      final cache = Directory('${runDir.path}/loop_cache');
      final cached = cache.listSync().whereType<File>().toList();
      expect(cached, hasLength(1));
      expect(cached.single.path, endsWith('.mkv'));
      final stamp = cached.single.lastModifiedSync();

      await relay.close();
      expect(state.activeStreams, 0);
      expect(_pidFiles(runDir), isEmpty);

      final again = await open();
      expect(again.statusCode, HttpStatus.ok);
      unawaited(again.drain<void>().catchError((Object _) {}));
      expect(cached.single.lastModifiedSync(), stamp);
    }, skip: mediaSkip);

    test('a missing sample file is a 404 naming it', () async {
      final empty = Directory.systemTemp.createTempSync('fake_samples_');
      addTearDown(() => empty.deleteSync(recursive: true));
      final bare = StreamRelay(
        FakeServerState(
          profile: fakeProfiles['default']!,
          samplesDir: empty.path,
          ffmpegPath: _ffmpegPath,
          runDir: runDir.path,
        ),
      );
      final response = await bare.handler(
        Request('GET', Uri.parse('http://x/live/test/test/1.ts')),
      );
      expect(response.statusCode, HttpStatus.notFound);
      expect(await response.readAsString(), contains(empty.path));
      await bare.close();
    });
  }, skip: mediaSkip);

  group('faults (docs/06)', () {
    test('http_status answers with that status, per request', () async {
      for (final (status, marker) in [
        (401, 'BAD_CREDENTIALS'),
        (403, maxConnectionsBody),
        (404, 'no live stream'),
        (429, 'TOO_MANY_REQUESTS'),
        (500, 'FAULT 500'),
      ]) {
        final response = await get('/live/test/test/1.ts?http_status=$status');
        expect(response.statusCode, status);
        expect(await response.readAsString(), contains(marker));
        expect(state.activeStreams, 0);
      }
      final limited = await get('/live/test/test/1.ts?http_status=429');
      expect(limited.headers['retry-after'], '1');
    });

    test('the fault set applies to every stream until cleared', () async {
      state.faults = const FakeFaults(httpStatus: 404);
      expect((await get('/live/test/test/2.ts')).statusCode, 404);
      state.faults = const FakeFaults();
      expect((await get('/live/test/test/999999.ts')).statusCode, 404);
    });

    test('slow_start_ms holds the answer back', () async {
      final watch = Stopwatch()..start();
      final response = await get('/live/test/test/999999.ts?slow_start_ms=300');
      expect(response.statusCode, 404);
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(300));
    });

    test('max_connections per request refuses before any work', () async {
      final response = await get('/live/test/test/1.ts?max_connections=0');
      expect(response.statusCode, HttpStatus.forbidden);
      expect(await response.readAsString(), contains(maxConnectionsBody));
    });

    test(
      'an expiring redirect: a token, then a 403 once it runs out',
      () async {
        final first = await get(
          '/live/test/test/1.ts?redirect_with_expiring_token=1',
        );
        expect(first.statusCode, HttpStatus.found);
        final location = Uri.parse(first.headers['location']!);
        expect(location.path, '/live/test/test/1.ts');
        expect(int.parse(location.queryParameters['token']!), greaterThan(0));

        final expired = await get(
          '/live/test/test/1.ts?redirect_with_expiring_token=1&token=1',
        );
        expect(expired.statusCode, HttpStatus.forbidden);
        expect(await expired.readAsString(), contains(tokenExpiredBody));
      },
    );

    test('drop_after_s ends the body and frees the slot', () async {
      final server = await shelf_io.serve(relay.handler, '127.0.0.1', 0);
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final response = await (await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}/live/test/test/1.ts?drop_after_s=1',
        ),
      )).close();
      final watch = Stopwatch()..start();
      var received = 0;
      await response
          .listen((chunk) => received += chunk.length, onError: (Object _) {})
          .asFuture<void>()
          .catchError((Object _) {})
          .timeout(const Duration(seconds: 10));
      expect(received, greaterThan(0));
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      await _until(() => state.activeStreams == 0, 'the slot to be freed');
    }, skip: mediaSkip);

    test('cut_after_s ends the body with no last chunk', () async {
      // Unlike drop_after_s, which ends the chunked body properly, a cut
      // leaves the response truncated: lavf reads that as a broken
      // connection and reconnects by itself (ADR-010 "The soak run").
      final server = await shelf_io.serve(relay.handler, '127.0.0.1', 0);
      addTearDown(() => server.close(force: true));
      final socket = await Socket.connect('127.0.0.1', server.port);
      addTearDown(socket.destroy);
      socket.write(
        'GET /live/test/test/1.ts?cut_after_s=1 HTTP/1.1\r\nHost: x\r\n'
        'Connection: close\r\n\r\n',
      );
      await socket.flush();
      final bytes = <int>[];
      await socket.forEach(bytes.addAll).timeout(const Duration(seconds: 20));
      final text = String.fromCharCodes(bytes.take(200));
      expect(text, contains('200 OK'));
      expect(text, contains('transfer-encoding: chunked'));
      expect(bytes.length, greaterThan(10000), reason: 'it played first');
      // The terminating chunk never arrives.
      expect(
        String.fromCharCodes(bytes.skip(bytes.length - 5)),
        isNot('0\r\n\r\n'),
      );
      await _until(() => state.activeStreams == 0, 'the slot to be freed');
    }, skip: mediaSkip);

    test('stall_after_s stops sending but keeps the connection open', () async {
      final server = await shelf_io.serve(relay.handler, '127.0.0.1', 0);
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final response = await (await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}/live/test/test/1.ts?stall_after_s=1',
        ),
      )).close();
      var received = 0;
      var done = false;
      final subscription = response.listen(
        (chunk) => received += chunk.length,
        onDone: () => done = true,
        onError: (Object _) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      final atStall = received;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(atStall, greaterThan(0));
      // Only null packets (one a second) after the stall: nothing playable.
      expect(received - atStall, lessThanOrEqualTo(3 * tsNullPacket.length));
      expect(done, isFalse, reason: 'still open');
      expect(state.activeStreams, 1);
      await subscription.cancel();
      client.close(force: true);
      await _until(() => state.activeStreams == 0, 'the slot to be freed');
    }, skip: mediaSkip);

    test(
      'codec_switch_after_s carries on with another codec in one body',
      () async {
        final server = await shelf_io.serve(relay.handler, '127.0.0.1', 0);
        addTearDown(() => server.close(force: true));
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final response = await (await client.getUrl(
          Uri.parse(
            'http://127.0.0.1:${server.port}/live/test/test/1.ts'
            '?codec_switch_after_s=1',
          ),
        )).close();
        var received = 0;
        final subscription = response.listen(
          (chunk) => received += chunk.length,
          onError: (Object _) {},
        );
        final pidsBefore = <String>{};
        await _until(() {
          pidsBefore.addAll(_pidFiles(runDir).map((f) => f.path));
          return pidsBefore.isNotEmpty;
        }, 'the first ffmpeg');
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        final atSwitch = received;
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        expect(received, greaterThan(atSwitch), reason: 'still flowing');
        final pidsAfter = _pidFiles(runDir).map((f) => f.path).toSet();
        expect(pidsAfter, hasLength(1));
        expect(pidsAfter.intersection(pidsBefore), isEmpty);
        expect(state.activeStreams, 1);
        await subscription.cancel();
        client.close(force: true);
        await _until(() => state.activeStreams == 0, 'the slot to be freed');
      },
      skip: mediaSkip,
    );
  });

  group('HLS', () {
    test('a playlist of segments served from /hls/, one slot, stopped once '
        'idle', () async {
      final idleRelay = StreamRelay(state, hlsIdle: const Duration(seconds: 2));
      addTearDown(idleRelay.close);
      final server = await shelf_io.serve(idleRelay.handler, '127.0.0.1', 0);
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      Future<(int, String)> fetch(String path) async {
        final response = await (await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}$path'),
        )).close();
        final chunks = await response.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        return (
          response.statusCode,
          response.headers.contentType?.mimeType == 'video/mp2t'
              ? '${chunks.length}'
              : String.fromCharCodes(chunks),
        );
      }

      final (status, playlist) = await fetch('/live/test/test/1.m3u8');
      expect(status, 200);
      expect(playlist, contains('#EXTM3U'));
      final segment = RegExp(
        r'^/hls/1/seg_\d+\.ts$',
        multiLine: true,
      ).firstMatch(playlist)!.group(0)!;
      final (segmentStatus, bytes) = await fetch(segment);
      expect(segmentStatus, 200);
      expect(int.parse(bytes), greaterThan(1000));
      expect(state.activeStreams, 1);

      // A second viewer of the same channel shares the session.
      await fetch('/live/test/test/1.m3u8');
      expect(state.activeStreams, 1);

      await _until(
        () => state.activeStreams == 0,
        'the idle session to stop',
        timeout: const Duration(seconds: 10),
      );
      expect(Directory('${runDir.path}/hls/1').existsSync(), isFalse);
    }, skip: mediaSkip);
  });
}

List<File> _pidFiles(Directory runDir) {
  final dir = Directory('${runDir.path}/pids');
  if (!dir.existsSync()) return [];
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pid'))
      .toList();
}

/// Closes [socket] with a reset rather than a FIN, as a player killing an
/// attempt does: SO_LINGER (13 on Linux) on, with a 0 s timeout.
void _reset(Socket socket) {
  socket
    ..setRawOption(
      RawSocketOption(
        RawSocketOption.levelSocket,
        13,
        Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0]),
      ),
    )
    ..destroy();
}

bool _isAlive(int pid) =>
    Platform.isLinux && File('/proc/$pid/cmdline').existsSync();

Future<void> _until(
  bool Function() done,
  String what, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('timed out waiting for $what');
}
