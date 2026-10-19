import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/player_mediakit/subtitle_style.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Settings → Playback → Subtitle size (ADR-038): the platform and the
/// size, to the scale the picture's view gets, to media_kit's subtitles.
void main() {
  const player = AppPlayerTokens();
  const own = SubtitleViewConfiguration();

  SubtitleViewConfiguration on(SubtitleSize size, {required bool tv}) =>
      subtitleConfiguration(player.subtitleScale(size, tv: tv));

  test("a desktop's Medium is media_kit's own configuration, as before", () {
    expect(player.subtitleScale(SubtitleSize.medium, tv: false), 1);
    expect(identical(on(SubtitleSize.medium, tv: false), own), isTrue);
    expect(own.style.fontSize, 32);
  });

  test('each platform and size: its font against the 32 px of a 1920×1080 '
      'picture', () {
    final sizes = {
      for (final tv in [false, true])
        for (final size in SubtitleSize.values)
          (tv ? 'tv' : 'desktop', size.name): on(size, tv: tv).style.fontSize,
    };
    // A TV's Medium is 1.4 times the player's own (about 45 px of a
    // 1080-line screen once its 1280×720 canvas shrinks the box);
    // Small and Large are 0.8 and 1.3 times the platform's Medium.
    final expected = {
      ('desktop', 'small'): 25.6,
      ('desktop', 'medium'): 32.0,
      ('desktop', 'large'): 41.6,
      ('tv', 'small'): 35.84,
      ('tv', 'medium'): 44.8,
      ('tv', 'large'): 58.24,
    };
    expect(sizes.keys, unorderedEquals(expected.keys));
    for (final MapEntry(:key, :value) in expected.entries) {
      expect(sizes[key], closeTo(value, 1e-9), reason: '$key');
    }
  });

  test('only the size changes: the place, the colours and the box stay '
      "media_kit's", () {
    for (final tv in [false, true]) {
      for (final size in SubtitleSize.values) {
        final configuration = on(size, tv: tv);
        final style = configuration.style;
        expect(style.color, own.style.color);
        expect(style.backgroundColor, own.style.backgroundColor);
        expect(style.height, own.style.height);
        expect(style.fontWeight, own.style.fontWeight);
        expect(style.letterSpacing, own.style.letterSpacing);
        expect(style.wordSpacing, own.style.wordSpacing);
        expect(configuration.padding, own.padding);
        expect(configuration.textAlign, own.textAlign);
        expect(configuration.visible, isTrue);
        // Left to media_kit, so the text still grows with the picture.
        expect(configuration.textScaler, isNull);
      }
    }
  });

  test('one configuration per scale, so a picture built again for '
      'something else leaves its subtitles alone', () {
    final styles = SubtitleStyles();
    final large = styles.at(1.3);

    expect(identical(styles.at(1.3), large), isTrue);
    expect(identical(styles.at(1), own), isTrue);
    expect(styles.at(1.4).style.fontSize, closeTo(44.8, 1e-9));
    expect(identical(styles.at(1.4), large), isFalse);
  });
}
