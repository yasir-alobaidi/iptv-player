import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:iptv_player/data/airplay/airplay_connection.dart';
import 'package:iptv_player/data/airplay/airplay_events.dart';
import 'package:iptv_player/data/airplay/airplay_http.dart';
import 'package:iptv_player/data/airplay/airplay_timing.dart';
import 'package:iptv_player/data/airplay/binary_plist.dart';
import 'package:iptv_player/data/airplay/hap_pairing.dart';
import 'package:iptv_player/data/airplay/hap_session.dart';

/// [HapSession] as a connection's cipher.
final class HapCipher implements AirPlayCipher {
  new(HapKeys keys)
    : _session = HapSession(writeKey: keys.writeKey, readKey: keys.readKey);

  final HapSession _session;

  @override
  Uint8List seal(Uint8List plain) => _session.encrypt(plain);

  @override
  Uint8List? open(Uint8List chunk) => switch (_session.decrypt(chunk)) {
    HapPlaintext(:final bytes) => bytes,
    HapReadFailed() => null,
  };
}

/// Why an AirPlay step failed (ADR-067). Words for the log; the casting
/// screens say it their own way.
sealed class AirPlayFailure {
  const new();
}

/// The receiver couldn't be reached, or the connection broke.
final class AirPlayUnreachable extends AirPlayFailure {
  const new(this.detail);

  final String detail;

  @override
  String toString() => 'unreachable: $detail';
}

/// The receiver wants this computer paired first: the code it shows on
/// its screen ([AirPlayPairing]).
final class AirPlayNeedsPairing extends AirPlayFailure {
  const new();

  @override
  String toString() => 'needs pairing';
}

/// Pairing or verifying failed: a wrong code, a receiver that forgot this
/// computer, one that is busy or wants a pause.
final class AirPlayPairingFailed extends AirPlayFailure {
  const new(this.failure);

  final HapFailure failure;

  @override
  String toString() => 'pairing: $failure';
}

/// The receiver answered a request with an error status.
final class AirPlayRefused extends AirPlayFailure {
  const new(this.step, this.status);

  final String step;
  final int? status;

  @override
  String toString() => 'refused $step${status == null ? '' : ' ($status)'}';
}

/// How an AirPlay step went: its value, or why not.
sealed class AirPlayResult<T> {
  const new();
}

final class AirPlayOk<T> extends AirPlayResult<T> {
  const new(this.value);

  final T value;
}

final class AirPlayFailed<T> extends AirPlayResult<T> {
  const new(this.failure);

  final AirPlayFailure failure;

  @override
  String toString() => 'AirPlayFailed($failure)';
}

/// Pairing with a receiver that shows a code (ADR-067): [start] asks it to
/// show the code, [finish] sends the code the user read off the screen
/// and gives the credentials to keep. One connection for both steps.
final class AirPlayPairing {
  new _(this._connection, this._setup);

  /// Connects to the receiver at [host]:[port] and asks it to show its
  /// code.
  static Future<AirPlayResult<AirPlayPairing>> start(
    String host,
    int port, {
    String name = 'Bijou',
  }) async {
    final connection = await AirPlayConnection.open(host, port);
    if (connection == null) {
      return const AirPlayFailed(AirPlayUnreachable('no connection'));
    }
    final setup = HapPairSetup(name: name);
    final pinStart = await _post(
      connection,
      '/pair-pin-start',
      airPlayPairingHeaders,
      null,
    );
    if (pinStart case AirPlayFailed(:final failure)) {
      await connection.close();
      return AirPlayFailed(failure);
    }
    final m2 = await _post(
      connection,
      '/pair-setup',
      airPlayPairingHeaders,
      setup.m1,
    );
    switch (m2) {
      case AirPlayFailed(:final failure):
        await connection.close();
        return AirPlayFailed(failure);
      case AirPlayOk(:final value):
        if (setup.readM2(value.body) case final failure?) {
          await connection.close();
          return AirPlayFailed(AirPlayPairingFailed(failure));
        }
    }
    return AirPlayOk(AirPlayPairing._(connection, setup));
  }

