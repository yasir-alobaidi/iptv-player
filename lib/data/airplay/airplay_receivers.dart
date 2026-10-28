import 'dart:async';

import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_pairing.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/airplay/airplay_session.dart';
import 'package:iptv_player/data/airplay/hap_pairing.dart';

/// Where an AirPlay TV's pairing is kept: the keychain's entry
/// `airplay.<device id>`, holding this computer's long-term key for it
/// (hard rule 3: never in the database or a log).
String airPlayCredentialKey(String deviceId) => 'airplay.$deviceId';

/// Reads and keeps AirPlay pairings in the [CredentialStore].
final class AirPlayCredentials {
  const new(this._store);

  final CredentialStore _store;

  Future<HapCredentials?> read(String deviceId) async =>
      switch (await _store.read(airPlayCredentialKey(deviceId))) {
        Ok(:final value?) => HapCredentials.parse(value),
        _ => null,
      };

  Future<void> write(String deviceId, HapCredentials credentials) =>
      _store.write(airPlayCredentialKey(deviceId), credentials.serialize());

  Future<void> forget(String deviceId) =>
      _store.delete(airPlayCredentialKey(deviceId));
}

/// Connects to an AirPlay receiver: [AirPlaySession.connect], a seam for
/// tests.
typedef AirPlayConnect = Future<AirPlayResult<AirPlayPlayback>> Function(
  String host,
  int port, {
  HapCredentials? credentials,
});

Future<AirPlayResult<AirPlayPlayback>> _connect(
  String host,
  int port, {
  HapCredentials? credentials,
}) => AirPlaySession.connect(host, port, credentials: credentials);

/// [CastReceivers] for AirPlay TVs (ADR-067): a join verifies with the
/// pairing kept for the device (or transiently, for a TV that lets
/// anyone on its network play); what plays is sent as the play queue's
/// item on `load`.
final class AirPlayReceivers implements CastReceivers {
  new({required this.credentials, this.log, this.connect = _connect});

  final AirPlayCredentials credentials;
  final AppLog? log;
  final AirPlayConnect connect;

  static const _tag = 'airplay';

  @override
  Future<CastJoinResult> join(
    CastAddress address, {
    void Function(String localAddress)? onConnected,
    CastProtocol protocol = CastProtocol.airPlay,
    String? deviceId,
  }) async {
    final kept = deviceId == null ? null : await credentials.read(deviceId);
    final clock = Stopwatch()..start();
    final result = await connect(address.host, address.port, credentials: kept);
    switch (result) {
      case AirPlayFailed(failure: AirPlayNeedsPairing()):
        log?.info(_tag, '$address wants pairing');
        return const CastJoinFailed(CastJoinFailure.needsPairing);
      case AirPlayFailed(failure: AirPlayPairingFailed(:final failure))
          when kept != null && failure is HapVerificationFailed:
        // The TV forgot this computer (reset, or removed it): pair again.
        log?.info(_tag, '$address no longer knows this computer: $failure');
        if (deviceId != null) await credentials.forget(deviceId);
        return const CastJoinFailed(CastJoinFailure.needsPairing);
      case AirPlayFailed(:final failure):
        log?.info(_tag, 'no session with $address: $failure');
        return CastJoinFailed(
          failure is AirPlayUnreachable
              ? CastJoinFailure.unreachable
              : CastJoinFailure.launchRefused,
          '$failure',
        );
      case AirPlayOk(value: final session):
        log?.info(
          _tag,
          '${kept == null ? 'transient' : 'paired'} session with $address '
          'in ${clock.elapsedMilliseconds} ms',
        );
        onConnected?.call(session.localAddress);
        return CastJoined(
          AirPlayCastSession(address, session, log: log),
          launched: true,
        );
    }
  }
}

