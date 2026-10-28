import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/airplay_features.dart';

import 'fake_hap_accessory.dart' show hexOf;

/// The user's Hisense Roku TV, as it advertised `_airplay._tcp` on port
/// 7000.
const _hisenseName = '58in Hisense Roku TV';
const _hisenseTxt = {
  'pk': 'c483e4c5d51722835752eee2ef22d09da2ae8eaf28b314f620eb6293f3f74e2e',
  'gcgl': '0',
  'gid': '00000000-0000-0000-0000-D13C2C48B5B5',
  'psi': '00000000-0000-0000-0000-D13C2C48B5B5',
  'pi': 'D1:3C:2C:48:B5:B5',
  'srcvers': '377.40.00',
  'protovers': '1.1',
  'serialNumber': 'a2ac20cd-f3e6-5a59-bd01-ffdd4a36c7f1',
  'manufacturer': 'Hisense',
  'integrator': 'Roku',
  'model': 'G204X',
  'flags': '0x244',
  'at': '0x1',
  'fv': 'p20.16.04.842',
  'rsf': '0x3',
  'fex': '0Ip/AEbPiwNACA',
  'features': '0x7F8AD0,0x38BCF46',
  'deviceid': 'D1:3C:2C:48:B5:B5',
  'acl': '0',
};

AirPlayDeviceInfo _info(Map<String, String> txt, {String name = 'TV'}) =>
    AirPlayDeviceInfo.fromTxt(name: name, txt: txt);

