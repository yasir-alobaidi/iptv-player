import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/cast/relay/fmp4_timeline.dart';

import 'support/fmp4_samples.dart';

/// The relay's continuous stream on a file's own clock (docs/04 "The TV's
/// own bar"): the length in the header, every fragment counted from where
/// the stream begins in the file.
void main() {
  Uint8List rewrite(
    List<int> stream, {
    Duration start = const Duration(seconds: 10),
    Duration? length = const Duration(seconds: 60),
    List<int>? cuts,
  }) {
    final timeline = Fmp4Timeline(start: start, length: length);
    final out = BytesBuilder();
    var at = 0;
    for (final cut in [...?cuts, stream.length]) {
      out.add(timeline.add(stream.sublist(at, cut)));
      at = cut;
    }
    out.add(timeline.close());
    return out.takeBytes();
  }

  int mvhd(Uint8List file) => timeField(file, ['moov', 'mvhd'], v0: 16, v1: 24);
  int tkhd(Uint8List file, int nth) =>
      timeField(file, ['moov', 'trak', 'tkhd'], v0: 20, v1: 28, nth: nth);
  int mdhd(Uint8List file, int nth) => timeField(
    file,
    ['moov', 'trak', 'mdia', 'mdhd'],
    v0: 16,
    v1: 24,
    nth: nth,
  );
  int mehd(Uint8List file) =>
      timeField(file, ['moov', 'mvex', 'mehd'], v0: 4, v1: 4);
  int tfdt(Uint8List file, {required int fragment, required int track}) =>
      timeField(
        file,
        ['moof', 'traf', 'tfdt'],
        v0: 4,
        v1: 4,
        nth: fragment * 2 + track,
      );

  test('a file from 10 s of 60 s: the length in the header, each '
      'fragment counted from 10 s, the index left out', () {
    final stream = sampleStream();
    final out = rewrite(stream);

    // The movie's timescale is 1000; the tracks' 16000 and 48000.
    expect(mvhd(out), 60000);
    expect(tkhd(out, 0), 60000, reason: 'version 0');
    expect(tkhd(out, 1), 60000, reason: 'version 1');
    expect(mdhd(out, 0), 60 * 16000);
    expect(mdhd(out, 1), 60 * 48000);
    expect(mehd(out), 60000);
    expect(
      findBox(out, ['moov', 'mvex', 'mehd'])!.body,
      lessThan(findBox(out, ['moov', 'mvex', 'trex'])!.body),
      reason: 'first in mvex',
    );
    expect(boxSize(out, ['moov']), boxSize(stream, ['moov']) + 20);
    expect(
      boxSize(out, ['moov', 'mvex']),
      boxSize(stream, ['moov', 'mvex']) + 20,
    );

    expect(tfdt(out, fragment: 0, track: 0), 10 * 16000);
    expect(tfdt(out, fragment: 0, track: 1), 10 * 48000, reason: 'version 0');
    expect(tfdt(out, fragment: 1, track: 0), 32000 + 10 * 16000);
    expect(tfdt(out, fragment: 1, track: 1), 96000 + 10 * 48000);

    expect(findBox(out, ['mfra']), isNull);
    // Everything else as it came: the pictures and sound untouched.
    expect(
      out.sublist(findBox(out, ['mdat'], nth: 1)!.body),
      stream.sublist(
        findBox(stream, ['mdat'], nth: 1)!.body,
        findBox(stream, ['mdat'], nth: 1)!.end,
      ),
    );
    expect(findBox(out, ['ftyp']), findBox(stream, ['ftyp']));
    expect(
      out.sublist(
        findBox(out, ['moov', 'udta'])!.body,
        findBox(out, ['moov', 'udta'])!.end,
      ),
      'made by hand'.codeUnits,
    );
    expect(out.length, stream.length + 20 - boxSize(stream, ['mfra']));
  });

  test('cut anywhere, the same bytes come out', () {
    final stream = sampleStream();
    final whole = rewrite(stream);
    expect(
      rewrite(stream, cuts: [for (var i = 1; i < stream.length; i++) i]),
      whole,
      reason: 'a byte at a time',
    );
    for (var cut = 1; cut < stream.length; cut++) {
      expect(rewrite(stream, cuts: [cut]), whole, reason: 'cut at $cut');
    }
    final random = Random(4);
    for (var run = 0; run < 50; run++) {
      final cuts = {
        for (var i = 0; i < 6; i++) 1 + random.nextInt(stream.length - 1),
      }.toList()..sort();
      expect(rewrite(stream, cuts: cuts), whole, reason: 'cuts at $cuts');
    }
  });

  test('a chunk inside the pictures and sound is passed on, not copied', () {
    final timeline = Fmp4Timeline(
      start: const Duration(seconds: 10),
      length: const Duration(seconds: 60),
    );
    final mdat = sampleMdat(10000);
    timeline
      ..add([
        ...sampleFtyp(),
        ...sampleMoov(),
        ...sampleMoof(sequence: 1, decode: {1: 0, 2: 0}),
      ])
      ..add(mdat.sublist(0, 8));
    final inside = Uint8List.fromList(mdat.sublist(8));
    final out = timeline.add(inside);
    expect(out, mdat.sublist(8));
    // The same bytes, not a copy of them.
    inside[0] ^= 0xff;
    expect(out[0], inside[0]);
  });

  test('no length: the header as FFmpeg wrote it, the fragments moved', () {
    final stream = sampleStream();
    final out = rewrite(stream, length: null);
    expect(mvhd(out), 0);
    expect(mdhd(out, 0), 0);
    expect(findBox(out, ['moov', 'mvex', 'mehd']), isNull);
    expect(boxSize(out, ['moov']), boxSize(stream, ['moov']));
    expect(tfdt(out, fragment: 1, track: 0), 32000 + 10 * 16000);
  });

  test('from the start: the length written, the fragments as they were', () {
    final out = rewrite(sampleStream(), start: Duration.zero);
    expect(mvhd(out), 60000);
    expect(tfdt(out, fragment: 0, track: 0), 0);
    expect(tfdt(out, fragment: 1, track: 1), 96000);
  });

  test('an mehd already there is set, not added', () {
    final stream = sampleStream(mehd: true);
    final out = rewrite(stream);
    expect(mehd(out), 60000);
    expect(boxSize(out, ['moov']), boxSize(stream, ['moov']));
    expect(findBox(out, ['moov', 'mvex', 'mehd'], nth: 1), isNull);
  });

  test('a version 1 movie header', () {
    final stream = Uint8List.fromList([
      ...sampleFtyp(),
      ...sampleMoov(mvhdV1: true),
      ...sampleMoof(sequence: 1, decode: {1: 0, 2: 0}),
      ...sampleMdat(10),
    ]);
    final out = rewrite(stream);
    expect(mvhd(out), 60000);
    expect(mehd(out), 60000);
  });

  test("a data offset from the stream's start moves with the header", () {
    final stream = sampleStream(baseDataOffset: 5000);
    final out = rewrite(stream);
    final tfhd = findBox(out, ['moof', 'traf', 'tfhd'])!;
    expect(ByteData.sublistView(out).getUint64(tfhd.body + 8), 5020);
  });

  test('a 64-bit size box passes', () {
    final wide = mp4WideBox('mdat', List.filled(40, 9));
    final stream = Uint8List.fromList([
      ...sampleFtyp(),
      ...sampleMoov(),
      ...sampleMoof(sequence: 1, decode: {1: 0, 2: 0}),
      ...wide,
      ...sampleMoof(sequence: 2, decode: {1: 32000, 2: 96000}),
      ...sampleMdat(5),
    ]);
    final out = rewrite(stream, cuts: [100, 300, stream.length - 30]);
    final passed = findBox(out, ['mdat'])!;
    expect(passed.end - passed.body, 40);
    expect(out.sublist(passed.body, passed.end), List.filled(40, 9));
    expect(tfdt(out, fragment: 1, track: 0), 32000 + 10 * 16000);
  });

  test('not an MP4: the rest goes on untouched', () {
    final junk = Uint8List.fromList([0, 0, 0, 3, ...'junk'.codeUnits, 1, 2]);
    final stream = Uint8List.fromList([
      ...sampleFtyp(),
      ...junk,
      ...sampleMoov(),
    ]);
    final out = rewrite(stream, cuts: [30, 33]);
    expect(out, stream);
  });

  test('a box cut short at the end is sent on as it came', () {
    final stream = sampleStream();
    final moof = findBox(stream, ['moof'], nth: 1)!;
    final cut = stream.sublist(0, moof.body + 10);
    final out = rewrite(cut, cuts: [50]);
    expect(out.length, cut.length + 20);
    expect(out.sublist(out.length - 18), cut.sublist(cut.length - 18));
  });

  test('a version 0 fragment time that would overflow is left as it is', () {
    final stream = Uint8List.fromList([
      ...sampleFtyp(),
      ...sampleMoov(),
      ...sampleMoof(sequence: 1, decode: {1: 0, 2: 0xFFFFFF00}),
      ...sampleMdat(10),
    ]);
    final out = rewrite(stream);
    expect(tfdt(out, fragment: 0, track: 1), 0xFFFFFF00);
    expect(tfdt(out, fragment: 0, track: 0), 10 * 16000);
  });

  test('a length too long for a version 0 header is written as unknown', () {
    final out = rewrite(sampleStream(), length: const Duration(days: 4000));
    expect(mvhd(out), 0xFFFFFFFF);
    expect(mehd(out), 4000 * 86400 * 1000, reason: 'version 1');
  });
}
