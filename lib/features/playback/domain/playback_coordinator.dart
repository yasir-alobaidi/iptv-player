import 'dart:async';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

const _tag = 'playback';

/// Finds out why a stream failed to open: one small request after the
/// player let go of the connection, read the way the provider clients
/// read statuses (docs/03 "Error classes").
abstract interface class StreamProber {
  Future<PlaybackProblem> diagnose(
    ChannelItem channel,
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

  int get maxAttempts => backoff.length;
}

/// The single owner of what is playing (docs/03). It opens channels on the
/// one [PlayerEngine], keeps a source's connection limit (a one-connection
/// panel gets the old stream closed before the new one opens), records
/// history, and watches the stream: an open that never shows a picture, a
/// stall, a drop or a failure is retried with backoff, and what can't be
/// retried becomes a [PlaybackFailed] the UI explains.
final class PlaybackCoordinator {
  new({
    required this.engine,
    required this._resolver,
    required this._prober,
    required this._history,
    required this._channels,
    required this._log,
    PlaybackSettings Function()? settings,
    this.timings = const WatchdogTimings(),
  }) : _settings = settings ?? (() => const PlaybackSettings()) {
    _events = engine.events.listen(_onEvent);
  }

  final PlayerEngine engine;
  final StreamResolver _resolver;
  final StreamProber _prober;
  final PlaybackHistory _history;
  final ChannelRepository _channels;
  final AppLog _log;
  final PlaybackSettings Function() _settings;
  final WatchdogTimings timings;

  late final StreamSubscription<PlayerEvent> _events;
  final _states = StreamController<PlaybackState>.broadcast(sync: true);
  PlaybackState _state = const PlaybackIdle();

  /// Bumped by every user action; async work from an older one is dropped.
  int _token = 0;

  /// The engine generation of the open this session is watching.
  int? _generation;
  int? _awaitingOpenFor;

  ResolvedStream? _stream;

  /// The source whose stream the engine holds open right now.
  String? _openSource;
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

  PlaybackState get state => _state;

  /// Every state, as it changes.
  Stream<PlaybackState> get states => _states.stream;

  ChannelItem? get current => _state.channel;

  /// The stream's address with its credentials masked, for the
  /// stream-info overlay.
  String? get redactedUrl => switch (_stream?.url) {
    final url? => redact(url),
    null => null,
  };

  /// The channel before this one, for Backspace.
  ChannelItem? get previous => _previous;

  /// Plays [channel], replacing whatever plays now.
  Future<void> playLive(ChannelItem channel) async {
    final now = current;
    if (now != null && now.id != channel.id) _previous = now;
    final token = ++_token;
    _attempts = 0;
    _recorded = false;
    _cancelTimers();
    _set(PlaybackOpening(channel));
    await _open(channel, token);
  }

  /// Tries again after a failure, from the first attempt.
  Future<void> retry() async {
    final channel = current;
    if (channel == null) return;
    final token = ++_token;
    _attempts = 0;
    _cancelTimers();
    _set(PlaybackOpening(channel));
    await _open(channel, token);
  }

