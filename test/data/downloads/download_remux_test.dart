import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/downloads/download_remux.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../cast/relay/relay_rig.dart' show relayBinaries;

/// docs/09 "Format", with the real FFmpeg: a finished download is remade
/// as MP4 when nothing is lost, and left alone otherwise.
void main() {
  final binaries = relayBinaries();
  if (binaries == null || Platform.isWindows) {
    test('remaking a download as MP4', () {}, skip: 'needs FFmpeg (Linux)');
    return;
  }
  late Directory temp;
  late ProcessSupervisor supervisor;
  final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());

  setUp(() {
    temp = Directory.systemTemp.createTempSync('remux_');
    supervisor = ProcessSupervisor(
      folder: Directory(p.join(temp.path, 'processes')),
      log: log,
    );
  });
  tearDown(() async {
    await supervisor.stopAll();
    temp.deleteSync(recursive: true);
  });

  FfmpegDownloadRemux remux({
    String? ffmpeg,
    int? Function(String)? free,
    RemuxTimings? timings,
  }) => FfmpegDownloadRemux(
    supervisor: supervisor,
    ffmpeg: ffmpeg ?? binaries.ffmpeg,
    ffprobe: binaries.ffprobe,
    log: log,
    freeSpace: free,
    timings:
        timings ??
        (stall: const Duration(seconds: 60), look: const Duration(seconds: 5)),
  );

  /// A 4-second clip named as a download's `.part` is.
  Future<String> clip(
    String name, {
    String format = 'matroska',
    String video = 'libx264',
    String audio = 'aac',
    bool subtitles = false,
  }) async {
    final path = p.join(temp.path, '$name.part');
    final srt = File(p.join(temp.path, 'words.srt'))
      ..writeAsStringSync(
        '1\n00:00:00,500 --> 00:00:02,000\nHello <i>there</i>\n\n'
        '2\n00:00:02,500 --> 00:00:03,500\nGoodbye\n',
      );
    final made = await Process.run(binaries.ffmpeg, [
      ...['-hide_banner', '-v', 'error', '-nostdin', '-y'],
      ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=4'],
      ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=4'],
      if (subtitles) ...['-i', srt.path],
      ...[
        '-map',
        '0:v',
        '-map',
        '1:a',
        if (subtitles) ...['-map', '2:s'],
      ],
      ...['-c:v', video, '-pix_fmt', 'yuv420p', '-c:a', audio],
      if (video == 'libx264') ...['-preset', 'ultrafast'],
      if (subtitles) ...['-c:s', 'srt', '-metadata:s:s:0', 'language=eng'],
      ...['-metadata:s:a:0', 'language=fre'],
      ...['-f', format, path],
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    return path;
  }

  Future<Map<String, Object?>> probe(String path) async {
    final run = await Process.run(binaries.ffprobe, [
      ...['-v', 'error', '-print_format', 'json'],
      ...['-show_format', '-show_streams', path],
    ]);
    return jsonDecode(run.stdout as String) as Map<String, Object?>;
  }

  List<String> codecs(Map<String, Object?> probed) => [
    for (final stream in probed['streams']! as List)
      '${(stream as Map)['codec_type']}:${stream['codec_name']}',
  ];

  test(
    'an MKV of H.264, AAC and SubRip becomes an MP4 with the same '
    'picture, sound, words and length; the original is not touched',
    () async {
      final input = await clip('Film.mkv', subtitles: true);
      final before = File(input).readAsBytesSync();
      final output = p.join(temp.path, 'Film.mp4.part');

      final outcome = await remux().toMp4(input, output);

      expect(outcome, isA<RemuxDone>());
      final media = (outcome as RemuxDone).media;
      expect(media.container, 'mov');
      expect(media.video?.codec, 'h264');
      expect(media.audio.single.codec, 'aac');
      expect(media.audio.single.language, 'fre');
      expect(media.subtitles.single.codec, 'mov_text');
      expect(media.subtitles.single.language, 'eng');
      expect(media.duration!.inSeconds, 4);
      expect(File(input).readAsBytesSync(), before);

      final made = await probe(output);
      expect(codecs(made), ['video:h264', 'audio:aac', 'subtitle:mov_text']);
      // The index is at the front: a player or a TV starts at once.
      final head = File(output).openSync().readSync(4096);
      final text = latin1.decode(head);
      final moov = text.indexOf('moov');
      final mdat = text.indexOf('mdat');
      expect(moov, greaterThan(0));
      expect(mdat < 0 || moov < mdat, isTrue, reason: 'moov $moov, mdat $mdat');
      // The same pictures, not encoded again: the packets' sizes agree.
      Future<List<String>> packets(String path) async => LineSplitter.split(
        (await Process.run(binaries.ffprobe, [
              ...['-v', 'error', '-select_streams', 'v:0'],
              ...['-show_entries', 'packet=size', '-of', 'csv=p=0', path],
            ])).stdout
            as String,
      ).toList();
      expect(await packets(output), await packets(input));
      expect(supervisor.runningCount, 0);
    },
  );

  test('MPEG-TS with AC-3 becomes MP4 too', () async {
    final input = await clip('Show.ts', format: 'mpegts', audio: 'ac3');
    final output = p.join(temp.path, 'Show.mp4.part');
    final outcome = await remux().toMp4(input, output);
    expect(outcome, isA<RemuxDone>());
    expect(codecs(await probe(output)), ['video:h264', 'audio:ac3']);
  });

  test(
    'what MP4 would not keep stays as it came, and nothing is written',
    () async {
      final output = p.join(temp.path, 'out.mp4.part');
      for (final (input, why) in [
        (await clip('Old.mkv', video: 'mpeg4'), 'its picture is mpeg4'),
        (await clip('Lossless.mkv', audio: 'flac'), 'a sound track is flac'),
        (await clip('Already.mp4', format: 'mp4'), 'it is MP4 already'),
      ]) {
        final outcome = await remux().toMp4(input, output);
        expect(outcome, isA<RemuxKept>(), reason: input);
        expect((outcome as RemuxKept).why, why);
        expect(outcome.media, isNotNull);
        expect(File(output).existsSync(), isFalse);
        expect(File(input).existsSync(), isTrue);
      }
      // Not a video at all.
      final junk = File(p.join(temp.path, 'junk.mkv.part'))
        ..writeAsBytesSync(List.filled(4096, 7));
      final outcome = await remux().toMp4(junk.path, output);
      expect((outcome as RemuxKept).why, "ffprobe didn't read it");
    },
  );

  test('no room for the copy: the file stays as it came', () async {
    final input = await clip('Film.mkv');
    final output = p.join(temp.path, 'Film.mp4.part');
    final outcome = await remux(free: (_) => 1 << 20).toMp4(input, output);
    expect((outcome as RemuxKept).why, 'the drive has no room for the copy');
    expect(File(output).existsSync(), isFalse);
  });

  group('an FFmpeg that misbehaves', () {
    /// A stand-in FFmpeg: a shell script.
    String script(String body) {
      final file = File(p.join(temp.path, 'ffmpeg.sh'))
        ..writeAsStringSync('#!/bin/sh\n$body\n');
      Process.runSync('chmod', ['+x', file.path]);
      return file.path;
    }

    const quick = (
      stall: Duration(milliseconds: 400),
      look: Duration(milliseconds: 50),
    );

    test('it fails: its half-made file goes and the download stays as it '
        'came', () async {
      final input = await clip('Film.mkv');
      final output = p.join(temp.path, 'Film.mp4.part');
      // The last argument is the output.
      final ffmpeg = script(
        r'for last; do :; done; echo half > "$last"; echo "no space" >&2; '
        'exit 3',
      );
      final outcome = await remux(ffmpeg: ffmpeg).toMp4(input, output);
      expect((outcome as RemuxKept).why, 'FFmpeg ended with 3 (no space)');
      expect(File(output).existsSync(), isFalse);
    });

    test(
      'it stops writing: killed, and the download stays as it came',
      () async {
        final input = await clip('Film.mkv');
        final output = p.join(temp.path, 'Film.mp4.part');
        final outcome = await remux(
          ffmpeg: script('exec sleep 30'),
          timings: quick,
        ).toMp4(input, output);
        expect((outcome as RemuxKept).why, 'FFmpeg stopped writing');
        expect(supervisor.runningCount, 0);
      },
    );

    test('a cancel or the app quitting stops it: nothing is decided', () async {
      for (final quit in [false, true]) {
        final input = await clip('Film.mkv');
        final output = p.join(temp.path, 'Film.mp4.part');
        final ffmpeg = script(
          r'for last; do :; done; echo half > "$last"; exec sleep 30',
        );
        final working = remux(ffmpeg: ffmpeg);
        final outcome = working.toMp4(input, output);
        while (!File(output).existsSync()) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        quit ? await working.close() : await working.stop(output);
        expect(await outcome, isA<RemuxStopped>());
        expect(File(output).existsSync(), isFalse);
        expect(supervisor.runningCount, 0);
        if (quit) {
          expect(await working.toMp4(input, output), isA<RemuxStopped>());
        }
      }
    });
  });
}
