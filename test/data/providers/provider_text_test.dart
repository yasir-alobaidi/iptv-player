import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/providers/provider_text.dart';
import 'package:iptv_player/data/providers/xtream/tolerant_json.dart';

void main() {
  group('cleanText', () {
    test('decodes named, decimal and hex entities, astral ones too', () {
      expect(cleanText('A &amp; B &#233; &#x1F600;'), 'A & B é 😀');
    });

    test('leaves entities it cannot decode as they were', () {
      expect(cleanText('&#xD800;'), '&#xD800;');
      expect(cleanText('&#99999999;'), '&#99999999;');
    });

    test('blank is null', () {
      expect(cleanText(null), isNull);
      expect(cleanText(''), isNull);
      expect(cleanText(' \t\n\u00a0 '), isNull);
    });
  });

  group('cleanImageUrl', () {
    test('keeps http(s) URLs with a host and a path', () {
      expect(
        cleanImageUrl(' https://img.test/a.png?x=1 '),
        'https://img.test/a.png?x=1',
      );
    });

    test('drops relative, hostless, other schemes, bare hosts', () {
      for (final junk in [
        'a.png',
        '/a.png',
        'http:///a.png',
        'data:image/png;base64,AAAA',
        'file:///a.png',
        'https://img.test',
        'https://img.test/',
      ]) {
        expect(cleanImageUrl(junk), isNull, reason: junk);
      }
    });
  });

  group('tolerant readers', () {
    test('ints from every shape panels send', () {
      expect(
        [12, 12.9, '12', ' 12 ', '12.0', '', 'x', null, true].map(readInt),
        [12, 12, 12, 12, 12, null, null, null, null],
      );
    });

    test('booleans from every shape panels send', () {
      expect(
        [1, 0, '1', '0', 'true', 'false', '', 'maybe', null].map(readBool),
        [true, false, true, false, true, false, false, null, null],
      );
    });

    test('ids read the same whether a number or a string', () {
      expect(readString(101), '101');
      expect(readString(101.0), '101');
      expect(readString(' 101 '), '101');
      expect(readString(''), isNull);
    });

    test('zero and negative timestamps mean none', () {
      expect(readUnixTime('0'), isNull);
      expect(readUnixTime(-5), isNull);
      expect(readUnixTime('1726000000')!.isUtc, isTrue);
    });
  });
}
