import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/tokens.dart';

void main() {
  group('AppearanceSettings as stored', () {
    test('the defaults follow the desktop', () {
      const settings = AppearanceSettings();

      expect(settings.accent, AppAccent.blue);
      expect(settings.textSize, TextSizeChoice.system);
      expect(settings.density, AppDensity.comfortable);
      expect(settings.reduceMotion, SystemSwitch.system);
      expect(settings.clock, ClockChoice.system);
    });

    test('every choice survives the round trip through JSON text', () {
      for (final accent in AppAccent.values) {
        for (final size in TextSizeChoice.values) {
          for (final clock in ClockChoice.values) {
            final settings = AppearanceSettings(
              accent: accent,
              textSize: size,
              density: AppDensity.compact,
              reduceMotion: SystemSwitch.on,
              clock: clock,
            );
            final read = AppearanceSettings.fromJson(
              jsonDecode(jsonEncode(settings.toJson())),
            );
            expect(read, settings);
          }
        }
      }
    });

    test('anything damaged or unknown reads as the default, key by key', () {
      expect(AppearanceSettings.fromJson(null), const AppearanceSettings());
      expect(AppearanceSettings.fromJson('blue'), const AppearanceSettings());
      expect(
        AppearanceSettings.fromJson(const [1]),
        const AppearanceSettings(),
      );
      expect(
        AppearanceSettings.fromJson(const {
          'accent': 'teal',
          'text_size': 'huge',
          'density': 7,
          'reduce_motion': null,
          'clock': 'h24',
          'from a newer version': true,
        }),
        const AppearanceSettings(
          accent: AppAccent.teal,
          clock: ClockChoice.h24,
        ),
      );
    });
  });

  group('what System resolves to', () {
    Appearance look(
      AppearanceSettings settings, {
      double textScale = 1,
      bool reduceMotion = false,
      bool use24Hour = false,
    }) => settings.resolve(
      SystemAppearance(
        textScale: textScale,
        reduceMotion: reduceMotion,
        use24Hour: use24Hour,
      ),
    );

    test("the desktop's text size, its animations switch and its clock", () {
      const settings = AppearanceSettings();

      expect(look(settings).textScale, 1);
      expect(look(settings, textScale: 1.25).textScale, 1.25);
      expect(look(settings, reduceMotion: true).reduceMotion, isTrue);
      expect(look(settings).timeStyle, TimeStyle.h12);
      expect(look(settings, use24Hour: true).timeStyle, TimeStyle.h24);
    });

    test('a desktop past 130 % gets 130 %; one under 100 % gets 100 %', () {
      const settings = AppearanceSettings();

      expect(look(settings, textScale: 1.5).textScale, 1.3);
      expect(look(settings, textScale: 2).textScale, 1.3);
      expect(look(settings, textScale: 0.8).textScale, 1);
      expect(look(settings, textScale: double.nan).textScale, 1);
      expect(look(settings, textScale: double.infinity).textScale, 1);
    });

    test('a size chosen here wins over the desktop', () {
      const big = AppearanceSettings(textSize: TextSizeChoice.s130);
      const usual = AppearanceSettings(textSize: TextSizeChoice.s100);

      expect(look(big).textScale, 1.3);
      expect(look(usual, textScale: 1.5).textScale, 1);
      expect(
        look(const AppearanceSettings(textSize: TextSizeChoice.s115)).textScale,
        1.15,
      );
    });

    test('On and Off win over the desktop, both ways', () {
      const on = AppearanceSettings(reduceMotion: SystemSwitch.on);
      const off = AppearanceSettings(reduceMotion: SystemSwitch.off);

      expect(look(on).reduceMotion, isTrue);
      expect(look(off, reduceMotion: true).reduceMotion, isFalse);
    });

    test('12-hour and 24-hour win over the desktop, both ways', () {
      const h12 = AppearanceSettings(clock: ClockChoice.h12);
      const h24 = AppearanceSettings(clock: ClockChoice.h24);

      expect(look(h12, use24Hour: true).timeStyle, TimeStyle.h12);
      expect(look(h24).timeStyle, TimeStyle.h24);
    });

    test('the accent and the density pass through', () {
      final resolved = look(
        const AppearanceSettings(
          accent: AppAccent.rose,
          density: AppDensity.compact,
        ),
      );

      expect(resolved.accent, AppAccent.rose);
      expect(resolved.density, AppDensity.compact);
    });
  });

  group('density', () {
    test('Compact takes 12 px off a long list row, never under 40', () {
      expect(AppDensity.comfortable.row(56), 56);
      expect(AppDensity.comfortable.row(72), 72);
      expect(AppDensity.compact.row(56), 44);
      expect(AppDensity.compact.row(72), 60);
      expect(AppDensity.compact.row(48), 40);
      expect(AppDensity.compact.row(40), 40);
      expect(AppDensity.compact.row(56), AppDensity.compact.rowHeight);
    });
  });
}
