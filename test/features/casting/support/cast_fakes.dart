import 'dart:async';

import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_store.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/casting/domain/cast_coordinator.dart';
import 'package:iptv_player/features/casting/domain/cast_items.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:logger/logger.dart';

import '../../playback/support/playback_fakes.dart';

const tvDevice = CastDevice(
  id: 'tv1',
  name: 'Living Room TV',
  host: '192.168.1.155',
  model: 'Chromecast',
);

/// H.264 1080p50 with AAC: copied into HLS.
const h264Facts = StreamFacts(
  origin: StreamFactsOrigin.probe,
  container: MediaContainer.mpegTs,
  video: VideoFacts(
    codec: 'h264',
    profile: 'High',
    width: 1920,
    height: 1080,
    fps: 50,
    interlaced: false,
    bitDepth: 8,
    bitRate: 8000000,
  ),
  audio: [AudioFacts(index: 0, codec: 'aac', channels: 2)],
);

/// HEVC 4K with E-AC-3: a continuous stream, the sound converted.
const hevc4kFacts = StreamFacts(
  origin: StreamFactsOrigin.probe,
  container: MediaContainer.mpegTs,
  video: VideoFacts(
    codec: 'hevc',
    profile: 'Main',
    width: 3840,
    height: 2160,
    fps: 25,
    interlaced: false,
    bitDepth: 8,
    bitRate: 20000000,
  ),
  audio: [AudioFacts(index: 0, codec: 'eac3', channels: 6)],
);

/// A movie in Matroska, H.264 with AC-3: one continuous stream.
const mkvFacts = StreamFacts(
  origin: StreamFactsOrigin.probe,
  container: MediaContainer.matroska,
  duration: Duration(minutes: 100),
  video: VideoFacts(
    codec: 'h264',
    profile: 'High',
    width: 1920,
    height: 1080,
    fps: 24,
    interlaced: false,
    bitDepth: 8,
  ),
  audio: [AudioFacts(index: 0, codec: 'ac3', channels: 6)],
);

/// A movie in MP4, H.264 with AAC: the TV reads it itself.
const mp4Facts = StreamFacts(
  origin: StreamFactsOrigin.probe,
  container: MediaContainer.mp4,
  duration: Duration(minutes: 100),
  video: VideoFacts(
    codec: 'h264',
    profile: 'High',
    width: 1920,
    height: 1080,
    fps: 24,
    interlaced: false,
    bitDepth: 8,
  ),
  audio: [AudioFacts(index: 0, codec: 'aac', channels: 2)],
);

/// A receiver session on a scripted TV: every command recorded; what it
/// reports, sent by the test.
final class FakeTv implements CastReceiverSession {
  new({this.localAddress = '192.168.1.20'});

  @override
  final CastAddress address = const CastAddress('192.168.1.155');

  @override
  final String localAddress;

  CastSessionState _state = const CastSessionState();
  final _states = StreamController<CastSessionState>.broadcast();
  final loads = <CastLoad>[];

  /// Every command but LOAD: `play`, `pause`, `seek:<ms>`, `stopMedia`,
  /// `stop`, `leave`, `volume:<level>`, `muted:<bool>`.
  final calls = <String>[];

  /// What a LOAD answers; by default (or null) the TV took it.
  CastCommandResult? Function(CastLoad load)? onLoad;
  int _media = 0;

  int get mediaSession => _media;

  @override
  CastSessionState get state => _state;

  @override
  Stream<CastSessionState> get states => _states.stream;