  /// Stops playback and lets go of the connection.
  Future<void> stop() async {
    ++_token;
    _cancelTimers();
    _generation = null;
    _stream = null;
    _set(const PlaybackIdle());
    await engine.stop();
    _openSource = null;
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

  Future<void> _open(ChannelItem channel, int token) async {
    final resolved = await _resolver.live(channel);
    if (token != _token) return;
    final stream = resolved.valueOrNull;
    if (stream == null) {
      _set(
        PlaybackFailed(
          channel,
          PlaybackProblem(
            PlaybackProblemKind.unavailable,
            failure: resolved.failureOrNull,
          ),
        ),
      );
      return;
    }
    // A one-connection source: the old stream has to be closed before the
    // panel lets a new one in (docs/03). Others just replace it.
    if (_openSource == channel.sourceId && stream.maxConnections <= 1) {
      final watch = Stopwatch()..start();
      await engine.stop();
      _openSource = null;
      _log.debug(
        _tag,
        'Closed the old stream in ${watch.elapsedMilliseconds} ms',
      );
      if (token != _token) return;
    }
    _stream = stream;
    _openSource = channel.sourceId;
    _generation = null;
    _awaitingOpenFor = token;
    _position = Duration.zero;
    _lastTickPosition = Duration.zero;
    _buffering = false;
    _stillTicks = 0;
    _bufferingTicks = 0;
    await engine.open(_settings().request(stream));
    if (token != _token) return;
    _openTimer?.cancel();
    _openTimer = Timer(_settings().preset.openTimeout, () {
      if (token != _token) return;
      _lost(
        channel,
        token,
        const PlaybackProblem(
          PlaybackProblemKind.network,
          detail: 'No picture within the open timeout',
        ),
      );
    });
  }

  void _onEvent(PlayerEvent event) {
    final channel = current;
    final token = _token;
    switch (event) {
      case PlayerOpening(:final generation):
        if (_awaitingOpenFor == token) {
          _generation = generation;
          _awaitingOpenFor = null;
        }
      case PlayerFirstFrame(:final generation):
        if (generation != _generation || channel == null) return;
        _openTimer?.cancel();
        _attempts = 0;
        _set(PlaybackPlaying(channel));
        _startTick(channel, token);
        if (!_recorded) {
          _recorded = true;
          unawaited(_history.recordLive(channel));
        }
      case PlayerProgress(:final position):
        _position = position;
      case PlayerBuffering(:final buffering):
        if (_generation == null || channel == null) return;
        _buffering = buffering;
        if (!buffering) _bufferingTicks = 0;
        if (_state is PlaybackPlaying) {
          _set(PlaybackPlaying(channel, buffering: buffering));
        }
      case PlayerEnded():
        if (_generation == null || channel == null) return;
        if (_state is! PlaybackPlaying) return;
        _lost(
          channel,
          token,
          const PlaybackProblem(
            PlaybackProblemKind.network,
            detail: 'The live stream ended',
          ),
        );
      case PlayerFailed(:final message):
        if (_generation == null || channel == null) return;
        if (_state is! PlaybackOpening &&
            _state is! PlaybackReconnecting &&
            _state is! PlaybackPlaying) {
          return;
        }
        unawaited(_diagnose(channel, token, message));
      case PlayerVideoChanged() || PlayerTracks():
        break;
    }
  }

  Future<void> _diagnose(ChannelItem channel, int token, String detail) async {
    _cancelTimers();
    _generation = null;
    final stream = _stream;
    final problem = stream == null
        ? PlaybackProblem(PlaybackProblemKind.network, detail: detail)
        : await _prober.diagnose(channel, stream, detail: detail);
    if (token != _token) return;
    _lost(channel, token, problem);
  }

  /// Once a second while playing: the position has to move unless the
  /// player is buffering, and buffering may not last forever.
  void _startTick(ChannelItem channel, int token) {
    _tick?.cancel();
    _lastTickPosition = _position;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (token != _token) return;
      if (_buffering) {
        _bufferingTicks++;
        _stillTicks = 0;
        if (_bufferingTicks >= timings.buffering.inSeconds) {
          _lost(
            channel,
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
            channel,
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

  void _lost(ChannelItem channel, int token, PlaybackProblem problem) {
    if (token != _token) return;
    _cancelTimers();
    _generation = null;
    final limit = problem.kind == PlaybackProblemKind.connectionLimit
        ? timings.connectionLimitAttempts
        : timings.maxAttempts;
    if (!problem.retryable || _attempts >= limit) {
      _log.warning(_tag, 'Playback failed: $problem after $_attempts tries');
      _set(PlaybackFailed(channel, problem, attempts: _attempts));
      _openSource = null;
      unawaited(engine.stop());
      return;
    }
    _attempts++;
    _log.info(_tag, 'Reconnecting (attempt $_attempts of $limit): $problem');
    _set(
      PlaybackReconnecting(
        channel,
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
      await _open(channel, token);
    });
  }

  void _cancelTimers() {
    _openTimer?.cancel();
    _backoffTimer?.cancel();
    _tick?.cancel();
    _openTimer = null;
    _backoffTimer = null;
    _tick = null;
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
  }
}
