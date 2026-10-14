import 'dart:async';

import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_device_store.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_mp4_copies.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/cast_subtitles.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/core/text/languages.dart';
import 'package:iptv_player/features/casting/domain/cast_items.dart';
import 'package:iptv_player/features/casting/domain/cast_learning.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/domain/remote_playback.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

const _tag = 'cast';

/// docs/03's error classes from a provider's answer: the playback side's
/// `classifyStreamFailure`, so a cast fails with the same words.
typedef StreamFailureClassifier = PlaybackProblem Function({
  required int? status,
  String body,
  String? detail,
});

/// The waits a cast keeps (docs/04, Phase 7 step 6).
final class CastTimings {
  const new({
    this.reach = const Duration(seconds: 10),
    this.liveEnd = const Duration(seconds: 10),
    this.learnWithin = const Duration(seconds: 15),
    this.directWithin = const Duration(seconds: 10),
    this.recasts = 3,
    this.recastWindow = const Duration(minutes: 2),
    this.lessons = 4,
    this.encoderTries = 4,
    this.picture = const Duration(seconds: 3),
    this.subtitles = const Duration(seconds: 2),
    this.saveEvery = const Duration(seconds: 10),
    this.earlyEnd = const Duration(seconds: 10),
    this.quit = const Duration(seconds: 3),
  });

  /// The TV must ask for the relay's stream within this of the LOAD;
  /// otherwise it can't reach this computer (a firewall, a VPN).
  final Duration reach;

  /// A live continuous stream that ended is loaded again when the TV
  /// hasn't said IDLE/FINISHED within this: the Bedroom TV never says it
  /// and stays BUFFERING (2026-10-14, the matrix's row 11).
  final Duration liveEnd;

  /// A refusal this soon after a relayed LOAD teaches the device's limits
  /// (docs/04 "Learning").
  final Duration learnWithin;

  /// A direct play that fails this soon goes through the relay from then
  /// on (docs/04 rule 1).
  final Duration directWithin;

  /// How often a cast is loaded again by itself (the TV dropped a live
  /// stream, its codec changed, a file was cut short) within
  /// [recastWindow] before it fails.
  final int recasts;
  final Duration recastWindow;

  /// How many lessons one cast can learn, each changing its plan once.
  final int lessons;

  /// How many encoders a re-encode tries before it gives up.
  final int encoderTries;

  /// How long the TV's picture may take; the LOAD goes without it after.
  final Duration picture;

  /// How long a file's LOAD waits for its subtitles, from the moment the
  /// cast began. Those made later are there for the asking: choosing one
  /// loads the file again where it is.
  final Duration subtitles;

  /// How often a file's place is saved while it plays.
  final Duration saveEvery;

  /// A file that ends further than this before its length was cut short:
  /// it carries on where it was.
  final Duration earlyEnd;

  /// What quitting gives the TV and the relay.
  final Duration quit;
}

/// Casts to one device at a time (docs/04's CastCoordinator, Phase 7
/// step 6). A session joins the device's receiver (the running one, else
/// a LAUNCH), and what the laptop played moves to it; from then on the
/// playback coordinator hands it every play (decision 2).
///
/// Each play: the stream's facts (the laptop's player, then what this run
/// remembers, then ffprobe through the relay's proxy: decision 4), a plan
/// (`planCast` with the device's profile and what it taught before), then
/// either a direct LOAD of the provider's URL or the relay, whose first
/// segments are made while the TV launches its receiver; the LOAD once
/// they are ready.
///
/// It follows the TV and the relay: a refusal soon after a LOAD teaches
/// the device a limit and plans again (docs/04 "Learning"), a direct play
/// that fails goes through the relay, a re-encode that fails tries the
/// next encoder, a live continuous stream that ends is loaded again
/// (ADR-004), a codec change is planned again, a TV that never fetches
/// the stream "couldn't reach this computer". A file's place is the TV's
/// time plus where the relay started; seeking a relayed file starts it
/// again there (decision 1); its place is saved like local playback. A
/// file on this computer brings its text subtitles as WebVTT the relay
/// serves, named in the LOAD and switched with [setSubtitle] (Phase 8
/// decision 12). While such a file is relayed with its picture copied, an
/// MP4 of it is made beside the relay; once it is whole, the next seek
/// loads it, and the TV seeks in it by itself from then on. The computer
/// is kept awake while something is cast (decision 7).
final class CastCoordinator implements RemotePlayback {
  new({
    required this._receivers,
    required this._relay,
    required this._lookup,
    required this._encoderDetection,
    required this._devices,
    required this._items,
    required this._playback,
    required this._classify,
    required this._log,
    this._progress,
    this._history,
    this._sleep = const NoSleepInhibitor(),
    this._pictures = const NoCastPictures(),
    this._subtitles = const NoCastSubtitles(),
    this._mp4s = const NoCastMp4Copies(),
    CastSettings Function()? settings,
    List<String> Function()? audioLanguages,
    List<String> Function()? subtitleLanguages,
    this._beforeFirstRelay,
    this.timings = const CastTimings(),
  }) : _settings = settings ?? (() => const CastSettings()),
       _languages = audioLanguages ?? (() => const []),
       _subtitleLanguages = subtitleLanguages ?? (() => const []) {
    _relayConnections = _relay.connections.listen(_onRelayConnections);
  }

  final CastReceivers _receivers;
  final CastRelay _relay;
  final StreamFactsLookup _lookup;
  final CastEncoderDetection _encoderDetection;
  final CastDeviceStore _devices;
  final CastItems _items;
  final PlaybackCoordinator _playback;
  final StreamFailureClassifier _classify;
  final AppLog _log;
  final WatchProgress? _progress;
  final PlaybackHistory? _history;
  final SleepInhibitor _sleep;
  final CastPictures _pictures;
  final CastSubtitles _subtitles;
  final CastMp4Copies _mp4s;
  final CastSettings Function() _settings;
  final List<String> Function() _languages;

  /// Settings → Playback's "Preferred subtitles", most wanted first.
  final List<String> Function() _subtitleLanguages;
  final CastTimings timings;

  /// Before the first relay start: Windows' firewall asks about it, and
  /// the app explains first (step 7's dialog).
  Future<void> Function()? _beforeFirstRelay;

  final _states = StreamController<CastingState>.broadcast();
  final _notices = StreamController<CastNotice>.broadcast();
  final _timelines = StreamController<VodTimeline>.broadcast();
  final _clock = Stopwatch()..start();
  CastingState _state = const CastingState();
  VodTimeline _timeline = const VodTimeline();
  late final StreamSubscription<CastRelayConnections> _relayConnections;
  final _relayOpen = <String, int>{};

  // The session.
  int _session = 0;
  CastDevice? _device;
  KnownCastDevice? _known;
  Future<void>? _profileReady;
  Future<void>? _markedUsed;
  late Future<CastEncoders> _encoders;
  Completer<String?>? _local;
  Future<CastReceiverSession?>? _joined;
  CastReceiverSession? _tv;
  StreamSubscription<CastSessionState>? _tvStates;
  var _joinFailed = false;
  var _awake = false;

  /// What plays now.
  _Cast? _cast;

  CastingState get state => _state;

  /// Every change of [state].
  Stream<CastingState> get states => _states.stream;

  /// The quiet fallbacks and the ends nobody here asked for: toasts.
  Stream<CastNotice> get notices => _notices.stream;

  /// Where a movie or an episode is on the TV, as it changes.
  Stream<VodTimeline> get timelines => _timelines.stream;

  VodTimeline get timeline => _timeline;

  @override
  String get deviceName => _device?.name ?? 'the TV';

  /// Starts a session on [device], ending any other first: what plays on
  /// the laptop moves to it, a file at its place, and everything played
  /// after goes there too (decision 2). Its receiver starts beside the
  /// stream's preparation (the TV's 3–6 s launch overlaps the relay's).
  Future<void> connect(CastDevice device) async {
    if (_device != null) await disconnect();
    final session = ++_session;
    _device = device;
    _known = null;
    _joinFailed = false;
    _set(CastingState(phase: CastPhase.connecting, device: device));
    _log.info(_tag, 'Casting to ${device.name}');
    final handover = await _playback.castStarted(this);
    if (session != _session) return;
    _profileReady = _loadKnown(device, session);
    _encoders = _encoderDetection.encoders();
    _join(device, session);
    if (handover != null) {
      // Not waited for: the cast goes on while the screens move on.
      unawaited(
        _play(handover.item, from: handover.position, handover: handover),
      );
    }
  }

  /// Stop casting: the TV goes back to its home screen, the relay stops,
  /// and nothing starts playing here by itself (decision 2).
  Future<void> disconnect() async {
    final device = _device;
    if (device == null) return;
    ++_session;
    final cast = _cast;
    _cast = null;
    if (cast != null) await _endCast(cast, save: true);
    final tv = _tv;
    await _forgetSession();
    if (tv != null) await tv.stop();
    _log.info(_tag, 'Stopped casting to ${device.name}');
  }

