import 'dart:convert';

import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/cast/ffprobe_json.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';

/// [StreamProbe] with the bundled ffprobe, under the [ProcessSupervisor].
final class FfprobeStreamProbe implements StreamProbe {
  new({
    required this.ffprobe,
    required this._supervisor,
    required this._log,
    this.timeout = const Duration(seconds: 8),
  });

  final String ffprobe;

  /// Phase 7 decision 4: 8 s, then the cast fails with the probe's reason.
  final Duration timeout;

  final ProcessSupervisor _supervisor;
  final AppLog _log;

  /// What ffprobe is asked. Two seconds of a stream are read: measured on
  /// the fake panel's live channels (sent at their real pace), that took
  /// 0.5–1.7 s, against 4–4.8 s for ffprobe's own five, and every field
  /// the planner needs was there (ADR-014 step 3).
  static List<String> arguments(String input, {String? userAgent}) => [
    ...['-hide_banner', '-v', 'error'],
    ...['-analyzeduration', '2000000', '-probesize', '5000000'],
    // An HTTP option: a file would be refused with it.
    if (userAgent != null && userAgent.isNotEmpty && _isHttp(input)) ...[
      '-user_agent',
      userAgent,
    ],
    ...['-print_format', 'json', '-show_format', '-show_streams'],
    ...['-i', input],
  ];

  @override
  Future<StreamProbeResult> probe(String input, {String? userAgent}) async {
    final watch = Stopwatch()..start();
    final run = await _supervisor.run(
      ffprobe,
      arguments(input, userAgent: userAgent),
      owner: 'ffprobe',
      timeout: timeout,
      maxOutput: 1 << 20,
    );
    final ms = watch.elapsedMilliseconds;
    final StreamProbeResult result;
    if (run.startError != null) {
      result = StreamProbeFailed(
        StreamProbeFailure.couldNotStart,
        _hide(run.startError!, input),
      );
    } else if (run.timedOut) {
      result = const StreamProbeFailed(StreamProbeFailure.timedOut);
    } else if (run.exitCode != 0 || run.overflowed) {
      result = StreamProbeFailed(
        StreamProbeFailure.unreadable,
        _lastLine(run.stderr, input) ??
            (run.overflowed ? 'too much output' : 'exit ${run.exitCode}'),
      );
    } else {
      final facts = readFfprobeJson(
        utf8.decode(run.stdout, allowMalformed: true),
      );
      result = facts == null
          ? const StreamProbeFailed(StreamProbeFailure.unreadable, 'not JSON')
          : facts.video == null && facts.audio.isEmpty
          ? const StreamProbeFailed(StreamProbeFailure.noStreams)
          : StreamProbed(facts);
    }
    switch (result) {
      case StreamProbed(:final facts):
        _log.info('probe', 'Read in $ms ms: ${_summary(facts)}');
      case StreamProbeFailed(:final reason, :final detail):
        final why = detail == null ? '' : ' ($detail)';
        _log.warning('probe', 'Failed in $ms ms: ${reason.name}$why');
    }
    return result;
  }

  /// `mpegTs, h264 1080i, mp2` — never the input.
  static String _summary(StreamFacts facts) {
    final video = facts.video;
    final picture = video == null
        ? 'no video'
        : '${video.codec ?? '?'} ${video.height ?? '?'}'
              '${video.interlaced ?? false ? 'i' : 'p'}';
    final sound = facts.audio.map((a) => a.codec ?? '?').join('+');
    return '${facts.container?.name ?? '?'}, $picture, '
        '${sound.isEmpty ? 'no audio' : sound}';
  }

  static bool _isHttp(String input) {
    final lower = input.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// ffprobe's last word, without the input: it names the URL in its
  /// errors, and a provider's URL carries credentials (hard rule 3).
  static String? _lastLine(String stderr, String input) {
    final lines = stderr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    return lines.isEmpty ? null : _hide(lines.last, input);
  }

  static String _hide(String text, String input) =>
      redact(text.replaceAll(input, '<input>'));
}

/// The probe of a build without ffprobe: every probe says it couldn't
/// start (`castReadinessProvider` already says why).
final class UnavailableStreamProbe implements StreamProbe {
  const new();

  @override
  Future<StreamProbeResult> probe(String input, {String? userAgent}) async =>
      const StreamProbeFailed(
        StreamProbeFailure.couldNotStart,
        'ffprobe is missing',
      );
}
