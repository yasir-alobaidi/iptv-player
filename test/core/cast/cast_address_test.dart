import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';

void main() {
  group('CastAddress.tryParse', () {
    const good = {
      '192.168.1.60': CastAddress('192.168.1.60'),
      '  192.168.1.60  ': CastAddress('192.168.1.60'),
      '192.168.1.60:8009': CastAddress('192.168.1.60'),
      '127.0.0.1:41234': CastAddress('127.0.0.1', 41234),
      'tv.local': CastAddress('tv.local'),
      'living-room-tv': CastAddress('living-room-tv'),
      'tv.local:8009': CastAddress('tv.local'),
      'fe80::1': CastAddress('fe80::1'),
      '2600:4040::89c3': CastAddress('2600:4040::89c3'),
      '[fe80::1]': CastAddress('fe80::1'),
      '[fe80::1]:9000': CastAddress('fe80::1', 9000),
      'fe80::1%wlo1': CastAddress('fe80::1%wlo1'),
    };
    for (final MapEntry(key: text, value: address) in good.entries) {
      test('reads "$text"', () {
        expect(CastAddress.tryParse(text), address);
      });
    }

    const bad = [
      '',
      '   ',
      '192.168.1.256',
      '192.168.1',
      '192.168.1.60:',
      '192.168.1.60:0',
      '192.168.1.60:70000',
      '192.168.1.60:80a',
      'http://192.168.1.60',
      'user@192.168.1.60',
      'living room tv',
      '-tv.local',
      '[fe80::1',
      '[fe80::1]x',
      '[tv.local]:8009',
      'a:b:c',
      '1.2.3.4.5',
    ];
    for (final text in bad) {
      test('refuses "$text"', () {
        expect(CastAddress.tryParse(text), isNull);
      });
    }
  });

  test('prints as typed, with the port only when it is not 8009', () {
    expect('${const CastAddress('192.168.1.60')}', '192.168.1.60');
    expect('${const CastAddress('127.0.0.1', 41234)}', '127.0.0.1:41234');
    expect('${const CastAddress('fe80::1', 9000)}', '[fe80::1]:9000');
  });
}
