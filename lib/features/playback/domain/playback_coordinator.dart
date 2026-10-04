import 'dart:async';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/domain/remote_playback.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

const _tag = 'playback';

/// Finds out why a stream failed to open: one small request after the
/// player let go of the connection, read the way the provider clients
/// read statuses (docs/03 "Error classes").
abstract interface class StreamProber {
  Future<PlaybackProblem> diagnose(
    String sourceId,
    ResolvedStream stream, {
    String? detail,
  });
}

/// docs/03's watchdog numbers.
final class WatchdogTimings {
  const new({
    this.backoff = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ],
    this.stall = const Duration(seconds: 8),
    this.buffering = const Duration(seconds: 15),
    this.connectionLimitAttempts = 3,
    this.fileOpen = const Duration(seconds: 30),
    this.earlyEnd = const Duration(seconds: 10),
  });

  /// One wait per automatic attempt; its length is the attempt count.
  final List<Duration> backoff;

  /// Playing, not buffering, and the position hasn't moved for this long.
  final Duration stall;

  /// Buffering for longer than this.
  final Duration buffering;

  /// A full account is retried less: the other device won't let go on its
  /// own, but a panel may still count the stream just closed.
  final int connectionLimitAttempts;

  /// The least a file gets for its first frame, whatever the preset: a
  /// resume on a panel that ignores Range reads its way to the position.
  final Duration fileOpen;

  /// A file that ends further than this before its length was cut short:
  /// it reconnects where it was, rather than counting as finished.
  final Duration earlyEnd;

  int get maxAttempts => backoff.length;
}

/// The single owner of what is playing (docs/03). It opens channels,
/// movies and episodes on the one [PlayerEngine], keeps a source's
/// connection limit (a one-connection panel gets the old stream closed
/// before the new one opens), records history, and watches the stream: an
/// open that never shows a picture, a stall, a drop or a failure is
/// retried with backoff, and what can't be retried becomes a
/// [PlaybackFailed] the UI explains.
///
/// A file (Phase 5 decision 1) also seeks and pauses, comes back where it
/// was after a drop, is never stalled while paused, ends in
/// [PlaybackEnded], and saves where it was left: every 10 s while it
/// plays, on pause, after a seek, on leaving and at the end.
///
/// While a cast session is on (Phase 7 decision 2), what the screens play
/// goes to the device instead ([castStarted]), the state says
/// [PlaybackCasting], and the laptop's player stays stopped.
final class PlaybackCoordinator {
  new({
    required this.engine,
    required this._resolver,
    required this._prober,
    required this._history,
    required this._channels,
    required this._log,
    this._progress,
    PlaybackSettings Function()? settings,
    SourceConnections? connections,
    this.timings = const WatchdogTimings(),
  }) : _settings = settings ?? (() => const PlaybackSettings()),
       connections = connections ?? SourceConnections() {
    _events = engine.events.listen(_onEvent);
  }

  /// How often a playing file's position is saved.
  static const saveEvery = Duration(seconds: 10);

  final PlayerEngine engine;
  final StreamResolver _resolver;
  final StreamProber _prober;
  final PlaybackHistory _history;
  final ChannelRepository _channels;
  final AppLog _log;

  /// Null: a file's position isn't saved (tests that only play live).
  final WatchProgress? _progress;
  final PlaybackSettings Function() _settings;
  final WatchdogTimings timings;

  /// Every holder's connections per source: the player's, a cast's, and
  /// Phase 8's downloads'.
  final SourceConnections connections;

  late final StreamSubscription<PlayerEvent> _events;
  final _states = StreamController<PlaybackState>.broadcast(sync: true);
  final _timelines = StreamController<VodTimeline>.broadcast(sync: true);
  PlaybackState _state = const PlaybackIdle();

  /// Bumped by every user action; async work from an older one is dropped.
  int _token = 0;

  /// The engine generation of the open this session is watching.
  int? _generation;
  int? _awaitingOpenFor;

  ResolvedStream? _stream;