  /// Ends the session and plays what was cast on the laptop: a file from
  /// its place on the TV.
  Future<void> playHere() async {
    final cast = _cast;
    final item = cast?.item ?? _state.item;
    final position = cast == null || cast.item.live ? null : _position(cast);
    await disconnect();
    switch (item) {
      case null:
        return;
      case PlayableChannel(:final channel):
        await _playback.playLive(channel);
      case final Playable file:
        await _playback.playVod(file, from: position);
    }
  }

  @override
  Future<void> play(Playable item, {Duration? from}) async {
    if (_device == null) {
      _log.warning(_tag, 'A play with no cast session');
      return;
    }
    await _play(item, from: from);
  }

  /// Tries again after a failure: the device, if it was the join that
  /// failed, then what was cast, a file from its place.
  @override
  Future<void> retry() async {
    final device = _device;
    if (device == null) return;
    final cast = _cast;
    final item = cast?.item ?? _state.item;
    final from = cast == null || cast.item.live ? cast?.from : _position(cast);
    if (_joinFailed) {
      _joinFailed = false;
      _set(_state.copyWith(phase: CastPhase.connecting, problem: null));
      _join(device, _session);
    }
    if (item != null) {
      await _play(item, from: from);
    } else if (_tv != null) {
      _set(_state.copyWith(phase: CastPhase.idle, problem: null));
    }
  }

  /// Moves the file on the TV to [position]: the TV seeks a direct file
  /// itself; the relay starts again there (decision 1), with "Preparing…"
  /// meanwhile — unless the MP4 made beside it is ready, which is loaded
  /// there instead, for the TV to seek in from then on.
  @override
  Future<void> seek(Duration position) async {
    final cast = _cast;
    final plan = cast?.plan;
    if (cast == null || plan == null || cast.item.live || !cast.played) {
      return;
    }
    final length = _length(cast);
    var to = position < Duration.zero ? Duration.zero : position;
    if (length != null && to > length) to = length;
    cast
      ..anchor = to
      ..running = false;
    _publishTimeline(cast);
    unawaited(_save(cast));
    if (_tvReads(cast)) {
      await _tv?.seek(to);
      return;
    }
    final session = cast.relay;
    if (session == null) return;
    if (cast.mp4Path != null) return await _moveToMp4(cast, to);
    final generation = _restart(cast);
    cast
      ..from = to
      ..starts = to;
    _set(_state.copyWith(phase: CastPhase.preparing, buffering: false));
    final begins = await _startOf(cast, to);
    if (!_current(cast, session, generation)) return;
    final failure = await session.renew(
      startAt: to,
      timeline: _clockOf(cast, begins),
    );
    if (failure != null || !_current(cast, session, generation)) return;
    final tv = await _joined;
    if (tv == null || !_current(cast, session, generation)) return;
    cast.starts = begins;
    await _load(
      cast,
      tv,
      generation,
      url: session.url,
      contentType: session.contentType,
      start: begins,
    );
  }

  /// Shows the [id]th of [CastingState.subtitles] on the TV (from 1), or
  /// none for null. One the TV already has is switched to at once. One
  /// that was made after the TV loaded the file needs the file loaded
  /// again where it is, with "Preparing…" meanwhile: a LOAD is the only
  /// way to hand a subtitle over.
  Future<void> setSubtitle(int? id) async {
    final cast = _cast;
    if (cast == null || cast.item.live) return;
    if (id != null && (id < 1 || id > _state.subtitles.length)) return;
    cast
      ..textTrack = id
      ..subtitleChosen = true;
    _set(_state.copyWith(subtitle: id));
    // Before it plays, the LOAD to come carries the choice; one already
    // on its way is followed once it plays.
    await _showChosenSubtitle(cast);
  }

  @override
  Future<void> setPaused({required bool paused}) async {
    final cast = _cast;
    final tv = _tv;
    if (cast == null || tv == null || !cast.played) return;
    if (paused) {
      cast
        ..anchor = _position(cast)
        ..running = false;
      unawaited(_save(cast));
      await tv.pause();
    } else {
      await tv.play();
    }
  }

  /// The TV's volume, 0–1 (a TV whose remote sets it keeps its own).
  Future<void> setVolume(double level) async {
    await _tv?.setVolume(level.clamp(0, 1).toDouble());
  }

  Future<void> setMuted({required bool muted}) async {
    await _tv?.setMuted(muted: muted);
  }

  /// The app quits: the TV's media and the relay stop, within
  /// [CastTimings.quit].
  Future<void> shutdown() async {
    try {
      await disconnect().timeout(timings.quit);
    } on TimeoutException {
      _log.warning(_tag, 'The TV did not stop in time for quitting');
    }
  }

  Future<void> dispose() async {
    await shutdown();
    await _relayConnections.cancel();
    await _states.close();
    await _notices.close();
    await _timelines.close();
  }

  // The session.

  Future<void> _loadKnown(CastDevice device, int session) async {
    final found = await _devices.byId(device.id);
    if (session == _session) _known = found.valueOrNull;
  }

  void _join(CastDevice device, int session) {
    final local = _local = Completer<String?>();
    final joined = Completer<CastReceiverSession?>();
    _joined = joined.future;
    unawaited(() async {
      final clock = Stopwatch()..start();
      final result = await _receivers.join(
        CastAddress(device.host, device.port),
        onConnected: (address) {
          if (!local.isCompleted) local.complete(address);
        },
      );
      if (session != _session) {
        // Stopped while it joined.
        if (result case CastJoined(:final session)) await session.stop();
        if (!local.isCompleted) local.complete(null);
        joined.complete(null);
        return;
      }
      switch (result) {
        case CastJoinFailed(:final reason, :final detail):
          _log.warning(_tag, 'Could not join ${device.name}: ${reason.name}');
          if (!local.isCompleted) local.complete(null);
          joined.complete(null);
          await _joinFailedWith(
            CastProblem(
              reason == CastJoinFailure.unreachable ||
                      reason == CastJoinFailure.noAnswer
                  ? CastProblemKind.deviceUnreachable
                  : CastProblemKind.receiverRefused,
              detail: detail,
            ),
          );
        case CastJoined(:final session, :final launched):
          _log.info(
            _tag,
            '${launched ? 'Launched' : 'Joined'} the receiver on '
            '${device.name} in ${clock.elapsedMilliseconds} ms',
          );
          if (!local.isCompleted) local.complete(session.localAddress);
          _tv = session;
          _tvStates = session.states.listen(_onTv);
          _markedUsed = _devices.markUsed(device, DateTime.now()).then((r) {
            if (r.failureOrNull case final failure?) {
              _log.warning(_tag, 'Could not keep ${device.name}: $failure');
            }
          });
          joined.complete(session);
          _set(
            _state.copyWith(
              volume: session.state.volume,
              phase: _state.phase == CastPhase.connecting
                  ? (_cast == null ? CastPhase.idle : CastPhase.preparing)
                  : _state.phase,
            ),
          );
      }
    }());
  }

  /// The join failed: the cast waiting for it stops too. Try again joins
  /// again; Play here plays on the laptop.
  Future<void> _joinFailedWith(CastProblem problem) async {
    _joinFailed = true;
    final cast = _cast;
    if (cast != null) await _stopRelay(cast);
    _set(_state.copyWith(phase: CastPhase.failed, problem: problem));
  }

  /// The session is over: nothing is cast, the computer may sleep, and
  /// the screens play here again.
  Future<void> _forgetSession() async {
    await _tvStates?.cancel();
    _tvStates = null;
    _tv = null;
    _device = null;
    _known = null;
    _joined = null;
    _local = null;
    _joinFailed = false;
    _playback.castEnded();
    _publish(const VodTimeline());
    _set(const CastingState());
  }

  /// What the TV says: its link, its volume, and the media this cast
  /// loaded (older loads' news is ignored).
  void _onTv(CastSessionState tv) {
    if (tv.link == CastLink.ended) {
      unawaited(_tvEnded(tv.end, tv.otherApp));
      return;
    }
    _set(
      _state.copyWith(
        reconnecting: tv.link == CastLink.reconnecting,
        volume: tv.volume,
      ),
    );
    final cast = _cast;
    if (cast == null) return;
    if (tv.link == CastLink.connected && cast.loadPending) {
      cast.loadPending = false;
      unawaited(_reload(cast));
      return;
    }
    final media = tv.media;
    if (media == null || !_ours(cast, media)) return;
    cast.mediaSession ??= media.sessionId;
    switch (media.playerState) {
      case CastPlayerState.playing:
        _playing(cast, media);
      case CastPlayerState.paused:
        _clockFrom(cast, media, running: false);
        if (cast.played) unawaited(_save(cast));
        _set(_state.copyWith(paused: true, buffering: false));
      case CastPlayerState.buffering || CastPlayerState.loading:
        _clockFrom(cast, media, running: false);
        _set(_state.copyWith(buffering: true));
      case CastPlayerState.idle:
        switch (media.idleReason) {
          case CastIdleReason.finished:
            unawaited(_finished(cast, media));
          case CastIdleReason.cancelled:
            unawaited(_stoppedOnDevice(cast));
          case CastIdleReason.error:
            unawaited(_refused(cast));
          case CastIdleReason.interrupted || null:
            break;
        }
    }
  }

