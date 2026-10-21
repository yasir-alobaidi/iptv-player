import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/features/playback/domain/frame_rate_match.dart';

import 'support/display_fakes.dart';

/// Match frame rate's choice of mode (decision 2): only a film's 23.976
/// or 24 fps, at the display's current size, within 0.01 Hz.
void main() {
  DisplayMode? switchesTo(DisplayFacts facts, double? fps) =>
      switch (pickDisplayMode(facts, fps)) {
        SwitchDisplayMode(:final mode) => mode,
        _ => null,
      };

  group('pickDisplayMode', () {
    test('23.976 fps takes the 23.976 Hz mode at the current size', () {
      expect(switchesTo(tvFacts(), 23.976023976), uhd23976);
      expect(switchesTo(tvFacts(), 23.98), uhd23976);
      expect(
        switchesTo(tvFacts(current: tvMode(7)), 23.976),
        tvMode(11),
        reason: '1080p stays 1080p',
      );
    });

    test('24 fps takes the 24 Hz mode: 23.976 and 24 are apart', () {
      expect(switchesTo(tvFacts(), 24), uhd24);
      expect(switchesTo(tvFacts(), 24.0001), uhd24);
      expect(switchesTo(tvFacts(current: tvMode(8)), 24), tvMode(12));
    });

    test('25 and 50 fps take the 50 Hz mode at the current size where the '
        'TV has one (ADR-049); none on a TV without', () {
      final samsung = tvFacts(current: samsung5994, modes: samsungModes);
      for (final fps in [25.0, 24.95, 50.0, 49.95]) {
        expect(switchesTo(samsung, fps), samsung50, reason: '$fps fps');
      }
      expect(
        switchesTo(
          tvFacts(current: samsungMode(1821), modes: samsungModes),
          25,
        ),
        samsungMode(1831),
        reason: '1080p stays 1080p',
      );
      final there = pickDisplayMode(
        tvFacts(current: samsung50, modes: samsungModes),
        25,
      );
      expect(there, isA<DisplayModeMatches>());
      // The Bedroom's Hisense has no 50 Hz.
      final none = pickDisplayMode(tvFacts(), 25);
      expect(none, isA<NoDisplayMode>());
      expect((none as NoDisplayMode).reason, 'no 50 Hz mode at 3840x2160');
    });

    test('nothing for any other rate, or none known', () {
      for (final fps in [29.97, 30.0, 59.94, 60.0, 23.5, 24.5, 26.0]) {
        final pick = pickDisplayMode(tvFacts(), fps);
        expect(pick, isA<NoDisplayMode>(), reason: '$fps fps');
        expect(
          (pick as NoDisplayMode).reason,
          contains('is not 23.976, 24, 25 or 50'),
        );
      }
      for (final fps in [null, 0.0, -24.0, double.nan]) {
        expect(
          pickDisplayMode(tvFacts(), fps),
          isA<NoDisplayMode>(),
          reason: '$fps',
        );
      }
    });

    test('nothing when the current size has no such mode', () {
      // 720p has only 59.94 and 60.
      final pick = pickDisplayMode(tvFacts(current: tvMode(13)), 23.976);
      expect(pick, isA<NoDisplayMode>());
      expect((pick as NoDisplayMode).reason, 'no 23.976 Hz mode at 1280x720');
      // 23.976 is no 24.
      const only24 = DisplayFacts(
        current: DisplayMode(id: 1, width: 1920, height: 1080, refreshRate: 60),
        modes: [
          DisplayMode(id: 1, width: 1920, height: 1080, refreshRate: 60),
          DisplayMode(id: 2, width: 1920, height: 1080, refreshRate: 24),
          DisplayMode(id: 3, width: 3840, height: 2160, refreshRate: 23.976),
        ],
      );
      expect(pickDisplayMode(only24, 23.976), isA<NoDisplayMode>());
      expect(switchesTo(only24, 24)?.id, 2);
    });

    test('nothing when the display is there already', () {
      final pick = pickDisplayMode(tvFacts(current: uhd23976), 23.976);
      expect(pick, isA<DisplayModeMatches>());
      expect((pick as DisplayModeMatches).mode, uhd23976);
      expect(
        pickDisplayMode(tvFacts(current: uhd24), 24),
        isA<DisplayModeMatches>(),
      );
      // At 24 Hz, a 23.976 film still moves.
      expect(switchesTo(tvFacts(current: uhd24), 23.976), uhd23976);
    });

    test("nothing when the display's mode isn't known", () {
      expect(
        pickDisplayMode(const DisplayFacts(current: null, modes: tvModes), 24),
        isA<NoDisplayMode>(),
      );
    });
  });

  group("the TV's own Match content frame rate (decision 1)", () {
    test('Always and unknown (before Android 12) allow it', () {
      expect(tvRefuses(tvFacts(), uhd23976), isNull);
      expect(
        tvRefuses(tvFacts(preference: MatchContentFrameRate.unknown), uhd23976),
        isNull,
      );
    });

    test('Never refuses it', () {
      expect(
        tvRefuses(tvFacts(preference: MatchContentFrameRate.never), uhd24),
        "the TV's Match content frame rate is Never",
      );
    });

    test("Seamless only, Google TV's own default, allows it too: only "
        'Never refuses (ADR-044)', () {
      expect(
        tvRefuses(
          tvFacts(preference: MatchContentFrameRate.seamlessOnly),
          uhd23976,
        ),
        isNull,
      );
      expect(
        tvRefuses(
          tvFacts(
            preference: MatchContentFrameRate.seamlessOnly,
            modes: samsungModes,
            current: samsung5994,
          ),
          samsung50,
        ),
        isNull,
      );
    });
  });

  group('pickChannelMode (ADR-044)', () {
    DisplayFacts samsung({DisplayMode? current}) =>
        tvFacts(current: current ?? samsung5994, modes: samsungModes);

    test('25 and 50 fps take the 50 Hz mode at the current size', () {
      for (final fps in [25.0, 50.0, 24.95, 50.05]) {
        final pick = pickChannelMode(samsung(), fps);
        expect(pick, isA<SwitchDisplayMode>(), reason: '$fps fps');
        expect((pick as SwitchDisplayMode).mode, samsung50);
      }
      final hd = pickChannelMode(samsung(current: samsungMode(1821)), 25);
      expect(
        (hd as SwitchDisplayMode).mode,
        samsungMode(1831),
        reason: '1080p stays 1080p, and 25 fps goes to 50 Hz, not 25',
      );
    });

    test('nothing when the display is at 50 Hz already', () {
      final pick = pickChannelMode(samsung(current: samsung50), 25);
      expect(pick, isA<DisplayModeMatches>());
      expect((pick as DisplayModeMatches).mode, samsung50);
    });

    test("any other rate plays on the TV's own mode", () {
      for (final fps in [23.976, 24.0, 29.97, 30.0, 59.94, 60.0, 48.0]) {
        final pick = pickChannelMode(samsung(), fps);
        expect(pick, isA<NoDisplayMode>(), reason: '$fps fps');
        expect((pick as NoDisplayMode).reason, contains('is not 25 or 50'));
      }
      for (final fps in [null, 0.0, double.nan]) {
        expect(
          (pickChannelMode(samsung(), fps) as NoDisplayMode).reason,
          "the channel's frame rate isn't known",
        );
      }
    });

    test('nothing on a TV with no 50 Hz mode (the Bedroom TV)', () {
      final pick = pickChannelMode(tvFacts(), 50);
      expect(pick, isA<NoDisplayMode>());
      expect((pick as NoDisplayMode).reason, 'no 50 Hz mode at 3840x2160');
    });
  });

  test('rates are written in as few figures as they need', () {
    expect(formatRate(23.976025), '23.976');
    expect(formatRate(23.976023976), '23.976');
    expect(formatRate(24), '24');
    expect(formatRate(59.94006), '59.94');
    expect(formatRate(29.97003), '29.97');
    expect(formatRate(25), '25');
    expect(formatRate(60.0001), '60');
  });
}