  /// The source whose stream the engine holds open right now, as
  /// [connections] counts it.
  String? _openSourceId;
  String? get _openSource => _openSourceId;
  set _openSource(String? id) {
    final before = _openSourceId;
    _openSourceId = id;
    if (before != null && before != id) {
      connections.set(before, StreamHolder.player, 0);
    }
    if (id != null) connections.set(id, StreamHolder.player, 1);
  }

  /// The cast session plays what the screens play, while one is on.
  RemotePlayback? _remote;

  /// The stream's tracks, for a cast that takes it over.
  PlayerTracks? _tracks;
  ChannelItem? _previous;
  int _attempts = 0;
  bool _recorded = false;

  Timer? _openTimer;
  Timer? _backoffTimer;
  Timer? _tick;
  Duration _position = Duration.zero;
  Duration _lastTickPosition = Duration.zero;
  bool _buffering = false;
  int _stillTicks = 0;
  int _bufferingTicks = 0;

  // A file's session.
  Duration? _startedFrom;
  Duration? _openAt;
  Duration? _duration;
  Duration _buffered = Duration.zero;
  bool _paused = false;
  bool _started = false;
  int _playedSeconds = 0;
  Duration? _seekTarget;
  Timer? _seekSettle;
  VodTimeline _timeline = const VodTimeline();

  PlaybackState get state => _state;

  /// Every state, as it changes.
  Stream<PlaybackState> get states => _states.stream;

  /// What plays, or last played up to a failure or the end.
  Playable? get item => _state.item;

  /// The live channel playing; null for a movie or an episode.
  ChannelItem? get current => _state.channel;

  /// Where a movie or an episode is, as it changes.
  Stream<VodTimeline> get timelines => _timelines.stream;

  VodTimeline get timeline => _timeline;

  /// Where the file playing was asked to start ("Resumed from 24:10");
  /// null when it started from the beginning, or for live.
  Duration? get startedFrom => _startedFrom;

  /// The stream's address with its credentials masked, for the
  /// stream-info overlay.
  String? get redactedUrl => switch (_stream?.url) {
    final url? => redact(url),
    null => null,
  };

  /// The channel before this one, for Backspace.
  ChannelItem? get previous => _previous;

  /// A cast session is on: plays go to the device.
  bool get casting => _remote != null;

  /// The device a session is on with ("Living Room TV"); null when none.
  String? get castDeviceName => _remote?.deviceName;

  /// A cast session started (decision 2): what plays here moves to it.
  /// The laptop's stream is closed first (a one-connection source needs
  /// it for the cast), a file's place is saved, and what the player knew
  /// comes along. Null when nothing was playing.
  Future<PlaybackHandover?> castStarted(RemotePlayback remote) async {
    final item = this.item;
    final state = _state;
    final handover =
        item == null ||
            state is PlaybackIdle ||
            state is PlaybackEnded ||
            state is PlaybackCasting
        ? null
        : PlaybackHandover(
            item: item,
            position: item.live ? null : _position,
            info: state is PlaybackPlaying ? await _streamInfo() : null,
            tracks: state is PlaybackPlaying ? _tracks : null,
          );
    final leaving = _leaving();
    ++_token;
    _cancelTimers();
    _generation = null;
    _stream = null;
    _remote = remote;
    _startFile(null);
    _set(
      handover == null
          ? const PlaybackIdle()
          : PlaybackCasting(handover.item, deviceName: remote.deviceName),
    );
    _publish();
    await Future.wait([engine.stop(), if (leaving != null) _save(leaving)]);
    _openSource = null;
    return handover;
  }

  /// What the cast shows changed on its own (it ended, failed, or the
  /// TV's remote stopped it): the screens follow.
  void castShows(Playable? item) {
    final remote = _remote;
    if (remote == null) return;
    _set(
      item == null
          ? const PlaybackIdle()
          : PlaybackCasting(item, deviceName: remote.deviceName),
    );
  }

  /// The cast session ended: nothing plays here by itself (decision 2).
  void castEnded() {
    if (_remote == null) return;
    _remote = null;
    ++_token;
    // Said even when it was idle already: the screens show the session.
    _set(const PlaybackIdle());
  }