void main() {
  group('the Hisense Roku TV', () {
    final tv = _info(_hisenseTxt, name: _hisenseName);

    test('names and ids', () {
      expect(tv.name, _hisenseName);
      expect(tv.model, 'G204X');
      expect(tv.manufacturer, 'Hisense');
      expect(tv.deviceId, 'D1:3C:2C:48:B5:B5');
      expect(tv.pairingId, 'D1:3C:2C:48:B5:B5');
      expect(tv.sourceVersion, '377.40.00');
      expect(hexOf(tv.publicKey!), _hisenseTxt['pk']);
      expect(tv.accessControl, 0);
      expect(tv.pairingDisabled, isFalse);
    });

    test('features: HIGH is the top 32 bits', () {
      // ignore: avoid_js_rounded_ints, the VM's 64-bit int.
      expect(tv.features.value, 0x038BCF46007F8AD0);
      expect(tv.features.videoV1, isFalse);
      expect(tv.features.videoHttpLiveStreams, isTrue);
      expect(tv.features.screen, isTrue);
      expect(tv.features.audio, isTrue);
      expect(tv.features.authentication4, isFalse);
      expect(tv.features.videoPlayQueue, isTrue);
      expect(tv.features.unifiedMediaControl, isTrue);
      expect(tv.features.systemPairing, isTrue);
      expect(tv.features.hkPairingAndAccessControl, isTrue);
      expect(tv.features.coreUtilsPairingAndEncryption, isTrue);
      expect(tv.features.airPlayVideoV2, isTrue);
      expect(tv.features.unifiedPairSetupAndMfi, isTrue);
    });

    test('a PIN the first time (0x200), no password, AirPlay 2, video', () {
      expect(tv.statusFlags, 0x244);
      expect(tv.needsPin, isTrue);
      expect(tv.needsPassword, isFalse);
      expect(tv.usesAirPlay2, isTrue);
      expect(tv.playsVideoUrls, isTrue);
      expect(tv.supportsTransientPairing, isTrue);
    });
  });

  group('AirPlayFeatures.parse', () {
    // pyatv's tests/protocols/airplay/test_utils.py.
    test('one number and two', () {
      expect(AirPlayFeatures.parse('0x00000001').value, 1);
      expect(AirPlayFeatures.parse('0x40000003').value, 0x40000003);
      expect(AirPlayFeatures.parse('0x00000003,0x00000001').value, 0x100000003);
    });

    test('a short LOW does not slide HIGH (unlike pyatv)', () {
      expect(AirPlayFeatures.parse('0x1,0x1').value, 0x100000001);
    });

    test('bit 63', () {
      final features = AirPlayFeatures.parse('0x0,0x80000000');
      expect(features.has(63), isTrue);
      expect(features.has(62), isFalse);
      expect(features.has(64), isFalse);
      expect(features.toString(), 'AirPlayFeatures(0x8000000000000000)');
    });

    test('anything else is no features, never a throw', () {
      for (final bad in [
        'foo',
        '1234',
        '0x00000001,',
        ',0x00000001',
        '0x00000001,0x00000001,0x00000001',
        '0x123456789',
        '0xZZ',
        '',
        null,
      ]) {
        expect(AirPlayFeatures.parse(bad).value, 0, reason: '$bad');
      }
    });

    test('upper-case 0X and spaces are fine', () {
      expect(AirPlayFeatures.parse(' 0X10 ').videoHttpLiveStreams, isTrue);
    });
  });

  group('AirPlayDeviceInfo.fromTxt', () {
    test('password: pw true, or flag 0x80', () {
      expect(_info({}).needsPassword, isFalse);
      expect(_info({'pw': 'false'}).needsPassword, isFalse);
      expect(_info({'pw': 'true'}).needsPassword, isTrue);
      expect(_info({'pw': 'TRUE'}).needsPassword, isTrue);
      expect(_info({'sf': '0x1'}).needsPassword, isFalse);
      expect(_info({'sf': '0x80'}).needsPassword, isTrue);
      expect(_info({'flags': '0x80'}).needsPassword, isTrue);
    });

    test('a PIN: flag 0x8 or 0x200', () {
      expect(_info({'sf': '0x1'}).needsPin, isFalse);
      expect(_info({'sf': '0x200'}).needsPin, isTrue);
      expect(_info({'flags': '0x200'}).needsPin, isTrue);
      expect(_info({'flags': '0x8'}).needsPin, isTrue);
      expect(_info({'flags': '0x0'}).needsPin, isFalse);
    });

    test('sf before flags, an empty one skipped (as pyatv)', () {
      expect(_info({'sf': '0x8', 'flags': '0x0'}).statusFlags, 0x8);
      expect(_info({'sf': '', 'flags': '0x80'}).statusFlags, 0x80);
      expect(_info({'ft': '0x10'}).features.videoHttpLiveStreams, isTrue);
    });

    test('AirPlay 2 is bit 38 or 48; video is bit 0, 4, 33 or 49', () {
      expect(_info({'features': '0x0,0x40'}).usesAirPlay2, isTrue);
      expect(_info({'features': '0x0,0x10000'}).usesAirPlay2, isTrue);
      expect(_info({'features': '0x1'}).usesAirPlay2, isFalse);
      for (final features in ['0x1', '0x10', '0x0,0x2', '0x0,0x20000']) {
        expect(_info({'features': features}).playsVideoUrls, isTrue);
      }
      expect(_info({'features': '0x200'}).playsVideoUrls, isFalse);
    });

    test('keys without case; bad values absent, never a throw', () {
      final info = _info({
        'Model': ' AppleTV6,2 ',
        'FLAGS': 'nonsense',
        'pk': 'abc',
        'acl': 'x',
        'features': '0xQQ',
      }, name: '\u0000');
      expect(info.model, 'AppleTV6,2');
      expect(info.name, 'AppleTV6,2');
      expect(info.statusFlags, 0);
      expect(info.publicKey, isNull);
      expect(info.accessControl, isNull);
      expect(info.features.value, 0);
      expect(_info({}, name: '').name, 'AirPlay device');
      expect(_info({'flags': '-1'}).statusFlags, 0);
    });

    test('acl 1 is pairing disabled', () {
      expect(_info({'acl': '1'}).pairingDisabled, isTrue);
    });
  });
}