  final AirPlayConnection _connection;
  final HapPairSetup _setup;

  /// Sends [pin], the code on the receiver's screen; the credentials to
  /// keep (secure storage only, hard rule 3) when it was right.
  Future<AirPlayResult<HapCredentials>> finish(String pin) async {
    try {
      final m3 = _setup.m3(pin);
      if (m3 case HapFailed(:final failure)) {
        return AirPlayFailed(AirPlayPairingFailed(failure));
      }
      final m4 = await _post(
        _connection,
        '/pair-setup',
        airPlayPairingHeaders,
        (m3 as HapOk<Uint8List>).value,
      );
      if (m4 case AirPlayFailed(:final failure)) return AirPlayFailed(failure);
      if (_setup.readM4((m4 as AirPlayOk<AirPlayMessage>).value.body)
          case final failure?) {
        return AirPlayFailed(AirPlayPairingFailed(failure));
      }
      final m5 = await _setup.m5();
      if (m5 case HapFailed(:final failure)) {
        return AirPlayFailed(AirPlayPairingFailed(failure));
      }
      final m6 = await _post(
        _connection,
        '/pair-setup',
        airPlayPairingHeaders,
        (m5 as HapOk<Uint8List>).value,
      );
      if (m6 case AirPlayFailed(:final failure)) return AirPlayFailed(failure);
      return switch (await _setup.readM6(
        (m6 as AirPlayOk<AirPlayMessage>).value.body,
      )) {
        HapOk(:final value) => AirPlayOk(value),
        HapFailed(:final failure) => AirPlayFailed(
          AirPlayPairingFailed(failure),
        ),
      };
    } finally {
      await _connection.close();
    }
  }

  /// Gives up without a code.
  Future<void> cancel() => _connection.close();
}

/// One AirPlay 2 session with a receiver, playing a URL (ADR-067), as
/// pyatv's AirPlayV2 does since tvOS 26: pair-verify (or transient
/// pairing) on the control connection, then everything sealed; SETUP with
/// the timing port, which names the event port; the event channel; a
/// feedback every 2 s; INFO, RECORD, a SETUP of the remote-control stream
/// (type 130), and the play queue's commands on `/command`.
final class AirPlaySession {
  new _(this._connection, this._secret, this._timing);

  /// Connects to [host]:[port] and verifies: with [credentials] kept from
  /// pairing, or else transiently when [transient] (a receiver that plays
  /// for anyone on its network). [AirPlayNeedsPairing] when it wants the
  /// code on its screen.
  static Future<AirPlayResult<AirPlaySession>> connect(
    String host,
    int port, {
    HapCredentials? credentials,
    bool transient = true,
  }) async {
    final connection = await AirPlayConnection.open(host, port);
    if (connection == null) {
      return const AirPlayFailed(AirPlayUnreachable('no connection'));
    }
    final AirPlayResult<HapSharedSecret> verified;
    if (credentials != null) {
      verified = await _verify(connection, credentials);
    } else if (transient) {
      verified = await _transient(connection);
    } else {
      verified = const AirPlayFailed(AirPlayNeedsPairing());
    }
    switch (verified) {
      case AirPlayFailed(:final failure):
        await connection.close();
        return AirPlayFailed(failure);
      case AirPlayOk(value: final secret):
        connection.encrypt(HapCipher(await secret.controlKeys()));
        final AirPlayTimingServer timing;
        try {
          timing = await AirPlayTimingServer.start(
            InternetAddress(connection.localAddress),
          );
        } on Object catch (error) {
          await connection.close();
          return AirPlayFailed(AirPlayUnreachable('timing port: $error'));
        }
        return AirPlayOk(AirPlaySession._(connection, secret, timing));
    }
  }

