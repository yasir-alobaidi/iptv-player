import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
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