/// One AirPlay session as a [CastReceiverSession]: LOAD is the play
/// queue's item, play and pause its rate. AirPlay sends no position or
/// length the way Cast does, and its volume is the TV's own.
final class AirPlayCastSession implements CastReceiverSession {
  new(this.address, this._session, {this.log}) {
    _subscription = _session.states.listen(_onState, onDone: _onDone);
  }

  @override
  final CastAddress address;
  final AirPlayPlayback _session;
  final AppLog? log;
  late final StreamSubscription<String> _subscription;
  final _states = StreamController<CastSessionState>.broadcast();
  var _state = const CastSessionState(volume: CastVolume(fixed: true));
  var _mediaSession = 0;
  String? _contentId;
  var _ended = false;

  @override
  String get localAddress => _session.localAddress;

  @override
  CastSessionState get state => _state;

  @override
  Stream<CastSessionState> get states => _states.stream;

  void _emit(CastSessionState next) {
    if (next == _state) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  void _onState(String state) {
    if (_contentId == null) return;
    _emit(
      _state.copyWith(
        media: CastMediaStatus(
          sessionId: _mediaSession,
          playerState: switch (state) {
            'playing' => CastPlayerState.playing,
            'paused' => CastPlayerState.paused,
            'loading' || 'buffering' => CastPlayerState.buffering,
            _ => CastPlayerState.idle,
          },
          idleReason: switch (state) {
            'stopped' || 'idle' || 'ended' => CastIdleReason.finished,
            _ => null,
          },
          rate: state == 'playing' ? 1 : 0,
          contentId: _contentId,
        ),
      ),
    );
  }

  /// The control connection closed on the TV's side: its remote, or the
  /// TV went to another input.
  void _onDone() {
    if (_ended) return;
    _end(CastEnd.closedOnDevice);
  }

  void _end(CastEnd end) {
    _ended = true;
    _emit(_state.copyWith(link: CastLink.ended, end: end));
    unawaited(_subscription.cancel());
    if (!_states.isClosed) unawaited(_states.close());
  }

  Future<CastCommandResult> _result(Future<AirPlayResult<void>> sent) async {
    if (_ended) return const CastDisconnected();
    return switch (await sent) {
      AirPlayOk() => const CastDone(),
      AirPlayFailed(failure: AirPlayUnreachable()) => const CastDisconnected(),
      AirPlayFailed(:final failure) => CastRefused(
        CastRefusal.invalidRequest,
        '$failure',
      ),
    };
  }

  @override
  Future<CastCommandResult> load(CastLoad request) async {
    _mediaSession++;
    _contentId = request.url;
    _emit(
      _state.copyWith(
        media: CastMediaStatus(
          sessionId: _mediaSession,
          playerState: CastPlayerState.loading,
          contentId: request.url,
          duration: request.duration,
          position: request.start,
        ),
      ),
    );
    final result = await _result(
      _session.play(request.url, position: request.start.inMilliseconds / 1000),
    );
    if (result is CastRefused) {
      _emit(
        _state.copyWith(
          media: CastMediaStatus(
            sessionId: _mediaSession,
            playerState: CastPlayerState.idle,
            idleReason: CastIdleReason.error,
            contentId: request.url,
          ),
        ),
      );
      return const CastRefused(CastRefusal.loadFailed);
    }
    return result;
  }

  @override
  Future<CastCommandResult> play() => _result(_session.setRate(1));

  @override
  Future<CastCommandResult> pause() => _result(_session.setRate(0));

  /// The play queue's commands have no seek pyatv knows of yet.
  @override
  Future<CastCommandResult> seek(Duration position) async => _ended
      ? const CastDisconnected()
      : const CastRefused(
          CastRefusal.invalidRequest,
          'no seek over AirPlay yet',
        );

  @override
  Future<CastCommandResult> stopMedia() => _result(_session.setRate(0));

  @override
  Future<CastCommandResult> showTextTrack(int? id) async => const CastRefused(
    CastRefusal.invalidRequest,
    'no text tracks over AirPlay',
  );

  @override
  Future<CastCommandResult> setVolume(double level) async =>
      const CastRefused(CastRefusal.invalidRequest, "the TV's own volume");

  @override
  Future<CastCommandResult> setMuted({required bool muted}) async =>
      const CastRefused(CastRefusal.invalidRequest, "the TV's own volume");

  @override
  Future<void> stop() async {
    if (_ended) return;
    _end(CastEnd.stopped);
    await _session.close();
  }

  @override
  Future<void> leave() async {
    // AirPlay plays only while its sender holds the session: letting go
    // ends what plays.
    if (_ended) return;
    _end(CastEnd.left);
    await _session.close();
  }
}

/// Sends each join to the receivers of its device's protocol.
final class ProtocolCastReceivers implements CastReceivers {
  const new({required this.googleCast, required this.airPlay});