  final AirPlayConnection _connection;
  final HapSharedSecret _secret;
  final AirPlayTimingServer _timing;
  final _random = Random.secure();
  late final String _sessionId = _uuid(_random);
  late final String _senderId = _senderDeviceId(_random);
  late final int _rtspSession = _random.nextInt(1 << 32);
  late final String _dacpId = [for (var i = 0; i < 8; i++) _random.nextInt(256)]
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  late final int _activeRemote = _random.nextInt(1 << 32);
  var _cseq = 0;
  AirPlayEventChannel? _events;
  Timer? _feedback;
  int? _streamId;
  final _states = StreamController<String>.broadcast();
  String? _state;

  /// This computer's address on the connection: where the receiver can
  /// reach the relay.
  String get localAddress => _connection.localAddress;

  /// The playback's state as the receiver names it ("loading", "playing",
  /// "paused", "stopped"), lower-cased; null until it says.
  String? get state => _state;

  /// Every change of [state].
  Stream<String> get states => _states.stream;

  /// Whether the control connection broke.
  bool get isBroken => _connection.isBroken;

  /// Plays [url] from [position] (seconds). Done when the receiver took
  /// every command; whether it plays shows in [states].
  Future<AirPlayResult<void>> play(String url, {double position = 0}) async {
    if (_streamId == null) {
      final ready = await _setUp();
      if (ready is AirPlayFailed) return ready;
    }
    final itemId = _uuid(_random);
    for (final command in <Map<String, Object?>>[
      {
        'type': 'insertPlayQueueItem',
        'item': {
          'uuid': itemId,
          'mediaType': 'file',
          'Content-Location': url,
          'Start-Position-Seconds': position,
        },
      },
      {
        'type': 'setProperty',
        'value': true,
        'property': 'isInterestedInDateRange',
        'item': {'uuid': itemId},
      },
      {'type': 'setProperty', 'value': 1, 'property': 'actionAtItemEnd'},
      {'type': 'setRate', 'rate': 1.0},
    ]) {
      final sent = await _command(command);
      if (sent is AirPlayFailed) return sent;
    }
    return const AirPlayOk(null);
  }

  /// Pauses (rate 0) or plays on (rate 1).
  Future<AirPlayResult<void>> setRate(double rate) =>
      _command({'type': 'setRate', 'rate': rate});

  /// Ends the session: the receiver stops what it plays for it.
  Future<void> close() async {
    _feedback?.cancel();
    _feedback = null;
    await _events?.close();
    _timing.close();
    await _connection.close();
    if (!_states.isClosed) await _states.close();
  }

