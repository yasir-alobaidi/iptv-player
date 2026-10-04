import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:path/path.dart' as p;

void main() {
  test('a picture on this computer is read from disk, decoded at the size '
      "drawn; a file: URL that isn't one of ours is no picture", () {
    final path = p.join('films', 'Paper Kites (2019)', 'poster.jpg');
    final url = localArtworkUrl(path);
    expect(url, startsWith('file://'));
    final image = const NetworkArtworkImages().image(
      url,
      width: 100,
      devicePixelRatio: 2,
    );
    expect(image, isA<ResizeImage>());
    final file = (image! as ResizeImage).imageProvider as FileImage;
    expect(file.file.path, p.absolute(path));
    expect((image as ResizeImage).width, 200);
    expect(fileArtwork('https://img.test/a.jpg', 100, 1), isNull);
  });

  test('only http(s) URLs with a host are pictures', () {
    expect(isArtworkUrl('https://img.test/a.jpg'), isTrue);
    expect(isArtworkUrl('http://127.0.0.1:8899/art/movie/1.jpg'), isTrue);
    for (final junk in [
      null,
      '',
      'n/a',
      'null',
      'htp:/broken.logo',
      '/images/404/missing.png',
      'about:blank',
      'file:///home/me/a.png',
      'http://',
    ]) {
      expect(isArtworkUrl(junk), isFalse, reason: '$junk');
    }
  });

  test('a picture is decoded at the width drawn times the density', () {
    const images = NetworkArtworkImages();
    final image = images.image(
      'https://img.test/poster.jpg',
      width: 170,
      devicePixelRatio: 1.5,
    );
    expect(image, isA<ResizeImage>());
    expect((image! as ResizeImage).width, 255);
    expect(images.image('n/a'), isNull);
    // No width: the file's own size.
    expect(images.image('https://img.test/a.jpg'), isA<NetworkImage>());
  });

  test("Flutter's decoded pictures are capped at docs/06's 150 MB", () {
    final cache = ImageCache();
    capDecodedImages(cache);
    expect(cache.maximumSizeBytes, 150 * 1024 * 1024);
  });

  testWidgets('the scope hands its images down; without one, plain network '
      'images', (tester) async {
    late ArtworkImages found;
    late ArtworkImages outside;
    final images = _Recording();
    await tester.pumpWidget(
      Column(
        children: [
          Builder(
            builder: (context) {
              outside = ArtworkScope.of(context);
              return const SizedBox();
            },
          ),
          ArtworkScope(
            images: images,
            child: Builder(
              builder: (context) {
                found = ArtworkScope.of(context);
                artworkFor(context, 'https://img.test/a.png', width: 40);
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
    expect(found, same(images));
    expect(outside, isA<NetworkArtworkImages>());
    expect(images.asked, [('https://img.test/a.png', 40.0)]);
  });
}

final class _Recording implements ArtworkImages {
  final asked = <(String?, double?)>[];

  @override
  ImageProvider? image(
    String? url, {
    double? width,
    double devicePixelRatio = 1,
  }) {
    asked.add((url, width));
    return MemoryImage(Uint8List(0));
  }
}
