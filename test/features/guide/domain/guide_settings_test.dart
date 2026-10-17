import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';

void main() {
  group('stored guide settings', () {
    test('read back as written, for every choice the menu offers', () {
      for (final days in GuideSettings.keepDaysOptions) {
        for (final enabled in [false, true]) {
          final settings = GuideSettings(enabled: enabled, keepDays: days);

          expect(GuideSettings.fromJson(settings.toJson()), settings);
          expect(settings.toJson(), {'enabled': enabled, 'keep_days': days});
          expect(settings.keepAhead, Duration(days: days));
        }
      }
    });

    test('the defaults keep a week, with the guide off (ADR-031)', () {
      const settings = GuideSettings();

      expect(settings.enabled, isFalse);
      expect(GuideSettings.defaultsOn(FormFactor.desktop), settings);
      expect(settings.keepDays, 7);
      expect(settings.keepAhead, const Duration(days: 7));
      expect(GuideSettings.keepDaysOptions, contains(settings.keepDays));
      expect(
        GuideSettings.keepDaysOptions.every(
          (days) =>
              days >= GuideSettings.minKeepDays &&
              days <= GuideSettings.maxKeepDays,
        ),
        isTrue,
      );
    });

    test('a TV starts with the guide off and three days ahead, and keeps '
        'two hours behind; a desktop a day (docs/07)', () {
      final tv = GuideSettings.defaultsOn(FormFactor.tv);

      expect(tv.enabled, isFalse);
      expect(tv.keepDays, 3);
      expect(tv.keepAhead, const Duration(days: 3));
      expect(GuideSettings.keepDaysOptions, contains(tv.keepDays));
      expect(
        GuideSettings.keepBehindOn(FormFactor.tv),
        const Duration(hours: 2),
      );
      expect(
        GuideSettings.keepBehindOn(FormFactor.desktop),
        const Duration(days: 1),
      );
    });

    test('the switch is on only when it says true; anything else is '
        'off', () {
      expect(GuideSettings.fromJson(const {'enabled': true}).enabled, isTrue);
      for (final value in <Object?>[
        false,
        null,
        'true',
        'yes',
        1,
        1.0,
        '',
        <Object?>[true],
        {'value': true},
      ]) {
        expect(
          GuideSettings.fromJson({'enabled': value, 'keep_days': 3}),
          const GuideSettings(keepDays: 3),
          reason: '$value',
        );
      }
      expect(GuideSettings.fromJson(const {'keep_days': 3}).enabled, isFalse);
    });

    test('each choice is read on its own: a damaged one is its default, '
        'the other is kept', () {
      expect(
        GuideSettings.fromJson(const {'enabled': true, 'keep_days': 'five'}),
        const GuideSettings(enabled: true),
      );
      expect(
        GuideSettings.fromJson(const {'enabled': 'on', 'keep_days': 5}),
        const GuideSettings(keepDays: 5),
      );
    });

    test("what is missing or damaged is the device's default", () {
      final tv = GuideSettings.defaultsOn(FormFactor.tv);

      for (final json in <Object?>[
        null,
        'keep_days',
        <String, Object?>{},
        {'keep_days': 'five'},
        {'keep_days': 15},
      ]) {
        expect(GuideSettings.fromJson(json, defaults: tv), tv, reason: '$json');
      }
      expect(
        GuideSettings.fromJson(const {
          'enabled': true,
          'keep_days': 10,
        }, defaults: tv),
        const GuideSettings(enabled: true, keepDays: 10),
      );
    });

    test('a number in another shape is read as that number', () {
      for (final (value, days) in [
        (5, 5),
        (5.0, 5),
        ('5', 5),
        (' 10 ', 10),
        (1, 1),
        (14, 14),
        (14.0, 14),
      ]) {
        expect(
          GuideSettings.fromJson({'keep_days': value}).keepDays,
          days,
          reason: '$value',
        );
      }
    });

    test('anything missing, damaged or out of range is the default', () {
      for (final json in <Object?>[
        null,
        '',
        'keep_days',
        7,
        [5],
        <Object?>[],
        <String, Object?>{},
        {'keepDays': 5},
        {'keep_days': null},
        {'keep_days': true},
        {'keep_days': 'five'},
        {'keep_days': ''},
        {'keep_days': '5.5'},
        {'keep_days': 5.5},
        {'keep_days': double.nan},
        {'keep_days': 0},
        {'keep_days': -3},
        {'keep_days': 15},
        {'keep_days': '15'},
        {'keep_days': 1 << 62},
        {
          'keep_days': [5],
        },
        {
          'keep_days': {'value': 5},
        },
      ]) {
        expect(
          GuideSettings.fromJson(json),
          const GuideSettings(),
          reason: '$json',
        );
      }
    });

    test('an infinite number is the default', () {
      // `jsonDecode` reads 1e999 as infinity.
      for (final json in [
        {'keep_days': double.infinity},
        {'keep_days': double.negativeInfinity},
      ]) {
        expect(
          GuideSettings.fromJson(json),
          const GuideSettings(),
          reason: '$json',
        );
      }
    });

    test('other keys are ignored', () {
      expect(
        GuideSettings.fromJson(const {'keep_days': 3, 'future_setting': 'on'}),
        const GuideSettings(keepDays: 3),
      );
    });

    test('copyWith changes only what it is given', () {
      const settings = GuideSettings(keepDays: 3);

      expect(settings.copyWith(), settings);
      expect(
        settings.copyWith(keepDays: 10),
        const GuideSettings(keepDays: 10),
      );
      expect(
        settings.copyWith(enabled: true),
        const GuideSettings(enabled: true, keepDays: 3),
      );
    });
  });

  test('the offset steps are half hours up to twelve hours either way', () {
    expect(guideOffsetStepMinutes, 30);
    expect(guideOffsetLimitMinutes, 720);
    expect(guideOffsetLimitMinutes % guideOffsetStepMinutes, 0);
  });
}
