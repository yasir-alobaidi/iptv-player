import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/cast/relay/ts_programs.dart';

import 'relay_rig.dart';

/// The proxy's watch on a live MPEG-TS stream's program map: a channel
/// that switches codec keeps its PIDs and changes their types. The
/// streams are FFmpeg's own MPEG-TS.
void main() {
  final binaries = relayBinaries();
  late Uint8List h264;
  late Uint8List hevc;
  late Uint8List mpeg2;

  setUpAll(() async {
    if (binaries == null) return;
    final temp = await Directory.systemTemp.createTemp('ts_programs');
    addTearDown(() => temp.delete(recursive: true));
    Future<Uint8List> make(String codec, String file) async {
      final out = '${temp.path}/$file';
      final result = await Process.run(binaries.ffmpeg, [
        ...['-hide_banner', '-loglevel', 'error', '-y'],
        ...['-f', 'lavfi', '-i', 'testsrc2=size=160x90:rate=25:duration=1'],
        ...['-f', 'lavfi', '-i', 'sine=duration=1'],
        ...['-c:v', codec, '-c:a', 'aac', '-f', 'mpegts', out],
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return File(out).readAsBytesSync();
    }

    h264 = await make('libx264', 'h264.ts');
    hevc = await make('libx265', 'hevc.ts');
    mpeg2 = await make('mpeg2video', 'mpeg2.ts');
  });

  List<(List<TsStream>, List<TsStream>)> feed(
    List<Uint8List> parts, {
    int seed = 1,
    int largest = 4000,
  }) {
    final changes = <(List<TsStream>, List<TsStream>)>[];
    final watch = TsProgramWatch((a, b) => changes.add((a, b)));
    final random = Random(seed);
    for (final part in parts) {
      var at = 0;
      while (at < part.length) {
        final take = min(part.length - at, 1 + random.nextInt(largest));
        watch.add(Uint8List.sublistView(part, at, at + take));
        at += take;
      }
    }
    return changes;
  }

  group('with FFmpeg', () {
    test('reads the program: H.264 and AAC on their PIDs', () {
      final watch = TsProgramWatch((_, _) => fail('no change'))..add(h264);
      expect(watch.streams, [
        (pid: 0x100, type: 0x1b),
        (pid: 0x101, type: 0x0f),
      ]);
    });

    test('the same program again is no change, in any chunks', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(feed([h264, h264, h264], seed: seed), isEmpty);
      }
    });

    test('H.264 → HEVC on the same PIDs is a change, once', () {
      for (var seed = 0; seed < 50; seed++) {
        final changes = feed([h264, hevc, hevc], seed: seed);
        expect(changes, hasLength(1), reason: 'seed $seed');
        final (before, after) = changes.single;
        expect(before.first.type, 0x1b);
        expect(after.first.type, 0x24);
      }
    });

    test('and back, and to MPEG-2', () {
      final changes = feed([h264, hevc, h264, mpeg2]);
      expect(
        [for (final (_, after) in changes) after.first.type],
        [0x24, 0x1b, 0x02],
      );
    });

    test('found again after bytes that are no packets', () {
      final junk = Uint8List.fromList(List.filled(1000, 0x47 ^ 0xff));
      final cut = Uint8List.sublistView(h264, 0, 188 * 3 + 77);
      final changes = feed([cut, junk, h264, junk, hevc]);
      expect(changes, hasLength(1));
    });

    test('a reconnect drops the half packet it was in', () {
      final changes = <(List<TsStream>, List<TsStream>)>[];
      final watch = TsProgramWatch((a, b) => changes.add((a, b)))
        ..add(h264)
        ..add(Uint8List.sublistView(hevc, 0, 100))
        ..restart()
        ..add(hevc);
      expect(changes, hasLength(1));
      expect(watch.streams!.first.type, 0x24);
    });
  }, skip: binaries == null ? 'no FFmpeg' : null);

  test('random bytes never throw, and never invent a program', () {
    final random = Random(7);
    final watch = TsProgramWatch((_, _) {});
    for (var round = 0; round < 2000; round++) {
      final bytes = Uint8List(random.nextInt(2000));
      for (var i = 0; i < bytes.length; i++) {
        // Sync bytes, often, so packets get read.
        bytes[i] = random.nextInt(4) == 0 ? 0x47 : random.nextInt(256);
      }
      watch.add(bytes);
    }
    // Junk can look like a PAT and a PMT; it must not crash reading them.
    expect(() => watch.streams, returnsNormally);
  });
}
