import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_subtitles.dart';
import 'package:iptv_player/core/text/languages.dart';

void main() {
  group('what a subtitle is called, here and on the TV', () {
    test('its language, then what its title adds', () {
      expect(
        castSubtitleLabel(const CastSubtitle(language: 'en'), 1),
        'English',
      );
      expect(
        castSubtitleLabel(const CastSubtitle(language: 'ger', title: 'SDH'), 2),
        'German · SDH',
      );
      // A title that only repeats the language adds nothing.
      expect(
        castSubtitleLabel(
          const CastSubtitle(language: 'eng', title: 'English'),
          1,
        ),
        'English',
      );
      // A language the app has no name for shows as its code.
      expect(castSubtitleLabel(const CastSubtitle(language: 'tlh'), 1), 'TLH');
    });

    test('no language: its title, else its number', () {
      expect(
        castSubtitleLabel(const CastSubtitle(title: 'Signs & songs'), 3),
        'Signs & songs',
      );
      expect(castSubtitleLabel(const CastSubtitle(), 3), 'Subtitles 3');
      expect(
        castSubtitleLabel(const CastSubtitle(title: '  '), 2),
        'Subtitles 2',
      );
    });

    test('forced is said once', () {
      expect(
        castSubtitleLabel(const CastSubtitle(language: 'fr', forced: true), 1),
        'French · forced',
      );
      expect(
        castSubtitleLabel(
          const CastSubtitle(language: 'fr', title: 'Forced', forced: true),
          1,
        ),
        'French · Forced',
      );
    });
  });

  test('no subtitles: nothing is made, and a relayed stream starts where '
      'it was asked to', () async {
    const none = NoCastSubtitles();
    final set = none.prepare('/videos/Film.mkv', beside: ['/videos/Film.srt']);
    await set.done;
    expect(set.subtitles, isEmpty);
    expect(await set.files(by: const Duration(minutes: 1)), isEmpty);
    await set.delete();
    expect(
      await none.startOf(
        '/videos/Film.mkv',
        at: const Duration(minutes: 3),
        copied: (video: true, audioTrack: 0),
      ),
      const Duration(minutes: 3),
    );
  });

  test("a language's short tag, as a TV wants it", () {
    expect(languageTag('eng'), 'en');
    expect(languageTag('ger'), 'de');
    expect(languageTag('deu'), 'de');
    expect(languageTag('ara'), 'ar');
    expect(languageTag('en-US'), 'en');
    expect(languageTag('PT_br'), 'pt');
    expect(languageTag('fr'), 'fr');
    // Not listed: as it is, lower case.
    expect(languageTag('TLH'), 'tlh');
    expect(languageTag('xx'), 'xx');
  });
}
