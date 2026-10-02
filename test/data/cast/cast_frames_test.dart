import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/cast/cast_frames.dart';

void main() {
  test('a frame is a 4-byte big-endian length and the body', () {
    expect(castFrame([7, 8, 9]), [0, 0, 0, 3, 7, 8, 9]);
    expect(castFrame(List.filled(300, 1)).sublist(0, 4), [0, 0, 1, 44]);
  });

  test('reads a frame split at every possible point', () {
    final bytes = [
      ...castFrame([1, 2, 3, 4, 5]),
      ...castFrame([6]),
    ];
    for (var cut = 0; cut <= bytes.length; cut++) {
      final reader = CastFrameReader();
      final frames = [
        ...reader.add(bytes.sublist(0, cut)),
        ...reader.add(bytes.sublist(cut)),
      ];
      expect(frames, [
        [1, 2, 3, 4, 5],
        [6],
      ], reason: 'cut at $cut');
    }
  });

  test('reads several frames in one read, and an empty one', () {
    final reader = CastFrameReader();
    expect(
      reader.add([
        ...castFrame([1]),
        ...castFrame([]),
        ...castFrame([2]),
      ]),
      [
        [1],
        <int>[],
        [2],
      ],
    );
  });

  test('a frame of exactly 64 KiB is read; one byte more stops', () {
    final reader = CastFrameReader();
    expect(
      reader.add(castFrame(Uint8List(castMaxFrame))).single,
      hasLength(castMaxFrame),
    );
    final over = CastFrameReader();
    expect(over.add([0, 1, 0, 1]), isEmpty);
    expect(over.failed, isTrue);
    // Nothing after can be trusted to start a frame.
    expect(over.add(castFrame([1])), isEmpty);
  });

  test('the frames before an oversized length are still returned', () {
    final reader = CastFrameReader();
    expect(
      reader.add([
        ...castFrame([5]),
        0xff,
        0xff,
        0xff,
        0xff,
      ]),
      [
        [5],
      ],
    );
    expect(reader.failed, isTrue);
  });

  test('fuzz: random frames in random reads come out whole', () {
    final random = Random(14);
    for (var round = 0; round < 500; round++) {
      final bodies = [
        for (var i = 0; i < random.nextInt(8); i++)
          [for (var j = 0; j < random.nextInt(600); j++) random.nextInt(256)],
      ];
      final stream = [for (final body in bodies) ...castFrame(body)];
      final reader = CastFrameReader();
      final read = <List<int>>[];
      var offset = 0;
      while (offset < stream.length) {
        final take = min(1 + random.nextInt(97), stream.length - offset);
        read.addAll(reader.add(stream.sublist(offset, offset + take)));
        offset += take;
      }
      expect(read, bodies, reason: 'round $round');
    }
  });

  test('fuzz: random bytes never throw', () {
    final random = Random(15);
    for (var round = 0; round < 2000; round++) {
      final reader = CastFrameReader(maxFrame: 64);
      for (var read = 0; read < 5; read++) {
        reader.add([
          for (var i = 0; i < random.nextInt(40); i++) random.nextInt(256),
        ]);
      }
    }
  });
}