  /// The device ended the session itself.
  Future<void> _tvEnded(CastEnd? end, String? otherApp) async {
    final device = _device;
    if (device == null || end == CastEnd.stopped || end == CastEnd.left) {
      return;
    }
    _log.info(_tag, '${device.name} ended the cast: ${end?.name}');
    ++_session;
    final cast = _cast;
    _cast = null;
    if (cast != null) await _endCast(cast, save: true);
    await _forgetSession();
    _notice(
      CastSessionClosed(device.name, end ?? CastEnd.lost, otherApp: otherApp),
    );
  }

  // A play.

  Future<void> _play(
    Playable item, {
    Duration? from,
    PlaybackHandover? handover,
  }) async {
    final previous = _cast;
    final cast = _cast = _Cast(item, from: from);
    if (handover != null && handover.item == item) {
      if (handover.info case final info?) {
        cast.fromPlayer = streamFactsFromPlayer(
          info,
          tracks: handover.tracks,
          duration: handover.duration,
        );
      }
      if (handover.tracks case final tracks?) {
        cast.audioTrack = playerAudioIndex(tracks);
        // The TV carries on as the laptop showed it: with its subtitle's
        // language, or with none.
        final shown = tracks.subtitles
            .where((t) => t.id == tracks.subtitleId)
            .firstOrNull;
        cast.playerSubtitle = (on: shown != null, language: shown?.language);
      }
    } else if (previous != null &&
        previous.item == item &&
        previous.subtitleChosen) {
      // Tried again: the same file, the same choice.
      cast
        ..textTrack = previous.textTrack
        ..subtitleChosen = true;
    }
    if (previous != null) await _endCast(previous, save: true);
    if (!identical(cast, _cast)) return;
    if (_joinFailed && _device != null) {
      _joinFailed = false;
      _join(_device!, _session);
    }
    cast.anchor = from ?? Duration.zero;
    _publishTimeline(cast);
    _set(
      _state.copyWith(
        phase: _tv == null ? CastPhase.connecting : CastPhase.preparing,
        item: item,
        plan: null,
        problem: null,
        paused: false,
        buffering: false,
        subtitles: const [],
        subtitle: null,
      ),
    );
    _playback.castShows(item);
    await _prepare(cast);
  }

  Future<void> _prepare(_Cast cast) async {
    final generation = cast.generation;
    final resolved = await _items.resolve(cast.item);
    if (!_fresh(cast, generation)) return;
    final stream = resolved.valueOrNull;
    if (stream == null) {
      return await _fail(
        cast,
        CastProblem(
          CastProblemKind.stream,
          stream: PlaybackProblem(
            PlaybackProblemKind.unavailable,
            failure: resolved.failureOrNull,
          ),
        ),
      );
    }
    cast
      ..stream = stream
      ..metadata = _items.metadataFor(cast.item);
    cast.picture = _servePicture(cast);
    if (stream.upstream.file case final file?) {
      // Made beside everything else; the LOAD waits a moment for them.
      final set = cast.subtitleSet = _subtitles.prepare(
        file,
        beside: stream.stream.subtitleFiles,
      );
      cast.subtitlesSince = _clock.elapsed;
      unawaited(set.done.then((_) => _publishSubtitles(cast)));
    }
    final facts = await _factsFor(cast, generation);
    if (facts == null || !_fresh(cast, generation)) return;
    cast.facts = facts;
    await _planAndDeliver(cast, generation);
  }

  /// Decision 4: the laptop's player, what this run remembers, then
  /// ffprobe through the relay's proxy (its input closed once read).
  /// Null when the cast failed, or a newer attempt took over.
  Future<StreamFacts?> _factsFor(_Cast cast, int generation) async {
    final stream = cast.stream!;
    CastRelayInput? input;
    final StreamProbeResult result;
    try {
      result = await _lookup.factsFor(
        stream.key,
        fromPlayer: cast.fromPlayer,
        probeInput: () async {
          // A file on this computer: ffprobe reads it itself.
          if (stream.upstream.file case final file?) return file;
          await _room(stream);
          final opened = input = await _relay.openInput(stream.upstream);
          if (opened == null) throw StateError('the relay cannot run here');
          return opened.url;
        },
      );
    } finally {
      await input?.close();
    }
    if (!_fresh(cast, generation)) return null;
    switch (result) {
      case StreamProbed(:final facts):
        _log.info(_tag, 'Facts from the ${facts.origin.name}');
        return facts;
      case StreamProbeFailed(:final reason, :final detail):
        _log.warning(_tag, 'The probe failed: ${reason.name}');
        final refusal = input?.refusal;
        await _fail(cast, switch (reason) {
          _ when refusal != null => _relayProblem(refusal),
          StreamProbeFailure.noStreams => CastProblem(
            CastProblemKind.nothingToPlay,
            detail: detail,
          ),
          StreamProbeFailure.couldNotStart => CastProblem(
            CastProblemKind.relay,
            detail: detail,
          ),
          StreamProbeFailure.timedOut ||
          StreamProbeFailure.unreadable => CastProblem(
            CastProblemKind.stream,
            stream: PlaybackProblem(
              PlaybackProblemKind.network,
              detail: detail,
            ),
            detail: detail,
          ),
        });
        return null;
    }
  }

  Future<void> _planAndDeliver(_Cast cast, int generation) async {
    final encoders = await _encoders;
    await _profileReady;
    if (!_fresh(cast, generation)) return;
    switch (_planFor(cast, encoders)) {
      case CastNothingToPlay():
        return await _fail(
          cast,
          const CastProblem(CastProblemKind.nothingToPlay),
        );
      case CastPlanned(:final plan):
        if (plan.video is CastVideoTranscode && !encoders.canTranscode) {
          return await _fail(
            cast,
            const CastProblem(CastProblemKind.cantReencode),
          );
        }
        cast.plan = plan;
        _log.info(_tag, 'The plan: $plan');
        _set(_state.copyWith(plan: plan));
        await _deliver(cast, generation);
    }
  }

  CastPlanResult _planFor(_Cast cast, CastEncoders encoders) => planCast(
    CastPlanRequest(
      facts: cast.facts!,
      source: cast.stream!.info,
      device: _profile,
      settings: _settings(),
      audio: CastAudioChoice(track: cast.audioTrack, languages: _languages()),
      softwareEncoderOnly: encoders.softwareOnly,
    ),
  );

  CastDeviceProfile get _profile => switch (_known) {
    final known? => CastDeviceProfile.fromKnown(known),
    null => CastDeviceProfile(model: _device?.model),
  };

  /// The plan carried out: a direct LOAD of the provider's URL, or the
  /// relay, then its LOAD once its first segments are ready. Only while
  /// [generation] is the cast's newest attempt: a session started for an
  /// older one is stopped at once.
  Future<void> _deliver(_Cast cast, int generation) async {
    final plan = cast.plan!;
    final stream = cast.stream!;
    if (cast.relay != null) await _stopRelay(cast);
    if (!_fresh(cast, generation)) return;
    // A file on this computer the TV reads by itself: the file as it is,
    // or the MP4 made of it.
    final own = cast.onMp4
        ? cast.mp4Path
        : (plan.delivery.direct ? stream.upstream.file : null);
    if (own != null) return await _deliverFile(cast, generation, own);
    if (plan.delivery.direct) {
      final tv = await _joined;
      if (tv == null || !_fresh(cast, generation)) return;
      await _room(stream);
      // Built again: a redirect's token may have expired meanwhile.
      final fresh = await stream.upstream.resolve();
      if (!_fresh(cast, generation)) return;
      cast
        ..directOnTv = true
        // The TV's own time is the file's.
        ..starts = Duration.zero;
      _countCast(stream.info.sourceId);
      await _load(
        cast,
        tv,
        generation,
        url: fresh.valueOrNull?.url ?? stream.stream.url,
        contentType: plan.delivery.contentType,
        start: plan.live ? Duration.zero : cast.from ?? Duration.zero,
      );
      return;
    }
    final local = await _local?.future;
    if (local == null || !_fresh(cast, generation)) return;
    if (_beforeFirstRelay case final explain?) {
      _beforeFirstRelay = null;
      await explain();
      if (!_fresh(cast, generation)) return;
    }
    if (plan.video is CastVideoTranscode) {
      cast.encoder ??= (await _encoders).best;
    }
    // Where the stream will begin in the file, which the relay counts it
    // from (docs/04 "The TV's own bar").
    final begins = await _startOf(cast, cast.from ?? Duration.zero);
    if (!_fresh(cast, generation)) return;
    final started = await _relay.start(
      CastRelayRequest(
        plan: plan,
        facts: cast.facts!,
        source: stream.upstream,
        localAddress: local,
        encoder: plan.video is CastVideoTranscode ? cast.encoder : null,
        startAt: plan.live ? null : cast.from,
        timeline: plan.live ? null : _clockOf(cast, begins),
      ),
    );
    switch (started) {
      case CastRelayNotStarted(:final failure):
        if (_fresh(cast, generation)) await _relayFailed(cast, failure);
      case CastRelayStarted(:final session):
        if (!_fresh(cast, generation) || cast.relay != null) {
          await session.stop();
          return;
        }
        cast
          ..relay = session
          ..starts = plan.live ? Duration.zero : begins;
        cast.relayEvents = session.events.listen(
          (event) => _onRelay(cast, session, event),
        );
        _makeMp4(cast);
        // A failure comes as the session's CastRelayFailed too.
        final failure = await session.ready;
        if (failure != null || !_current(cast, session, generation)) return;
        final tv = await _joined;
        if (tv == null || !_current(cast, session, generation)) return;
        await _load(
          cast,
          tv,
          generation,
          url: session.url,
          contentType: session.contentType,
          start: cast.starts,
        );
    }
  }

