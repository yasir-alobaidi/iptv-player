import 'dart:async';
import 'dart:math';

import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/cast/cast_channel.dart';
import 'package:iptv_player/data/cast/cast_namespaces.dart';
import 'package:iptv_player/data/cast/cast_status_json.dart';
import 'package:iptv_player/data/cast/cast_transport.dart';

/// The timings a Cast connection runs on; tests shorten them.
final class CastTimings {
  const new({
    this.connect = const Duration(seconds: 5),
    this.answer = const Duration(seconds: 5),
    this.launch = const Duration(seconds: 30),
    this.command = const Duration(seconds: 10),
    this.heartbeat = const Duration(seconds: 5),
    this.missedPings = 3,
    this.reconnectFor = const Duration(seconds: 30),
    this.firstRetry = const Duration(milliseconds: 500),
    this.longestRetry = const Duration(seconds: 5),
  });

  /// For the TLS connection to open.
  final Duration connect;

  /// For a status the device should send at once.
  final Duration answer;

  /// For the receiver to start (3–6 s on Living Room TV, ADR-004).
  final Duration launch;

  /// For LOAD and the media commands to be answered.
  final Duration command;

  /// A PING this often; [missedPings] intervals with nothing heard lose
  /// the connection (docs/04).
  final Duration heartbeat;
  final int missedPings;

  /// How long a broken connection is retried before the session ends.
  final Duration reconnectFor;

  /// The wait before the first retry; doubled each time up to
  /// [longestRetry].
  final Duration firstRetry;
  final Duration longestRetry;
}

/// Opens a [CastChannel] to [address]: the channel, or null and why not.
Future<(CastChannel?, String?)> openCastChannel(
  CastAddress address, {
  CastConnect connect = connectCastSocket,
  CastTimings timings = const CastTimings(),
  AppLog? log,
}) async {
  try {
    final transport = await connect(
      address.host,
      address.port,
      timings.connect,
    );
    return (
      CastChannel(
        transport,
        log: log,
        heartbeat: timings.heartbeat,
        missedPings: timings.missedPings,
      ),
      null,
    );
  } on Object catch (error) {
    return (null, '$error');
  }
}

/// [CastReceivers] on our own Cast v2 client (docs/04, ADR-004).
final class CastV2Receivers implements CastReceivers {
  new({
    this.log,
    this.connect = connectCastSocket,
    this.timings = const CastTimings(),
    this.appId = defaultMediaReceiverAppId,
  });

  final AppLog? log;
  final CastConnect connect;
  final CastTimings timings;
  final String appId;

  static const _tag = 'cast.session';

  @override
  Future<CastJoinResult> join(
    CastAddress address, {
    void Function(String localAddress)? onConnected,
  }) async {
    final clock = Stopwatch()..start();
    final (channel, error) = await openCastChannel(
      address,
      connect: connect,
      timings: timings,
      log: log,
    );
    if (channel == null) {
      log?.info(_tag, 'no connection to $address: $error');
      return CastJoinFailed(CastJoinFailure.unreachable, error);
    }
    onConnected?.call(channel.localAddress);
    final receiver = ReceiverChannel(channel);
    final status = await receiver.status(timeout: timings.answer);
    if (status == null) {
      await channel.close();
      log?.info(_tag, '$address connected but did not answer');
      return const CastJoinFailed(CastJoinFailure.noAnswer);
    }
    var app = status.app(appId);
    final launched = app == null;
    if (app == null) {
      final (started, failure) = await _launch(channel, receiver);
      if (started == null) {
        await channel.close();
        log?.info(_tag, 'the receiver did not start on $address: $failure');
        return failure!;
      }
      app = started;
    }
    log?.info(
      _tag,
      '${launched ? 'launched' : 'joined the running'} receiver on $address '
      'after ${clock.elapsedMilliseconds} ms',
    );
    final session = _CastV2Session(this, address, channel, app, status.volume);
    await session.refreshMedia();
    return CastJoined(session, launched: launched);
  }

  /// LAUNCH, then the app as the device lists it. The answer usually
  /// lists it; if it doesn't yet, the status is asked again until
  /// [CastTimings.launch] runs out.
  Future<(CastRunningApp?, CastJoinFailed?)> _launch(
    CastChannel channel,
    ReceiverChannel receiver,
  ) async {
    var expired = false;
    final deadline = Timer(timings.launch, () => expired = true);
    try {
      final reply = await receiver.launch(appId, timeout: timings.launch);
      if (reply == null) {
        return channel.isOpen
            ? (null, const CastJoinFailed(CastJoinFailure.launchTimedOut))
            : (
                null,
                const CastJoinFailed(
                  CastJoinFailure.unreachable,
                  'the connection broke during LAUNCH',
                ),
              );
      }
      if (reply.type == 'LAUNCH_ERROR') {
        return (
          null,
          CastJoinFailed(
            CastJoinFailure.launchRefused,
            'LAUNCH_ERROR ${reply.payload['reason'] ?? ''}'.trim(),
          ),
        );
      }
      var app = CastReceiverStatus.tryRead(reply.payload)?.app(appId);
      while (app == null && !expired && channel.isOpen) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        app = (await receiver.status(timeout: timings.answer))?.app(appId);
      }
      if (app != null) return (app, null);
      return (null, const CastJoinFailed(CastJoinFailure.launchTimedOut));
    } finally {
      deadline.cancel();
    }
  }
}