  void emit(CastSessionState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  /// The last LOAD's media is now [playerState].
  void media(
    CastPlayerState playerState, {
    CastIdleReason? idle,
    Duration position = Duration.zero,
    Duration? duration,
  }) => emit(
    _state.copyWith(
      media: CastMediaStatus(
        sessionId: _media,
        playerState: playerState,
        idleReason: idle,
        position: position,
        duration: duration,
        contentId: loads.lastOrNull?.url,
      ),
    ),
  );

  void playing({Duration position = Duration.zero}) =>
      media(CastPlayerState.playing, position: position);

  void idle(CastIdleReason reason, {Duration position = Duration.zero}) =>
      media(CastPlayerState.idle, idle: reason, position: position);

  @override
  Future<CastCommandResult> load(CastLoad request) async {
    loads.add(request);
    _media++;
    return onLoad?.call(request) ??
        CastDone(
          CastMediaStatus(
            sessionId: _media,
            playerState: CastPlayerState.loading,
            contentId: request.url,
          ),
        );
  }

  @override
  Future<CastCommandResult> play() async {
    calls.add('play');
    return const CastDone();
  }

  @override
  Future<CastCommandResult> pause() async {
    calls.add('pause');
    return const CastDone();
  }

  @override
  Future<CastCommandResult> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    return const CastDone();
  }

  @override
  Future<CastCommandResult> stopMedia() async {
    calls.add('stopMedia');
    return const CastDone();
  }

  @override
  Future<CastCommandResult> setVolume(double level) async {
    calls.add('volume:$level');
    return const CastDone();
  }

  @override
  Future<CastCommandResult> setMuted({required bool muted}) async {
    calls.add('muted:$muted');
    return const CastDone();
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emit(_state.copyWith(link: CastLink.ended, end: CastEnd.stopped));
  }

  @override
  Future<void> leave() async {
    calls.add('leave');
    emit(_state.copyWith(link: CastLink.ended, end: CastEnd.left));
  }
}

final class FakeReceivers implements CastReceivers {
  FakeTv tv = FakeTv();

  /// What a join answers; by default the TV joined, its receiver
  /// launched.
  CastJoinResult Function()? answer;

  /// Holds a join after its connection is up (the TV launching).
  Completer<void>? launching;
  final joins = <CastAddress>[];
  bool joined = false;

  @override
  Future<CastJoinResult> join(
    CastAddress address, {
    void Function(String localAddress)? onConnected,
  }) async {
    joins.add(address);
    final result = answer?.call() ?? CastJoined(tv, launched: true);
    if (result is CastJoined) onConnected?.call(tv.localAddress);
    if (launching case final wait?) await wait.future;
    joined = result is CastJoined;
    return result;
  }
}

final class FakeRelaySession implements CastRelaySession {
  new(this.request, this.id, this.log)
    : url = 'http://192.168.1.20:38400/r/$id/index.m3u8';

  final CastRelayRequest request;
  final List<String> log;

  @override
  final String id;

  @override
  String url;

  @override
  String get contentType => request.plan.delivery.contentType;

  final _ready = Completer<CastRelayFailure?>();
  final _events = StreamController<CastRelayEvent>();
  final renews = <({Duration? startAt, bool plan})>[];
  CastRelayFailure? renewFailure;
  bool stopped = false;

  void becomeReady() {
    if (!_ready.isCompleted) _ready.complete(null);
  }

  void emit(CastRelayEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// The session fails, as the relay tells it: `ready` and the event.
  void fail(CastRelayFailure failure) {
    if (!_ready.isCompleted) _ready.complete(failure);
    emit(CastRelayFailed(failure));
  }

  @override
  Future<CastRelayFailure?> get ready => _ready.future;

  @override
  Stream<CastRelayEvent> get events => _events.stream;

  @override
  Future<CastRelayFailure?> renew({Duration? startAt, CastPlan? plan}) async {
    renews.add((startAt: startAt, plan: plan != null));
    log.add('renew:$id');
    if (renewFailure case final failure?) {
      fail(failure);
      return failure;
    }
    url = 'http://192.168.1.20:38400/p/$id-${renews.length}/stream.mp4';
    return null;
  }

  @override
  Future<void> stop() async {
    if (stopped) return;
    stopped = true;
    log.add('stop:$id');
    if (!_ready.isCompleted) {
      _ready.complete(
        const CastRelayFailure(
          CastRelayFailureKind.couldNotStart,
          detail: 'stopped',
        ),
      );
    }
    await _events.close();
  }
}

final class FakeInput implements CastRelayInput {
  new(this.url, this.log);

  final List<String> log;

  @override
  final String url;

  @override
  CastRelayFailure? refusal;

