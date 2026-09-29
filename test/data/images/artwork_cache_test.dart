import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';

/// Eight bytes of PNG signature and a little more: enough for the cache,
/// which checks what a file starts with and decodes nothing.
final png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ...List.filled(64, 7),
]);

/// A scripted server: `/ok/<name>` a picture, `/missing` 404, `/page` a
/// web page with 200, `/huge` 11 MB, `/held/<name>` a picture once
/// [release] completes. It counts what it was asked.
final class _Server {
  new _(this._server) {
    _server.listen(_answer);
  }

  static Future<_Server> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final wrapper = _Server._(server);
    addTearDown(() => server.close(force: true));
    return wrapper;
  }

  final HttpServer _server;
  final hits = <String>[];
  Completer<void> release = Completer<void>();
  int holding = 0;
  int mostHeld = 0;

  String url(String path) => 'http://127.0.0.1:${_server.port}$path';

  Future<void> _answer(HttpRequest request) async {
    final path = request.uri.path;
    hits.add(path);
    final response = request.response;
    if (path.startsWith('/ok/')) {
      response.add(png);
    } else if (path.startsWith('/held/')) {
      holding++;
      if (holding > mostHeld) mostHeld = holding;
      await release.future;
      holding--;
      response.add(png);
    } else if (path == '/page') {
      response
        ..headers.contentType = ContentType.html
        ..write('<html>Not found</html>');
    } else if (path == '/huge') {
      response.add(Uint8List(11 * 1024 * 1024)..setAll(0, png));
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }
}

