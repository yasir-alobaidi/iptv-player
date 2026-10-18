import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/player_mediakit/desktop_picture.dart';

void main() {
  group('High quality: the size mpv draws the picture at', () {
    const hd = Size(1920, 1080);
    const sd43 = Size(768, 576);

    (int, int)? size(
      Size video,
      Size box, {
      double ratio = 1,
      BoxFit fit = BoxFit.contain,
    }) => highQualityPictureSize(
      video: video,
      box: box,
      devicePixelRatio: ratio,
      fit: fit,
    );

    test('Fit: the picture as it sits in the box, bars left out', () {
      // 16:9 and 4:3 in a 16:9 box.
      expect(size(hd, const Size(1280, 720)), (1280, 720));
      expect(size(sd43, const Size(1920, 1080)), (1440, 1080));
      // In a 21:9 box (2560 × 1080): bars at the sides.
      expect(size(hd, const Size(2560, 1080)), (1920, 1080));
      expect(size(sd43, const Size(2560, 1080)), (1440, 1080));
      // In a 4:3 box: bars above and below for 16:9.
      expect(size(hd, const Size(1024, 768)), (1024, 576));
      expect(size(sd43, const Size(1024, 768)), (1024, 768));
    });

    test('Fit: the bars on either side are whole pixels, so the picture '
        "isn't drawn half a pixel off the screen's (which blurs it)", () {
      // 16:9 in 1000 × 700 is 562.5 high: 562, with bars of 69.
      expect(size(hd, const Size(1000, 700)), (1000, 562));
      // 4:3 in 1279 × 720 is 960 wide, which would leave 319: 959.
      expect(size(sd43, const Size(1279, 720)), (959, 720));
      // The same at 125 %: 1023.2 × 576 is 1279 × 720 pixels.
      expect(size(sd43, const Size(1023.2, 576), ratio: 1.25), (959, 720));
    });

    test('Fill and Stretch: the whole box (mpv crops or stretches into '
        'it)', () {
      for (final fit in [BoxFit.cover, BoxFit.fill]) {
        expect(size(sd43, const Size(1920, 1080), fit: fit), (1920, 1080));
        expect(size(hd, const Size(2560, 1080), fit: fit), (2560, 1080));
        expect(size(hd, const Size(1024, 768), fit: fit), (1024, 768));
      }
    });

    test("in the screen's pixels: the box times the device pixel ratio", () {
      expect(size(hd, const Size(960, 540), ratio: 2), (1920, 1080));
      expect(size(sd43, const Size(960, 540), ratio: 2), (1440, 1080));
      expect(size(hd, const Size(640, 480), ratio: 2, fit: BoxFit.cover), (
        1280,
        960,
      ));
    });

    test('at most 4K, keeping its shape, unless the video itself is '
        'larger; at least 2 × 2', () {
      // A 4K screen at 200 %.
      expect(size(hd, const Size(3840, 2160), ratio: 2), (3840, 2160));
      // 21:9 at 200 %, filled: made smaller evenly.
      expect(size(hd, const Size(2560, 1080), ratio: 2, fit: BoxFit.cover), (
        3840,
        1620,
      ));
      // An 8K video on an 8K screen is drawn at its own size.
      expect(size(const Size(7680, 4320), const Size(3840, 2160), ratio: 2), (
        7680,
        4320,
      ));
      expect(size(hd, const Size(1, 1)), (2, 2));
    });

    test("nothing to fix while the box is empty or the video's size "
        'unknown: the video keeps its own', () {
      expect(size(hd, Size.zero), isNull);
      expect(size(hd, const Size(640, 0)), isNull);
      expect(size(Size.zero, const Size(1920, 1080)), isNull);
      expect(size(hd, Size.infinite), isNull);
      expect(size(hd, const Size(1920, 1080), ratio: 0), isNull);
    });
  });

  group("the desktop's picture", () {
    late List<String> sizes;
    late List<DateTime> sentAt;
    late ValueNotifier<Rect?> texture;
    late List<String> warnings;
    late DesktopPicture picture;
    late List<BoxFit> fits;
    var failing = false;

    /// The controller's answer, held back while set.
    Completer<void>? held;

    // Made outside the test's fake time, as the engine makes it outside
    // any frame: what it sends mustn't hang on the zone it was made in.
    setUp(() {
      sizes = [];
      sentAt = [];
      warnings = [];
      fits = [];
      failing = false;
      held = null;
      texture = ValueNotifier(null);
      picture = DesktopPicture(
        setSize: ({width, height}) async {
          if (failing) throw StateError('no texture');
          sizes.add(width == null ? 'own' : '$width×$height');
          sentAt.add(TestWidgetsFlutterBinding.instance.clock.now());
          await held?.future;
        },
        texture: texture,
        warn: warnings.add,
      );
      addTearDown(() {
        picture.dispose();
        texture.dispose();
      });
    });

    /// A 4K screen at 100 %, so every box below is laid out at the size
    /// asked (the test's own screen is 800 × 600 at 300 %).
    void bigScreen(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(3840, 2160)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Widget view(Size box, {double ratio = 1}) => MediaQuery(
      data: MediaQueryData(size: box, devicePixelRatio: ratio),
      child: Center(
        child: SizedBox.fromSize(
          size: box,
          child: picture.view(
            picture: (fit) {
              fits.add(fit);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    Future<void> show(WidgetTester tester, Size box, {double ratio = 1}) {
      bigScreen(tester);
      return tester.pumpWidget(view(box, ratio: ratio));
    }

    testWidgets("Standard leaves the texture at the video's own size", (
      tester,
    ) async {
      picture.video(1920, 1080);
      await show(tester, const Size(1280, 720));
      await tester.pump(const Duration(seconds: 1));

      expect(sizes, isEmpty);
    });

    testWidgets("High draws at the picture's size on screen, from the "
        "frame that shows it; Standard puts the video's own back", (
      tester,
    ) async {
      picture
        ..quality = PictureQuality.high
        ..video(1920, 1080);
      await show(tester, const Size(1280, 720), ratio: 1.5);
      expect(sizes, ['1920×1080']);

      picture.quality = PictureQuality.standard;
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1920×1080', 'own']);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('while the box keeps changing (a window dragged) the '
        'texture is resized at most every 150 ms, and ends at the last '
        'box', (tester) async {
      picture
        ..quality = PictureQuality.high
        ..video(1920, 1080);
      await show(tester, const Size(640, 360));
      expect(sizes, ['640×360']);

      // 400 ms of a window growing by 16 × 9 every 20 ms.
      for (var width = 656.0; width <= 960; width += 16) {
        await show(tester, Size(width, width * 9 / 16));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(sizes.length, inInclusiveRange(3, 5), reason: '$sizes');
      for (var i = 1; i < sentAt.length; i++) {
        expect(
          sentAt[i].difference(sentAt[i - 1]),
          greaterThanOrEqualTo(const Duration(milliseconds: 150)),
          reason: '$sentAt',
        );
      }
      expect(sizes.last, '960×540');
    });

    testWidgets("a new video's size is sent again, even an unchanged one: "
        "media_kit's controller puts the video's own size back by itself; "
        "nothing when the video's own size is the one drawn at", (
      tester,
    ) async {
      picture
        ..quality = PictureQuality.high
        ..video(1280, 720);
      await show(tester, const Size(1920, 1080));
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1920×1080']);

      picture.video(1024, 576);
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1920×1080', 'own', '1920×1080']);
      await tester.pump(const Duration(milliseconds: 200));

      // A 1080p stream full screen on a 1080p screen: the controller's
      // own size is ours.
      picture.video(1920, 1080);
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1920×1080', 'own', '1920×1080']);
    });

    testWidgets("Fill and Stretch are the picture widget's fit, for "
        'Standard too; for High the texture takes the whole box', (
      tester,
    ) async {
      picture.video(768, 576);
      await show(tester, const Size(1920, 1080));
      expect(fits.last, BoxFit.contain);

      for (final fit in [BoxFit.cover, BoxFit.fill]) {
        picture.pictureFit = fit;
        await tester.pump();
        expect(fits.last, fit);
      }
      expect(sizes, isEmpty, reason: 'Standard');

      // Stretch, then Fill: the whole box both times.
      picture.quality = PictureQuality.high;
      await tester.pump();
      expect(sizes, ['1920×1080']);
      picture.pictureFit = BoxFit.cover;
      await tester.pump(const Duration(milliseconds: 200));
      expect(fits.last, BoxFit.cover);
      expect(sizes, ['1920×1080']);

      picture.pictureFit = BoxFit.contain;
      await tester.pump(const Duration(milliseconds: 200));
      expect(fits.last, BoxFit.contain);
      expect(sizes.last, '1440×1080');
    });

    testWidgets('a stream opening hides the picture: its place is kept '
        "for the next one, whose size is sent before it's shown", (
      tester,
    ) async {
      picture
        ..quality = PictureQuality.high
        ..video(1920, 1080);
      await show(tester, const Size(1280, 720));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1280×720'], reason: 'nothing undone while hidden');

      picture.video(768, 576);
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1280×720', '960×720']);

      await show(tester, const Size(1280, 720));
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1280×720', '960×720'], reason: 'already right');
    });

    testWidgets('the larger of two views is drawn for; when it goes, the '
        'one left', (tester) async {
      bigScreen(tester);
      picture
        ..quality = PictureQuality.high
        ..video(1920, 1080);
      Widget both({required bool full}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            SizedBox(
              width: 640,
              height: 360,
              child: picture.view(picture: _blank),
            ),
            if (full)
              SizedBox(
                width: 1600,
                height: 900,
                child: picture.view(picture: _blank),
              ),
          ],
        ),
      );
      await tester.pumpWidget(both(full: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes.last, '1600×900');

      await tester.pumpWidget(both(full: false));
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes.last, '640×360');
    });

    testWidgets('both views hidden at once (a zap with the preview under '
        'the full-screen player): the place kept is the one drawn for, '
        'whichever goes last', (tester) async {
      bigScreen(tester);
      picture
        ..quality = PictureQuality.high
        ..video(1920, 1080);
      // The full-screen view first, so it is the first to go.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              SizedBox(
                width: 1600,
                height: 900,
                child: picture.view(picture: _blank),
              ),
              SizedBox(
                width: 640,
                height: 360,
                child: picture.view(picture: _blank),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1600×900']);

      await tester.pumpWidget(const SizedBox.shrink());
      picture.video(1280, 720);
      await tester.pump(const Duration(milliseconds: 200));

      expect(sizes, ['1600×900', 'own', '1600×900']);
    });

    testWidgets("the texture back at the video's own size after ours (the "
        "controller's resize landed last): ours is sent again, a few "
        'times at most', (tester) async {
      picture
        ..quality = PictureQuality.high
        ..video(1280, 720);
      await show(tester, const Size(1920, 1080));
      await tester.pump(const Duration(milliseconds: 200));
      texture.value = const Rect.fromLTWH(0, 0, 1920, 1080);
      expect(sizes, ['1920×1080']);

      for (var i = 0; i < 5; i++) {
        texture.value = const Rect.fromLTWH(0, 0, 1280, 720);
        await tester.pump(const Duration(milliseconds: 200));
        texture.value = null;
      }

      expect(sizes, [
        '1920×1080',
        for (var i = 0; i < 3; i++) ...['own', '1920×1080'],
      ]);
    });

    testWidgets("the texture passing through the video's own size on its "
        "way to ours isn't the controller's resize: nothing sent again", (
      tester,
    ) async {
      picture
        ..quality = PictureQuality.high
        ..video(1280, 720);
      await show(tester, const Size(1920, 1080));
      expect(sizes, ['1920×1080']);

      texture.value = const Rect.fromLTWH(0, 0, 1280, 720);
      await tester.pump(const Duration(milliseconds: 20));
      texture.value = const Rect.fromLTWH(0, 0, 1920, 1080);
      await tester.pump(const Duration(milliseconds: 300));

      expect(sizes, ['1920×1080']);
    });

    testWidgets('a slow controller: one send at a time, so its sizes land '
        'in order', (tester) async {
      held = Completer();
      picture
        ..quality = PictureQuality.high
        ..video(1280, 720);
      await show(tester, const Size(1920, 1080));
      picture.video(1024, 576);
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1920×1080'], reason: 'the first still under way');

      held!.complete();
      held = null;
      await tester.pump(const Duration(milliseconds: 200));
      expect(sizes, ['1920×1080', 'own', '1920×1080']);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a texture that refuses to be sized: one warning, and the '
        'picture plays on', (tester) async {
      failing = true;
      picture
        ..quality = PictureQuality.high
        ..video(1920, 1080);
      await show(tester, const Size(1280, 720));
      await tester.pump(const Duration(milliseconds: 200));
      await show(tester, const Size(640, 360));
      await tester.pump(const Duration(milliseconds: 200));

      expect(warnings, hasLength(1));
      expect(warnings.single, contains('no texture'));
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _blank(BoxFit fit) => const SizedBox.expand();