  Future<AirPlayResult<void>> _setUp() async {
    final base = await _exchange(
      'SETUP',
      body: {
        'deviceID': _senderId,
        'sessionUUID': _sessionId,
        'sessionCorrelationUUID': _uuid(_random),
        'timingPort': _timing.port,
        'timingProtocol': 'NTP',
        'isMultiSelectAirPlay': true,
        'groupContainsGroupLeader': false,
        'macAddress': _senderId,
        'model': 'iPhone14,3',
        'name': 'Bijou',
        'osBuildVersion': '20F66',
        'osName': 'iPhone OS',
        'osVersion': '16.5',
        'senderSupportsRelay': false,
        'sourceVersion': '690.7.1',
        'statsCollectionEnabled': false,
      },
    );
    if (base case AirPlayFailed(:final failure)) return AirPlayFailed(failure);
    final setup = readBinaryPlistDict(
      (base as AirPlayOk<AirPlayMessage>).value.body,
    );
    final eventPort = setup?['eventPort'];
    if (eventPort is int && eventPort > 0) {
      final events = await AirPlayEventChannel.open(
        _connection.remoteAddress,
        eventPort,
        cipher: HapCipher(await _secret.eventsKeys()),
        decodePlist: (bytes) => switch (readBinaryPlist(bytes)) {
          PlistRead(:final value) => value,
          PlistUnreadable() => null,
        },
      );
      _events = events;
      events?.events.listen((event) {
        final state = playbackStateIn(event);
        if (state == null || state == _state) return;
        _state = state;
        if (!_states.isClosed) _states.add(state);
      });
    }
    // Best effort, as pyatv: a missed one ends nothing.
    _feedback = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_exchange('POST', uri: '/feedback')),
    );
    // Not every receiver has /info on the session; its answer is not
    // needed.
    await _exchange('GET', uri: '/info');
    final record = await _exchange('RECORD');
    if (record case AirPlayFailed(:final failure)) {
      return AirPlayFailed(failure);
    }
    final stream = await _exchange(
      'SETUP',
      body: {
        'streams': [
          {
            'clientUUID': _uuid(_random),
            'clientTypeUUID': _remoteControlClientType,
            'channelID': '$_senderId-RCS-1',
            'controlType': 1,
            'type': 130,
          },
        ],
      },
    );
    if (stream case AirPlayFailed(:final failure)) {
      return AirPlayFailed(failure);
    }
    final streams = readBinaryPlistDict(
      (stream as AirPlayOk<AirPlayMessage>).value.body,
    )?['streams'];
    final id = switch (streams) {
      [{'streamID': final int id}, ...] => id,
      _ => null,
    };
    if (id == null) {
      return const AirPlayFailed(AirPlayRefused('SETUP 130', null));
    }
    _streamId = id;
    return const AirPlayOk(null);
  }

  Future<AirPlayResult<void>> _command(Map<String, Object?> command) async {
    final sent = await _exchange(
      'POST',
      uri: '/command',
      protocol: 'HTTP/1.1',
      headers: {
        'User-Agent': _commandUserAgent,
        'X-Apple-ProtocolVersion': '1',
        'X-Apple-Session-ID': _sessionId,
        'X-Apple-StreamID': '$_streamId',
      },
      body: {
        'params': {'data': writeBinaryPlist(command)},
      },
    );
    return switch (sent) {
      AirPlayOk() => const AirPlayOk(null),
      AirPlayFailed(:final failure) => AirPlayFailed(failure),
    };
  }

  /// One request on the session (pyatv's `RtspSession.exchange`): its
  /// CSeq and the sender's ids; a map [body] as a binary plist.
  Future<AirPlayResult<AirPlayMessage>> _exchange(
    String method, {
    String? uri,
    String protocol = 'RTSP/1.0',
    Map<String, Object> headers = const {},
    Map<String, Object?>? body,
  }) async {
    final request = formatAirPlayRequest(
      method: method,
      uri: uri ?? 'rtsp://${_connection.localAddress}/$_rtspSession',
      protocol: protocol,
      contentType: body == null ? null : binaryPlistContentType,
      body: body == null ? null : writeBinaryPlist(body),
      headers: {
        'CSeq': _cseq++,
        'DACP-ID': _dacpId,
        'Active-Remote': _activeRemote,
        'Client-Instance': _dacpId,
        ...headers,
      },
    );
    return _answer(await _connection.send(request), '$method ${uri ?? ''}');
  }

  static Future<AirPlayResult<HapSharedSecret>> _verify(
    AirPlayConnection connection,
    HapCredentials credentials,
  ) async {
    final verify = HapPairVerify(credentials);
    final m2 = await _post(
      connection,
      '/pair-verify',
      airPlayPairingHeaders,
      await verify.m1(),
    );
    if (m2 case AirPlayFailed(:final failure)) return AirPlayFailed(failure);
    if (await verify.readM2((m2 as AirPlayOk<AirPlayMessage>).value.body)
        case final failure?) {
      return AirPlayFailed(AirPlayPairingFailed(failure));
    }
    final m3 = await verify.m3();
    if (m3 case HapFailed(:final failure)) {
      return AirPlayFailed(AirPlayPairingFailed(failure));
    }
    final m4 = await _post(
      connection,
      '/pair-verify',
      airPlayPairingHeaders,
      (m3 as HapOk<Uint8List>).value,
    );
    if (m4 case AirPlayFailed(:final failure)) return AirPlayFailed(failure);
    return switch (verify.readM4(
      (m4 as AirPlayOk<AirPlayMessage>).value.body,
    )) {
      HapOk(:final value) => AirPlayOk(value),
      HapFailed(:final failure) => AirPlayFailed(AirPlayPairingFailed(failure)),
    };
  }

  static Future<AirPlayResult<HapSharedSecret>> _transient(
    AirPlayConnection connection,
  ) async {
    final setup = HapTransientPairSetup();
    final pinStart = await _post(
      connection,
      '/pair-pin-start',
      airPlayTransientPairingHeaders,
      null,
    );
    // A receiver that wants its code shown refuses this from a stranger.
    if (pinStart case AirPlayFailed(failure: AirPlayRefused())) {
      return const AirPlayFailed(AirPlayNeedsPairing());
    }
    if (pinStart case AirPlayFailed(:final failure)) {
      return AirPlayFailed(failure);
    }
    final m2 = await _post(
      connection,
      '/pair-setup',
      airPlayTransientPairingHeaders,
      setup.m1,
    );
    if (m2 case AirPlayFailed(failure: AirPlayRefused())) {
      return const AirPlayFailed(AirPlayNeedsPairing());
    }
    if (m2 case AirPlayFailed(:final failure)) return AirPlayFailed(failure);
    if (setup.readM2((m2 as AirPlayOk<AirPlayMessage>).value.body)
        case final failure?) {
      return AirPlayFailed(_transientFailure(failure));
    }
    final m3 = setup.m3();
    if (m3 case HapFailed(:final failure)) {
      return AirPlayFailed(_transientFailure(failure));
    }
    final m4 = await _post(
      connection,
      '/pair-setup',
      airPlayTransientPairingHeaders,
      (m3 as HapOk<Uint8List>).value,
    );
    if (m4 case AirPlayFailed(failure: AirPlayRefused())) {
      return const AirPlayFailed(AirPlayNeedsPairing());
    }
    if (m4 case AirPlayFailed(:final failure)) return AirPlayFailed(failure);
    return switch (setup.readM4((m4 as AirPlayOk<AirPlayMessage>).value.body)) {
      HapOk(:final value) => AirPlayOk(value),
      HapFailed(:final failure) => AirPlayFailed(_transientFailure(failure)),
    };
  }

  /// A refused transient pairing means the receiver wants its code.
  static AirPlayFailure _transientFailure(HapFailure failure) =>
      failure is HapAuthenticationFailed
      ? const AirPlayNeedsPairing()
      : AirPlayPairingFailed(failure);
}

