import 'dart:async';
import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/cast_v2_receivers.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/cast/relay/isolate_cast_relay.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/cast/relay/relay_runtime.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// The media samples the fake panel loops (tools/media_samples).
final samples = Directory('tools/media_samples/out');

/// The fake panel's live channels, by the sample each loops
/// (`liveSamples`' order, from stream id 1).
const channelOf = {
  'h264_1080p50_aac': 1,
  'h264_1080p25_ac3': 2,
  'hevc_1080p50_aac': 3,
  'h264_1080i50_mp2': 4,
  'mpeg2_576i25_mp2': 5,
  'hevc_2160p25_eac3': 6,
  'h264_2160p25_aac': 7,
  'codec_switch_h264_720p_to_1080p': 8,
};

/// The bundled FFmpeg, else the system's (CI's 4.4); `RELAY_FFMPEG_DIR`
/// picks one (`/usr/bin`: as CI runs).
FfmpegBinaries? relayBinaries() {
  final chosen = Platform.environment['RELAY_FFMPEG_DIR'];
  final bundled = chosen == null ? FfmpegBinaries.locate() : null;
  if (bundled != null) return bundled;
  for (final folder in [?chosen, '/usr/bin', '/usr/local/bin']) {
    final ffmpeg = File('$folder/ffmpeg');
    final ffprobe = File('$folder/ffprobe');
    if (ffmpeg.existsSync() && ffprobe.existsSync()) {
      return FfmpegBinaries(ffmpeg: ffmpeg.path, ffprobe: ffprobe.path);
    }
  }
  return null;
}

/// Why a test needing [needed] samples can't run here, or null.
String? relaySkip(List<String> needed) {
  if (Platform.isWindows) return 'the relay tests run on Linux';
  if (relayBinaries() == null) return 'no FFmpeg';
  for (final name in needed) {
    if (!File('${samples.path}/$name.ts').existsSync()) {
      return 'no $name sample (tools/media_samples/generate.sh)';
    }
  }
  return null;
}

/// Everything a cast through the relay needs, real except the TV: the
/// fake panel, the relay in its isolate with FFmpeg, a fake receiver that
/// fetches and checks what it plays, and the app's own Cast client.
final class RelayRig {
  new _({
    required this.temp,
    required this.binaries,
    required this.panel,
    required this.relay,
    required this.tv,
    required this.receivers,
    required this.supervisor,
    required this.logged,
    required this.log,
  });

