import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';

void main() {
  group("docs/04's table, by model", () {
    test('only Chromecast Ultra is seeded, written any way', () {
      for (final model in ['Chromecast Ultra', ' chromecast ULTRA ']) {
        final profile = CastDeviceProfile(model: model);
        expect(profile.playsHevc, isTrue, reason: model);
        expect(profile.maxHeight, 2160, reason: model);
      }
    });

    test('"Chromecast" (the 1080p ones and the 4K Google TV) is learned', () {
      const profile = CastDeviceProfile(model: 'Chromecast');
      expect(profile.seed, isNull);
      expect(profile.playsHevc, isNull);
      expect(profile.maxHeight, isNull);
    });

    test('unknown and missing models are learned', () {
      for (final model in [null, '', 'Google TV Streamer', 'BRAVIA 4K']) {
        final profile = CastDeviceProfile(model: model);
        expect(profile.playsHevc, isNull, reason: model);
        expect(profile.maxHeight, isNull, reason: model);
      }
    });
  });

  group('HEVC', () {
    test("the user's Yes and No win over everything", () {
      const refused = CastLearned(refusedCodecs: {'hevc'});
      expect(
        const CastDeviceProfile(
          hevc: HevcSupport.yes,
          learned: refused,
        ).playsHevc,
        isTrue,
      );
      expect(
        const CastDeviceProfile(
          model: 'Chromecast Ultra',
          hevc: HevcSupport.no,
        ).playsHevc,
        isFalse,
      );
    });

    test('Automatic: a refusal, then the model, then not known', () {
      expect(
        const CastDeviceProfile(
          model: 'Chromecast Ultra',
          learned: CastLearned(refusedCodecs: {'hevc'}),
        ).playsHevc,
        isFalse,
      );
      expect(
        const CastDeviceProfile(model: 'Chromecast Ultra').playsHevc,
        isTrue,
      );
      expect(const CastDeviceProfile().playsHevc, isNull);
    });
  });

  group('the tallest picture', () {
    test('the lower of learned and seeded', () {
      expect(
        const CastDeviceProfile(
          model: 'Chromecast Ultra',
          learned: CastLearned(maxHeight: 1080),
        ).maxHeight,
        1080,
      );
      expect(
        const CastDeviceProfile(
          model: 'Chromecast Ultra',
          learned: CastLearned(maxHeight: 4320),
        ).maxHeight,
        2160,
      );
      expect(
        const CastDeviceProfile(learned: CastLearned(maxHeight: 720)).maxHeight,
        720,
      );
    });
  });

  test('refused audio codecs', () {
    const profile = CastDeviceProfile(
      learned: CastLearned(refusedCodecs: {'eac3', 'hevc'}),
    );
    expect(profile.refusedAudio('eac3'), isTrue);
    expect(profile.refusedAudio('aac'), isFalse);
    expect(profile.refusedAudio(null), isFalse);
  });

  test('a kept device brings its model, setting and learning', () {
    const known = KnownCastDevice(
      id: 'aaaa',
      name: 'Living Room TV',
      host: '192.168.1.155',
      port: castPort,
      manual: false,
      hevc: HevcSupport.no,
      learned: CastLearned(maxHeight: 1080),
      model: 'Chromecast',
    );
    final profile = CastDeviceProfile.fromKnown(known);
    expect(profile.model, 'Chromecast');
    expect(profile.hevc, HevcSupport.no);
    expect(profile.learned, const CastLearned(maxHeight: 1080));
  });
}