/// A pairing POST over HTTP/1.1 with [headers] and an octet-stream body.
Future<AirPlayResult<AirPlayMessage>> _post(
  AirPlayConnection connection,
  String path,
  Map<String, String> headers,
  Uint8List? body,
) async {
  final request = formatAirPlayRequest(
    method: 'POST',
    uri: path,
    protocol: 'HTTP/1.1',
    headers: headers,
    body: body,
  );
  return _answer(await connection.send(request), 'POST $path');
}

AirPlayResult<AirPlayMessage> _answer(AirPlayExchange exchange, String step) =>
    switch (exchange) {
      AirPlayAnswered(:final response)
          when (response.status ?? 0) >= 200 && (response.status ?? 0) < 300 =>
        AirPlayOk(response),
      AirPlayAnswered(:final response) => AirPlayFailed(
        AirPlayRefused(step, response.status),
      ),
      AirPlayNoAnswer(:final failure, :final detail) => AirPlayFailed(
        AirPlayUnreachable(
          '$step: ${failure.name}${detail == null ? '' : ' ($detail)'}',
        ),
      ),
    };

/// The client type pyatv names the URL control stream with.
const _remoteControlClientType = 'A6B27562-B43A-4F2D-B75F-82391E250194';

/// The User-Agent of `/command`: receivers since tvOS 26 check it.
const _commandUserAgent = 'AirPlay/870.14.1';

String _uuid(Random random) {
  final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
          '${hex.substring(20)}'
      .toUpperCase();
}

/// A MAC-shaped id with the locally administered bit set, as pyatv makes.
String _senderDeviceId(Random random) {
  final bytes = [for (var i = 0; i < 6; i++) random.nextInt(256)];
  bytes[0] = (bytes[0] & 0xFC) | 0x02;
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}