  Future<StreamInfo?> _streamInfo() async {
    try {
      return await engine.streamInfo();
    } on Object catch (error) {
      _log.info(_tag, 'No stream info for the cast: $error');
      return null;
    }
  }

  /// Plays [channel], replacing whatever plays now.
  Future<void> playLive(ChannelItem channel) async {
    final now = current;
    if (now != null && now.id != channel.id) _previous = now;
    await _play(PlayableChannel(channel), null);
  }

  /// Plays a movie or an episode from [from] (a resume), or from its
  /// start, replacing whatever plays now.
  ///
  /// [finishedLeaving]: the file playing now was watched to its credits
  /// (the next episode's card), so it is saved at its end, as watched,
  /// wherever the credits began.
  Future<void> playVod(
    Playable item, {
    Duration? from,
    bool finishedLeaving = false,
  }) async {
    assert(!item.live, 'playLive plays channels');
    await _play(
      item,
      from != null && from > Duration.zero ? from : null,
      finishedLeaving: finishedLeaving,
    );
  }

  Future<void> _play(
    Playable item,
    Duration? from, {
    bool finishedLeaving = false,
  }) async {
    if (_remote case final remote?) {
      ++_token;
      _set(PlaybackCasting(item, deviceName: remote.deviceName));
      await remote.play(item, from: from);
      return;
    }
    final leaving = _leaving();
    final token = ++_token;
    _attempts = 0;
    _recorded = false;
    _cancelTimers();
    _startFile(from);
    if (leaving != null) {
      unawaited(finishedLeaving ? _saveWatched(leaving) : _save(leaving));
    }
    _set(PlaybackOpening(item));
    _publish();
    await _open(item, token);
  }

  /// Tries again after a failure, from the first attempt; a file from
  /// where it was.
  Future<void> retry() async {
    if (_remote case final remote?) return await remote.retry();
    final item = this.item;
    if (item == null) return;
    final token = ++_token;
    _attempts = 0;
    _cancelTimers();
    if (!item.live) _openAt = _position;
    _set(PlaybackOpening(item));
    await _open(item, token);
  }

  /// Stops playback and lets go of the connection; a file's position is
  /// saved first. While casting nothing plays here, and the cast goes on:
  /// screens stop what they showed when they are left, and only Stop
  /// casting ends a cast.
  Future<void> stop() async {
    if (_remote != null) return;
    final leaving = _leaving();
    ++_token;
    _cancelTimers();
    _generation = null;
    _stream = null;
    _startFile(null);
    _set(const PlaybackIdle());
    _publish();
    await Future.wait([engine.stop(), if (leaving != null) _save(leaving)]);
    _openSource = null;
  }

  /// Moves the file playing to [position], within its length.
  Future<void> seek(Duration position) async {
    if (_remote case final remote?) return await remote.seek(position);
    final item = this.item;
    if (item == null || item.live || _state is! PlaybackPlaying) return;
    final length = _duration ?? _knownLength(item);
    var target = position < Duration.zero ? Duration.zero : position;
    if (length != null && target > length) target = length;
    _position = target;
    _lastTickPosition = target;
    _stillTicks = 0;
    // The player may still report where it was for a moment.
    _seekTarget = target;
    _seekSettle?.cancel();
    _seekSettle = Timer(const Duration(seconds: 2), () => _seekTarget = null);
    _publish();
    await engine.seek(target);
    if (_started) unawaited(_save((item.vodRef!, target, length)));
  }

  /// Pauses or resumes the file playing.
  Future<void> setPaused({required bool paused}) async {
    if (_remote case final remote?) {
      return await remote.setPaused(paused: paused);
    }
    final item = this.item;
    if (item == null || item.live || _state is! PlaybackPlaying) return;
    if (paused == _paused) return;
    await engine.setPaused(paused: paused);
  }

  /// The last channel before this one: this session's, or, on a fresh
  /// start, the history's.
  Future<ChannelItem?> lastChannel(String sourceId) async {
    final remembered = _previous;
    if (remembered != null && remembered.id != current?.id) return remembered;
    final recent = await _history.recentLive(sourceId, limit: 3);
    final keys = recent.valueOrNull ?? const <String>[];
    for (final key in keys) {
      if (key == current?.remoteKey) continue;
      final found = await _channels.byRemoteKey(sourceId, key);
      if (found.valueOrNull case final channel?) return channel;
    }
    return null;
  }

