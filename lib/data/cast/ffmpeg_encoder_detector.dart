import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffmpeg_video_args.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:path/path.dart' as p;

/// [CastEncoderDetection] with the bundled FFmpeg (Phase 7 step 4).
///
/// Each candidate of docs/04's order gets a one-second test encode with
/// the very arguments a re-encode uses; each hardware one that passes,
/// a test decode of every [HardwareDecode] kind on its chip. VA-API and
/// Quick Sync are tried on each render node, with the bundled libva first
/// and then the system's. What works is remembered in [folder] for this
/// FFmpeg, for [maxAge].
final class FfmpegEncoderDetector implements CastEncoderDetection {
  new({
    required this.binaries,
    required this.folder,
    required this._supervisor,
    required this._log,
    bool? windows,
    this._kinds,
    List<String> Function()? renderNodes,
    DateTime Function()? now,
    this.maxAge = const Duration(days: 7),
    this.testTimeout = const Duration(seconds: 20),
  }) : windows = windows ?? Platform.isWindows,
       _renderNodes = renderNodes ?? linuxRenderNodes,
       _now = now ?? DateTime.now;

  final FfmpegBinaries binaries;

  /// Where the result is remembered (`encoders.json`) and the test
  /// pictures are made (`encoder-test/`, deleted after).
  final Directory folder;
  final bool windows;

  /// A driver or a GPU can change without FFmpeg changing: tested again
  /// after this long.
  final Duration maxAge;

  /// Per test. The first use of a CUDA filter compiles it (about 6 s on
  /// this laptop), and a sleeping GPU has to wake.
  final Duration testTimeout;

  final ProcessSupervisor _supervisor;
  final AppLog _log;

  /// The candidates, when not docs/04's order for this system (tests).
  final List<CastEncoderKind>? _kinds;
  final List<String> Function() _renderNodes;
  final DateTime Function() _now;

  CastEncoders? _known;
  Future<CastEncoders>? _running;

  File get _cacheFile => File(p.join(folder.path, 'encoders.json'));

  @override
  Future<CastEncoders> encoders() {
    final known = _known;
    if (known != null) return Future.value(known);
    return _once(useCache: true);
  }

  @override
  Future<CastEncoders> detectAgain() => _once(useCache: false);

  /// One detection at a time; whoever asks meanwhile shares it.
  Future<CastEncoders> _once({required bool useCache}) {
    final running = _running;
    if (running != null) return running;
    final next = _detectSafely(useCache: useCache);
    _running = next;
    unawaited(
      next.whenComplete(() {
        if (identical(_running, next)) _running = null;
      }),
    );
    return next;
  }

  Future<CastEncoders> _detectSafely({required bool useCache}) async {
    try {
      final found = await _detect(useCache: useCache);
      _known = found;
      return found;
    } on Object catch (error, stack) {
      _log.error(
        'encoders',
        'Detection failed',
        error: error,
        stackTrace: stack,
      );
      return CastEncoders.none;
    }
  }

  Future<CastEncoders> _detect({required bool useCache}) async {
    final watch = Stopwatch()..start();
    final version = await _ffmpegVersion();
    if (version == null) {
      _log.warning('encoders', "FFmpeg didn't start: nothing can re-encode");
      return CastEncoders.none;
    }
    if (useCache) {
      final remembered = _readCache(version);
      if (remembered != null) {
        _log.info('encoders', 'Remembered: $remembered');
        return remembered;
      }
    }

    final trial = _Trial();
    final found = <CastEncoder>[];
    final samples = Directory(p.join(folder.path, 'encoder-test'));
    Map<HardwareDecode, String>? sampleFiles;
    try {
      for (final kind in _kinds ?? CastEncoderKind.order(windows: windows)) {
        final encoder = await _tryEncoder(kind, trial);
        if (encoder == null) continue;
        if (!kind.hardware) {
          found.add(encoder);
          continue;
        }
        sampleFiles ??= await _makeSamples(samples, trial);
        found.add(await _withDecodes(encoder, sampleFiles, trial));
      }
    } finally {
      _delete(samples);
    }

    final result = CastEncoders(found);
    _log.info('encoders', 'Found in ${watch.elapsedMilliseconds} ms: $result');
    if (trial.interrupted) {
      _log.info('encoders', 'Not remembered: a test was cut short');
    } else {
      _writeCache(version, result);
    }
    return result;
  }

