import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/design/tokens.dart';

void main() {
  group('AppTokens', () {
    test('the accent drives every accent-derived color', () {
      for (final accent in AppAccent.values) {
        final tokens = AppTokens.defaults(accent: accent);
        expect(tokens.colors.accentBase, accent.base);
        expect(tokens.colors.accentHover, accent.hover);
        expect(tokens.colors.accentPressed, accent.pressed);
        expect(tokens.colors.accentSoft.a, closeTo(0.16, 0.001));
        expect(tokens.colors.accentSoftBorder.a, closeTo(0.5, 0.001));
      }
    });

    test('density sets the row height (docs/05: 56 / 44)', () {
      expect(AppDensity.comfortable.rowHeight, 56);
      expect(AppDensity.compact.rowHeight, 44);
    });

    test('reduce motion shortens every duration to 80 ms or less', () {
      const motion = AppMotion(reduceMotion: true);
      for (final duration in [
        motion.fast,
        motion.base,
        motion.slow,
        motion.osdIn,
        motion.osdOut,
      ]) {
        expect(duration.inMilliseconds, lessThanOrEqualTo(80));
      }
      expect(motion.allowScale, isFalse);
      expect(motion.allowShimmer, isFalse);
    });

    test('full motion keeps the docs/05 durations', () {
      const motion = AppMotion(reduceMotion: false);
      expect(motion.fast.inMilliseconds, 120);
      expect(motion.base.inMilliseconds, 200);
      expect(motion.slow.inMilliseconds, 320);
      expect(motion.osdIn.inMilliseconds, 180);
      expect(motion.osdOut.inMilliseconds, 240);
    });

    test('the focus ring matches the canvas', () {
      const focus = AppFocusTokens();
      expect(focus.ringWidth, 2);
      expect(focus.glowWidth, 4);
      expect(focus.glowOpacity, 0.25);
      expect(focus.tileScale, 1.03);
    });

    test('the canvas radius of 10 is a token', () {
      expect(const AppRadii().control, 10);
    });

    test('type styles use the bundled families with a wght variation', () {
      const text = AppTypography();
      final styles = {
        'display': text.display,
        'h2': text.h2,
        'titleSmall': text.titleSmall,
        'body': text.body,
        'label': text.label,
        'labelSmall': text.labelSmall,
        'micro': text.micro,
        'mono': text.mono,
      };
      for (final entry in styles.entries) {
        final style = entry.value;
        expect(
          style.fontFamily,
          anyOf(AppFonts.sans, AppFonts.mono),
          reason: entry.key,
        );
        expect(style.fontVariations, isNotEmpty, reason: entry.key);
        expect(
          style.fontVariations!.single.value,
          style.fontWeight!.value.toDouble(),
          reason: entry.key,
        );
        // Times and channel numbers must not jitter.
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: entry.key,
        );
      }
      expect(text.mono.fontFamily, AppFonts.mono);
    });

    test('the canvas sizes are the ones docs/05 was missing', () {
      const text = AppTypography();
      expect(text.titleSmall.fontSize, 17);
      expect(text.label.fontSize, 14);
      expect(text.labelSmall.fontSize, 12);
    });

    test('lerp snaps rather than blending discrete tokens', () {
      final blue = AppTokens.defaults();
      final rose = AppTokens.defaults(accent: AppAccent.rose);
      expect(blue.lerp(rose, 0.2).colors.accentBase, AppAccent.blue.base);
      expect(blue.lerp(rose, 0.8).colors.accentBase, AppAccent.rose.base);
      expect(blue.lerp(null, 0.8).colors.accentBase, AppAccent.blue.base);
    });
  });

  group('buildAppTheme', () {
    test('carries the tokens as a ThemeExtension', () {
      final theme = buildAppTheme(
        accent: AppAccent.teal,
        density: AppDensity.compact,
        reduceMotion: true,
      );
      final tokens = theme.extension<AppTokens>()!;

      expect(tokens.colors.accentBase, AppAccent.teal.base);
      expect(tokens.density, AppDensity.compact);
      expect(tokens.motion.reduceMotion, isTrue);
    });

    test('is dark and uses the bundled sans font', () {
      final theme = buildAppTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppTokens.defaults().colors.bg);
      expect(theme.textTheme.bodyLarge!.fontFamily, AppFonts.sans);
    });
  });

  testWidgets('context.tokens falls back when no theme is present', (
    tester,
  ) async {
    late AppTokens tokens;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          tokens = context.tokens;
          return const SizedBox();
        },
      ),
    );
    expect(tokens.colors.accentBase, AppAccent.blue.base);
  });
}