  /// A file on this computer the TV plays as it is (docs/04 "Direct
  /// file"), or the MP4 made of one it can't: the relay's server gives it
  /// to the TV with Range, so the TV seeks in it by itself. No provider
  /// connection is asked for or counted.
  Future<void> _deliverFile(_Cast cast, int generation, String file) async {
    final plan = cast.plan!;
    final local = await _local?.future;
    if (local == null || !_fresh(cast, generation)) return;
    if (_beforeFirstRelay case final explain?) {
      _beforeFirstRelay = null;
      await explain();
      if (!_fresh(cast, generation)) return;
    }
    // Loaded again (the connection came back): the same URL still serves.
    final served =
        cast.served ?? await _relay.serveFile(file, localAddress: local);
    if (!_fresh(cast, generation)) {
      if (!identical(served, cast.served)) await served?.close();
      return;
    }
    if (served == null) {
      return await _fail(
        cast,
        const CastProblem(
          CastProblemKind.relay,
          detail: 'The file could not be served to the TV.',
        ),
      );
    }
    cast
      ..served = served
      // The TV's own time is the file's.
      ..starts = Duration.zero;
    final tv = await _joined;
    if (tv == null || !_fresh(cast, generation)) return;
    await _load(
      cast,
      tv,
      generation,
      url: served.url,
      contentType: plan.delivery.contentType,
      start: cast.from ?? Duration.zero,
    );
  }

  Future<void> _load(
    _Cast cast,
    CastReceiverSession tv,
    int generation, {
    required String url,
    required String contentType,
    Duration start = Duration.zero,
  }) async {
    final plan = cast.plan!;
    final metadata = await cast.metadata!;
    final picture = await cast.picture!.timeout(
      timings.picture,
      onTimeout: () => null,
    );
    if (!_fresh(cast, generation)) return;
    final tracks = await _textTracks(cast, tv, generation);
    if (!_fresh(cast, generation)) return;
    final shown = tracks.any((t) => t.id == cast.textTrack)
        ? cast.textTrack
        : null;
    final serial = ++cast.loads;
    cast
      ..loadedUrl = url
      ..mediaSession = null
      ..fetched = false
      ..tracksLoaded = tracks.length
      ..shownTrack = shown
      ..loadedAt = _clock.elapsed;
    cast.reachTimer?.cancel();
    final result = await tv.load(
      CastLoad(
        url: url,
        contentType: contentType,
        live: plan.live,
        title: metadata.title,
        subtitle: metadata.subtitle,
        imageUrl: picture?.url,
        start: start,
        duration: plan.live ? null : _length(cast),
        textTracks: tracks,
        activeTextTrack: shown,
      ),
    );
    if (!_fresh(cast, generation) || cast.loads != serial) return;
    switch (result) {
      case CastDone(:final media):
        if (media != null) cast.mediaSession = media.sessionId;
        if (!_tvReads(cast)) _watchReach(cast);
      case CastRefused(:final reason, :final detail):
        _log.info(_tag, 'The TV refused the LOAD: ${reason.name}');
        if (reason != CastRefusal.loadCancelled) {
          await _refused(cast, detail: detail);
        }
      case CastUnanswered():
        // Its status says how it went.
        _log.info(_tag, 'The TV did not answer the LOAD');
        if (!_tvReads(cast)) _watchReach(cast);
      case CastDisconnected():
        // Loaded again once the connection is back.
        cast.loadPending = true;
    }
  }

  /// The TV must ask the relay for the stream soon after the LOAD; if it
  /// never does, it can't reach this computer.
  void _watchReach(_Cast cast) {
    if (cast.fetched) return;
    final serial = cast.loads;
    cast.reachTimer = Timer(timings.reach, () {
      if (!identical(cast, _cast) || cast.fetched || cast.loads != serial) {
        return;
      }
      _log.warning(_tag, '$deviceName never fetched the stream');
      unawaited(
        _fail(
          cast,
          const CastProblem(CastProblemKind.computerUnreachable),
          stopMedia: true,
        ),
      );
    });
  }

  // A file's subtitles.

  /// The file's subtitles for a LOAD: each WebVTT file served by the
  /// relay, its cues at the file's own times, which are the TV's.
  /// What the first LOAD names decides which shows from the start.
  Future<List<CastTextTrack>> _textTracks(
    _Cast cast,
    CastReceiverSession tv,
    int generation,
  ) async {
    final set = cast.subtitleSet;
    final plan = cast.plan!;
    if (set == null || plan.live) return const [];
    final left =
        timings.subtitles -
        (_clock.elapsed - (cast.subtitlesSince ?? _clock.elapsed));
    if (left > Duration.zero) {
      await set.done.timeout(left, onTimeout: () {});
      if (!_fresh(cast, generation)) return const [];
    }
    await _closeTracks(cast);
    final subtitles = set.subtitles;
    if (subtitles.isEmpty || !_fresh(cast, generation)) return const [];
    // On the file's own clock, which is the TV's: a relayed stream is
    // counted from where it begins in the file (docs/04 "The TV's own
    // bar").
    final files = await set.files();
    final served = <CastServedFile>[];
    final tracks = <CastTextTrack>[];
    for (final (index, subtitle) in subtitles.indexed) {
      if (index >= files.length || !_fresh(cast, generation)) break;
      final file = await _relay.serveFile(
        files[index],
        localAddress: tv.localAddress,
      );
      if (file == null) continue;
      served.add(file);
      tracks.add(
        CastTextTrack(
          id: index + 1,
          url: file.url,
          language: switch (subtitle.language) {
            final language? => languageTag(language),
            null => null,
          },
          name: castSubtitleLabel(subtitle, index + 1),
        ),
      );
    }
    if (!_fresh(cast, generation)) {
      for (final file in served) {
        await file.close();
      }
      return const [];
    }
    cast.servedTracks = served;
    if (!cast.subtitleChosen && tracks.isNotEmpty) {
      cast
        ..subtitleChosen = true
        ..textTrack = _firstSubtitle(cast, subtitles);
    }
    // A choice the TV can't be given is none.
    if (!tracks.any((t) => t.id == cast.textTrack)) cast.textTrack = null;
    _set(_state.copyWith(subtitles: subtitles, subtitle: cast.textTrack));
    return tracks;
  }

  /// Which subtitle shows from the start. Handed over from the laptop's
  /// player: the one in the language it showed, or none if it showed
  /// none. Otherwise as the player starts a file: the first in the most
  /// wanted of Settings' "Preferred subtitles" that has one, else a
  /// subtitle file the user put beside the video, else none.
  int? _firstSubtitle(_Cast cast, List<CastSubtitle> subtitles) {
    int? first(bool Function(CastSubtitle subtitle) test) {
      final index = subtitles.indexWhere(test);
      return index < 0 ? null : index + 1;
    }

    if (cast.playerSubtitle case final shown?) {
      if (!shown.on) return null;
      final same = first(
        (s) => shown.language == null
            ? s.language == null
            : sameLanguage(s.language, shown.language),
      );
      if (same != null) return same;
    }
    for (final wanted in _subtitleLanguages()) {
      final preferred = first(
        (s) => !s.forced && sameLanguage(s.language, wanted),
      );
      if (preferred != null) return preferred;
    }
    return first((s) => s.beside && !s.forced);
  }