  /// FFmpeg's first line (`ffmpeg version n8.1.2-…`), or null.
  Future<String?> _ffmpegVersion() async {
    final run = await _supervisor.run(
      binaries.ffmpeg,
      const ['-hide_banner', '-version'],
      owner: 'encoder-test',
      timeout: const Duration(seconds: 10),
      maxOutput: 64 << 10,
    );
    if (run.exitCode != 0) return null;
    final first = utf8
        .decode(run.stdout, allowMalformed: true)
        .split('\n')
        .first
        .trim();
    return first.isEmpty ? null : first;
  }

  Future<CastEncoder?> _tryEncoder(CastEncoderKind kind, _Trial trial) async {
    final onNode =
        !windows &&
        (kind == CastEncoderKind.vaapi || kind == CastEncoderKind.qsv);
    if (!onNode) {
      final encoder = CastEncoder(kind);
      return await _encodes(encoder, trial) ? encoder : null;
    }
    for (final node in _renderNodes()) {
      // The bundled libva first: on the systems the app supports, the
      // system's is too old and FFmpeg aborts on it; where it is newer
      // than the bundled one, the bundled one fails cleanly.
      for (final bundled in [if (binaries.libva != null) true, false]) {
        final encoder = CastEncoder(kind, device: node, bundledLibva: bundled);
        if (await _encodes(encoder, trial)) return encoder;
      }
    }
    return null;
  }

  /// The one-second test encode: a 1080p picture from the processor, as
  /// a picture its chip can't decode would come.
  Future<bool> _encodes(CastEncoder encoder, _Trial trial) {
    final args = _argsFor(
      encoder,
      const VideoFacts(codec: 'rawvideo', width: 1920, height: 1080, fps: 25),
      const CastVideoTranscode(
        height: 1080,
        bitRate: 6000000,
        fps: 25,
        reasons: [TranscodeReason.codecUnsupported],
      ),
    );
    return _passes(
      '${encoder.kind.label} encode',
      encoder,
      [
        ...args.input,
        ...['-f', 'lavfi', '-t', '1'],
        ...['-i', 'testsrc2=size=1920x1080:rate=25'],
        ...args.output,
      ],
      args.environment,
      trial,
    );
  }

  /// Each kind of picture its chip decodes, scaled (and deinterlaced) on
  /// the chip as a re-encode would.
  Future<CastEncoder> _withDecodes(
    CastEncoder encoder,
    Map<HardwareDecode, String> samples,
    _Trial trial,
  ) async {
    final decodes = <HardwareDecode>{};
    for (final MapEntry(key: kind, value: file) in samples.entries) {
      final sample = _samples[kind]!;
      final trying = CastEncoder(
        encoder.kind,
        device: encoder.device,
        decodes: {kind},
        bundledLibva: encoder.bundledLibva,
      );
      final args = _argsFor(trying, sample.facts, sample.plan);
      final passed = await _passes(
        '${encoder.kind.label} decode ${kind.name}',
        trying,
        [
          ...args.input,
          ...['-i', file, '-map', '0:v:0'],
          ...args.output,
        ],
        args.environment,
        trial,
      );
      if (passed) decodes.add(kind);
    }
    return CastEncoder(
      encoder.kind,
      device: encoder.device,
      decodes: decodes,
      bundledLibva: encoder.bundledLibva,
    );
  }

  FfmpegVideoArgs _argsFor(
    CastEncoder encoder,
    VideoFacts source,
    CastVideoTranscode plan,
  ) => videoTranscodeArgs(
    plan: plan,
    encoder: encoder,
    source: source,
    libvaEnvironment: binaries.libvaEnvironment(),
    windows: windows,
  );

  /// Runs a test to `-f null`: it passes when FFmpeg ends well and says
  /// it made pictures (`-progress`), so a picture its chip refused and
  /// the processor decoded instead can't pass.
  Future<bool> _passes(
    String what,
    CastEncoder encoder,
    List<String> arguments,
    Map<String, String> environment,
    _Trial trial,
  ) async {
    final run = await _supervisor.run(
      binaries.ffmpeg,
      [
        ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
        ...['-nostats', '-progress', 'pipe:1'],
        ...arguments,
        ...['-f', 'null', '-'],
      ],
      owner: 'encoder-test',
      timeout: testTimeout,
      maxOutput: 256 << 10,
      environment: environment.isEmpty ? null : environment,
    );
    trial.saw(run, windows: windows);
    final frames = _lastFrameCount(
      utf8.decode(run.stdout, allowMalformed: true),
    );
    if (run.exitCode == 0 && frames > 0) return true;
    final why = run.startError != null
        ? "didn't start"
        : run.timedOut
        ? 'timed out'
        : run.exitCode == 0
        ? 'made no pictures'
        : _why(run.stderr);
    final where = encoder.device == null
        ? ''
        : ' on ${encoder.device}'
              '${encoder.bundledLibva ? ' (bundled libva)' : ''}';
    _log.info('encoders', '$what$where: no ($why)');
    return false;
  }