  @override
  Future<void> close() async => log.add('input closed');
}

final class FakeServed implements CastServedFile {
  new(this.url, this.closed);

  final List<String> closed;

  @override
  final String url;

  @override
  Future<void> close() async => closed.add(url);
}

/// The relay, scripted: sessions ready at once unless told otherwise.
final class FakeRelay implements CastRelay {
  final sessions = <FakeRelaySession>[];

  /// What happened, in order: `input`, `input closed`, `start:<id>`,
  /// `stop:<id>`, `renew:<id>`.
  final log = <String>[];
  bool readyAtOnce = true;
  CastRelayFailure? notStarted;

  /// The refusal a probe's input records.
  CastRelayFailure? inputRefusal;
  final pictures = <String>[];
  final unserved = <String>[];
  final _connections = StreamController<CastRelayConnections>.broadcast();

  FakeRelaySession get last => sessions.last;

  @override
  Future<CastRelayStart> start(CastRelayRequest request) async {
    if (notStarted case final failure?) return CastRelayNotStarted(failure);
    final session = FakeRelaySession(
      request,
      'cast-${sessions.length + 1}',
      log,
    );
    sessions.add(session);
    log.add('start:${session.id}');
    if (readyAtOnce) session.becomeReady();
    return CastRelayStarted(session);
  }

  @override
  Future<CastRelayInput?> openInput(CastUpstreamSource source) async {
    log.add('input');
    return FakeInput('http://127.0.0.1:41000/in/probe', log)
      ..refusal = inputRefusal;
  }

  @override
  Future<CastServedFile?> servePicture(
    String path, {
    required String localAddress,
  }) async {
    pictures.add(path);
    return FakeServed('http://$localAddress:38400/f/pic/media.png', unserved);
  }

  @override
  Stream<CastRelayConnections> get connections => _connections.stream;

  void connectionsNow(String sourceId, int open) =>
      _connections.add(CastRelayConnections(sourceId, open));

  @override
  Future<void> close() async {}
}

final class FakeProbe implements StreamProbe {
  StreamProbeResult next = const StreamProbed(h264Facts);
  final inputs = <String>[];

  @override
  Future<StreamProbeResult> probe(String input, {String? userAgent}) async {
    inputs.add(input);
    return next;
  }
}

final class FakeEncoderDetection implements CastEncoderDetection {
  CastEncoders found = const CastEncoders([
    CastEncoder(CastEncoderKind.nvenc),
    CastEncoder(CastEncoderKind.x264),
  ]);

  /// What detecting again finds; [found] when null.
  CastEncoders? again;
  int detectedAgain = 0;

  @override
  Future<CastEncoders> encoders() async => found;

  @override
  Future<CastEncoders> detectAgain() async {
    detectedAgain++;
    return again ?? found;
  }
}

/// `cast_devices` in memory.
final class MemoryCastDevices implements CastDeviceStore {
  final devices = <String, KnownCastDevice>{};
  final used = <String>[];
  final _changes = StreamController<void>.broadcast();

  List<KnownCastDevice> get _sorted =>
      devices.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  void _changed() => _changes.add(null);

  @override
  Stream<List<KnownCastDevice>> watchAll() async* {
    yield _sorted;
    yield* _changes.stream.map((_) => _sorted);
  }

  @override
  Future<Result<KnownCastDevice?>> byId(String id) async => Ok(devices[id]);

  KnownCastDevice _from(CastDevice device, {required bool manual}) =>
      devices[device.id]?.copyWith(
        name: device.name,
        host: device.host,
        port: device.port,
        model: device.model,
      ) ??
      KnownCastDevice(
        id: device.id,
        name: device.name,
        host: device.host,
        port: device.port,
        manual: manual,
        model: device.model,
        hevc: HevcSupport.auto,
        learned: const CastLearned(),
      );

  @override
  Future<Result<void>> addManual(CastDevice device) async {
    devices[device.id] = _from(device, manual: true);
    _changed();
    return const Ok(null);
  }

  @override
  Future<Result<void>> markUsed(CastDevice device, DateTime at) async {
    used.add(device.id);
    devices[device.id] = _from(
      device,
      manual: device.manual,
    ).copyWith(lastUsedAt: at);
    _changed();
    return const Ok(null);
  }