  /// The subtitles are all made: the view lists them. Those the TV
  /// wasn't given with its LOAD are handed over when one is chosen.
  void _publishSubtitles(_Cast cast) {
    final set = cast.subtitleSet;
    if (set == null || !identical(cast, _cast) || cast.failed) return;
    _set(_state.copyWith(subtitles: set.subtitles));
  }

  /// Tells the TV which subtitle to show, when it isn't the one chosen.
  /// A TV that isn't ready to be told is told again once it plays. One
  /// made after the TV loaded the file comes with a new LOAD of it.
  Future<void> _showChosenSubtitle(_Cast cast) async {
    final tv = _tv;
    final wanted = cast.textTrack;
    if (tv == null ||
        !identical(cast, _cast) ||
        !cast.played ||
        cast.loadedUrl == null ||
        cast.mediaSession == null ||
        wanted == cast.shownTrack) {
      return;
    }
    if (wanted != null && wanted > cast.tracksLoaded) {
      // What that LOAD names decides again whether it can show: this
      // can't go round twice.
      _log.info(_tag, 'Loading the file again for a subtitle made since');
      return await _loadAgainHere(cast);
    }
    final serial = cast.loads;
    final result = await tv.showTextTrack(wanted);
    // A LOAD made meanwhile carried the choice itself.
    if (!identical(cast, _cast) || cast.loads != serial) return;
    switch (result) {
      case CastDone():
        cast.shownTrack = wanted;
        // Chosen again meanwhile.
        if (cast.textTrack != wanted) await _showChosenSubtitle(cast);
      case CastRefused(reason: CastRefusal.noMedia || CastRefusal.invalidState):
      case CastUnanswered():
      case CastDisconnected():
        // Not now: the next time it plays.
        break;
      case CastRefused(:final reason):
        _log.warning(_tag, 'The TV refused the subtitle: ${reason.name}');
        if (cast.textTrack == wanted) {
          cast.textTrack = cast.shownTrack;
          _set(_state.copyWith(subtitle: cast.shownTrack));
          // The view goes back to what the TV shows: say why.
          _notice(CastSubtitleRefused(deviceName));
        }
    }
  }

  /// The file loaded again where it is.
  Future<void> _loadAgainHere(_Cast cast) async {
    final plan = cast.plan;
    if (plan == null) return;
    final position = _position(cast);
    cast
      ..from = position
      ..starts = position
      ..anchor = position
      ..running = false;
    _publishTimeline(cast);
    unawaited(_save(cast));
    _set(_state.copyWith(phase: CastPhase.preparing, buffering: false));
    if (plan.delivery.direct || cast.relay == null) {
      return await _deliver(cast, _restart(cast));
    }
    await _reload(cast);
  }

  Future<void> _closeTracks(_Cast cast) async {
    final served = cast.servedTracks;
    cast.servedTracks = const [];
    for (final file in served) {
      await file.close();
    }
  }

  // The MP4 made beside a relayed file (Phase 8 decision 12).

  /// The TV fetches what plays by itself and seeks in it: the provider's
  /// own stream, a file as it is, or the MP4 made of one.
  bool _tvReads(_Cast cast) =>
      cast.onMp4 || (cast.plan?.delivery.direct ?? false);

  /// Starts the MP4 of a file on this computer that is relayed with its
  /// picture copied: once per cast and plan.
  void _makeMp4(_Cast cast) {
    final file = cast.stream?.upstream.file;
    final plan = cast.plan;
    final facts = cast.facts;
    if (file == null ||
        plan == null ||
        facts == null ||
        cast.mp4 != null ||
        cast.mp4Refused ||
        plan.live ||
        plan.video is! CastVideoCopy ||
        plan.delivery != CastDelivery.relayContinuous) {
      return;
    }
    final copy = cast.mp4 = _mp4s.make(file, plan: plan, facts: facts);
    unawaited(
      copy.ready.then((path) {
        if (identical(cast.mp4, copy)) cast.mp4Path = path;
      }),
    );
  }

  /// The MP4 is whole and the file is being moved anyway: the relay
  /// stops, and the TV loads the MP4 at [at]. Its time is the file's own
  /// from then on, and it seeks by itself.
  Future<void> _moveToMp4(_Cast cast, Duration at) async {
    _log.info(_tag, 'The MP4 is ready: $deviceName reads it by itself now');
    final generation = _restart(cast);
    cast
      ..onMp4 = true
      ..from = at
      ..starts = Duration.zero;
    _set(_state.copyWith(phase: CastPhase.preparing, buffering: false));
    await _stopRelay(cast);
    if (!_fresh(cast, generation)) return;
    await _deliver(cast, generation);
  }

  /// The TV wouldn't play the MP4 made for it: the relay again, where it
  /// was, and no MP4 for this cast any more. Nothing is learned: the
  /// file itself was never offered to the TV.
  Future<void> _backToRelay(_Cast cast) async {
    _log.info(_tag, '$deviceName refused the MP4: the relay again');
    final at = cast.played ? _position(cast) : cast.from ?? Duration.zero;
    final generation = _restart(cast);
    cast
      ..mp4Refused = true
      ..from = at
      ..starts = at;
    _dropMp4(cast);
    _set(_state.copyWith(phase: CastPhase.preparing, buffering: false));
    // The MP4's URL goes with it.
    await _stopRelay(cast);
    if (!_fresh(cast, generation)) return;
    await _deliver(cast, generation);
  }

  /// Stops the MP4's making and deletes it. Not waited for: FFmpeg is
  /// killed, which nothing that follows needs to wait on.
  void _dropMp4(_Cast cast) {
    unawaited(cast.mp4?.delete());
    cast
      ..mp4 = null
      ..mp4Path = null
      ..onMp4 = false;
  }

  /// Where a relayed file's stream really begins when asked to start at
  /// [at]: the key frame before it when the picture is copied (docs/04).
  /// The relay counts the stream from there, so the TV's time is the
  /// file's. [at] itself for anything but a file on this computer.
  Future<Duration> _startOf(_Cast cast, Duration at) async {
    final file = cast.stream?.upstream.file;
    final plan = cast.plan;
    if (file == null || plan == null || plan.live || at <= Duration.zero) {
      return at;
    }
    try {
      return await _subtitles.startOf(
        file,
        at: at,
        copied: (
          video: plan.video is CastVideoCopy,
          audioTrack: switch (plan.audio) {
            CastAudioCopy(:final track) => track,
            _ => null,
          },
        ),
      );
    } on Object catch (error) {
      _log.info(_tag, 'Where the file starts is not known: $error');
      return at;
    }
  }

  /// The same stream loaded again: after the TV dropped a live one, or
  /// once the connection to it is back.
  Future<void> _reload(_Cast cast) async {
    final plan = cast.plan;
    if (plan != null &&
        !plan.live &&
        cast.relay != null &&
        cast.mp4Path != null) {
      // A file that is loaded again anyway takes its MP4 once it is made.
      return await _moveToMp4(cast, cast.from ?? Duration.zero);
    }
    final generation = _restart(cast);
    final tv = await _joined;
    if (plan == null || tv == null || !_fresh(cast, generation)) return;
    final session = cast.relay;
    if (plan.delivery.direct || session == null) {
      return await _deliver(cast, generation);
    }
    if (plan.delivery == CastDelivery.relayContinuous) {
      // A continuous stream that ended needs a new one (ADR-004), from
      // the place this one was asked for.
      final at = cast.from ?? Duration.zero;
      final begins = await _startOf(cast, at);
      if (!_current(cast, session, generation)) return;
      final failure = await session.renew(
        startAt: plan.live ? null : at,
        timeline: plan.live ? null : _clockOf(cast, begins),
      );
      if (failure != null || !_current(cast, session, generation)) return;
      if (!plan.live) cast.starts = begins;
    }
    await _load(
      cast,
      tv,
      generation,
      url: session.url,
      contentType: session.contentType,
      start: cast.starts,
    );
  }

  /// A new attempt at what [cast] plays (a re-LOAD, a new plan, a seek):
  /// what an older one was doing stops counting, and the TV's news of the
  /// media loaded before is stale.
  int _restart(_Cast cast) {
    cast
      ..loadedUrl = null
      ..mediaSession = null
      ..loadPending = false;
    cast.reachTimer?.cancel();
    return ++cast.generation;
  }

  bool _fresh(_Cast cast, int generation) =>
      identical(cast, _cast) && cast.generation == generation;

  // What the TV does.

