import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'mpv_probe.dart';
import 'stream_server.dart';

const samples = [
  'h264_1080p50_aac.ts',
  'h264_1080p25_ac3.ts',
  'h264_1080i50_mp2.ts',
  'hevc_1080p50_aac.ts',
  'hevc_2160p25_eac3.ts',
  'mpeg2_576i25_mp2.ts',
  'codec_switch_h264_720p_to_1080p.ts',
  'vod_h264_aac_10min.mp4',
  'vod_h264_ac3_10min.mkv',
  'vod_hevc_eac3_subs.mkv',
];

class SpikeOptions {
  SpikeOptions._(List<String> args) : _args = args;

  final List<String> _args;

  String? _get(String name) {
    final i = _args.indexOf('--$name');
    return i >= 0 && i + 1 < _args.length ? _args[i + 1] : null;
  }

  late final String repo = _get('repo') ?? _findRepo();
  late final String auto = _get('auto') ?? 'none';
  late final String hwdec = _get('hwdec') ?? 'auto-safe';
  late final String label = _get('label') ?? 'manual';
  late final String? out = _get('out');
  late final int zapRuns = int.tryParse(_get('zap-runs') ?? '') ?? 20;
  late final List<String> only = _get('only')?.split(',') ?? samples;

  String get ffmpeg => '$repo/third_party/ffmpeg/linux-x64/ffmpeg';
  String get samplesDir => '$repo/tools/media_samples/out';

