import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/streams.dart' show maxConnectionsBody;
import 'package:fake_provider/vod.dart';
import 'package:test/test.dart';

/// The VOD relay parses nothing, so the samples here are stand-ins: bytes
/// that encode their own offset, so any slice can be checked on its own.
const int sampleSize = 300 * 1024;

Uint8List sampleBytes() =>
    Uint8List.fromList(List<int>.generate(sampleSize, (i) => (i * 7) % 251));

/// Movie ids start at [movieIdBase]; the samples cycle through
/// [vodSamples], so movie 0 is the MP4 and movies 1 and 2 are MKVs.
const movieMp4 = '/movie/test/test/100000.mp4';
const movieMkv = '/movie/test/test/100001.mkv';

void main() {
  late Directory samples;
  late FakeProviderServer server;
  late HttpClient client;
  final expected = sampleBytes();

  Future<void> start({int maxConnections = 2}) async {
    samples = Directory.systemTemp.createTempSync('fake_provider_vod_');
    for (final name in vodSamples) {
      File('${samples.path}/$name').writeAsBytesSync(expected);
    }
    server = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!.copyWith(
          maxConnections: maxConnections,
        ),
        samplesDir: samples.path,
        ffmpegPath: 'ffmpeg',
        runDir: samples.path,
      ),
      port: 0,
    );
    client = HttpClient();
  }

  tearDown(() async {
    client.close(force: true);
    await server.close();
    samples.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> send(
    String path, {
    String method = 'GET',
    Map<String, String> headers = const {},
  }) async {
    final request = await client.openUrl(method, server.url.resolve(path));
    headers.forEach(request.headers.set);
    return await request.close();
  }

  Future<List<int>> body(HttpClientResponse response) async {
    final out = BytesBuilder(copy: false);
    await response.forEach(out.add);
    return out.takeBytes();
  }

  /// Waits for the relay to notice a closed connection.
  Future<void> settled(int streams) async {
    for (var i = 0; i < 100 && server.state.activeStreams != streams; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(server.state.activeStreams, streams);
  }

  group('whole files and ranges', () {
    setUp(start);

    test('a GET is the whole file with its validators', () async {
      final response = await send(movieMp4);
      expect(response.statusCode, HttpStatus.ok);
      expect(response.contentLength, sampleSize);
      expect(response.headers.value('accept-ranges'), 'bytes');
      expect(response.headers.value('content-type'), 'video/mp4');
      expect(
        response.headers.value('etag'),
        matches(r'^"[0-9a-f]+-[0-9a-f]+"$'),
      );
      expect(
        () => HttpDate.parse(response.headers.value('last-modified')!),
        returnsNormally,
      );
      expect(await body(response), expected);
      await settled(0);
    });

    test('byte ranges: closed, open, suffix, and past the end', () async {
      final cases = {
        'bytes=100-199': (100, 199),
        'bytes=1000-': (1000, sampleSize - 1),
        'bytes=-500': (sampleSize - 500, sampleSize - 1),
        'bytes=100-99999999': (100, sampleSize - 1),
        'bytes=0-0': (0, 0),
      };
      for (final MapEntry(key: range, value: (from, to)) in cases.entries) {
        final response = await send(movieMkv, headers: {'range': range});
        expect(response.statusCode, HttpStatus.partialContent, reason: range);
        expect(
          response.headers.value('content-range'),
          'bytes $from-$to/$sampleSize',
          reason: range,
        );
        expect(response.contentLength, to - from + 1, reason: range);
        expect(response.headers.value('content-type'), 'video/x-matroska');
        expect(await body(response), expected.sublist(from, to + 1));
      }
    });

    test('a range past the end is a 416 naming the size', () async {
      for (final range in ['bytes=$sampleSize-', 'bytes=-0']) {
        final response = await send(movieMp4, headers: {'range': range});
        expect(response.statusCode, 416, reason: range);
        expect(response.headers.value('content-range'), 'bytes */$sampleSize');
        await body(response);
      }
    });

    test('a range this server does not take is ignored: 200', () async {
      for (final range in ['bytes=0-1,5-6', 'items=0-5', 'bytes=9-3']) {
        final response = await send(movieMp4, headers: {'range': range});
        expect(response.statusCode, HttpStatus.ok, reason: range);
        expect(await body(response), hasLength(sampleSize));
      }
    });

    test('If-Range: the same file keeps the range, another does not', () async {
      final first = await send(movieMp4);
      final etag = first.headers.value('etag')!;
      final modified = first.headers.value('last-modified')!;
      await body(first);

      for (final validator in [etag, modified]) {
        final same = await send(
          movieMp4,
          headers: {'range': 'bytes=10-19', 'if-range': validator},
        );
        expect(same.statusCode, HttpStatus.partialContent, reason: validator);
        await body(same);
      }
      final changed = await send(
        movieMp4,
        headers: {'range': 'bytes=10-19', 'if-range': '"another"'},
      );
      expect(changed.statusCode, HttpStatus.ok);
      expect(await body(changed), hasLength(sampleSize));
    });

    test('HEAD answers the headers only, and holds no connection', () async {
      final response = await send(movieMp4, method: 'HEAD');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('content-length'), '$sampleSize');
      expect(response.headers.value('accept-ranges'), 'bytes');
      expect(await body(response), isEmpty);

      final ranged = await send(
        movieMp4,
        method: 'HEAD',
        headers: {'range': 'bytes=0-9'},
      );
      expect(ranged.statusCode, HttpStatus.partialContent);
      expect(ranged.headers.value('content-length'), '10');
      await body(ranged);
      expect(server.state.activeStreams, 0);
    });

    test('an episode is served from /series/', () async {
      final catalog = server.state.catalog;
      final episode = catalog
          .episodesOf(catalog.seriesById(seriesIdBase)!)
          .values
          .first
          .first;
      final response = await send(
        '/series/test/test/${episode.id}.${episode.containerExtension}',
        headers: {'range': 'bytes=0-99'},
      );
      expect(response.statusCode, HttpStatus.partialContent);
      expect(await body(response), expected.sublist(0, 100));
    });
  });

  group('refusals', () {
    setUp(start);

    Future<int> status(String path) async {
      final response = await send(path);
      await body(response);
      return response.statusCode;
    }

    test('bad credentials are 401', () async {
      expect(await status('/movie/test/wrong/100000.mp4'), 401);
    });

    test('an unknown id, a wrong extension or kind is a 404', () async {
      expect(await status('/movie/test/test/99.mp4'), 404);
      expect(await status('/movie/test/test/abc.mp4'), 404);
      expect(await status('/movie/test/test/100000.mkv'), 404);
      expect(await status('/series/test/test/100000.mp4'), 404);
      expect(await status('/movie/test/test/300101.mkv'), 404);
      expect(server.state.activeStreams, 0);
    });

    test('a missing sample says which file', () async {
      File('${samples.path}/${vodSamples.first}').deleteSync();
      final response = await send(movieMp4);
      expect(response.statusCode, 404);
      expect(
        await response.transform(utf8.decoder).join(),
        contains('missing sample'),
      );
    });
  });

  group('faults', () {
    setUp(start);

    test('http_status answers that status', () async {
      final response = await send('$movieMp4?http_status=404');
      expect(response.statusCode, 404);
      await body(response);
      final full = await send('$movieMp4?http_status=429');
      expect(full.statusCode, 429);
      expect(full.headers.value('retry-after'), '1');
      await body(full);
    });

    test('ignore_range sends the whole file for any range', () async {
      final response = await send(
        '$movieMp4?ignore_range=1',
        headers: {'range': 'bytes=1000-1999'},
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('accept-ranges'), isNull);
      expect(await body(response), expected);
    });

    test('drop_after_bytes closes the connection at that byte, once', () async {
      const dropAt = 100 * 1024;
      final response = await send('$movieMp4?drop_after_bytes=$dropAt');
      expect(response.contentLength, sampleSize);
      final got = BytesBuilder(copy: false);
      Object? error;
      try {
        await response.forEach(got.add);
      } on HttpException catch (e) {
        error = e;
      }
      expect(error, isNotNull, reason: 'the body ends short of its length');
      expect(got.takeBytes(), expected.sublist(0, dropAt));
      await settled(0);

      // A player reconnecting from where it was gets the rest.
      final resumed = await send(
        '$movieMp4?drop_after_bytes=$dropAt',
        headers: {'range': 'bytes=$dropAt-'},
      );
      expect(resumed.statusCode, HttpStatus.partialContent);
      expect(await body(resumed), expected.sublist(dropAt));
    });

    test('change_etag: new validators every time, so If-Range never '
        'matches and a resume gets the whole file', () async {
      final first = await send('$movieMp4?change_etag=1');
      final etag = first.headers.value('etag')!;
      final modified = first.headers.value('last-modified')!;
      await body(first);

      for (final validator in [etag, modified]) {
        final again = await send(
          '$movieMp4?change_etag=1',
          headers: {'range': 'bytes=$sampleSize-', 'if-range': validator},
        );
        // Past the end, but If-Range failing first means the whole file.
        expect(again.statusCode, HttpStatus.ok, reason: validator);
        expect(again.headers.value('etag'), isNot(etag));
        expect(again.headers.value('last-modified'), isNot(modified));
        expect(await body(again), expected);
      }
    });

    test('wrong_content_length says more than the body holds', () async {
      final response = await send('$movieMp4?wrong_content_length=1');
      expect(response.contentLength, sampleSize + 4096);
      final got = BytesBuilder(copy: false);
      Object? error;
      try {
        await response.forEach(got.add);
      } on HttpException catch (e) {
        error = e;
      }
      expect(error, isNotNull, reason: 'the body ends short of its length');
      expect(got.takeBytes(), expected);

      final ranged = await send(
        '$movieMp4?wrong_content_length=1',
        headers: {'range': 'bytes=0-99'},
      );
      expect(ranged.contentLength, 100 + 4096);
      await ranged.drain<void>().catchError((Object _) {});
      await settled(0);
    });

    test('size_mb pads the file with filler, in every range', () async {
      const size = 2 * 1024 * 1024;
      final head = await send('$movieMp4?size_mb=2', method: 'HEAD');
      expect(head.contentLength, size);
      final etag = head.headers.value('etag')!;
      await body(head);

      final whole = await send('$movieMp4?size_mb=2');
      expect(whole.headers.value('etag'), etag);
      final bytes = await body(whole);
      expect(bytes, hasLength(size));
      expect(bytes.sublist(0, sampleSize), expected);
      for (final at in [sampleSize, sampleSize + 70000, size - 1]) {
        expect(bytes[at], fakePaddingByte(at), reason: '$at');
      }

      // A range across the sample's end, and one in the padding alone.
      final across = await send(
        '$movieMp4?size_mb=2',
        headers: {'range': 'bytes=${sampleSize - 10}-${sampleSize + 9}'},
      );
      expect(across.statusCode, HttpStatus.partialContent);
      expect(await body(across), [
        ...expected.sublist(sampleSize - 10),
        for (var at = sampleSize; at < sampleSize + 10; at++)
          fakePaddingByte(at),
      ]);
      final tail = await send(
        '$movieMp4?size_mb=2',
        headers: {'range': 'bytes=-5'},
      );
      expect(await body(tail), [
        for (var at = size - 5; at < size; at++) fakePaddingByte(at),
      ]);

      // Smaller than the sample: the sample as it is.
      final small = await send('$movieMp4?size_mb=0', method: 'HEAD');
      expect(small.contentLength, sampleSize);
      await body(small);
    });

    test('throttle_kbps paces the body', () async {
      // 256 kbit/s = 32 KB/s: 48 KB takes about 1.5 s.
      final clock = Stopwatch()..start();
      final response = await send(
        '$movieMp4?throttle_kbps=256',
        headers: {'range': 'bytes=0-${48 * 1024 - 1}'},
      );
      expect(await body(response), hasLength(48 * 1024));
      expect(clock.elapsed, greaterThan(const Duration(milliseconds: 1300)));
    });
  });

  group(
    'vod_as_hls',
    () {
      setUp(() async {
        await start();
        // A real clip under the MP4's name: ffmpeg cuts it into segments.
        final made = await Process.run('ffmpeg', [
          ...['-hide_banner', '-loglevel', 'error', '-y'],
          ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=9'],
          ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=9'],
          ...['-c:v', 'libx264', '-g', '50', '-c:a', 'aac', '-shortest'],
          '${samples.path}/${vodSamples.first}',
        ]);
        expect(made.exitCode, 0, reason: '${made.stderr}');
      });

      test('a movie answers a VOD playlist whose segments ffprobe reads end to '
          'end', () async {
        final response = await send('$movieMp4?vod_as_hls=1');
        expect(response.statusCode, HttpStatus.ok);
        expect(
          response.headers.contentType?.mimeType,
          'application/vnd.apple.mpegurl',
        );
        final playlist = utf8.decode(await body(response));
        expect(playlist, startsWith('#EXTM3U'));
        expect(playlist, contains('#EXT-X-PLAYLIST-TYPE:VOD'));
        expect(playlist, contains('#EXT-X-ENDLIST'));
        final segments = [
          for (final line in const LineSplitter().convert(playlist))
            if (line.startsWith('/vodhls/')) line,
        ];
        expect(segments.length, greaterThanOrEqualTo(2));

        for (final segment in segments) {
          final got = await send(segment);
          expect(got.statusCode, HttpStatus.ok, reason: segment);
          expect(got.headers.contentType?.mimeType, 'video/mp2t');
          expect(await body(got), isNotEmpty);
        }
        await settled(0);

        final probe = await Process.run('ffprobe', [
          ...['-v', 'error', '-show_entries', 'format=duration'],
          ...['-of', 'default=nw=1:nk=1'],
          server.url.resolve('$movieMp4?vod_as_hls=1').toString(),
        ]);
        expect(probe.exitCode, 0, reason: '${probe.stderr}');
        expect(double.parse('${probe.stdout}'.trim()), closeTo(9, 0.5));
      });

      test('a segment holds a connection slot: none free, none sent', () async {
        final playlist = utf8.decode(
          await body(await send('$movieMp4?vod_as_hls=1')),
        );
        final first = const LineSplitter()
            .convert(playlist)
            .firstWhere((line) => line.startsWith('/vodhls/'));
        final refused = await send('$first?max_connections=0');
        expect(refused.statusCode, HttpStatus.forbidden);
        expect(utf8.decode(await body(refused)), contains(maxConnectionsBody));
        expect((await send('/vodhls/nothing/seg_00000.ts')).statusCode, 404);
        expect(
          (await send('${first.substring(0, first.lastIndexOf('/'))}/x.ts'))
              .statusCode,
          404,
        );
      });
    },
    skip: _hasTool('ffmpeg') && _hasTool('ffprobe')
        ? false
        : 'needs ffmpeg and ffprobe on PATH',
  );

  group('connections', () {
    /// A body that stays open: 16 kbit/s makes the 300 KB file last minutes.
    Future<(HttpClientResponse, StreamSubscription<List<int>>, Future<void>)>
    hold(String path, {Map<String, String> headers = const {}}) async {
      final response = await send('$path?throttle_kbps=16', headers: headers);
      final ended = Completer<void>();
      // The caller cancels it: the body is what the test holds open.
      // ignore: cancel_subscriptions
      final subscription = response.listen(
        (_) {},
        onError: (Object _) {
          if (!ended.isCompleted) ended.complete();
        },
        onDone: () {
          if (!ended.isCompleted) ended.complete();
        },
        cancelOnError: true,
      );
      return (response, subscription, ended.future);
    }

    test('an open body counts, and leaving frees it', () async {
      await start(maxConnections: 1);
      final (response, subscription, _) = await hold(movieMp4);
      expect(response.statusCode, HttpStatus.ok);
      await settled(1);

      final other = await send(movieMkv);
      expect(other.statusCode, HttpStatus.forbidden);
      expect(await other.transform(utf8.decoder).join(), contains('MAX_CONN'));

      await subscription.cancel();
      await settled(0);
    });

    test('a new request for the same file takes over the open one', () async {
      await start(maxConnections: 1);
      final (_, subscription, ended) = await hold(movieMp4);
      await settled(1);

      // What a player's seek looks like on a one-connection panel.
      final seek = await send(movieMp4, headers: {'range': 'bytes=200000-'});
      expect(seek.statusCode, HttpStatus.partialContent);
      await ended.timeout(const Duration(seconds: 5));
      expect(await body(seek), expected.sublist(200000));
      await subscription.cancel();
      await settled(0);
    });

    test('closing the server frees every slot', () async {
      await start();
      final (_, first, _) = await hold(movieMp4);
      final (_, second, _) = await hold(movieMkv);
      await settled(2);
      await server.close();
      expect(server.state.activeStreams, 0);
      await first.cancel();
      await second.cancel();
    });
  });
}

bool _hasTool(String name) {
  try {
    return Process.runSync(name, ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}
