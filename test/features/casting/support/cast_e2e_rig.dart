import 'dart:async';
import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/cast_v2_receivers.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/cast/relay/isolate_cast_relay.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:iptv_player/features/casting/data/artwork_cast_pictures.dart';
import 'package:iptv_player/features/casting/domain/cast_coordinator.dart';
import 'package:iptv_player/features/casting/domain/cast_items.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../../data/cast/relay/relay_rig.dart';
import '../../playback/support/playback_fakes.dart';
import 'cast_fakes.dart';

/// The fake panel's streams, built as `DbStreamResolver` builds a
/// panel's: from its address and credentials, on every call, with
/// [query]'s faults.
final class PanelResolver implements StreamResolver {
  new(this._panel);

  final FakeProviderServer _panel;
  String query = '';
  bool hls = false;
  int maxConnections = 1;
  final resolved = <String>[];

  /// A channel's stream served from another of the panel's: a channel
  /// that switched codec for good (the panel's own switch starts again
  /// with every connection).
  final remap = <String, int>{};

  Future<Result<ResolvedStream>> _answer(
    String path, {
    bool hls = false,
  }) async {
    resolved.add(path);
    return Ok(
      ResolvedStream(
        url: '${_panel.url}/$path${query.isEmpty ? '' : '?$query'}',
        userAgent: 'VLC/3.0.20 LibVLC/3.0.20',
        hls: hls,
        maxConnections: maxConnections,
      ),
    );
  }

  @override
  Future<Result<ResolvedStream>> live(ChannelItem channel) => _answer(
    'live/test/test/${remap[channel.remoteKey] ?? channel.remoteKey}'
    '.${hls ? 'm3u8' : 'ts'}',
    hls: hls,
  );

  @override
  Future<Result<ResolvedStream>> movie(MovieItem movie) =>
      _answer('movie/test/test/${movie.remoteKey}.${movie.ext}');

  @override
  Future<Result<ResolvedStream>> episode(EpisodeItem episode) =>
      _answer('series/test/test/${episode.remoteKey}.${episode.ext}');
}

/// A cast through the app, real except the screens and the TV: the fake
/// panel, the relay in its isolate with FFmpeg, ffprobe, our own Cast
/// client, the coordinators, and a fake TV that fetches and checks what
/// it plays (Phase 7 decision 8).
final class CastE2E {
  new _({
    required this.temp,
    required this.panel,
    required this.tv,
    required this.relay,
    required this.coordinator,
    required this.playback,
    required this.engine,
    required this.resolver,
    required this.devices,
    required this.progress,
    required this.logged,
    required this.binaries,
  });