  void _playing(_Cast cast, CastMediaStatus media) {
    // Playing proves it reached the stream.
    cast.fetched = true;
    cast.reachTimer?.cancel();
    _clockFrom(cast, media, running: true);
    _checkLength(cast, media);
    if (!cast.played) {
      cast.played = true;
      final loadedAt = cast.loadedAt;
      final after = loadedAt == null
          ? ''
          : ' ${(_clock.elapsed - loadedAt).inMilliseconds} ms after the LOAD';
      _log.info(_tag, 'Playing on $deviceName$after');
      if (cast.item case PlayableChannel(:final channel)) {
        unawaited(_history?.recordLive(channel));
      }
      if (!cast.item.live) _startTick(cast);
    }
    _set(
      _state.copyWith(
        phase: CastPhase.playing,
        paused: false,
        buffering: false,
        problem: null,
      ),
    );
    if (cast.shownTrack != cast.textTrack) {
      unawaited(_showChosenSubtitle(cast));
    }
  }

  /// The relay's live continuous stream ended: the TV plays out what it
  /// has and says IDLE/FINISHED (ADR-004), which loads it again. A TV
  /// that says nothing within [CastTimings.liveEnd] (the Bedroom TV stays
  /// BUFFERING) is taken as having said it.
  void _awaitLiveEnd(_Cast cast) {
    if (cast.plan?.live != true) return;
    final loads = cast.loads;
    cast.endTimer?.cancel();
    cast.endTimer = Timer(timings.liveEnd, () {
      if (!identical(cast, _cast) || cast.loads != loads) return;
      _log.info(
        _tag,
        '$deviceName said nothing of the stream ending: as if it had',
      );
      unawaited(_liveEnded(cast));
    });
  }

  /// A live stream ended on the TV: loaded again, a few times.
  Future<void> _liveEnded(_Cast cast) async {
    cast.endTimer?.cancel();
    if (!_recast(cast)) {
      return await _fail(
        cast,
        const CastProblem(
          CastProblemKind.relay,
          detail: 'The stream kept ending on the TV',
        ),
      );
    }
    _log.info(_tag, 'The live stream ended on the TV: loading it again');
    _set(_state.copyWith(buffering: true));
    return await _reload(cast);
  }

  /// IDLE/FINISHED: a live stream dropped (on a continuous stream that is
  /// how it ends, ADR-004) and is loaded again; a file cut short carries
  /// on where it was; a file at its end has been watched.
  Future<void> _finished(_Cast cast, CastMediaStatus media) async {
    final plan = cast.plan;
    if (plan == null) return;
    if (plan.live) return await _liveEnded(cast);
    final position = _fileTime(cast, media.position);
    final length = _length(cast);
    if (length != null && position + timings.earlyEnd < length) {
      if (!_recast(cast)) {
        return await _fail(
          cast,
          const CastProblem(
            CastProblemKind.relay,
            detail: 'The file kept ending early on the TV',
          ),
        );
      }
      _log.info(_tag, 'The file ended at $position of $length: carrying on');
      cast
        ..from = position
        ..starts = position
        ..anchor = position;
      if (plan.delivery.direct || cast.relay == null) {
        return await _deliver(cast, _restart(cast));
      }
      return await _reload(cast);
    }
    cast
      ..anchor = length ?? position
      ..running = false;
    _publishTimeline(cast);
    if (cast.item.vodRef case final ref?) {
      await _progress?.save(ref, position: cast.anchor, duration: length);
    }
    cast.played = false;
    await _endCast(cast, save: false);
    _set(
      _state.copyWith(
        phase: CastPhase.ended,
        paused: false,
        subtitles: const [],
        subtitle: null,
      ),
    );
  }

  /// IDLE/CANCELLED: the TV's remote, or another sender, stopped it.
  Future<void> _stoppedOnDevice(_Cast cast) async {
    _log.info(_tag, 'Stopped on $deviceName');
    await _endCast(cast, save: true);
    if (!identical(cast, _cast)) return;
    _cast = null;
    _playback.castShows(null);
    _set(
      _state.copyWith(
        phase: CastPhase.idle,
        item: null,
        plan: null,
        paused: false,
        buffering: false,
        subtitles: const [],
        subtitle: null,
      ),
    );
    _notice(CastStoppedOnDevice(deviceName));
  }

  /// The TV couldn't play what it was sent (a LOAD_FAILED, or IDLE/ERROR).
  /// Soon after the LOAD that teaches it a limit, and the plan changes
  /// (docs/04 "Learning"; a direct play goes through the relay). Later,
  /// a live stream that played is loaded again.
  Future<void> _refused(_Cast cast, {String? detail}) async {
    final plan = cast.plan;
    final loadedAt = cast.loadedAt;
    if (plan == null || loadedAt == null) return;
    // A LOAD_FAILED and the IDLE/ERROR after it are one refusal.
    if (cast.refusedLoad == cast.loads) return;
    cast.refusedLoad = cast.loads;
    if (cast.onMp4) return await _backToRelay(cast);
    final since = _clock.elapsed - loadedAt;
    final window = plan.delivery.direct
        ? timings.directWithin
        : timings.learnWithin;
    if (since <= window && cast.lessons < timings.lessons) {
      final lesson = learnFromRefusal(
        plan: plan,
        facts: cast.facts!,
        learned: _profile.learned,
        sourceId: cast.stream!.info.sourceId,
      );
      if (lesson != null) return await _learn(cast, lesson);
    }
    if (plan.live && cast.played && _recast(cast)) {
      _log.info(_tag, 'The TV stopped playing with an error: loading again');
      return await _reload(cast);
    }
    await _fail(
      cast,
      CastProblem(CastProblemKind.deviceCantPlay, detail: detail),
    );
  }

  Future<void> _learn(_Cast cast, CastLesson lesson) async {
    final device = _device;
    final before = cast.plan;
    if (device == null || before == null) return;
    cast.lessons++;
    _log.info(_tag, '${device.name} refused $before: ${lesson.kind.name}');
    _known =
        _known?.copyWith(learned: lesson.learned) ??
        KnownCastDevice(
          id: device.id,
          name: device.name,
          host: device.host,
          port: device.port,
          manual: device.manual,
          model: device.model,
          hevc: HevcSupport.auto,
          learned: lesson.learned,
        );
    await _markedUsed;
    final saved = await _devices.setLearned(device.id, lesson.learned);
    if (saved.failureOrNull case final failure?) {
      _log.warning(_tag, 'Could not keep what ${device.name} taught: $failure');
    }
    if (!identical(cast, _cast)) return;
    final encoders = await _encoders;
    final planned = _planFor(cast, encoders);
    if (planned is! CastPlanned || planned.plan == before) {
      return await _fail(
        cast,
        const CastProblem(CastProblemKind.deviceCantPlay),
      );
    }
    final after = planned.plan;
    if (after.video is CastVideoTranscode && !encoders.canTranscode) {
      return await _fail(cast, const CastProblem(CastProblemKind.cantReencode));
    }
    _notice(CastPlanChanged(device.name, before: before, after: after));
    await _replan(cast, after);
  }

  /// A new plan for what plays: the old relay session goes (its provider
  /// connection first), and the new plan is carried out.
  Future<void> _replan(_Cast cast, CastPlan plan) async {
    final generation = _restart(cast);
    // An MP4 made for the old plan isn't what the new one sends.
    _dropMp4(cast);
    await _stopRelay(cast);
    if (!_fresh(cast, generation)) return;
    _log.info(_tag, 'The new plan: $plan');
    cast.plan = plan;
    _set(
      _state.copyWith(plan: plan, phase: CastPhase.preparing, buffering: false),
    );
    await _deliver(cast, generation);
  }

  // What the relay does.

  void _onRelay(_Cast cast, CastRelaySession session, CastRelayEvent event) {
    if (!_current(cast, session)) return;
    switch (event) {
      case CastRelayFetched():
        cast.fetched = true;
        cast.reachTimer?.cancel();
      case CastRelayOpened(:final facts):
        unawaited(_opened(cast, facts));
      case CastRelayStreamsChanged():
        unawaited(_streamsChanged(cast));
      case CastRelayRestarted(:final count):
        _log.info(_tag, 'The relay started FFmpeg again ($count)');
      case CastRelayEnded(:final tvLeft):
        _log.info(
          _tag,
          tvLeft ? 'The TV left the stream' : 'The continuous stream ended',
        );
        if (!tvLeft) _awaitLiveEnd(cast);
      case CastRelayFailed(:final failure):
        unawaited(_relayFailed(cast, failure));
    }
  }

  /// FFmpeg says what it opened (decision 4): remembered for the next
  /// cast, and planned again if the plan was made from other facts.
  Future<void> _opened(_Cast cast, StreamFacts facts) async {
    final stream = cast.stream;
    final before = cast.facts;
    final plan = cast.plan;
    if (stream == null || before == null || plan == null) return;
    _lookup.remember(stream.key, facts);
    if (!_factsDiffer(before, facts)) return;
    _log.info(_tag, 'FFmpeg found other streams than the plan knew');
    cast.facts = facts;
    final planned = _planFor(cast, await _encoders);
    if (planned is! CastPlanned || _sameShape(planned.plan, plan)) return;
    if (!identical(cast, _cast)) return;
    await _replan(cast, planned.plan);
  }

