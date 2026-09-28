import 'dart:io';
import 'dart:typed_data';

import 'package:fake_provider/artwork.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

FakeServerState stateOf(FakeProfile profile) => FakeServerState(
  profile: profile,
  samplesDir: '.',
  ffmpegPath: 'ffmpeg',
  runDir: '.',
);

Future<Uint8List> bytesOf(Response response) async {
  final builder = BytesBuilder(copy: false);
  await response.read().forEach(builder.add);
  return builder.takeBytes();
}

/// Width and height from a PNG's IHDR, which follows the 8-byte signature
/// and the chunk's length and type.
(int, int) pngSize(Uint8List png) {
  final data = ByteData.sublistView(png);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  final state = stateOf(fakeProfiles['default']!);
  final handler = artworkHandler(state);

  Future<Response> get(String path, {Map<String, String>? headers}) =>
      Future.value(
        handler(Request('GET', Uri.parse('http://x$path'), headers: headers)),
      );

  test('each kind is a PNG at the size real panels serve', () async {
    final cases = {
      '/art/live/1.png': ArtworkKind.live,
      '/art/movie/100000.jpg': ArtworkKind.movie,
      '/art/series/200000.jpg': ArtworkKind.series,
      '/art/episode/300101.jpg': ArtworkKind.episode,
      '/art/backdrop/movie/100000.jpg': ArtworkKind.backdrop,
      '/art/backdrop/series/200000.jpg': ArtworkKind.backdrop,
    };
    for (final MapEntry(key: path, value: kind) in cases.entries) {
      final response = await get(path);
      expect(response.statusCode, HttpStatus.ok, reason: path);
      expect(response.headers['content-type'], 'image/png');
      expect(response.headers['cache-control'], contains('max-age'));
      final png = await bytesOf(response);
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(pngSize(png), (kind.width, kind.height), reason: path);
      // Grain keeps them near a real poster's weight instead of a few KB.
      expect(png.length, greaterThan(kind.width * kind.height ~/ 20));
    }
  });

  test('the same item always gets the same picture, and an ETag', () async {
    final first = await get('/art/movie/100001.jpg');
    final again = await get('/art/movie/100001.jpg');
    expect(await bytesOf(again), await bytesOf(first));
    final tag = first.headers['etag']!;

    final cached = await get(
      '/art/movie/100001.jpg',
      headers: {'if-none-match': tag},
    );
    expect(cached.statusCode, HttpStatus.notModified);

    final other = await get('/art/movie/100002.jpg');
    expect(other.headers['etag'], isNot(tag));
  });

  test('an id the catalogue lacks, or an unknown kind, is a 404', () async {
    for (final path in [
      '/art/movie/99.jpg',
      '/art/movie/abc.jpg',
      '/art/live/100000.png',
      '/art/series/999999.jpg',
      '/art/episode/300000.jpg',
      '/art/poster/100000.jpg',
      '/art/backdrop/live/1.jpg',
    ]) {
      expect((await get(path)).statusCode, HttpStatus.notFound, reason: path);
    }
  });

  test('every artwork URL the generator hands out resolves here', () async {
    const origin = 'http://x';
    final catalog = state.catalog;
    final urls = <String>[
      for (final channel in catalog.channels().take(30))
        ?artworkFor(channel.icon, origin),
      for (final movie in catalog.movies().take(30)) ...[
        ?artworkFor(movie.icon, origin),
        ?artworkFor(movie.backdrop, origin),
      ],
      for (final series in catalog.series().take(10)) ...[
        ?artworkFor(series.cover, origin),
        ?artworkFor(series.backdrop, origin),
        for (final episode in catalog.episodesOf(series).values.first)
          ?artworkFor(episode.still, origin),
      ],
    ];
    expect(urls.length, greaterThan(100));
    for (final url in urls) {
      expect(url, startsWith('$origin/art/'));
      final response = await get(url.substring(origin.length));
      expect(response.statusCode, HttpStatus.ok, reason: url);
    }
  });

  test('artworkFor rewrites only our own artwork', () {
    expect(
      artworkFor('$artworkRoot/movie/1.jpg', 'http://h:1'),
      'http://h:1/art/movie/1.jpg',
    );
    expect(artworkFor('n/a', 'http://h:1'), 'n/a');
    expect(
      artworkFor('https://images.northwind.invalid/404.png', 'http://h:1'),
      'https://images.northwind.invalid/404.png',
    );
    expect(artworkFor(null, 'http://h:1'), isNull);
  });
}