  static Future<CastE2E> start({
    FakeDevice device = FakeDevice.tv4k,
    int maxConnections = 1,
    Duration giveUp = const Duration(seconds: 3),
  }) async {
    final binaries = relayBinaries()!;
    final temp = await Directory.systemTemp.createTemp('cast_e2e');
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
    );
    final tv = await FakeReceiver.start(
      device: device,
      pingEvery: null,
      playback: FakePlayback(ffprobe: binaries.ffprobe, giveUp: giveUp),
    );
    final resolver = PanelResolver(panel)..maxConnections = maxConnections;
    final engine = FakePlayerEngine();
    final progress = FakeWatchProgress();
    final playback = PlaybackCoordinator(
      engine: engine,
      resolver: resolver,
      prober: FakeProber(),
      history: FakeHistory(),
      channels: FakeChannels(),
      progress: progress,
      log: log,
    );
    final devices = MemoryCastDevices();
    final coordinator = CastCoordinator(
      receivers: CastV2Receivers(log: log),
      relay: relay,
      lookup: StreamFactsLookup(
        probe: FfprobeStreamProbe(
          ffprobe: binaries.ffprobe,
          supervisor: ProcessSupervisor(folder: processes, log: log),
          log: log,
        ),
      ),
      encoderDetection: _X264Only(),
      devices: devices,
      items: CastItems(resolver: resolver),
      playback: playback,
      classify: classifyStreamFailure,
      log: log,
      progress: progress,
      pictures: ArtworkCastPictures(
        ArtworkCache(directory: Directory(p.join(temp.path, 'art'))),
      ),
    );
    return CastE2E._(
      temp: temp,
      panel: panel,
      tv: tv,
      relay: relay,
      coordinator: coordinator,
      playback: playback,
      engine: engine,
      resolver: resolver,
      devices: devices,
      progress: progress,
      logged: logged,
      binaries: binaries,
    );
  }

  final Directory temp;
  final FakeProviderServer panel;
  final FakeReceiver tv;
  final IsolateCastRelay relay;
  final CastCoordinator coordinator;
  final PlaybackCoordinator playback;
  final FakePlayerEngine engine;
  final PanelResolver resolver;
  final MemoryCastDevices devices;
  final FakeWatchProgress progress;
  final MemoryOutput logged;
  final FfmpegBinaries binaries;

  /// The fake TV, as the app sees it: added by its address.
  CastDevice get device => CastDevice(
    id: 'fake-tv',
    name: 'Fake TV',
    host: tv.host,
    port: tv.port,
    model: 'Chromecast',
    manual: true,
  );

  CastingState get state => coordinator.state;

  /// Every plan the cast had, in order, from when this is first asked.
  List<CastPlan> get plans {
    if (_plans == null) {
      final plans = _plans = [];
      coordinator.states.listen((state) {
        final plan = state.plan;
        if (plan != null && plans.lastOrNull != plan) plans.add(plan);
      });
    }
    return _plans!;
  }

  List<CastPlan>? _plans;

  Iterable<String> get logLines => logged.buffer.expand((e) => e.lines);

  /// The FFmpegs running now, by their PID files.
  List<File> get running {
    final folder = Directory(p.join(temp.path, 'processes'));
    return folder.existsSync()
        ? folder.listSync().whereType<File>().toList()
        : const [];
  }

  /// This run's relay sessions' folders.
  List<FileSystemEntity> get sessionFolders {
    final folder = Directory(p.join(temp.path, 'relay', '$pid'));
    return folder.existsSync() ? folder.listSync() : const [];
  }

  /// Until the coordinator is in [phase].
  Future<void> phase(
    CastPhase phase, {
    Duration within = const Duration(seconds: 30),
  }) => until(
    () => state.phase == phase,
    within: within,
    what: '${phase.name} ($state)',
  );

  /// Until the TV plays and has checked [checks] more pieces than
  /// [after].
  Future<void> tvPlaying({
    int after = 0,
    int checks = 2,
    Duration within = const Duration(seconds: 40),
  }) => until(
    () => tv.playerState == 'PLAYING' && tv.checks.length >= after + checks,
    within: within,
    what: 'the TV PLAYING with $checks checks (${tv.playerState})',
  );

  Future<void> close() async {
    if (Platform.environment['RELAY_LOG'] == '1') {
      // RELAY_LOG=1 shows the cast's log, for a test that fails.
      // ignore: avoid_print
      logLines.forEach(print);
    }
    await coordinator.dispose();
    await playback.dispose();
    await relay.close();
    await tv.close();
    await panel.close();
    await temp.delete(recursive: true);
  }
}

/// CI has no GPU: re-encodes run on the processor.
final class _X264Only implements CastEncoderDetection {
  static const _found = CastEncoders([CastEncoder(CastEncoderKind.x264)]);

  @override
  Future<CastEncoders> encoders() async => _found;

  @override
  Future<CastEncoders> detectAgain() async => _found;
}

/// A panel channel as the screens hold it: its stream id is its key.
ChannelItem panelChannel(int streamId, {String? logoUrl}) => ChannelItem(
  id: streamId,
  sourceId: 'panel',
  remoteKey: '$streamId',
  name: 'Channel $streamId',
  number: streamId,
  logoUrl: logoUrl,
);