  /// One test picture of each kind, a second long; a kind FFmpeg can't
  /// make isn't tested (and never counts as decoded on the chip).
  Future<Map<HardwareDecode, String>> _makeSamples(
    Directory samples,
    _Trial trial,
  ) async {
    _delete(samples);
    try {
      samples.createSync(recursive: true);
    } on FileSystemException catch (error) {
      _log.warning('encoders', 'No folder for test pictures', error: error);
      return const {};
    }
    final made = <HardwareDecode, String>{};
    for (final MapEntry(key: kind, value: sample) in _samples.entries) {
      final file = p.join(samples.path, sample.file);
      final run = await _supervisor.run(
        binaries.ffmpeg,
        [
          ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
          ...['-f', 'lavfi', '-t', '1'],
          ...['-i', 'testsrc2=size=${sample.size}:rate=25'],
          ...sample.encode,
          ...['-y', file],
        ],
        owner: 'encoder-test',
        timeout: testTimeout,
        maxOutput: 64 << 10,
      );
      trial.saw(run, windows: windows);
      if (run.exitCode == 0 && File(file).existsSync()) {
        made[kind] = file;
      } else {
        _log.info(
          'encoders',
          "Couldn't make a ${kind.name} test picture (${_why(run.stderr)})",
        );
      }
    }
    return made;
  }

  CastEncoders? _readCache(String version) {
    try {
      final file = _cacheFile;
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map) return null;
      if (json['format'] != 1 ||
          json['ffmpeg'] != version ||
          json['windows'] != windows ||
          json['libva'] != (binaries.libva != null)) {
        return null;
      }
      final at = DateTime.tryParse('${json['detected_at']}');
      final now = _now();
      if (at == null || at.isAfter(now) || now.difference(at) > maxAge) {
        return null;
      }
      final list = json['encoders'];
      if (list is! List) return null;
      return CastEncoders([for (final entry in list) _encoderFrom(entry)]);
    } on Object {
      // Anything but what was written: tested again.
      return null;
    }
  }

  /// Throws on anything this file didn't write.
  static CastEncoder _encoderFrom(Object? json) {
    if (json is! Map) throw const FormatException('not an object');
    final kind = CastEncoderKind.values.byName(json['kind'] as String);
    final device = json['device'];
    final decodes = json['decodes'] as List;
    return CastEncoder(
      kind,
      device: device is String ? device : null,
      decodes: {
        for (final name in decodes)
          HardwareDecode.values.byName(name as String),
      },
      bundledLibva: json['bundled_libva'] as bool,
    );
  }

  void _writeCache(String version, CastEncoders found) {
    final file = _cacheFile;
    final temporary = File('${file.path}.tmp');
    try {
      folder.createSync(recursive: true);
      temporary
        ..writeAsStringSync(
          jsonEncode({
            'format': 1,
            'ffmpeg': version,
            'windows': windows,
            'libva': binaries.libva != null,
            'detected_at': _now().toUtc().toIso8601String(),
            'encoders': [
              for (final encoder in found.available)
                {
                  'kind': encoder.kind.name,
                  'device': encoder.device,
                  'decodes': [
                    for (final kind in HardwareDecode.values)
                      if (encoder.decodes.contains(kind)) kind.name,
                  ],
                  'bundled_libva': encoder.bundledLibva,
                },
            ],
          }),
          flush: true,
        )
        ..renameSync(file.path);
    } on FileSystemException catch (error) {
      _log.warning('encoders', "Couldn't remember the encoders", error: error);
    }
  }

  void _delete(Directory directory) {
    try {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    } on FileSystemException {
      // The next detection clears it first.
    }
  }

  /// FFmpeg's last word on why, redacted, past the lines it ends every
  /// failure with; a hint for the libva too old for it.
  static String _why(String stderr) {
    if (stderr.contains('vaMapBuffer2')) {
      return "this system's libva is older than 2.21";
    }
    final lines = stderr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return 'no reason given';
    final telling = lines.lastWhere(
      (line) => !_trailers.any(line.contains),
      orElse: () => lines.last,
    );
    return redact(
      telling.length > 200 ? '${telling.substring(0, 200)}…' : telling,
    );
  }

  /// What FFmpeg says after the reason, whatever it was.
  static const _trailers = [
    'Error parsing global options',
    'Failed to set value',
    'Conversion failed',
    'Nothing was written into output file',
    'Error opening output',
  ];

  static int _lastFrameCount(String progress) {
    var frames = 0;
    for (final line in progress.split('\n')) {
      if (!line.startsWith('frame=')) continue;
      frames = int.tryParse(line.substring(6).trim()) ?? frames;
    }
    return frames;
  }
}

