import 'dart:async';
import 'dart:io';

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

    test('an extension other than .ts is 501', () async {
      final response = await get('/live/test/test/1.m3u8');
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

    test('reuses the cached remux and never remuxes twice at once', () async {
      // Two concurrent requests for the same sample (default profile allows
      // two connections): one remux, one cached MKV, no .part left behind.
      final responses = await Future.wait([
        get('/live/test/test/1.ts'),
        get('/live/test/test/1.ts'),
      ]);
      expect(responses.map((r) => r.statusCode), everyElement(HttpStatus.ok));
      expect(state.activeStreams, 2);

      final cache = Directory('${runDir.path}/loop_cache');
      final cached = cache.listSync().whereType<File>().toList();
      expect(cached, hasLength(1));
      expect(cached.single.path, endsWith('.mkv'));
      final stamp = cached.single.lastModifiedSync();

      await relay.close();
      expect(state.activeStreams, 0);
      expect(_pidFiles(runDir), isEmpty);

      final again = await get('/live/test/test/1.ts');
      expect(again.statusCode, HttpStatus.ok);
      expect(cached.single.lastModifiedSync(), stamp);
    });

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

bool _isAlive(int pid) =>
    Platform.isLinux && File('/proc/$pid/cmdline').existsSync();

Future<void> _until(bool Function() done, String what) async {
  for (var i = 0; i < 100; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('timed out waiting for $what');
}