  Future<void> _open(Playable item, int token) async {
    final resolved = await switch (item) {
      PlayableChannel(:final channel) => _resolver.live(channel),
      PlayableMovie(:final movie) => _resolver.movie(movie),
      PlayableEpisode(:final episode) => _resolver.episode(episode),
      PlayableLibraryItem(:final item) => _resolver.libraryFile(item),
    };
    if (token != _token) return;
    final stream = resolved.valueOrNull;
    if (stream == null) {
      _set(
        PlaybackFailed(
          item,
          PlaybackProblem(
            item is PlayableLibraryItem
                ? PlaybackProblemKind.fileUnreadable
                : PlaybackProblemKind.unavailable,
            failure: resolved.failureOrNull,
          ),
        ),
      );
      return;
    }
    if (!stream.local) await _makeRoom(item, stream, token);
    if (token != _token) return;
    _stream = stream;
    // A file on this computer holds no connection (Phase 8 decision 8).
    _openSource = stream.local ? null : item.sourceId;
    _generation = null;
    _awaitingOpenFor = token;
    _position = _openAt ?? Duration.zero;
    _lastTickPosition = _position;
    _buffering = false;
    _paused = false;
    _stillTicks = 0;
    _bufferingTicks = 0;
    _seekTarget = null;
    await engine.open(
      _settings().request(stream, live: item.live, start: _openAt),
    );
    if (token != _token) return;
    _openTimer?.cancel();
    final preset = _settings().preset.openTimeout;
    _openTimer = Timer(
      item.live || preset > timings.fileOpen ? preset : timings.fileOpen,
      () {
        if (token != _token) return;
        _lost(
          item,
          token,
          const PlaybackProblem(
            PlaybackProblemKind.network,
            detail: 'No picture within the open timeout',
          ),
        );
      },
    );
  }

  /// The source's connection rules, before a provider's stream opens.
  Future<void> _makeRoom(
    Playable item,
    ResolvedStream stream,
    int token,
  ) async {
    // A one-connection source: the old stream has to be closed before the
    // panel lets a new one in (docs/03). Others just replace it.
    if (_openSource == item.sourceId && stream.maxConnections <= 1) {
      final watch = Stopwatch()..start();
      await engine.stop();
      _openSource = null;
      _log.debug(
        _tag,
        'Closed the old stream in ${watch.elapsedMilliseconds} ms',
      );
      if (token != _token) return;
    }
    // Another holder's stream on the source (a cast just ended, Phase 8's
    // downloads): the panel lets this one in only once that one closes.
    // After the wait it opens anyway; a refusal is the watchdog's.
    final room = await connections.room(
      item.sourceId,
      limit: stream.maxConnections,
      holder: StreamHolder.player,
    );
    if (!room) {
      _log.info(_tag, 'Opening while the source has every connection in use');
    }
  }