final class _CastV2Session implements CastReceiverSession {
  new(
    this._owner,
    this.address,
    CastChannel channel,
    CastRunningApp app,
    CastVolume volume,
  ) : _channel = channel,
      _appSessionId = app.sessionId,
      _transportId = app.transportId,
      _state = CastSessionState(volume: volume) {
    _attach(channel);
  }

  final CastV2Receivers _owner;

  @override
  final CastAddress address;

  CastChannel _channel;
  final String _appSessionId;
  String _transportId;
  CastSessionState _state;
  final _states = StreamController<CastSessionState>.broadcast();
  StreamSubscription<CastMessageIn>? _listening;

  /// The highest media session id seen: a status of an older session,
  /// arriving after a new LOAD, is out of date.
  var _newestMedia = 0;

  /// Set once this app stops or leaves: what the device then reports
  /// about the receiver closing is its answer, not news.
  var _ending = false;

  static const _tag = 'cast.session';

  CastTimings get _timings => _owner.timings;
  AppLog? get _log => _owner.log;

  @override
  String get localAddress => _channel.localAddress;

  @override
  CastSessionState get state => _state;

  @override
  Stream<CastSessionState> get states => _states.stream;

  /// The channel commands go on; null while reconnecting or ended.
  CastChannel? get _live =>
      _state.link == CastLink.connected && _channel.isOpen ? _channel : null;

  void _attach(CastChannel channel) {
    _channel = channel;
    channel
      ..connectTo(castReceiverId)
      ..connectTo(_transportId);
    unawaited(_listening?.cancel());
    _listening = channel.messages.listen(_onMessage);
    unawaited(channel.closed.then((reason) => _onClosed(channel, reason)));
  }

  /// Asks the media status, for a receiver joined as it was.
  Future<void> refreshMedia() async {
    final channel = _live;
    if (channel == null) return;
    // The answer goes through [_onMessage] like any status.
    await MediaChannel(channel, _transportId).status(timeout: _timings.answer);
  }

  void _onMessage(CastMessageIn message) {
    if (_state.link == CastLink.ended) return;
    switch ((message.namespace, message.type)) {
      case (CastNamespace.receiver, 'RECEIVER_STATUS'):
        _onReceiverStatus(message);
      case (CastNamespace.media, 'MEDIA_STATUS')
          when message.source == _transportId:
        _onMediaStatus(message);
      case (CastNamespace.media, 'LOAD_FAILED')
          when message.source == _transportId:
        // The TV sends IDLE/ERROR too; this doesn't wait for it.
        final media = _state.media;
        _set(
          _state.copyWith(
            media: CastMediaStatus(
              sessionId: media?.sessionId ?? _newestMedia,
              playerState: CastPlayerState.idle,
              idleReason: CastIdleReason.error,
              contentId: media?.contentId,
            ),
          ),
        );
      case (CastNamespace.connection, 'CLOSE'):
        if (message.source == castReceiverId) {
          _channel.destroy('the device closed the receiver connection');
        } else if (message.source == _transportId && !_ending) {
          // The receiver let go of this app: it closed, or another sender
          // took it. Its status tells which.
          unawaited(_recheck());
        }
    }
  }

  void _onReceiverStatus(CastMessageIn message) {
    final status = CastReceiverStatus.tryRead(message.payload);
    if (status == null) return;
    _set(_state.copyWith(volume: status.volume));
    if (_ending || status.session(_appSessionId) != null) return;
    final other = status.foreground;
    _log?.info(
      _tag,
      'the receiver on $address closed'
      '${other == null ? '' : '; ${other.displayName ?? other.appId} runs'}',
    );
    _end(
      other == null ? CastEnd.closedOnDevice : CastEnd.otherApp,
      otherApp: other?.displayName ?? other?.appId,
    );
  }

  void _onMediaStatus(CastMessageIn message) {
    final read = readMediaStatus(message.payload, previous: _state.media);
    final media = read.media;
    if (media == null) {
      _set(_state.copyWith(media: null));
      return;
    }
    if (media.sessionId < _newestMedia) return;
    _newestMedia = media.sessionId;
    _set(_state.copyWith(media: media));
  }

  Future<void> _recheck() async {
    final channel = _live;
    if (channel == null) return;
    final status = await ReceiverChannel(channel)
        .status(timeout: _timings.answer);
    // A status that lists the app was handled; one that doesn't ended
    // the session in [_onReceiverStatus].
    if (status?.session(_appSessionId) != null && channel.isOpen) {
      channel.connectTo(_transportId);
    }
  }

  void _onClosed(CastChannel channel, String reason) {
    if (!identical(channel, _channel) || _ending) return;
    if (_state.link == CastLink.ended) return;
    unawaited(_reconnect(reason));
  }

