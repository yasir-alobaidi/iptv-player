import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/binary_plist.dart';

import 'airplay_vectors.dart';
import 'fake_hap_accessory.dart' show unhex;

/// The dictionary `plistSample` is Python's
/// `plistlib.dumps(…, fmt=FMT_BINARY, sort_keys=False)` of.
Map<String, Object?> _sample() => {
  'Content-Location': 'http://192.168.1.10:8080/stream.m3u8',
  'Start-Position': 0.0,
  'uuid': 'E1D4A7A2-4C5B-4B8E-9F0A-3D2C1B0A9F8E',
  'rate': 1.0,
  'count': 300,
  'big': 70000,
  'huge': 5000000000,
  'neg': -2,
  'yes': true,
  'no': false,
  'data': Uint8List.fromList([0, 1, 2]),
  'when': DateTime.utc(2026, 10, 27, 12, 30, 15),
  'name': 'Café ☕',
  'list': [
    'rate',
    1,
    1.0,
    true,
    ['nested'],
    <String, Object?>{},
  ],
  'dict': {'rate': 'rate', 'count': 300},
  'long': 'x' * 20,
};

Object? _value(PlistReadResult result) => switch (result) {
  PlistRead(:final value) => value,
  PlistUnreadable(:final reason) => fail('unreadable: $reason'),
};

/// A plist by hand: [objects] after the header, each object's bytes, the
/// offsets of 1 byte, refs of 1 byte, [top] the root.
Uint8List _handMade(List<List<int>> objects, {int top = 0}) {
  final out = <int>[...'bplist00'.codeUnits];
  final offsets = <int>[];
  for (final object in objects) {
    offsets.add(out.length);
    out.addAll(object);
  }
  final table = out.length;
  out.addAll(offsets);
  final trailer = ByteData(32)
    ..setUint8(6, 1)
    ..setUint8(7, 1)
    ..setUint64(8, objects.length)
    ..setUint64(16, top)
    ..setUint64(24, table);
  out.addAll(trailer.buffer.asUint8List());
  return Uint8List.fromList(out);
}

