import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffmpeg_cast_mp4_copies.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'relay/relay_rig.dart' show relayBinaries;

/// Phase 8 decision 12, with the real FFmpeg: a file that is relayed
/// with its picture copied is made into an MP4 the TV can seek in by
/// itself.
void main() {
  final binaries = relayBinaries();
  if (binaries == null || Platform.isWindows) {
    test('the MP4 beside the relay', () {}, skip: 'needs FFmpeg (Linux)');
    return;
  }
  late Directory temp;
  late Directory folder;
  late ProcessSupervisor supervisor;
  late MemoryOutput logged;
  late AppLog log;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cast_mp4_');
    folder = Directory(p.join(temp.path, 'relay', 'run'));
    logged = MemoryOutput();
    log = AppLog(output: logged, secrets: SecretRegistry());
    supervisor = ProcessSupervisor(
      folder: Directory(p.join(temp.path, 'processes')),
      log: log,
    );
  });
  tearDown(() async {
    await supervisor.stopAll();
    temp.deleteSync(recursive: true);
  });

  FfmpegCastMp4Copies copies({
    String? ffmpeg,
    int? Function(String)? free,
    CastMp4Timings? timings,
  }) => FfmpegCastMp4Copies(
    supervisor: supervisor,
    binaries: FfmpegBinaries(
      ffmpeg: ffmpeg ?? binaries.ffmpeg,
      ffprobe: binaries.ffprobe,
    ),
    folder: folder,
    log: log,
    freeSpace: free,
    timings:
        timings ??
        (stall: const Duration(seconds: 60), look: const Duration(seconds: 5)),
  );

  /// A 4-second Matroska clip.
  Future<String> clip(
    String name, {
    String video = 'libx264',
    String audio = 'ac3',
  }) async {
    final path = p.join(temp.path, name);
    final made = await Process.run(binaries.ffmpeg, [
      ...['-hide_banner', '-v', 'error', '-nostdin', '-y'],
      ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:duration=4'],
      ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=4'],
      ...['-c:v', video, '-pix_fmt', 'yuv420p', '-preset', 'ultrafast'],
      ...['-c:a', audio, '-f', 'matroska', path],
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    return path;
  }

  /// What ffprobe reads in [path], and the plan the app makes of it for a
  /// 4K Chromecast.
  Future<(StreamFacts, CastPlan)> planned(String path) async {
    final probed = await FfprobeStreamProbe(
      ffprobe: binaries.ffprobe,
      supervisor: supervisor,
      log: log,
    ).probe(path);
    final facts = (probed as StreamProbed).facts;
    final plan = (planCast(
      CastPlanRequest(
        facts: facts,
        source: CastSourceInfo(
          sourceId: 'file:$path',
          live: false,
          fileExtension: p.extension(path).substring(1),
        ),
        device: const CastDeviceProfile(
          model: 'Chromecast',
          hevc: HevcSupport.yes,
        ),
      ),
    ) as CastPlanned).plan;
    return (facts, plan);
  }

  Future<List<Map<Object?, Object?>>> streams(String path) async {
    final run = await Process.run(binaries.ffprobe, [
      ...['-v', 'error', '-print_format', 'json', '-show_streams', path],
    ]);
    final json = jsonDecode(run.stdout as String) as Map<String, Object?>;
    return [for (final s in json['streams']! as List) s as Map];
  }

  /// A stand-in for FFmpeg that does [script].
  String script(String name, String script) {
    final file = File(p.join(temp.path, name))
      ..writeAsStringSync('#!/bin/sh\n$script\n');
    Process.runSync('chmod', ['+x', file.path]);
    return file.path;
  }

  Iterable<String> lines() => logged.buffer.expand((e) => e.lines);

  test('H.264 with AC-3 in Matroska: an MP4 with the same picture, the '
      'sound as the relay sends it, the index in front, and the original '
      'untouched', () async {
    final input = await clip('Film.mkv');
    final before = File(input).readAsBytesSync();
    final (facts, plan) = await planned(input);
    expect(plan.delivery, CastDelivery.relayContinuous);
    expect(plan.video, isA<CastVideoCopy>());
    expect(plan.audio, isA<CastAudioToAac>());

    final copy = copies().make(input, plan: plan, facts: facts);
    final path = await copy.ready;

    expect(path, isNotNull);
    expect(p.basename(path!), 'media.mp4');
    expect(p.isWithin(folder.path, path), isTrue);
    final made = await streams(path);
    expect(
      [for (final s in made) '${s['codec_type']}:${s['codec_name']}'],
      ['video:h264', 'audio:aac'],
    );
    expect(made[1]['channels'], 2);
    final head = latin1.decode(File(path).openSync().readSync(4096));
    expect(head.indexOf('moov'), greaterThan(0));
    expect(head.indexOf('moov'), lessThan(head.indexOf('mdat')));
    expect(File(input).readAsBytesSync(), before);
    // Nothing half-made beside it, and no FFmpeg left.
    expect(File(path).parent.listSync(), hasLength(1));
    expect(supervisor.folder.listSync(), isEmpty);
    expect(lines().join('\n'), contains('The MP4 for seeking on the TV is'));

    await copy.delete();
    expect(File(path).existsSync(), isFalse);
    expect(folder.listSync(), isEmpty);
  });

  test("HEVC is tagged hvc1, as the relay's own stream is", () async {
    final input = await clip('Film.mkv', video: 'libx265', audio: 'eac3');
    final (facts, plan) = await planned(input);
    expect(plan.video, isA<CastVideoCopy>());
    final path = await copies().make(input, plan: plan, facts: facts).ready;
    expect(path, isNotNull);
    final video = (await streams(path!)).first;
    expect(video['codec_name'], 'hevc');
    expect(video['codec_tag_string'], 'hvc1');
  });

  test('no room for the file and 1 GB beside it: not made, FFmpeg not '
      'even started', () async {
    final input = await clip('Film.mkv');
    final (facts, plan) = await planned(input);
    final size = File(input).lengthSync();
    final asked = <String>[];
    final ffmpeg = script('never', 'touch "${temp.path}/ran"');
    final tight = copies(
      ffmpeg: ffmpeg,
      free: (path) {
        asked.add(path);
        return size + FfmpegCastMp4Copies.spareBytes - 1;
      },
    );
    expect(await tight.make(input, plan: plan, facts: facts).ready, isNull);
    expect(asked, [folder.path]);
    expect(File(p.join(temp.path, 'ran')).existsSync(), isFalse);
    expect(folder.existsSync(), isFalse);
    expect(lines().join('\n'), contains('the drive has no room for it'));

    // Just enough: made.
    final roomy = copies(free: (_) => size + FfmpegCastMp4Copies.spareBytes);
    expect(await roomy.make(input, plan: plan, facts: facts).ready, isNotNull);
  });

  test('a plan that re-encodes the picture, or a live one: none', () async {
    final input = await clip('Film.mkv');
    final (facts, plan) = await planned(input);
    final reencoded = CastPlan(
      delivery: plan.delivery,
      video: const CastVideoTranscode(
        height: 180,
        bitRate: 1000000,
        reasons: [TranscodeReason.codecUnsupported],
      ),
      audio: plan.audio,
      live: false,
      output: plan.output,
    );
    final live = CastPlan(
      delivery: plan.delivery,
      video: plan.video,
      audio: plan.audio,
      live: true,
      output: plan.output,
    );
    final maker = copies();
    expect(
      await maker.make(input, plan: reencoded, facts: facts).ready,
      isNull,
    );
    expect(await maker.make(input, plan: live, facts: facts).ready, isNull);
    expect(folder.existsSync(), isFalse);
  });

  test('FFmpeg fails, or its MP4 is not the whole file: none, and '
      'nothing left', () async {
    final input = await clip('Film.mkv');
    final (facts, plan) = await planned(input);
    final failing = copies(
      ffmpeg: script('fails', 'echo "broken" >&2; exit 3'),
    );
    expect(await failing.make(input, plan: plan, facts: facts).ready, isNull);
    expect(lines().join('\n'), contains('FFmpeg ended with 3 (broken)'));

    // Half the film: the last argument is where the MP4 goes.
    final short = copies(
      ffmpeg: script(
        'short',
        'for last; do :; done\n'
            '"${binaries.ffmpeg}" -v error -y -i "$input" -t 1 '
            r'-c copy -an -f mp4 "$last"',
      ),
    );
    expect(await short.make(input, plan: plan, facts: facts).ready, isNull);
    expect(lines().join('\n'), contains('it came out 1 s long, of 4 s'));

    final gone = copies().make(
      p.join(temp.path, 'Gone.mkv'),
      plan: plan,
      facts: facts,
    );
    expect(await gone.ready, isNull);
    expect(
      folder.existsSync() ? folder.listSync() : const <FileSystemEntity>[],
      isEmpty,
    );
    expect(supervisor.folder.listSync(), isEmpty);
  });

  test('a copy that stops writing is killed', () async {
    final input = await clip('Film.mkv');
    final (facts, plan) = await planned(input);
    final stuck = copies(
      ffmpeg: script('stuck', 'exec sleep 60'),
      timings: (
        stall: const Duration(milliseconds: 300),
        look: const Duration(milliseconds: 100),
      ),
    );
    final clock = Stopwatch()..start();
    expect(await stuck.make(input, plan: plan, facts: facts).ready, isNull);
    expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
    expect(lines().join('\n'), contains('FFmpeg stopped writing'));
    expect(supervisor.folder.listSync(), isEmpty);
  });

  test('deleted while it is made: FFmpeg killed, the folder gone, and '
      'never ready', () async {
    final input = await clip('Film.mkv');
    final (facts, plan) = await planned(input);
    final slow = copies(ffmpeg: script('slow', 'exec sleep 60'));
    final copy = slow.make(input, plan: plan, facts: facts);
    // Until FFmpeg runs.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!supervisor.folder.existsSync() ||
        supervisor.folder.listSync().isEmpty) {
      expect(DateTime.now().isBefore(deadline), isTrue, reason: 'no FFmpeg');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await copy.delete();
    expect(await copy.ready, isNull);
    expect(folder.listSync(), isEmpty);
    expect(supervisor.folder.listSync(), isEmpty);
    await copy.delete();
  });
}