  static String _findRepo() {
    var dir = File(Platform.resolvedExecutable).parent;
    while (dir.path != dir.parent.path) {
      if (Directory('${dir.path}/third_party/ffmpeg').existsSync())
        return dir.path;
      dir = dir.parent;
    }
    return Directory.current.path;
  }
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final opts = SpikeOptions._(args);
  final server = await StreamServer.start(
    ffmpeg: opts.ffmpeg,
    samplesDir: opts.samplesDir,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: SpikeScreen(opts: opts, server: server),
    ),
  );
}

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key, required this.opts, required this.server});

  final SpikeOptions opts;
  final StreamServer server;

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  late final Player player = Player(
    configuration: const PlayerConfiguration(
      title: 'playback_spike',
      logLevel: MPVLogLevel.warn,
    ),
  );
  late final VideoController controller = VideoController(
    player,
    configuration: VideoControllerConfiguration(hwdec: widget.opts.hwdec),
  );
  late final MpvProbe probe = MpvProbe(player.platform! as NativePlayer);
  final subs = <StreamSubscription<Object?>>[];
  IOSink? outSink;
  Timer? overlayTimer;
  CpuSample lastCpu = CpuSample.now();
  Map<String, String> stats = {};
  String status = 'starting';
  int n = 0;

  SpikeOptions get opts => widget.opts;

  void emit(String type, Map<String, Object?> data) {
    final line = jsonEncode({
      'type': type,
      'label': opts.label,
      't': DateTime.now().toIso8601String(),
      ...data,
    });
    stdout.writeln('SPIKE $line');
    outSink?.writeln(line);
  }

  void setStatus(String s) {
    if (mounted) setState(() => status = s);
  }

  @override
  void initState() {
    super.initState();
    if (opts.out != null) {
      outSink = File(opts.out!).openWrite(mode: FileMode.append);
    }
    subs
      ..add(
        player.stream.log.listen(
          (l) => emit('mpv_log', {
            'prefix': l.prefix,
            'level': l.level,
            'text': l.text.trim(),
          }),
        ),
      )
      ..add(
        player.stream.error.listen((e) => emit('player_error', {'error': e})),
      );
    unawaited(_start());
  }

  Future<void> _start() async {
    final readBack = await probe.applyOptions(MpvProbe.balancedPreset);
    emit('start', {
      'hwdec_requested': opts.hwdec,
      'cores': Platform.numberOfProcessors,
      'env': {
        for (final k in [
          'XDG_SESSION_TYPE',
          'GDK_BACKEND',
          'DRI_PRIME',
          '__NV_PRIME_RENDER_OFFLOAD',
          '__GLX_VENDOR_LIBRARY_NAME',
        ])
          k: Platform.environment[k],
      },
      'versions': await probe.read(['mpv-version', 'ffmpeg-version']),
      'options_read_back': readBack,
      'names': await probe.verifyNames(),
    });
    overlayTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final s = await probe.read(MpvProbe.statProps);
      final now = CpuSample.now();
      s['cpu % (all cores)'] = now.since(lastCpu).total.toStringAsFixed(1);
      lastCpu = now;
      if (mounted) setState(() => stats = s);
    });
    if (opts.auto == 'samples' || opts.auto == 'all') await _runSamples();
    if (opts.auto == 'zap' || opts.auto == 'all') await _runZap();
    if (opts.auto != 'none') await _shutdown();
  }

  Future<int?> _open(String sample, {int burst = 0, Duration? timeout}) async {
    final token = 'n=${n++}';
    final sw = Stopwatch()..start();
    await player.open(
      Media(widget.server.url(sample, token: token, burst: burst)),
    );
    return probe.waitForFirstFrame(
      token,
      sw,
      timeout: timeout ?? const Duration(seconds: 20),
    );
  }

  Future<void> _runSamples() async {
    for (final name in opts.only) {
      setStatus('sample $name');
      final firstFrame = await _open(name);
      if (firstFrame == null) {
        emit('sample_result', {
          'sample': name,
          'ok': false,
          'reason': 'no first frame within 20 s',
          'last': await probe.read(MpvProbe.statProps),
        });
        continue;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
      final window = name.startsWith('codec_switch') ? 45 : 12;
      const dropProps = ['frame-drop-count', 'decoder-frame-drop-count'];
      final drops0 = await probe.read(dropProps);
      final cpu0 = CpuSample.now();
      const seenKeys = [
        'hwdec-current',
        'hwdec-interop',
        'current-vo',
        'video-codec',
        'video-format',
        'video-params/hw-pixelformat',
        'video-frame-info/interlaced',
        'audio-codec-name',
        'audio-params/channel-count',
      ];
      final seen = {
        for (final k in [...seenKeys, 'size']) k: <String>{},
      };
      var last = <String, String>{};
      for (var i = 0; i < window; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        last = await probe.read(MpvProbe.statProps);
        for (final k in seenKeys) {
          seen[k]!.add(last[k]!);
        }
        seen['size']!.add(
          '${last['video-params/w']}x${last['video-params/h']}',
        );
        emit('tick', {'sample': name, 'i': i, 'stats': last});
      }
      final cpu = CpuSample.now().since(cpu0);
      final drops1 = await probe.read(dropProps);
      int delta(String k) =>
          (int.tryParse(drops1[k]!) ?? 0) - (int.tryParse(drops0[k]!) ?? 0);
      emit('sample_result', {
        'sample': name,
        'ok': true,
        'first_frame_ms': firstFrame,
        'window_s': window,
        'cpu_total_pct': double.parse(cpu.total.toStringAsFixed(1)),
        'cpu_one_core_pct': double.parse(cpu.oneCore.toStringAsFixed(1)),
        'vo_drops': delta('frame-drop-count'),
        'decoder_drops': delta('decoder-frame-drop-count'),
        'seen': {for (final e in seen.entries) e.key: e.value.toList()},
        'last': last,
      });
    }
  }

  Future<void> _runZap() async {
    const a = 'h264_1080p50_aac.ts';
    const b = 'h264_1080p25_ac3.ts';
    for (final burst in [0, 2]) {
      setStatus('zap warm-up (burst $burst s)');
      await _open(a, burst: burst);
      await Future<void>.delayed(const Duration(seconds: 2));
      final times = <int>[];
      var failures = 0;
      for (var i = 0; i < opts.zapRuns; i++) {
        final target = i.isEven ? b : a;
        setStatus('zap ${i + 1}/${opts.zapRuns} → $target (burst $burst s)');
        final ms = await _open(
          target,
          burst: burst,
          timeout: const Duration(seconds: 15),
        );
        if (ms == null) {
          failures++;
        } else {
          times.add(ms);
        }
        emit('zap_run', {'burst_s': burst, 'i': i, 'to': target, 'ms': ms});
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
      times.sort();
      int? pct(double q) =>
          times.isEmpty ? null : times[(q * times.length).ceil() - 1];
      emit('zap_result', {
        'burst_s': burst,
        'runs': opts.zapRuns,
        'failures': failures,
        'p50_ms': pct(0.5),
        'p95_ms': pct(0.95),
        'min_ms': times.firstOrNull,
        'max_ms': times.lastOrNull,
        'all_ms': times,
      });
    }
  }

  Future<void> _shutdown() async {
    emit('done', {});
    overlayTimer?.cancel();
    for (final s in subs) {
      await s.cancel();
    }
    await player.dispose();
    await widget.server.close();
    await outSink?.flush();
    await outSink?.close();
    exit(0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = event.character;
    final index = ch == null ? null : int.tryParse(ch);
    if (index != null && index < samples.length) {
      setStatus('manual ${samples[index]}');
      unawaited(_open(samples[index]));
      return KeyEventResult.handled;
    }
    if (ch == 'z') {
      unawaited(_runZap());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    overlayTimer?.cancel();
    unawaited(player.dispose());
    unawaited(widget.server.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = [
      status,
      for (final e in stats.entries) '${e.key.padRight(28)} ${e.value}',
      '',
      'keys: 0-9 open sample · z zap test',
    ].join('\n');
    return Material(
      color: Colors.black,
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: Video(controller: controller, controls: NoVideoControls),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