  void _onEvent(PlayerEvent event) {
    final item = this.item;
    final token = _token;
    switch (event) {
      case PlayerOpening(:final generation):
        if (_awaitingOpenFor == token) {
          _generation = generation;
          _awaitingOpenFor = null;
          _tracks = null;
        }
      case PlayerFirstFrame(:final generation):
        if (generation != _generation || item == null) return;
        _openTimer?.cancel();
        _attempts = 0;
        _started = true;
        _set(PlaybackPlaying(item));
        _startTick(item, token);
        if (item case PlayableChannel(:final channel) when !_recorded) {
          _recorded = true;
          unawaited(_history.recordLive(channel));
        }
      case PlayerProgress(:final position, :final buffered):
        if (_seekTarget case final target?) {
          // A report from before the seek landed.
          if ((position - target).abs() > const Duration(seconds: 3)) return;
          _seekTarget = null;
        }
        _position = position;
        _buffered = buffered;
        if (item != null && !item.live) _publish();
      case PlayerDuration(:final duration):
        if (_generation == null || item == null || item.live) return;
        _duration = duration;
        _publish();
      case PlayerPaused(:final paused):
        if (_generation == null || item == null || item.live) return;
        if (paused == _paused) return;
        _paused = paused;
        _stillTicks = 0;
        _lastTickPosition = _position;
        _publish();
        if (paused) {
          if (_leaving() case final leaving?) unawaited(_save(leaving));
        }
      case PlayerBuffering(:final buffering):
        if (_generation == null || item == null) return;
        _buffering = buffering;
        if (!buffering) _bufferingTicks = 0;
        if (_state is PlaybackPlaying) {
          _set(PlaybackPlaying(item, buffering: buffering));
        }
      case PlayerEnded():
        if (_generation == null || item == null) return;
        if (_state is! PlaybackPlaying) return;
        if (item.live) {
          _lost(
            item,
            token,
            const PlaybackProblem(
              PlaybackProblemKind.network,
              detail: 'The live stream ended',
            ),
          );
        } else {
          _fileEnded(item, token);
        }
      case PlayerFailed(:final message):
        if (_generation == null || item == null) return;
        if (_state is! PlaybackOpening &&
            _state is! PlaybackReconnecting &&
            _state is! PlaybackPlaying) {
          return;
        }
        unawaited(_diagnose(item, token, message));
      case PlayerTracks():
        if (_generation != null) _tracks = event;
      case PlayerVideoChanged():
        break;
    }
  }

  /// The end of a file: finished, unless it came well before the file's
  /// length, which is a drop to come back from.
  void _fileEnded(Playable item, int token) {
    final length = _duration;
    // A file on this computer can't drop: what ends, ends.
    final local = _stream?.local ?? false;
    if (!local && length != null && _position + timings.earlyEnd < length) {
      _lost(
        item,
        token,
        PlaybackProblem(
          PlaybackProblemKind.network,
          detail: 'The file ended at $_position of $length',
        ),
      );
      return;
    }
    _cancelTimers();
    _generation = null;
    final end = length ?? _position;
    _position = end;
    _publish();
    unawaited(_save((item.vodRef!, end, length ?? _knownLength(item))));
    _set(PlaybackEnded(item));
    _openSource = null;
    unawaited(engine.stop());
  }

  Future<void> _diagnose(Playable item, int token, String detail) async {
    _cancelTimers();
    _generation = null;
    final stream = _stream;
    final problem = stream == null || stream.local
        ? PlaybackProblem(PlaybackProblemKind.network, detail: detail)
        : await _prober.diagnose(item.sourceId, stream, detail: detail);
    if (token != _token) return;
    _lost(item, token, problem);
  }