  static Future<RelayRig> start({
    FakeDevice device = FakeDevice.tv4k,
    int maxConnections = 2,
    RelayTimings timings = const RelayTimings(),
    RelayProxyTimings proxyTimings = const RelayProxyTimings(),
  }) async {
    final binaries = relayBinaries()!;
    final temp = await Directory.systemTemp.createTemp('relay_rig');
    final panel = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!.copyWith(
          maxConnections: maxConnections,
        ),
        samplesDir: samples.path,
        ffmpegPath: binaries.ffmpeg,
        runDir: p.join(temp.path, 'panel'),
      ),
      port: 0,
    );
    final logged = MemoryOutput(bufferSize: 100000);
    final log = AppLog(output: logged, secrets: SecretRegistry());
    final processes = Directory(p.join(temp.path, 'processes'));
    final relay = IsolateCastRelay(
      binaries: binaries,
      processFolder: processes,
      relayFolder: Directory(p.join(temp.path, 'relay')),
      log: log,
      timings: timings,
      proxyTimings: proxyTimings,
    );
    final tv = await FakeReceiver.start(
      device: device,
      pingEvery: null,
      playback: FakePlayback(ffprobe: binaries.ffprobe),
    );
    return RelayRig._(
      temp: temp,
      binaries: binaries,
      panel: panel,
      relay: relay,
      tv: tv,
      receivers: CastV2Receivers(log: log),
      supervisor: ProcessSupervisor(folder: processes, log: log),
      logged: logged,
      log: log,
    );
  }

  final Directory temp;
  final FfmpegBinaries binaries;
  final FakeProviderServer panel;
  final IsolateCastRelay relay;
  final FakeReceiver tv;
  final CastV2Receivers receivers;
  final ProcessSupervisor supervisor;
  final MemoryOutput logged;
  final AppLog log;
  CastReceiverSession? _cast;

  /// The PID files of FFmpegs running now.
  Directory get processes => Directory(p.join(temp.path, 'processes'));

  /// This run's relay sessions' folders.
  Directory get sessions => Directory(p.join(temp.path, 'relay', '$pid'));

  Iterable<String> get logLines => logged.buffer.expand((event) => event.lines);

  /// [channel] of the panel, its URL built afresh as the app's
  /// `StreamResolver` does, with the panel's credentials in it and
  /// [query]'s faults.
  CastUpstreamSource source(
    int channel, {
    String query = '',
    String sourceId = 'panel',
    int maxConnections = 2,
    bool hls = false,
  }) => CastUpstreamSource(
    sourceId: sourceId,
    live: true,
    resolve: () async => Ok(
      CastUpstream(
        url:
            '${panel.url}/live/test/test/$channel.${hls ? 'm3u8' : 'ts'}'
            '${query.isEmpty ? '' : '?$query'}',
        userAgent: 'VLC/3.0.20 LibVLC/3.0.20',
        maxConnections: maxConnections,
        hls: hls,
      ),
    ),
  );

  /// [channel]'s facts, read by ffprobe through the relay's proxy
  /// (decision 3).
  Future<StreamFacts> probe(int channel, {int maxConnections = 2}) async {
    final input = await relay.openInput(
      source(channel, maxConnections: maxConnections),
    );
    expect(input, isNotNull);
    expect(input!.url, startsWith('http://127.0.0.1:'));
    try {
      final result = await FfprobeStreamProbe(
        ffprobe: binaries.ffprobe,
        supervisor: supervisor,
        log: log,
      ).probe(input.url);
      return switch (result) {
        StreamProbed(:final facts) => facts,
        StreamProbeFailed(:final reason, :final detail) => throw StateError(
          'probe failed: $reason $detail',
        ),
      };
    } finally {
      await input.close();
    }
  }

  CastPlan plan(
    StreamFacts facts, {
    CastDeviceProfile device = const CastDeviceProfile(),
    CastSettings settings = const CastSettings(),
    bool softwareEncoderOnly = true,
  }) {
    final planned = planCast(
      CastPlanRequest(
        facts: facts,
        source: const CastSourceInfo(sourceId: 'panel', live: true),
        device: device,
        settings: settings,
        softwareEncoderOnly: softwareEncoderOnly,
      ),
    );
    return (planned as CastPlanned).plan;
  }

  /// Starts relaying [plan], and waits until a LOAD can go.
  Future<Relayed> relayed(
    CastPlan plan,
    StreamFacts facts,
    CastUpstreamSource source, {
    Duration ready = const Duration(seconds: 25),
  }) async {
    final started = await relay.start(
      CastRelayRequest(
        plan: plan,
        facts: facts,
        source: source,
        localAddress: '127.0.0.1',
        encoder: plan.video is CastVideoTranscode
            ? const CastEncoder(CastEncoderKind.x264)
            : null,
      ),
    );
    final session = switch (started) {
      CastRelayStarted(:final session) => session,
      CastRelayNotStarted(:final failure) => throw StateError('$failure'),
    };
    final relayed = Relayed(session);
    expect(await session.ready.timeout(ready), isNull);
    return relayed;
  }

  /// The next [load] joins the TV again (LAUNCH): its receiver closed.
  void joinAgain() => _cast = null;

  /// LOADs [relayed] on the fake TV, as the coordinator will.
  Future<void> load(Relayed relayed, {bool live = true}) async {
    final session = relayed.session;
    final cast = _cast ??= switch (await receivers.join(
      CastAddress(tv.host, tv.port),
    )) {
      CastJoined(:final session) => session,
      final other => throw StateError('$other'),
    };
    final loaded = await cast.load(
      CastLoad(
        url: session.url,
        contentType: session.contentType,
        live: live,
        title: 'Relay test',
      ),
    );
    expect(loaded, isA<CastDone>());
  }

  /// Until the TV plays and has checked [checks] pieces of the stream.
  Future<void> playing({
    int checks = 2,
    Duration within = const Duration(seconds: 30),
  }) => until(
    () => tv.playerState == 'PLAYING' && tv.checks.length >= checks,
    within: within,
    what: 'PLAYING with $checks checks (${tv.playerState}, ${tv.checks})',
  );

  /// The FFmpegs running now, by their PID files.
  List<File> get running => processes.existsSync()
      ? processes.listSync().whereType<File>().toList()
      : const [];

  Future<void> close() async {
    if (Platform.environment['RELAY_LOG'] == '1') {
      // RELAY_LOG=1 shows the relay's log, for a test that fails.
      // ignore: avoid_print
      logLines.forEach(print);
    }
    await _cast?.stop();
    await relay.close();
    await tv.close();
    await panel.close();
    await log.close();
    await temp.delete(recursive: true);
  }
}

Future<void> until(
  bool Function() test, {
  Duration within = const Duration(seconds: 20),
  String what = 'the condition',
}) async {
  final deadline = DateTime.now().add(within);
  while (!test()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('waited ${within.inSeconds} s for $what');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// A relay session and everything it told, from its start.
final class Relayed {
  new(this.session) {
    session.events.listen(events.add);
  }

  final CastRelaySession session;
  final events = <CastRelayEvent>[];

  /// The first event of type [T] not taken yet.
  Future<T> next<T extends CastRelayEvent>({
    Duration within = const Duration(seconds: 30),
  }) async {
    await until(
      () => events.any((e) => e is T),
      within: within,
      what: '$T (${[for (final e in events) e.runtimeType]})',
    );
    final found = events.firstWhere((e) => e is T) as T;
    events.remove(found);
    return found;
  }
}

/// The proxy's timings shortened for the refusals' retries.
const quickRetries = RelayProxyTimings(
  limitRetries: [Duration(milliseconds: 300)],
  networkRetries: [Duration(milliseconds: 300)],
);
