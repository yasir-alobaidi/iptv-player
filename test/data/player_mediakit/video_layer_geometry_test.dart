import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/player_mediakit/video_layer.dart';
import 'package:iptv_player/data/player_mediakit/video_layer_geometry.dart';

void main() {
  const screen = Rect.fromLTWH(0, 0, 1920, 1080);

  group('videoLayerRect', () {
    test('a 16:9 film fills a 16:9 screen, whatever its own size', () {
      for (final video in const [Size(1920, 1080), Size(3840, 2160)]) {
        expect(
          videoLayerRect(box: screen, video: video, fit: BoxFit.contain),
          screen,
        );
      }
    });

    test('Fit pillarboxes 4:3 and letterboxes scope, centred', () {
      expect(
        videoLayerRect(
          box: screen,
          video: const Size(1440, 1080),
          fit: BoxFit.contain,
        ),
        const Rect.fromLTWH(240, 0, 1440, 1080),
      );
      expect(
        videoLayerRect(
          box: screen,
          video: const Size(1920, 804),
          fit: BoxFit.contain,
        ),
        const Rect.fromLTWH(0, 138, 1920, 804),
      );
    });

    test('Fill covers the screen: larger than it, the edges cropped', () {
      expect(
        videoLayerRect(
          box: screen,
          video: const Size(1440, 1080),
          fit: BoxFit.cover,
        ),
        const Rect.fromLTWH(0, -180, 1920, 1440),
      );
    });

    test('Stretch is the box, whatever the shape', () {
      expect(
        videoLayerRect(
          box: screen,
          video: const Size(720, 576),
          fit: BoxFit.fill,
        ),
        screen,
      );
    });

    test('follows a box that is not at the origin, in whole pixels', () {
      expect(
        videoLayerRect(
          box: const Rect.fromLTWH(100.4, 50.6, 960, 540),
          video: const Size(1440, 1080),
          fit: BoxFit.contain,
        ),
        const Rect.fromLTRB(220, 51, 940, 591),
      );
    });

    test('nothing to fit is no rect', () {
      expect(
        videoLayerRect(
          box: Rect.zero,
          video: const Size(1920, 1080),
          fit: BoxFit.contain,
        ),
        isNull,
      );
      expect(
        videoLayerRect(box: screen, video: Size.zero, fit: BoxFit.contain),
        isNull,
      );
    });
  });

  group('playsOnLayer', () {
    test('a file or a channel on the direct output, in a build with the '
        'layer (ADR-045)', () {
      expect(playsOnLayer(built: true, direct: true), isTrue);
    });

    test('never the desktop, or a build without it', () {
      expect(playsOnLayer(built: true, direct: false), isFalse);
      expect(playsOnLayer(built: false, direct: true), isFalse);
    });

    test('no build of this test has it: it is never off Android', () {
      expect(videoLayerBuilt, isFalse);
    });

    test('a TV build has it unless built with BIJOU_VIDEO_LAYER=off (the '
        'Bedroom TV decided: ADR-035 §1)', () {
      expect(videoLayerWanted(''), isTrue);
      expect(videoLayerWanted('true'), isTrue);
      expect(videoLayerWanted('clear'), isTrue);
      expect(videoLayerWanted('off'), isFalse);
    });
  });
}