  final CastReceivers googleCast;
  final CastReceivers airPlay;

  @override
  Future<CastJoinResult> join(
    CastAddress address, {
    void Function(String localAddress)? onConnected,
    CastProtocol protocol = CastProtocol.googleCast,
    String? deviceId,
  }) => switch (protocol) {
    CastProtocol.googleCast => googleCast.join(
      address,
      onConnected: onConnected,
      deviceId: deviceId,
    ),
    CastProtocol.airPlay => airPlay.join(
      address,
      onConnected: onConnected,
      protocol: protocol,
      deviceId: deviceId,
    ),
  };
}

/// Pairs with AirPlay TVs that show a code ([CastPairing], ADR-067).
final class AirPlayCastPairing implements CastPairing {
  new({required this.credentials, this.log, this.startPairing = _startPairing});

  final AirPlayCredentials credentials;
  final AppLog? log;

  /// [AirPlayPairing.start]; another in tests.
  final Future<AirPlayResult<AirPlayPairing>> Function(String host, int port)
  startPairing;

  static Future<AirPlayResult<AirPlayPairing>> _startPairing(
    String host,
    int port,
  ) => AirPlayPairing.start(host, port);

  @override
  Future<bool> isPaired(CastDevice device) async =>
      await credentials.read(device.id) != null;

  @override
  Future<CastPairingStart> start(CastDevice device) async {
    switch (await startPairing(device.host, device.port)) {
      case AirPlayFailed(:final failure):
        log?.info('airplay', 'pairing with ${device.name} failed: $failure');
        return CastPairingUnavailable(switch (failure) {
          AirPlayUnreachable() => CastPairingProblem.unreachable,
          AirPlayPairingFailed(failure: HapBusy() || HapBackOff()) =>
            CastPairingProblem.busy,
          _ => CastPairingProblem.refused,
        }, '$failure');
      case AirPlayOk(value: final pairing):
        return CastPairingShown(_Attempt(this, device, pairing));
    }
  }

  @override
  Future<void> forget(CastDevice device) => credentials.forget(device.id);
}

final class _Attempt implements CastPairingAttempt {
  new(this._owner, this._device, this._pairing);

  final AirPlayCastPairing _owner;
  final CastDevice _device;
  final AirPlayPairing _pairing;

  @override
  Future<CastPairingResult> finish(String code) async {
    switch (await _pairing.finish(code)) {
      case AirPlayOk(value: final credentials):
        await _owner.credentials.write(_device.id, credentials);
        _owner.log?.info('airplay', 'paired with ${_device.name}');
        return CastPairingResult.paired;
      case AirPlayFailed(:final failure):
        _owner.log?.info('airplay', 'pairing with ${_device.name}: $failure');
        return switch (failure) {
          AirPlayPairingFailed(
            failure: HapAuthenticationFailed() || HapVerificationFailed(),
          ) =>
            CastPairingResult.wrongCode,
          AirPlayPairingFailed(failure: HapMaxTries() || HapBackOff()) =>
            CastPairingResult.tooManyTries,
          _ => CastPairingResult.failed,
        };
    }
  }

  @override
  Future<void> cancel() => _pairing.cancel();
}