  Future<void> _reconnect(String reason) async {
    _log?.info(_tag, 'lost $address ($reason); reconnecting');
    _set(_state.copyWith(link: CastLink.reconnecting));
    var expired = false;
    final deadline = Timer(_timings.reconnectFor, () => expired = true);
    var wait = _timings.firstRetry;
    try {
      while (!_ending) {
        await Future<void>.delayed(wait);
        if (_ending) return;
        if (await _rejoin()) return;
        if (expired) break;
        wait = Duration(
          microseconds: min(
            wait.inMicroseconds * 2,
            _timings.longestRetry.inMicroseconds,
          ),
        );
      }
      if (!_ending) {
        _log?.info(_tag, 'gave up on $address');
        _end(CastEnd.lost);
      }
    } finally {
      deadline.cancel();
    }
  }

  /// One attempt to connect again and join the receiver this session
  /// left. True when it is done: rejoined, or found gone (the session
  /// ended); false to try again.
  Future<bool> _rejoin() async {
    final (channel, _) = await openCastChannel(
      address,
      connect: _owner.connect,
      timings: _timings,
      log: _log,
    );
    if (channel == null) return false;
    if (_ending) {
      await channel.close();
      return true;
    }
    final status = await ReceiverChannel(channel)
        .status(timeout: _timings.answer);
    if (status == null || _ending) {
      await channel.close();
      return _ending;
    }
    final app =
        status.session(_appSessionId) ??
        status.apps.where((a) => a.transportId == _transportId).firstOrNull;
    if (app == null) {
      await channel.close();
      final other = status.foreground;
      _log?.info(_tag, 'reconnected to $address; the receiver is gone');
      _end(
        other == null ? CastEnd.closedOnDevice : CastEnd.otherApp,
        otherApp: other?.displayName ?? other?.appId,
      );
      return true;
    }
    _transportId = app.transportId;
    _attach(channel);
    _set(_state.copyWith(link: CastLink.connected, volume: status.volume));
    _log?.info(_tag, 'rejoined the receiver on $address');
    await refreshMedia();
    return true;
  }

  @override
  Future<CastCommandResult> load(CastLoad request) async {
    final channel = _live;
    if (channel == null) return const CastDisconnected();
    final reply = await MediaChannel(
      channel,
      _transportId,
    ).load(request, timeout: _timings.command);
    return castCommandResult(
      reply,
      open: channel.isOpen,
      previous: _state.media,
    );
  }

  @override
  Future<CastCommandResult> play() => _command('PLAY');

  @override
  Future<CastCommandResult> pause() => _command('PAUSE');

  @override
  Future<CastCommandResult> seek(Duration position) =>
      _command('SEEK', extra: {'currentTime': position.inMilliseconds / 1000});

  @override
  Future<CastCommandResult> stopMedia() => _command('STOP');

  Future<CastCommandResult> _command(
    String type, {
    Map<String, Object?> extra = const {},
  }) async {
    final channel = _live;
    if (channel == null) return const CastDisconnected();
    final media = _state.media;
    if (media == null) return const CastRefused(CastRefusal.noMedia);
    final reply = await MediaChannel(
      channel,
      _transportId,
    ).command(type, media.sessionId, extra: extra, timeout: _timings.command);
    return castCommandResult(
      reply,
      open: channel.isOpen,
      previous: _state.media,
    );
  }

  @override
  Future<CastCommandResult> setVolume(double level) => _volume(level: level);

  @override
  Future<CastCommandResult> setMuted({required bool muted}) =>
      _volume(muted: muted);

  Future<CastCommandResult> _volume({double? level, bool? muted}) async {
    final channel = _live;
    if (channel == null) return const CastDisconnected();
    final reply = await ReceiverChannel(channel)
        .setVolume(level: level, muted: muted, timeout: _timings.answer);
    return castCommandResult(
      reply,
      open: channel.isOpen,
      previous: _state.media,
    );
  }

  @override
  Future<void> stop() async {
    if (_ending) return;
    _ending = true;
    final channel = _live;
    if (channel != null) {
      await ReceiverChannel(channel)
          .stop(_appSessionId, timeout: _timings.answer);
      await channel.close();
    }
    _log?.info(_tag, 'stopped the receiver on $address');
    _end(CastEnd.stopped);
  }

  @override
  Future<void> leave() async {
    if (_ending) return;
    _ending = true;
    await _channel.close();
    _log?.info(_tag, 'left the receiver on $address');
    _end(CastEnd.left);
  }

  void _end(CastEnd end, {String? otherApp}) {
    if (_state.link == CastLink.ended) return;
    _ending = true;
    unawaited(_listening?.cancel());
    if (_channel.isOpen) unawaited(_channel.close());
    _set(_state.copyWith(link: CastLink.ended, end: end, otherApp: otherApp));
    unawaited(_states.close());
  }

  void _set(CastSessionState next) {
    if (next == _state || _states.isClosed) return;
    _state = next;
    _states.add(next);
  }
}