/// The render nodes, in order (`/dev/dri/renderD128`, `renderD129`…):
/// the first isn't always the GPU VA-API works on (on this laptop it is
/// NVIDIA's, which has none).
List<String> linuxRenderNodes() {
  if (!Platform.isLinux) return const [];
  try {
    final nodes =
        Directory('/dev/dri')
            .listSync()
            .map((e) => e.path)
            .where((path) => p.basename(path).startsWith('renderD'))
            .toList()
          ..sort((a, b) => _nodeNumber(a).compareTo(_nodeNumber(b)));
    return nodes;
  } on FileSystemException {
    return const [];
  }
}

int _nodeNumber(String path) =>
    int.tryParse(p.basename(path).substring('renderD'.length)) ?? 1 << 20;

/// Whether any test was cut short (the app quitting, a timeout, a process
/// that couldn't start): such a result isn't remembered.
final class _Trial {
  bool interrupted = false;

  void saw(SupervisedRun run, {required bool windows}) {
    final code = run.exitCode;
    if (run.startError != null ||
        run.timedOut ||
        // Stopped by the supervisor (SIGTERM, SIGKILL): the app quitting.
        (!windows && (code == -15 || code == -9))) {
      interrupted = true;
    }
  }
}

/// A test picture: how it is made, and what a re-encode of it asks.
final class _Sample {
  const new({
    required this.file,
    required this.size,
    required this.encode,
    required this.facts,
    required this.plan,
  });

  final String file;
  final String size;
  final List<String> encode;
  final VideoFacts facts;
  final CastVideoTranscode plan;
}

const _x265Quiet = ['-x265-params', 'log-level=error'];

/// Each made smaller on the chip; the MPEG-2 one interlaced, so its test
/// deinterlaces there too.
const Map<HardwareDecode, _Sample> _samples = {
  HardwareDecode.h264: _Sample(
    file: 'h264.mkv',
    size: '1280x720',
    encode: ['-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p'],
    facts: VideoFacts(
      codec: 'h264',
      profile: 'High',
      width: 1280,
      height: 720,
      fps: 25,
      bitDepth: 8,
    ),
    plan: CastVideoTranscode(
      height: 360,
      bitRate: 1500000,
      fps: 25,
      reasons: [TranscodeReason.aboveModelHeight],
    ),
  ),
  HardwareDecode.hevc: _Sample(
    file: 'hevc.mkv',
    size: '1280x720',
    encode: [
      ...['-c:v', 'libx265', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p'],
      ..._x265Quiet,
    ],
    facts: VideoFacts(
      codec: 'hevc',
      profile: 'Main',
      width: 1280,
      height: 720,
      fps: 25,
      bitDepth: 8,
    ),
    plan: CastVideoTranscode(
      height: 360,
      bitRate: 1500000,
      fps: 25,
      reasons: [TranscodeReason.hevcRefused],
    ),
  ),
  HardwareDecode.hevc10: _Sample(
    file: 'hevc10.mkv',
    size: '1280x720',
    encode: [
      ...['-c:v', 'libx265', '-preset', 'ultrafast'],
      ...['-pix_fmt', 'yuv420p10le'],
      ..._x265Quiet,
    ],
    facts: VideoFacts(
      codec: 'hevc',
      profile: 'Main 10',
      width: 1280,
      height: 720,
      fps: 25,
      bitDepth: 10,
    ),
    plan: CastVideoTranscode(
      height: 360,
      bitRate: 1500000,
      fps: 25,
      reasons: [TranscodeReason.hevcRefused],
    ),
  ),
  HardwareDecode.mpeg2: _Sample(
    file: 'mpeg2.ts',
    size: '720x576',
    encode: [
      ...['-vf', 'setfield=tff', '-c:v', 'mpeg2video'],
      ...['-flags', '+ilme+ildct', '-top', '1', '-b:v', '4000000'],
    ],
    facts: VideoFacts(
      codec: 'mpeg2video',
      profile: 'Main',
      width: 720,
      height: 576,
      fps: 25,
      interlaced: true,
      bitDepth: 8,
    ),
    plan: CastVideoTranscode(
      height: 288,
      bitRate: 1500000,
      fps: 50,
      deinterlace: true,
      reasons: [TranscodeReason.codecUnsupported],
    ),
  ),
};
