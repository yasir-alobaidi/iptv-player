import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/tokens.dart';

void main() {
  group('AppLayoutTokens: how many cards a row of Home holds', () {
    const layout = AppLayoutTokens();

    /// Home's rows are the window less the collapsed nav rail (72 px) and
    /// a 32 px margin each side.
    double row(double window) => window - 72 - 64;

    (int, int, int) across(double window) => (
      layout.across(row(window), layout.continueCardMin, 24),
      layout.across(row(window), layout.channelTileMin, 16),
      layout.across(row(window), layout.posterMin, 20),
    );

    test("the canvas's window holds what the canvas draws: 4, 5 and 8", () {
      expect(across(1440), (4, 5, 8));
    });

    test('the smallest window holds fewer, each near its drawn size', () {
      expect(across(1024), (3, 4, 5));
      expect(
        layout.cardWidth(row(1024), layout.posterMin, 20),
        greaterThan(150),
      );
    });

    test('a larger window holds more, not larger ones', () {
      expect(across(1920), (6, 7, 11));
      expect(across(2560), (8, 10, 15));
      for (final window in [1280.0, 1920.0, 2560.0, 3440.0]) {
        expect(
          layout.cardWidth(row(window), layout.posterMin, 20),
          inInclusiveRange(140, 175),
          reason: 'a poster in a $window px window',
        );
      }
    });

    test('the cards of a row share its width exactly', () {
      final width = row(1366);
      final count = layout.across(width, layout.channelTileMin, 16);
      final card = layout.cardWidth(width, layout.channelTileMin, 16);
      expect(count * card + (count - 1) * 16, closeTo(width, 0.001));
    });

    test('a row narrower than one card still holds one', () {
      expect(layout.across(90, layout.posterMin, 20), 1);
      expect(layout.cardWidth(90, layout.posterMin, 20), 90);
    });
  });

  group("AppPlayerTokens: the OSD's size in a window", () {
    const player = AppPlayerTokens();

    test('the drawn size up to 1280 × 800', () {
      expect(player.scaleFor(const Size(1024, 640)), 1);
      expect(player.scaleFor(const Size(1280, 800)), 1);
      // Wide enough, not tall enough.
      expect(player.scaleFor(const Size(1920, 700)), 1);
    });

    test('larger with the window, by its tighter side', () {
      expect(player.scaleFor(const Size(1920, 1080)), 1.35);
      expect(player.scaleFor(const Size(2560, 1440)), 1.8);
      expect(player.scaleFor(const Size(1600, 1200)), 1.25);
    });

    test('twice at most', () {
      expect(player.scaleFor(const Size(3840, 2160)), 2);
      expect(player.scaleFor(const Size(7680, 4320)), 2);
    });
  });
}