  /// Once a second while playing: the position has to move unless the
  /// player is buffering or paused, and buffering may not last forever. A
  /// file's position is saved every [saveEvery] it plays.
  void _startTick(Playable item, int token) {
    _tick?.cancel();
    _lastTickPosition = _position;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (token != _token) return;
      if (_paused) {
        _stillTicks = 0;
        _bufferingTicks = 0;
        _lastTickPosition = _position;
        return;
      }
      if (!item.live && ++_playedSeconds >= saveEvery.inSeconds) {
        _playedSeconds = 0;
        if (_leaving() case final leaving?) unawaited(_save(leaving));
      }
      if (_buffering) {
        _bufferingTicks++;
        _stillTicks = 0;
        if (_bufferingTicks >= timings.buffering.inSeconds) {
          _lost(
            item,
            token,
            const PlaybackProblem(
              PlaybackProblemKind.network,
              detail: 'Buffering for too long',
            ),
          );
        }
        return;
      }
      if (_position == _lastTickPosition) {
        _stillTicks++;
        if (_stillTicks >= timings.stall.inSeconds) {
          _lost(
            item,
            token,
            const PlaybackProblem(
              PlaybackProblemKind.network,
              detail: 'The stream stalled',
            ),
          );
        }
      } else {
        _stillTicks = 0;
        _lastTickPosition = _position;
      }
    });
  }

  void _lost(Playable item, int token, PlaybackProblem lost) {
    if (token != _token) return;
    // docs/09: no reconnects for a file on this computer; it is missing
    // or damaged.
    final problem = _stream?.local ?? false
        ? PlaybackProblem(
            PlaybackProblemKind.fileUnreadable,
            detail: lost.detail,
            failure: lost.failure,
          )
        : lost;
    _cancelTimers();
    _generation = null;
    // A file comes back where it was, with a URL built again.
    if (!item.live) _openAt = _position;
    final limit = problem.kind == PlaybackProblemKind.connectionLimit
        ? timings.connectionLimitAttempts
        : timings.maxAttempts;
    if (!problem.retryable || _attempts >= limit) {
      _log.warning(_tag, 'Playback failed: $problem after $_attempts tries');
      if (_leaving() case final leaving?) unawaited(_save(leaving));
      _set(PlaybackFailed(item, problem, attempts: _attempts));
      _openSource = null;
      unawaited(engine.stop());
      return;
    }
    _attempts++;
    _log.info(_tag, 'Reconnecting (attempt $_attempts of $limit): $problem');
    _set(
      PlaybackReconnecting(
        item,
        attempt: _attempts,
        maxAttempts: limit,
        problem: problem,
      ),
    );
    _backoffTimer = Timer(timings.backoff[_attempts - 1], () async {
      if (token != _token) return;
      // The dead stream's connection goes first, whatever the limit.
      await engine.stop();
      _openSource = null;
      if (token != _token) return;
      await _open(item, token);
    });
  }

  /// A new file session (or none), starting at [from].
  void _startFile(Duration? from) {
    _startedFrom = from;
    _openAt = from;
    _duration = null;
    _buffered = Duration.zero;
    _paused = false;
    _started = false;
    _playedSeconds = 0;
    _seekTarget = null;
    _position = from ?? Duration.zero;
  }

  /// What to save for the file playing, once it has shown a picture.
  (VodRef, Duration, Duration?)? _leaving() {
    final item = this.item;
    if (item == null || item.live || !_started) return null;
    if (_state is PlaybackEnded) return null;
    return (item.vodRef!, _position, _duration ?? _knownLength(item));
  }

  Future<void> _save((VodRef, Duration, Duration?) at) async {
    final (ref, position, duration) = at;
    final saved = await _progress?.save(
      ref,
      position: position,
      duration: duration,
    );
    if (saved?.failureOrNull case final failure?) {
      _log.warning(_tag, 'Could not save where it was left: $failure');
    }
  }

  /// [at]'s file saved as watched: at its end when its length is known.
  Future<void> _saveWatched((VodRef, Duration, Duration?) at) async {
    final (ref, _, duration) = at;
    if (duration != null && duration > Duration.zero) {
      await _save((ref, duration, duration));
      return;
    }
    final saved = await _progress?.setWatched(ref, watched: true);
    if (saved?.failureOrNull case final failure?) {
      _log.warning(_tag, 'Could not save it as watched: $failure');
    }
  }

  /// The provider's length, for when the player doesn't know one.
  static Duration? _knownLength(Playable item) => switch (item) {
    PlayableMovie(:final movie) => movie.runtime,
    PlayableEpisode(:final episode) => episode.duration,
    PlayableLibraryItem(:final item) => item.duration,
    PlayableChannel() => null,
  };

  void _publish() {
    final item = this.item;
    final next = VodTimeline(
      position: _position,
      duration: _duration ?? (item == null ? null : _knownLength(item)),
      buffered: _buffered,
      paused: _paused,
    );
    if (next == _timeline) return;
    _timeline = next;
    if (!_timelines.isClosed) _timelines.add(next);
  }

  void _cancelTimers() {
    _openTimer?.cancel();
    _backoffTimer?.cancel();
    _tick?.cancel();
    _seekSettle?.cancel();
    _openTimer = null;
    _backoffTimer = null;
    _tick = null;
    _seekSettle = null;
  }

  void _set(PlaybackState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> dispose() async {
    ++_token;
    _cancelTimers();
    await _events.cancel();
    await _states.close();
    await _timelines.close();
  }
}