void main() {
  late Directory directory;
  late DateTime now;

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('artwork_cache');
    addTearDown(() => directory.delete(recursive: true));
    now = DateTime.utc(2026, 9, 28, 9);
  });

  ArtworkCache cache({int concurrency = 6, int maxWaiting = 96}) {
    final made = ArtworkCache(
      directory: directory,
      concurrency: concurrency,
      maxWaiting: maxWaiting,
      clock: () => now,
    );
    addTearDown(made.close);
    return made;
  }

  test('fetched once, kept on disk, read from there after', () async {
    final server = await _Server.start();
    final url = server.url('/ok/poster.jpg');
    final first = cache();

    expect(await first.bytes(url), png);
    expect(first.fileFor(url).existsSync(), isTrue);

    // A new cache over the same folder: the next launch.
    expect(await cache().bytes(url), png);
    expect(server.hits, ['/ok/poster.jpg']);
  });

  test('two asks at once share one request', () async {
    final server = await _Server.start();
    final url = server.url('/ok/a.jpg');
    final artwork = cache();

    final both = await Future.wait([artwork.bytes(url), artwork.bytes(url)]);

    expect(both, [png, png]);
    expect(server.hits, hasLength(1));
  });

  test('a 404, a web page, or a file too big is no picture, and is not '
      'asked for again for ten minutes', () async {
    final server = await _Server.start();
    final artwork = cache();

    for (final path in ['/missing', '/page', '/huge']) {
      await expectLater(
        artwork.bytes(server.url(path)),
        throwsA(isA<ArtworkUnavailable>()),
        reason: path,
      );
      expect(artwork.fileFor(server.url(path)).existsSync(), isFalse);
    }
    expect(server.hits, hasLength(3));

    await expectLater(
      artwork.bytes(server.url('/missing')),
      throwsA(isA<ArtworkUnavailable>()),
    );
    expect(server.hits, hasLength(3), reason: 'failed a moment ago');

    now = now.add(const Duration(minutes: 11));
    await expectLater(
      artwork.bytes(server.url('/missing')),
      throwsA(isA<ArtworkUnavailable>()),
    );
    expect(server.hits, hasLength(4));
  });

  test('a failure never names the URL (hard rule 3)', () async {
    final artwork = cache();
    const url = 'http://127.0.0.1:1/images/u/s3cret/poster.jpg?token=abc';

    Object? error;
    try {
      await artwork.bytes(url);
    } on Object catch (e) {
      error = e;
    }

    expect(error, isA<ArtworkUnavailable>());
    expect('$error', isNot(contains('s3cret')));
    expect('$error', isNot(contains('token')));
  });

  test('at most [concurrency] at once, the newest first, the oldest '
      'waiting dropped', () async {
    final server = await _Server.start();
    final artwork = cache(concurrency: 2, maxWaiting: 2);

    final results = <String, Future<Object?>>{};
    for (final name in ['a', 'b', 'c', 'd', 'e']) {
      results[name] = artwork
          .bytes(server.url('/held/$name'))
          .then<Object?>((bytes) => bytes, onError: (Object e) => e);
      await pumpEventQueue();
    }
    // a and b started; c, d and e waited, and c, the oldest, went when e
    // came.
    expect(await results['c'], isA<ArtworkUnavailable>());
    server.release.complete();
    for (final name in ['a', 'b', 'd', 'e']) {
      expect(await results[name], png, reason: name);
    }
    expect(server.mostHeld, 2);
    // e, the newest, before d.
    expect(server.hits, ['/held/a', '/held/b', '/held/e', '/held/d']);
  });

  test('forget drops the file, and the next ask fetches it again', () async {
    final server = await _Server.start();
    final url = server.url('/ok/damaged.jpg');
    final artwork = cache();
    await artwork.bytes(url);

    await artwork.forget(url);
    await artwork.bytes(url);

    expect(server.hits, hasLength(2));
  });

  test('a file name is 32 hex digits, the same every time', () {
    final name = artworkName('http://img.test/a.jpg');
    expect(name, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(artworkName('http://img.test/a.jpg'), name);
    expect(artworkName('http://img.test/b.jpg'), isNot(name));
  });

  test('what a picture starts with', () {
    Uint8List bytes(List<int> head) => Uint8List.fromList([...head, 0, 0]);
    expect(looksLikeImage(bytes([0xFF, 0xD8, 0xFF])), isTrue);
    expect(looksLikeImage(png), isTrue);
    expect(looksLikeImage(bytes('GIF89a'.codeUnits)), isTrue);
    expect(
      looksLikeImage(
        bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
      ),
      isTrue,
    );
    expect(looksLikeImage(bytes('<html>'.codeUnits)), isFalse);
    expect(looksLikeImage(Uint8List(0)), isFalse);
  });

  group('the sweep', () {
    File file(String name, int size, DateTime used) =>
        File('${directory.path}/$name')
          ..writeAsBytesSync(Uint8List(size))
          ..setLastModifiedSync(used);

    test('least recently used first, down to 90 % of the cap', () {
      final t = DateTime.utc(2026, 9);
      final oldest = file('a', 400, t);
      final old = file('b', 400, t.add(const Duration(days: 1)));
      final recent = file('c', 400, t.add(const Duration(days: 2)));
      final newest = file('d', 400, t.add(const Duration(days: 3)));

      final swept = sweepArtwork(
        directory.path,
        1000,
        t.add(const Duration(days: 4)).millisecondsSinceEpoch,
      );

      expect(swept, (removed: 2, bytes: 800));
      expect(oldest.existsSync(), isFalse);
      expect(old.existsSync(), isFalse);
      expect(recent.existsSync(), isTrue);
      expect(newest.existsSync(), isTrue);
    });

    test('under the cap it deletes nothing; a .part being written stays, '
        'one a killed download left goes', () {
      final t = DateTime.utc(2026, 9, 1, 12);
      final kept = file('a', 100, t);
      final writing = file('b.part', 100, t);
      final leftOver = file(
        'c.part',
        100,
        t.subtract(const Duration(hours: 1)),
      );

      final swept = sweepArtwork(
        directory.path,
        1000,
        t.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      );

      expect(swept.removed, 1);
      // What is left, the .part being written not counted.
      expect(swept.bytes, 100);
      expect(kept.existsSync(), isTrue);
      expect(writing.existsSync(), isTrue);
      expect(leftOver.existsSync(), isFalse);
    });

    test('once a sweep knows the folder, the cache sweeps as soon as its '
        'writes pass the cap', () async {
      final server = await _Server.start();
      final t = DateTime.utc(2026, 9);
      // 900 bytes used of a 1,000-byte cap.
      file('old', 900, t);
      final artwork = ArtworkCache(
        directory: directory,
        maxBytes: 1000,
        // Never reached here: the cap is what starts the sweep.
        sweepAfterWriting: 1 << 30,
        clock: () => t.add(const Duration(days: 1)),
      );
      addTearDown(artwork.close);
      expect(await artwork.sweep(), 0);

      // Two pictures of 72 bytes: 1,044 bytes, past the cap.
      await artwork.bytes(server.url('/ok/a'));
      await artwork.bytes(server.url('/ok/b'));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (File('${directory.path}/old').existsSync() &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(File('${directory.path}/old').existsSync(), isFalse);
      expect(artwork.fileFor(server.url('/ok/b')).existsSync(), isTrue);
    });

    test('runs in an isolate from the cache, one at a time', () async {
      final t = DateTime.utc(2026, 9);
      file('a', 600 * 1024 * 1024 ~/ 1024, t);
      final artwork = ArtworkCache(
        directory: directory,
        maxBytes: 1024,
        clock: () => t,
      );
      addTearDown(artwork.close);

      final first = artwork.sweep();
      expect(identical(artwork.sweep(), first), isTrue);
      expect(await first, 1);
    });
  });
}
