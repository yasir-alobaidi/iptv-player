@Tags(['benchmark'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffmpeg_encoder_detector.dart';
import 'package:iptv_player/data/cast/ffmpeg_video_args.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// Phase 7 step 4's measurement on this computer's GPUs (Linux; nothing
/// is cast and nothing shows): encoder detection, fresh and remembered,
/// then the processor's cost of each re-encode the step names, with
/// every encoder found and libx264, at the stream's own pace.
///
/// `flutter test --tags benchmark --run-skipped test/tools/cast_transcode_measure_test.dart`
/// (`MEASURE_SECONDS=30` by default). The report goes to
/// `build/cast_measure/`.
void main() {
  final binaries = FfmpegBinaries.locate();
  final skip = binaries == null || !Platform.isLinux
      ? 'needs the bundled FFmpeg, on Linux'
      : null;
  final seconds = int.tryParse(Platform.environment['MEASURE_SECONDS'] ?? '');

  test(
    'detection, then each re-encode with each encoder',
    skip: skip,
    timeout: const Timeout(Duration(minutes: 30)),
    () async {
      final report = StringBuffer();
      void say(String line) {
        report.writeln(line);
        // ignore: avoid_print, the measurement's report
        print(line);
      }

      final temp = Directory.systemTemp.createTempSync('cast_measure_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final log = AppLog(output: _Print(say), secrets: SecretRegistry());
      final supervisor = ProcessSupervisor(
        folder: Directory(p.join(temp.path, 'processes')),
        log: log,
      );
      addTearDown(supervisor.stopAll);

      say('# Phase 7 step 4 — re-encode measurements');
      say('FFmpeg: ${binaries!.ffmpeg}');
      say('Bundled libva: ${binaries.libva ?? 'none'}');
      say('');

      final folder = Directory(p.join(temp.path, 'cast'));
      final fresh = FfmpegEncoderDetector(
        binaries: binaries,
        folder: folder,
        supervisor: supervisor,
        log: log,
      );
      var watch = Stopwatch()..start();
      final found = await fresh.encoders();
      say('Detection, fresh: ${watch.elapsedMilliseconds} ms → $found');
      watch = Stopwatch()..start();
      final again = await FfmpegEncoderDetector(
        binaries: binaries,
        folder: folder,
        supervisor: supervisor,
        log: log,
      ).encoders();
      say('Detection, remembered: ${watch.elapsedMilliseconds} ms → $again');
      expect(again, found);
      say('');

      final probe = FfprobeStreamProbe(
        ffprobe: binaries.ffprobe,
        supervisor: supervisor,
        log: log,
      );
      final encoders = [
        ...found.available.where((e) => e.kind.hardware),
        // The processor too, for comparison, even when hardware was found.
        const CastEncoder(CastEncoderKind.x264),
      ];
      final runFor = seconds ?? 30;
      say(
        "Each case: $runFor s at the stream's pace (`-re`), video only; "
        'CPU = user + system time of FFmpeg ÷ wall time, % of one core '
        '(${Platform.numberOfProcessors} threads).',
      );
      say('Speed: the same with no pacing, for 10 s of the stream.');
      say('');
      for (final measured in _cases) {
        final file = p.join('tools/media_samples/out', measured.sample);
        if (!File(file).existsSync()) {
          say('${measured.name}: no sample ($file)');
          continue;
        }
        final probed = await probe.probe(file);
        final facts = (probed as StreamProbed).facts;
        final planned = planCast(
          CastPlanRequest(
            facts: facts,
            source: const CastSourceInfo(sourceId: 'measure', live: true),
            device: measured.device,
            settings: measured.settings,
          ),
        );
        final plan = (planned as CastPlanned).plan;
        final video = plan.video as CastVideoTranscode;
        say('## ${measured.name}');
        say('Plan: $video');
        for (final encoder in encoders) {
          // libx264 stays at 1080p or below (docs/04 rule 3).
          final args = videoTranscodeArgs(
            plan: video,
            encoder: encoder,
            source: facts.video!,
            libvaEnvironment: binaries.libvaEnvironment(),
          );
          final paced = await _run(
            supervisor,
            binaries.ffmpeg,
            args,
            file,
            seconds: runFor,
            paced: true,
          );
          final fast = await _run(
            supervisor,
            binaries.ffmpeg,
            args,
            file,
            seconds: 10,
            paced: false,
          );
          final where = encoder.kind.hardware
              ? (encoder.decodesOnChip(facts.video!)
                    ? ' (decoded on the chip)'
                    : ' (decoded on the processor)')
              : '';
          say(
            '- ${encoder.kind.label}$where: CPU ${paced.cpu}, '
            '${paced.frames} pictures; speed ${fast.speed}'
            '${paced.error ?? fast.error ?? ''}',
          );
        }
        say('');
      }

      final out = Directory('build/cast_measure')..createSync(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      File(p.join(out.path, 'transcode-$stamp.md'))
          .writeAsStringSync(report.toString());
    },
  );
}

final class _Case {
  const new(
    this.name,
    this.sample, {
    required this.device,
    this.settings = const CastSettings(),
  });

  final String name;
  final String sample;
  final CastDeviceProfile device;
  final CastSettings settings;
}

/// The step's two, and Smooth interlaced on a 1080i channel.
const _cases = [
  _Case(
    'HEVC 2160p25 → H.264 1080p (HEVC set to No, 1080p learned)',
    'hevc_2160p25_eac3.ts',
    device: CastDeviceProfile(
      model: 'Chromecast',
      hevc: HevcSupport.no,
      learned: CastLearned(maxHeight: 1080),
    ),
  ),
  _Case(
    'MPEG-2 576i25 → H.264 576p50',
    'mpeg2_576i25_mp2.ts',
    device: CastDeviceProfile(model: 'Chromecast'),
  ),
  _Case(
    'H.264 1080i50 → H.264 1080p50 (Smooth interlaced)',
    'h264_1080i50_mp2.ts',
    device: CastDeviceProfile(model: 'Chromecast'),
    settings: CastSettings(smoothInterlaced: true),
  ),
];

final class _Result {
  const new({
    required this.cpu,
    required this.speed,
    required this.frames,
    this.error,
  });

  final String cpu;
  final String speed;
  final int frames;
  final String? error;
}

/// Runs a re-encode to `-f null`, reading its processor time from
/// `/proc/<pid>/stat` as it goes (the last reading before it ends).
Future<_Result> _run(
  ProcessSupervisor supervisor,
  String ffmpeg,
  FfmpegVideoArgs args,
  String file, {
  required int seconds,
  required bool paced,
}) async {
  final process = await supervisor.start(
    ffmpeg,
    [
      ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
      ...['-nostats', '-progress', 'pipe:1'],
      ...args.input,
      if (paced) '-re',
      ...['-stream_loop', '-1', '-i', file, '-map', '0:v:0'],
      ...args.output,
      ...['-t', '$seconds', '-f', 'null', '-'],
    ],
    owner: 'measure',
    timeout: Duration(seconds: seconds * 3 + 60),
    environment: args.environment.isEmpty ? null : args.environment,
  );
  final progress = StringBuffer();
  final errors = StringBuffer();
  final out = process.stdout
      .transform(utf8.decoder)
      .listen(progress.write)
      .asFuture<void>();
  final err = process.stderr
      .transform(utf8.decoder)
      .listen(errors.write)
      .asFuture<void>();
  final watch = Stopwatch()..start();
  var ticks = 0;
  final poll = Timer.periodic(const Duration(milliseconds: 200), (_) {
    ticks = _cpuTicks(process.pid) ?? ticks;
  });
  final code = await process.exitCode;
  poll.cancel();
  final wall = watch.elapsedMicroseconds / 1e6;
  await Future.wait([out, err]);
  final lines = progress.toString().split('\n');
  String last(String key) => lines
      .lastWhere((l) => l.startsWith('$key='), orElse: () => '$key=?')
      .substring(key.length + 1)
      .trim();
  final frames = int.tryParse(last('frame')) ?? 0;
  // USER_HZ is 100 on Linux.
  final cpu = ticks / 100 / wall * 100;
  final lastError = errors
      .toString()
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .lastOrNull;
  return _Result(
    cpu: '${cpu.toStringAsFixed(0)} %',
    speed: last('speed'),
    frames: frames,
    error: code == 0 ? null : ' — FAILED ($code): ${lastError ?? ''}',
  );
}

/// utime + stime, in clock ticks; null once it has gone.
int? _cpuTicks(int pid) {
  try {
    final stat = File('/proc/$pid/stat').readAsStringSync();
    // The name, in brackets, may hold spaces: count from after it.
    final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
    return int.parse(fields[11]) + int.parse(fields[12]);
  } on Object {
    return null;
  }
}

final class _Print extends LogOutput {
  new(this._say);

  final void Function(String) _say;

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      _say('  log: $line');
    }
  }
}