  /// The channel changed codec (FFmpeg goes on copying the old one): its
  /// facts are read again and the plan made again, with a new LOAD.
  Future<void> _streamsChanged(_Cast cast) async {
    final stream = cast.stream;
    if (stream == null) return;
    _log.info(_tag, 'The stream changed: planning again');
    _lookup.forget(stream.key);
    if (!_recast(cast)) {
      return await _fail(
        cast,
        const CastProblem(
          CastProblemKind.relay,
          detail: 'The stream kept changing',
        ),
      );
    }
    final generation = _restart(cast);
    await _stopRelay(cast);
    cast.fromPlayer = null;
    _set(_state.copyWith(phase: CastPhase.preparing, buffering: false));
    final facts = await _factsFor(cast, generation);
    if (facts == null || !_fresh(cast, generation)) return;
    cast.facts = facts;
    await _planAndDeliver(cast, generation);
  }

  /// The relay's session failed: a re-encode tries the next encoder;
  /// anything else is the cast's failure, with the provider's answer in
  /// docs/03's words.
  Future<void> _relayFailed(_Cast cast, CastRelayFailure failure) async {
    if (failure.kind == CastRelayFailureKind.encoderFailed &&
        cast.plan?.video is CastVideoTranscode &&
        cast.encoderTries < timings.encoderTries) {
      cast.encoderTries++;
      final failed = cast.encoder;
      _log.warning(_tag, 'The re-encode failed with ${failed ?? 'nothing'}');
      final encoders = await (_encoders = _encoderDetection.detectAgain());
      final next = failed == null ? encoders.best : encoders.after(failed.kind);
      if (!identical(cast, _cast)) return;
      if (next != null) {
        _log.info(_tag, 'Re-encoding with $next instead');
        cast.encoder = next;
        final generation = _restart(cast);
        await _stopRelay(cast);
        if (_fresh(cast, generation)) await _deliver(cast, generation);
        return;
      }
    }
    await _fail(cast, _relayProblem(failure), stopMedia: true);
  }

  CastProblem _relayProblem(CastRelayFailure failure) {
    final detail = failure.detail;
    return switch (failure.kind) {
      CastRelayFailureKind.providerRefused => CastProblem(
        CastProblemKind.stream,
        stream: _classify(
          status: failure.status,
          body: failure.body,
          detail: detail,
        ),
        detail: detail,
      ),
      CastRelayFailureKind.providerUnreachable => CastProblem(
        CastProblemKind.stream,
        stream: PlaybackProblem(PlaybackProblemKind.network, detail: detail),
        detail: detail,
      ),
      CastRelayFailureKind.unresolved => CastProblem(
        CastProblemKind.stream,
        stream: PlaybackProblem(
          PlaybackProblemKind.unavailable,
          detail: detail,
        ),
        detail: detail,
      ),
      CastRelayFailureKind.connectionsInUse => CastProblem(
        CastProblemKind.stream,
        stream: PlaybackProblem(
          PlaybackProblemKind.connectionLimit,
          detail: detail,
        ),
        detail: detail,
      ),
      CastRelayFailureKind.encoderFailed => CastProblem(
        CastProblemKind.cantReencode,
        detail: detail,
      ),
      CastRelayFailureKind.ffmpegFailed ||
      CastRelayFailureKind.restartBudget ||
      CastRelayFailureKind.couldNotStart => CastProblem(
        CastProblemKind.relay,
        detail: detail,
      ),
    };
  }

  // The end of a play.

  /// The cast failed: its relay stops, a file's place is kept, and the
  /// view shows why (Try again, Play here, Details). [stopMedia]: the TV
  /// is still on it and is told to stop.
  Future<void> _fail(
    _Cast cast,
    CastProblem problem, {
    bool stopMedia = false,
  }) async {
    if (!identical(cast, _cast)) return;
    _log.warning(_tag, 'The cast failed: $problem');
    cast.failed = true;
    await _endCast(cast, save: true);
    if (!identical(cast, _cast)) return;
    if (stopMedia) await _tv?.stopMedia();
    _set(
      _state.copyWith(
        phase: CastPhase.failed,
        problem: problem,
        buffering: false,
        subtitles: const [],
        subtitle: null,
      ),
    );
  }

  /// Lets go of what [cast] holds: its relay session and provider
  /// connection, its picture, its subtitles, its timers. A file's place
  /// is saved first when [save].
  Future<void> _endCast(_Cast cast, {required bool save}) async {
    cast.tick?.cancel();
    cast.tick = null;
    if (save) await _save(cast);
    await _stopRelay(cast);
    // Not waited for: a subtitle still being read from a slow drive is
    // stopped, which the next play needn't wait on.
    unawaited(cast.subtitleSet?.delete());
    cast.subtitleSet = null;
    _dropMp4(cast);
    final picture = await cast.picture?.timeout(
      timings.picture,
      onTimeout: () => null,
    );
    await picture?.close();
    cast.picture = null;
  }

  Future<void> _stopRelay(_Cast cast) async {
    cast.reachTimer?.cancel();
    cast.endTimer?.cancel();
    final session = cast.relay;
    cast.relay = null;
    final events = cast.relayEvents;
    cast.relayEvents = null;
    if (cast.directOnTv) {
      cast.directOnTv = false;
      if (cast.stream case final stream?) _countCast(stream.info.sourceId);
    }
    await events?.cancel();
    await session?.stop();
    final served = cast.served;
    cast.served = null;
    await served?.close();
    await _closeTracks(cast);
  }

  /// One more automatic LOAD of [cast]; false once
  /// [CastTimings.recasts] were made within [CastTimings.recastWindow].
  bool _recast(_Cast cast) {
    final now = _clock.elapsed;
    cast.recasts.removeWhere((at) => now - at > timings.recastWindow);
    if (cast.recasts.length >= timings.recasts) return false;
    cast.recasts.add(now);
    return true;
  }

  // Connections (hard rule 7).

  /// Waits until the source has room for one more connection of the
  /// cast's (the laptop's player closing, Phase 8's downloads).
  Future<void> _room(CastItemStream stream) async {
    final room = await _playback.connections.room(
      stream.info.sourceId,
      limit: stream.stream.maxConnections,
      holder: StreamHolder.cast,
    );
    if (!room) {
      _log.info(_tag, 'The source has every connection in use; trying anyway');
    }
  }

  void _onRelayConnections(CastRelayConnections connections) {
    _relayOpen[connections.sourceId] = connections.open;
    _countCast(connections.sourceId);
  }

  /// The cast's connections at [sourceId]: the relay's proxy, and the TV
  /// reading the provider directly.
  void _countCast(String sourceId) {
    final direct =
        _cast?.directOnTv == true && _cast?.stream?.info.sourceId == sourceId;
    _playback.connections.set(
      sourceId,
      StreamHolder.cast,
      (_relayOpen[sourceId] ?? 0) + (direct ? 1 : 0),
    );
  }

  // A file's place.

  /// The TV's time plus where the relay started it, moved on by the
  /// clock while it plays (the TV reports on changes only).
  Duration _position(_Cast cast) {
    final at = cast.running
        ? cast.anchor + (_clock.elapsed - cast.anchorAt)
        : cast.anchor;
    final length = _length(cast);
    return length != null && at > length ? length : at;
  }

  void _clockFrom(_Cast cast, CastMediaStatus media, {required bool running}) {
    if (cast.item.live) return;
    cast
      ..anchor = _fileTime(cast, media.position)
      ..anchorAt = _clock.elapsed
      ..running = running;
    _publishTimeline(cast);
  }

  /// A relayed file's own clock for the relay (docs/04 "The TV's own
  /// bar"), from [begins]: its length only as the stream itself says it.
  /// A catalogue's runtime is rounded, or wrong, and a TV told a length
  /// shorter than the film's would stop at it.
  CastTimeline _clockOf(_Cast cast, Duration begins) =>
      CastTimeline(start: begins, length: cast.facts?.duration);

  /// The file's time for the TV's [tv]. A relayed stream is counted from
  /// where it begins in the file (docs/04 "The TV's own bar"), so the
  /// TV's time is the file's, never before that start: a TV says 0:00
  /// until its first picture, which must not be saved as where the film
  /// is. A TV that counts the stream from 0 anyway shows itself in its
  /// first report past a second, well before where the stream began; its
  /// time is then added to the start, for the rest of the cast.
  Duration _fileTime(_Cast cast, Duration tv) {
    final starts = cast.starts;
    if (!cast.clockChecked &&
        tv > const Duration(seconds: 1) &&
        starts >= const Duration(seconds: 10)) {
      cast.clockChecked = true;
      if (tv + const Duration(seconds: 5) < starts) {
        cast.countsFromZero = true;
        _log.warning(
          _tag,
          '$deviceName counts the stream from 0, not the film: its own '
          "bar and the subtitles' times are off",
        );
      }
    }
    if (cast.countsFromZero) return starts + tv;
    return tv < starts ? starts : tv;
  }