  @override
  Future<Result<void>> refresh(CastDevice device) async => const Ok(null);

  @override
  Future<Result<void>> setHevcSupport(String id, HevcSupport value) async {
    devices[id] = devices[id]!.copyWith(hevc: value);
    _changed();
    return const Ok(null);
  }

  @override
  Future<Result<void>> setLearned(String id, CastLearned learned) async {
    final known = devices[id];
    if (known == null) return Err(NotFoundFailure('device $id'));
    devices[id] = known.copyWith(learned: learned);
    _changed();
    return const Ok(null);
  }

  @override
  Future<Result<void>> forget(String id) async {
    devices.remove(id);
    _changed();
    return const Ok(null);
  }
}

final class FakeSleep implements SleepInhibitor {
  bool held = false;
  final calls = <String>[];

  @override
  Future<bool> hold(String why) async {
    calls.add('hold');
    return held = true;
  }

  @override
  Future<void> release() async {
    calls.add('release');
    held = false;
  }
}

final class FakePictures implements CastPictures {
  @override
  Future<String?> fileFor(String url) async => '/cache/${url.hashCode}';
}

/// Short waits, so every rule runs in a test's time.
const fastTimings = CastTimings(
  reach: Duration(milliseconds: 400),
  learnWithin: Duration(seconds: 2),
  directWithin: Duration(seconds: 2),
  picture: Duration(milliseconds: 200),
  saveEvery: Duration(seconds: 1),
  quit: Duration(seconds: 1),
);

/// A cast coordinator on fakes, beside a playback coordinator on fakes.
final class CastRig {
  new({CastTimings timings = fastTimings, this.beforeFirstRelay, Rig? playback})
    : playback = playback ?? Rig() {
    coordinator = CastCoordinator(
      receivers: receivers,
      relay: relay,
      lookup: StreamFactsLookup(probe: probe),
      encoderDetection: encoders,
      devices: devices,
      items: CastItems(resolver: this.playback.resolver),
      playback: this.playback.coordinator,
      classify: classifyStreamFailure,
      log: AppLog(output: logged, secrets: SecretRegistry()),
      progress: this.playback.progress,
      history: this.playback.history,
      sleep: sleep,
      pictures: FakePictures(),
      beforeFirstRelay: beforeFirstRelay,
      timings: timings,
    );
    coordinator.states.listen(states.add);
    coordinator.notices.listen(notices.add);
  }

  final Future<void> Function()? beforeFirstRelay;
  final Rig playback;
  final receivers = FakeReceivers();
  final relay = FakeRelay();
  final probe = FakeProbe();
  final encoders = FakeEncoderDetection();
  final devices = MemoryCastDevices();
  final sleep = FakeSleep();
  final logged = MemoryOutput(bufferSize: 10000);
  late final CastCoordinator coordinator;
  final states = <CastingState>[];
  final notices = <CastNotice>[];

  FakeTv get tv => receivers.tv;
  CastingState get state => coordinator.state;
  Iterable<String> get logLines => logged.buffer.expand((e) => e.lines);

  /// Until [test] holds, or fails after [within].
  Future<void> until(
    bool Function() test, {
    Duration within = const Duration(seconds: 5),
    String? what,
  }) async {
    final deadline = DateTime.now().add(within);
    while (!test()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'waited for ${what ?? 'the condition'}: $state\n'
          '${logLines.join('\n')}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> phase(CastPhase phase) =>
      until(() => state.phase == phase, what: phase.name);

  /// Until the TV got [count] LOADs.
  Future<void> loaded([int count = 1]) =>
      until(() => tv.loads.length >= count, what: '$count LOADs');

  /// The TV refuses the next LOAD with a bare LOAD_FAILED, then takes
  /// them again.
  void refuseNextLoad() {
    var refused = false;
    tv.onLoad = (_) {
      if (refused) return null;
      refused = true;
      return const CastRefused(CastRefusal.loadFailed);
    };
  }

  Future<void> dispose() => coordinator.dispose();
}
