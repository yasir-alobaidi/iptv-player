import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/tlv8.dart';

void main() {
  // pyatv's tests/auth/test_hap_tlv8.py vectors.
  group('writeTlv8', () {
    test('one item is its type, length and value', () {
      expect(writeTlv8({10: '123'.codeUnits}), [0x0A, 0x03, 0x31, 0x32, 0x33]);
    });

    test('items keep the map order', () {
      expect(writeTlv8({1: '111'.codeUnits, 4: '222'.codeUnits}), [
        0x01, 0x03, 0x31, 0x31, 0x31, //
        0x04, 0x03, 0x32, 0x32, 0x32,
      ]);
    });

    test('a value over 255 bytes is split into consecutive items', () {
      final bytes = writeTlv8({2: List.filled(256, 0x31)});
      expect(bytes, [2, 0xFF, ...List.filled(255, 0x31), 2, 1, 0x31]);
    });

    test('a value of exactly 255 bytes is one item; 510 is two', () {
      expect(writeTlv8({3: List.filled(255, 7)}), hasLength(257));
      expect(writeTlv8({3: List.filled(510, 7)}), hasLength(514));
    });

    test('an empty value is an item of length 0 (a separator)', () {
      expect(
        writeTlv8Items([
          (TlvType.identifier, [1]),
          (TlvType.separator, const []),
          (TlvType.identifier, [2]),
        ]),
        [1, 1, 1, 0xFF, 0, 1, 1, 2],
      );
    });
  });

  group('readTlv8', () {
    test('reads one item and two', () {
      expect(readTlv8([0x0A, 0x03, 0x31, 0x32, 0x33]), {10: '123'.codeUnits});
      expect(readTlv8([1, 3, 0x31, 0x31, 0x31, 4, 3, 0x32, 0x32, 0x32]), {
        1: '111'.codeUnits,
        4: '222'.codeUnits,
      });
    });

    test('joins a value split over 255 bytes', () {
      final value = List.generate(700, (i) => i % 256);
      expect(readTlv8(writeTlv8({TlvType.publicKey: value})), {
        TlvType.publicKey: value,
      });
    });

    test('joins every item of a type, as pyatv', () {
      expect(readTlv8([1, 1, 0xA, 2, 1, 0xB, 1, 1, 0xC]), {
        1: [0xA, 0xC],
        2: [0xB],
      });
    });

    test('a truncated last item is dropped, never thrown', () {
      expect(readTlv8([6, 1, 2, 3, 5, 1, 2]), {
        6: [2],
      });
      expect(readTlv8([6, 1, 2, 3]), {
        6: [2],
      });
      expect(readTlv8([]), isEmpty);
      expect(readTlv8([7]), isEmpty);
    });

    test('an empty item reads as an empty value', () {
      expect(readTlv8([0xFF, 0, 6, 1, 4]), {
        0xFF: <int>[],
        6: [4],
      });
    });

    test('fuzz: random bytes never throw', () {
      final random = Random(3);
      for (var round = 0; round < 2000; round++) {
        final bytes = List.generate(
          random.nextInt(40),
          (_) => random.nextInt(256),
        );
        readTlv8(bytes);
        readTlv8Items(bytes);
      }
    });
  });

  group('readTlv8Items', () {
    test('joins consecutive fragments and keeps separators', () {
      final bytes = writeTlv8Items([
        (TlvType.identifier, List.filled(300, 1)),
        (TlvType.separator, const []),
        (TlvType.identifier, [2]),
        (TlvType.permissions, [1]),
      ]);
      final items = readTlv8Items(bytes);
      expect(items.map((item) => item.$1), [
        TlvType.identifier,
        TlvType.separator,
        TlvType.identifier,
        TlvType.permissions,
      ]);
      expect(items[0].$2, List.filled(300, 1));
      expect(items[2].$2, [2]);
    });
  });

  test('readTlvInt reads little-endian numbers', () {
    expect(readTlvInt([2]), 2);
    expect(readTlvInt([0x02, 0x00]), 2);
    expect(readTlvInt([0x2C, 0x01]), 300);
    expect(readTlvInt([]), isNull);
    expect(readTlvInt(null), isNull);
    expect(readTlvInt(List.filled(8, 1)), isNull);
  });

  group('describeTlv8', () {
    test('names the method, state, error and back-off', () {
      expect(
        describeTlv8({
          TlvType.method: [0],
          TlvType.state: [1],
          TlvType.error: [3],
          TlvType.backOff: [1, 0],
        }),
        'Method=PairSetup, State=M1, Error=BackOff, BackOff=1s',
      );
      expect(
        describeTlv8({
          TlvType.method: [2],
        }),
        'Method=PairVerify',
      );
      expect(
        describeTlv8({
          TlvType.error: [5],
        }),
        'Error=MaxTries',
      );
    });

    test('everything else only by its length', () {
      expect(
        describeTlv8({
          TlvType.salt: List.filled(16, 9),
          TlvType.proof: List.filled(64, 9),
          TlvType.flags: [0x10],
        }),
        'Salt=16bytes, Proof=64bytes, Flags=1bytes',
      );
    });

    test('unknown values in hex', () {
      expect(
        describeTlv8({
          TlvType.method: [0xAA],
          TlvType.state: [0xAB],
          TlvType.error: [0xAC],
          0xAD: [1, 2, 3],
        }),
        'Method=0xaa, State=0xab, Error=0xac, 0xad=3bytes',
      );
    });
  });
}