void main() {
  group('writeBinaryPlist', () {
    test("writes exactly Python plistlib's bytes", () {
      expect(writeBinaryPlist(_sample()), unhex(plistSample));
    });

    test('sorts keys when asked, as plistlib by default', () {
      expect(
        writeBinaryPlist({
          'b': 1,
          'a': [2, 'b'],
        }, sortKeys: true),
        unhex(plistSorted),
      );
    });

    test('two-byte refs past 255 objects', () {
      final many = {
        for (var i = 0; i < 140; i++) 'key${'$i'.padLeft(3, '0')}': i,
      };
      expect(writeBinaryPlist(many), unhex(plistMany));
    });

    test('long strings, data and arrays carry an integer length', () {
      final value = {
        'text': 'y' * 300,
        'data': Uint8List(70000),
        'list': List.filled(20, 0),
      };
      expect(_value(readBinaryPlist(writeBinaryPlist(value))), value);
    });

    test('the same container twice is written once, equal ones twice', () {
      final shared = ['x'];
      final once = writeBinaryPlist([shared, shared]);
      final twice = writeBinaryPlist([
        ['x'],
        ['x'],
      ]);
      expect(twice.length, greaterThan(once.length));
      expect(_value(readBinaryPlist(once)), [
        ['x'],
        ['x'],
      ]);
    });

    test('UIDs, null and extreme integers round-trip', () {
      final value = [
        const PlistUid(5),
        const PlistUid(70000),
        null,
        -1 << 63,
        (1 << 63) - 1,
        0,
        255,
        256,
        double.infinity,
      ];
      expect(_value(readBinaryPlist(writeBinaryPlist(value))), value);
    });

    test('a value that is no plist type is an ArgumentError', () {
      expect(() => writeBinaryPlist({'a': Object()}), throwsArgumentError);
      expect(() => writeBinaryPlist({1: 'a'}), throwsArgumentError);
    });
  });

  group('readBinaryPlist', () {
    test("reads Python plistlib's bytes back", () {
      expect(_value(readBinaryPlist(unhex(plistSample))), _sample());
    });

    test('keeps the dictionary order of the file', () {
      final dict = readBinaryPlistDict(unhex(plistSample))!;
      expect(dict.keys.take(3), ['Content-Location', 'Start-Position', 'uuid']);
    });

    test('reads float32 reals, 16-byte integers, sets and UTF-16', () {
      final bytes = _handMade([
        [0xA4, 1, 2, 3, 4],
        [0x22, 0x3F, 0xC0, 0x00, 0x00], // 1.5 as float32
        [0x14, ...List.filled(15, 0), 7], // 7 in 16 bytes
        [0xC1, 1], // a set
        [0x62, 0x00, 0x68, 0x00, 0xE9], // "hé" in UTF-16BE
      ]);
      expect(_value(readBinaryPlist(bytes)), [
        1.5,
        7,
        [1.5],
        'hé',
      ]);
    });

    test('a dictionary key that is not a string is skipped', () {
      final bytes = _handMade([
        [0xD2, 1, 2, 3, 4],
        [0x10, 1],
        [0x51, 0x6B],
        [0x51, 0x61],
        [0x51, 0x62],
      ]);
      expect(_value(readBinaryPlist(bytes)), {'k': 'b'});
    });

    test('readBinaryPlistDict is null for another root or bad bytes', () {
      expect(readBinaryPlistDict(writeBinaryPlist([1])), isNull);
      expect(readBinaryPlistDict([1, 2, 3]), isNull);
      expect(readBinaryPlistDict(writeBinaryPlist({'a': 1})), {'a': 1});
    });

    group('is unreadable, never a throw, for', () {
      void unreadable(String what, List<int> bytes) {
        test(what, () {
          expect(readBinaryPlist(bytes), isA<PlistUnreadable>());
        });
      }

      final good = writeBinaryPlist({
        'a': [1, 'b'],
      });
      unreadable('nothing', const []);
      unreadable('another header', [...'bplist01'.codeUnits, ...good.skip(8)]);
      unreadable('a cut trailer', good.sublist(0, good.length - 1));
      unreadable('an XML plist', '<?xml version="1.0"?><plist/>'.codeUnits);
      unreadable(
        'an object that contains itself',
        _handMade([
          [0xA1, 0],
        ]),
      );
      unreadable(
        'a reference past the objects',
        _handMade([
          [0xA1, 9],
        ]),
      );
      unreadable(
        'a length past the end',
        _handMade([
          [0x4F, 0x10, 200, 1, 2],
        ]),
      );
      unreadable(
        'an unknown marker',
        _handMade([
          [0x70],
        ]),
      );
      unreadable(
        'a 16-byte integer too big',
        _handMade([
          [0x14, 1, ...List.filled(15, 0)],
        ]),
      );
      unreadable(
        'a top object past the count',
        _handMade([
          [0x10, 1],
        ], top: 3),
      );
      unreadable(
        'an absurd date',
        _handMade([
          [0x33, 0x7F, 0xF0, 0, 0, 0, 0, 0, 0],
        ]),
      );
      final huge = Uint8List.fromList(good);
      ByteData.sublistView(huge).setUint64(huge.length - 24, 1 << 40);
      unreadable('an object count past the bytes', huge);
      final negative = Uint8List.fromList(good);
      ByteData.sublistView(negative).setUint64(negative.length - 8, -1);
      unreadable('an offset table at 2^64 − 1', negative);
    });

    test('nesting past 512 levels is unreadable, not a stack overflow', () {
      // Object i is an array holding object i + 1 (2-byte refs and
      // offsets); the last is an int.
      const depth = 600;
      final objects = [
        for (var i = 0; i < depth; i++) [0xA1, (i + 1) >> 8, (i + 1) & 0xFF],
        [0x10, 1],
      ];
      final out = <int>[...'bplist00'.codeUnits];
      final offsets = <int>[];
      for (final object in objects) {
        offsets.add(out.length);
        out.addAll(object);
      }
      final table = out.length;
      for (final offset in offsets) {
        out.addAll((ByteData(2)..setUint16(0, offset)).buffer.asUint8List());
      }
      final trailer = ByteData(32)
        ..setUint8(6, 2)
        ..setUint8(7, 2)
        ..setUint64(8, objects.length)
        ..setUint64(16, 0)
        ..setUint64(24, table);
      out.addAll(trailer.buffer.asUint8List());
      expect(readBinaryPlist(out), isA<PlistUnreadable>());
    });

    test('fuzz: mutated plists never throw', () {
      final random = Random(11);
      final good = unhex(plistSample);
      for (var round = 0; round < 3000; round++) {
        final bytes = Uint8List.fromList(good);
        for (var flips = random.nextInt(4) + 1; flips > 0; flips--) {
          bytes[random.nextInt(bytes.length)] = random.nextInt(256);
        }
        final cut = random.nextBool()
            ? bytes
            : bytes.sublist(0, random.nextInt(bytes.length));
        expect(
          () => readBinaryPlist(cut),
          returnsNormally,
          reason: 'round $round',
        );
      }
    });
  });
}
