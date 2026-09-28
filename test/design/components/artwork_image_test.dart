import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';
import 'package:iptv_player/data/images/cached_artwork.dart';
import 'package:iptv_player/design/components.dart';

import '../design_harness.dart';

/// A 1 × 1 PNG.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  const fallback = ColoredBox(color: Color(0xFF123456), child: Text('AS'));

  testWidgets('no picture: the stand-in', (tester) async {
    await pumpDesign(
      tester,
      const SizedBox.square(
        dimension: 40,
        child: ArtworkImage(image: null, fallback: fallback),
      ),
    );
    expect(find.text('AS'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a picture that fails: the stand-in stays, and nothing is '
      'reported', (tester) async {
    await pumpDesign(
      tester,
      SizedBox.square(
        dimension: 40,
        child: ArtworkImage(
          image: MemoryImage(Uint8List.fromList([1, 2, 3])),
          fallback: fallback,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('AS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a picture fades in over the stand-in, which fades out', (
    tester,
  ) async {
    final image = MemoryImage(_pixel);
    await pumpDesign(
      tester,
      SizedBox.square(
        dimension: 40,
        child: ArtworkImage(image: image, fallback: fallback),
      ),
    );
    await tester.runAsync(
      () => precacheImage(image, tester.element(find.byType(ArtworkImage))),
    );
    await tester.pumpAndSettle();

    final opacities = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .map((o) => o.opacity)
        .toList();
    // The picture came after the first build: the stand-in faded out, the
    // picture in.
    expect(opacities, [0.0, 1.0]);
  });

  testWidgets('a damaged cached file is dropped, so the next ask fetches it '
      'again', (tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('artwork_damaged'),
    );
    addTearDown(() => directory!.deleteSync(recursive: true));
    final cache = ArtworkCache(directory: directory!);
    addTearDown(cache.close);
    const url = 'http://127.0.0.1:1/poster.jpg';
    // Starts like a JPEG, decodes as nothing.
    cache.fileFor(url).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0, 1, 2, 3]);

    Object? failure;
    await tester.runAsync(() async {
      final stream = CachedArtwork(
        url,
        cache,
      ).resolve(ImageConfiguration.empty);
      final done = Completer<void>();
      stream.addListener(
        ImageStreamListener(
          (_, _) => done.complete(),
          onError: (error, _) {
            failure = error;
            done.complete();
          },
        ),
      );
      await done.future;
    });

    expect(failure, isA<ArtworkUnavailable>());
    expect(cache.fileFor(url).existsSync(), isFalse);
  });
}
