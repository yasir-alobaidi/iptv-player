import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/data/cast/cast_txt.dart';

/// Living Room TV's TXT record as Avahi listed it (ids made up, same
/// shape), and the Nest Mini beside it.
const _tvTxt = [
  'rs=Televizo',
  'rr=AndroidNativeApp',
  'ct=7D21A9',
  'nf=1',
  'bs=0A1B2C3D4E5F',
  'st=1',
  'ca=465413',
  'fn=Living Room TV',
  'ic=/setup/icon.png',
  'md=Chromecast',
  've=05',
  'rm=2C7E91A04F6B3D58',
  'cd=9A0E3C7B55D1428F6B2C0E91D4A7F318',
  'id=4f1c9e27a0b35d68c2e71f094ab6d3e5',
];
const _speakerTxt = [
  'rs=',
  'nf=1',
  'st=0',
  'ca=198660',
  'fn=Living Room speaker',
  'md=Google Nest Mini',
  'id=8d3a5f0c1e2b4a6978c5d0e1f2a3b4c5',
];
const _tvInstance = 'Chromecast-4f1c9e27a0b35d68c2e71f094ab6d3e5';

CastAddressAnswer? _read(
  List<String> txt, {
  String instance = _tvInstance,
  List<String> hosts = const ['192.168.1.60'],
  int? port = 8009,
}) => readCastService(
  instance: instance,
  txt: parseTxtStrings(txt),
  hosts: hosts,
  port: port,
);

CastDevice _device(CastAddressAnswer? answer) =>
    (answer! as CastDeviceAnswered).device;

void main() {
  group('parseTxtStrings', () {
    test('reads key=value pairs, keys without case', () {
      expect(parseTxtStrings(['fn=TV', 'MD=Chromecast', 'ca=5']), {
        'fn': 'TV',
        'md': 'Chromecast',
        'ca': '5',
      });
    });

    test('the first of a repeated key wins', () {
      expect(parseTxtStrings(['fn=First', 'FN=Second']), {'fn': 'First'});
    });

    test('a value keeps its own = signs and spaces', () {
      expect(parseTxtStrings(['fn= a=b ']), {'fn': ' a=b '});
    });

    test('no = is an empty value; an empty key is skipped', () {
      expect(parseTxtStrings(['flag', '=x', '', ' =y']), {'flag': ''});
    });
  });

  group('readCastService', () {
    test('Living Room TV as it announces itself', () {
      expect(
        _device(_read(_tvTxt)),
        const CastDevice(
          id: '4f1c9e27a0b35d68c2e71f094ab6d3e5',
          name: 'Living Room TV',
          model: 'Chromecast',
          host: '192.168.1.60',
          capabilities: 465413,
          status: 'Televizo',
        ),
      );
    });

    test('a speaker (no video out) is audio only, by its name', () {
      final answer = _read(
        _speakerTxt,
        instance: 'Google-Nest-Mini-8d3a5f0c1e2b4a6978c5d0e1f2a3b4c5',
      );
      expect(answer, isA<CastAudioOnlyAnswered>());
      expect((answer! as CastAudioOnlyAnswered).name, 'Living Room speaker');
    });

    test('an empty rs is running nothing', () {
      expect(_device(_read(['ca=5', 'rs=', 'id=aa', 'fn=TV'])).status, isNull);
    });

    group('odd records', () {
      test('no fn: the model is the name', () {
        expect(
          _device(_read(['md=Chromecast Ultra', 'ca=5'])).name,
          'Chromecast Ultra',
        );
      });

      test('no fn and no md: the instance name without its id', () {
        final device = _device(_read(['ca=5']));
        expect(device.name, 'Chromecast');
        expect(device.model, isNull);
      });

      test('nothing at all: still listed, as "Cast device"', () {
        final device = _device(
          _read(const [], instance: '4f1c9e27a0b35d68c2e71f094ab6d3e5'),
        );
        expect(device.name, 'Cast device');
        expect(device.id, '4f1c9e27a0b35d68c2e71f094ab6d3e5');
      });

      test('no id: the 32 hex digits the instance name ends in', () {
        expect(
          _device(_read(['fn=TV'])).id,
          '4f1c9e27a0b35d68c2e71f094ab6d3e5',
        );
      });

      test('no id and no hex tail: the instance name, lower case', () {
        expect(
          _device(_read(['fn=TV'], instance: 'Bedroom TV')).id,
          'bedroom tv',
        );
      });

      test('an id in capitals reads the same as in lower case', () {
        expect(
          _device(_read(['id=4F1C9E27A0B35D68C2E71F094AB6D3E5'])).id,
          '4f1c9e27a0b35d68c2e71f094ab6d3e5',
        );
      });

      for (final ca in ['', 'x', '0x5', '4654 13', '9999999999999999999999']) {
        test('a ca of "$ca" is no bits: listed', () {
          final device = _device(_read(['fn=TV', 'ca=$ca']));
          expect(device.capabilities, isNull);
        });
      }

      test('a name with control characters, runs of spaces and U+FFFD', () {
        expect(
          _device(_read(['fn=\u0000Living\t\tRoom\uFFFD TV\n'])).name,
          'Living Room TV',
        );
      });

      test('a name of spaces only falls back to the model', () {
        expect(_device(_read(['fn=   ', 'md=Chromecast'])).name, 'Chromecast');
      });

      test('a very long name is cut at 100 characters', () {
        final name = _device(_read(['fn=${'Ä' * 300}'])).name;
        expect(name.runes.length, 100);
      });

      test('Arabic and emoji names are kept', () {
        expect(_device(_read(['fn=تلفاز الصالة 📺'])).name, 'تلفاز الصالة 📺');
      });

      test('a port outside 1–65535 is 8009', () {
        expect(_device(_read(_tvTxt, port: 0)).port, 8009);
        expect(_device(_read(_tvTxt, port: 70000)).port, 8009);
        expect(_device(_read(_tvTxt, port: null)).port, 8009);
        expect(_device(_read(_tvTxt, port: 9000)).port, 9000);
      });

      test('no address: nothing to list', () {
        expect(_read(_tvTxt, hosts: const []), isNull);
        expect(_read(_tvTxt, hosts: const ['', ' ']), isNull);
      });
    });
  });

  group('preferredHost', () {
    test('IPv4 first, whatever the order', () {
      expect(
        preferredHost(['2600:4040::89c3', 'fe80::1', '192.168.1.60']),
        '192.168.1.60',
      );
    });

    test('then a global IPv6 address before a link-local one', () {
      expect(preferredHost(['fe80::1', '2600:4040::89c3']), '2600:4040::89c3');
    });

    test('then anything', () {
      expect(preferredHost(['fe80::1']), 'fe80::1');
      expect(preferredHost(['tv.local']), 'tv.local');
      expect(preferredHost(const []), isNull);
    });
  });
}