  /// What the TV says a file's length is while it plays, which its own
  /// bar shows (docs/04 "The TV's own bar"). The app's timeline doesn't
  /// use it; a length that isn't the file's is logged, once per LOAD, so
  /// that a TV showing the wrong one is in the diagnostics.
  void _checkLength(_Cast cast, CastMediaStatus media) {
    final length = _length(cast);
    final says = media.duration;
    if (cast.item.live || length == null || says == null) return;
    if (cast.lengthWrongAt == cast.loads) return;
    if ((says - length).abs() <= const Duration(seconds: 2)) return;
    cast.lengthWrongAt = cast.loads;
    _log.warning(
      _tag,
      '$deviceName says the file is ${says.inSeconds} s long, '
      'not ${length.inSeconds} s',
    );
  }

  Duration? _length(_Cast cast) =>
      cast.facts?.duration ??
      switch (cast.item) {
        PlayableMovie(:final movie) => movie.runtime,
        PlayableEpisode(:final episode) => episode.duration,
        PlayableLibraryItem(:final item) => item.duration,
        PlayableChannel() => null,
      };

  void _startTick(_Cast cast) {
    cast.tick?.cancel();
    var playedFor = Duration.zero;
    const every = Duration(seconds: 1);
    cast.tick = Timer.periodic(every, (_) {
      if (!identical(cast, _cast)) return;
      _publishTimeline(cast);
      if (!cast.running) return;
      playedFor += every;
      if (playedFor >= timings.saveEvery) {
        playedFor = Duration.zero;
        unawaited(_save(cast));
      }
    });
  }

  void _publishTimeline(_Cast cast) {
    if (cast.item.live) return;
    _publish(
      VodTimeline(
        position: _position(cast),
        duration: _length(cast),
        paused: _state.paused,
      ),
    );
  }

  void _publish(VodTimeline timeline) {
    if (timeline == _timeline) return;
    _timeline = timeline;
    if (!_timelines.isClosed) _timelines.add(timeline);
  }

  /// Saves where a file is on the TV, once it has played.
  Future<void> _save(_Cast cast) async {
    final ref = cast.item.vodRef;
    final progress = _progress;
    if (ref == null || progress == null || !cast.played) return;
    final saved = await progress.save(
      ref,
      position: _position(cast),
      duration: _length(cast),
    );
    if (saved.failureOrNull case final failure?) {
      _log.warning(_tag, 'Could not save where it was left: $failure');
    }
  }

  // The rest.

  /// The picture the TV shows while it loads: the app's cached copy,
  /// served by the relay on the TV's network.
  Future<CastServedFile?> _servePicture(_Cast cast) async {
    try {
      final url = (await cast.metadata!).imageUrl;
      if (url == null) return null;
      final path = await _pictures.fileFor(url);
      if (path == null) return null;
      final local = await _local?.future;
      if (local == null) return null;
      final served = await _relay.servePicture(path, localAddress: local);
      if (!identical(cast, _cast)) {
        await served?.close();
        return null;
      }
      return served;
    } on Object catch (error) {
      _log.info(_tag, 'No picture for the TV: $error');
      return null;
    }
  }

  /// [session] is [cast]'s relay session now, and [generation], when
  /// given, its newest attempt.
  bool _current(_Cast cast, CastRelaySession session, [int? generation]) =>
      identical(cast, _cast) &&
      identical(cast.relay, session) &&
      (generation == null || cast.generation == generation);

  /// [media] is the one [cast] loaded: its media session, else its URL.
  static bool _ours(_Cast cast, CastMediaStatus media) {
    if (cast.loadedUrl == null) return false;
    final id = cast.mediaSession;
    if (id != null) return media.sessionId == id;
    return media.contentId == cast.loadedUrl;
  }

  /// The picture's codec or height, or the sound's codecs, differ: what
  /// the plan rests on (fields FFmpeg doesn't report don't count).
  static bool _factsDiffer(StreamFacts before, StreamFacts after) {
    final a = before.video;
    final b = after.video;
    if ((a == null) != (b == null)) return true;
    if (a != null && b != null) {
      if (a.codec != null && b.codec != null && a.codec != b.codec) {
        return true;
      }
      if (a.height != null && b.height != null && a.height != b.height) {
        return true;
      }
    }
    final soundsBefore = [for (final s in before.audio) s.codec];
    final soundsAfter = [for (final s in after.audio) s.codec];
    if (soundsBefore.length != soundsAfter.length) return true;
    for (var i = 0; i < soundsBefore.length; i++) {
      final x = soundsBefore[i];
      final y = soundsAfter[i];
      if (x != null && y != null && x != y) return true;
    }
    return false;
  }

  /// Plans that do the same things (a bit rate apart).
  static bool _sameShape(CastPlan a, CastPlan b) =>
      a.delivery == b.delivery &&
      a.video.runtimeType == b.video.runtimeType &&
      a.audio == b.audio;

  void _notice(CastNotice notice) {
    if (!_notices.isClosed) _notices.add(notice);
  }

  void _set(CastingState next) {
    if (next == _state) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
    final awake =
        next.phase == CastPhase.preparing || next.phase == CastPhase.playing;
    if (awake == _awake) return;
    _awake = awake;
    if (awake) {
      unawaited(_sleep.hold('Casting to $deviceName'));
    } else {
      unawaited(_sleep.release());
    }
  }
}

/// One play on the TV, from its facts to its end.
final class _Cast {
  new(this.item, {this.from});

  final Playable item;

  /// Where a file starts: a resume, a seek, where it was cut short.
  Duration? from;

  /// The laptop's player's facts, when it handed this over.
  StreamFacts? fromPlayer;
  int? audioTrack;

  CastItemStream? stream;
  Future<CastMetadata>? metadata;
  Future<CastServedFile?>? picture;
  StreamFacts? facts;
  CastPlan? plan;
  CastEncoder? encoder;
  int encoderTries = 0;

  /// Bumped by every new attempt at it (a re-LOAD, a new plan, a seek):
  /// an older one's work stops counting.
  int generation = 0;

  CastRelaySession? relay;
  // Cancelled with its session, by the coordinator's _stopRelay.
  // ignore: cancel_subscriptions
  StreamSubscription<CastRelayEvent>? relayEvents;

  /// The TV reads the provider itself: one of the source's connections.
  bool directOnTv = false;

  /// A file on this computer the TV reads from the relay's server.
  CastServedFile? served;

  /// Its subtitles as WebVTT files, and since when they are being made.
  CastSubtitleSet? subtitleSet;
  Duration? subtitlesSince;

  /// The ones the last LOAD named, as the relay serves them, and how
  /// many they were.
  List<CastServedFile> servedTracks = const [];
  int tracksLoaded = 0;

  /// Which subtitle should show (from 1; null for none), whether that
  /// was decided yet, and which the TV was last told.
  int? textTrack;
  bool subtitleChosen = false;
  int? shownTrack;

  /// What the laptop's player showed when it handed this over.
  ({bool on, String? language})? playerSubtitle;

  /// The MP4 being made of a relayed file, its path once it is whole,
  /// whether the TV reads it now, and whether the TV refused it.
  CastMp4Copy? mp4;
  String? mp4Path;
  bool onMp4 = false;
  bool mp4Refused = false;

  /// LOADs made, the URL of the last, and its media session on the TV.
  int loads = 0;
  int? refusedLoad;
  String? loadedUrl;
  int? mediaSession;
  Duration? loadedAt;
  bool loadPending = false;
  bool fetched = false;
  Timer? reachTimer;

  /// Waits for the TV to say a live continuous stream ended.
  Timer? endTimer;

  bool played = false;
  bool failed = false;
  int lessons = 0;
  final recasts = <Duration>[];

  /// Where a relayed file's stream begins in the file: the relay counts
  /// it from there (docs/04 "The TV's own bar"), so the TV's time is the
  /// file's from that point on. Zero for anything the TV reads itself.
  Duration starts = Duration.zero;

  /// Whether the TV's time was checked against [starts], and found to
  /// count from 0 after all (`_fileTime`).
  bool clockChecked = false;
  bool countsFromZero = false;

  /// The LOAD whose length the TV said wrong (`_checkLength`).
  int? lengthWrongAt;

  /// Where the file was at [anchorAt] on the coordinator's clock, and
  /// whether it moves on from there.
  Duration anchor = Duration.zero;
  Duration anchorAt = Duration.zero;
  bool running = false;
  Timer? tick;
}
