import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';

void main() {
  group('stored guide settings', () {
    test('read back as written, for every choice the menu offers', () {
      for (final days in GuideSettings.keepDaysOptions) {
        final settings = GuideSettings(keepDays: days);

        expect(GuideSettings.fromJson(settings.toJson()), settings);
        expect(settings.toJson(), {'keep_days': days});
        expect(settings.keepAhead, Duration(days: days));
      }
    });

    test('the defaults keep a week', () {
      const settings = GuideSettings();

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
      expect(settings.copyWith(keepDays: 10).keepDays, 10);
    });
  });

  test('the offset steps are half hours up to twelve hours either way', () {
    expect(guideOffsetStepMinutes, 30);
    expect(guideOffsetLimitMinutes, 720);
    expect(guideOffsetLimitMinutes % guideOffsetStepMinutes, 0);
  });
}
