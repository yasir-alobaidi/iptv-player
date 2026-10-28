import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_subtitles.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/cast_text.dart';

void main() {
  test("an AirPlay TV's line names AirPlay; a Chromecast's is as it was", () {
    expect(
      castModelLine(
        const CastDevice(
          id: '${airPlayIdPrefix}D1:3C',
          name: 'Bedroom Roku',
          host: '192.168.1.162',
          port: 7000,
          model: 'Hisense G204X',
        ),
        null,
      ),
      'Hisense G204X · AirPlay',
    );
    expect(
      castModelLine(
        const CastDevice(
          id: 'tv1',
          name: 'TV',
          host: '192.168.1.155',
          model: 'Chromecast',
        ),
        null,
      ),
      'Chromecast',
    );
  });

  group('the casting view on subtitles', () {
    const subtitles = [
      CastSubtitle(language: 'en', beside: true),
      CastSubtitle(language: 'ger', title: 'SDH'),
      CastSubtitle(),
    ];

    test('nothing to show: no line', () {
      expect(castSubtitlesLine(const CastingState()), isNull);
      expect(
        castSubtitlesLine(const CastingState(phase: CastPhase.playing)),
        isNull,
      );
    });

    test('which shows, or off', () {
      CastingState showing(int? id) => CastingState(
        phase: CastPhase.playing,
        subtitles: subtitles,
        subtitle: id,
      );
      expect(castSubtitlesLine(showing(null)), 'Subtitles: off');
      expect(castSubtitlesLine(showing(1)), 'Subtitles: English');
      expect(castSubtitlesLine(showing(2)), 'Subtitles: German · SDH');
      expect(castSubtitlesLine(showing(3)), 'Subtitles: Subtitles 3');
      // One that isn't there is none.
      expect(castSubtitlesLine(showing(4)), 'Subtitles: off');
      expect(castSubtitlesLine(showing(0)), 'Subtitles: off');
    });
  });
}
