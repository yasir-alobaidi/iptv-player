import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iptv_player/data/airplay/airplay_http.dart';
import 'package:iptv_player/data/cast/cast_transport.dart';

/// The encryption a connection switches to after pair-verify (ADR-067):
/// what goes out sealed, what comes in opened, each with its own counter.
abstract interface class AirPlayCipher {
  /// [plain] as the bytes to send.
  Uint8List seal(Uint8List plain);

  /// The plain bytes [chunk] completes, however the stream was cut; null
  /// when a frame failed its check (the connection is then broken).
  Uint8List? open(Uint8List chunk);
}

/// Why a request got no answer.
enum AirPlayConnectionFailure {
  /// The receiver closed the connection, or it broke.
  closed,

  /// Nothing came back in time.
  timedOut,

  /// A frame failed its check: the keys don't match.
  undecryptable,
}

/// How a request went: the receiver's response, or why there was none.
sealed class AirPlayExchange {
  const new();
}

final class AirPlayAnswered extends AirPlayExchange {
  const new(this.response);

  final AirPlayMessage response;
}

final class AirPlayNoAnswer extends AirPlayExchange {
  const new(this.failure, [this.detail]);

  final AirPlayConnectionFailure failure;

  /// For the log; never shown in front.
  final String? detail;

  @override
  String toString() =>
      'AirPlayNoAnswer(${failure.name}${detail == null ? '' : ', $detail'})';
}

/// One TCP connection to a receiver's AirPlay port (7000), carrying HTTP
/// and RTSP requests one at a time, as pyatv's does: a receiver answers in
/// order, and the next request waits for the answer before it.
final class AirPlayConnection {
  new _(this._socket, this.localAddress, this.remoteAddress) {
    _subscription = _socket.listen(
      _onData,
      onError: (Object error) =>
          _fail(AirPlayConnectionFailure.closed, '$error'),
      onDone: () => _fail(AirPlayConnectionFailure.closed, 'closed'),
      cancelOnError: true,
    );
  }

  /// Connects to [host]:[port] within [timeout]; null when it can't.
  static Future<AirPlayConnection?> open(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      return AirPlayConnection._(
        socket,
        await localAddressOn(socket),
        socket.remoteAddress.address,
      );
    } on Object {
      return null;
    }
  }

  final Socket _socket;
  late final StreamSubscription<Uint8List> _subscription;
  final _reader = AirPlayMessageReader();

  /// This computer's address on the connection: where the receiver can
  /// reach the relay and the timing port.
  final String localAddress;
  final String remoteAddress;

  AirPlayCipher? _cipher;
  Completer<AirPlayExchange>? _waiting;
  Future<void> _queue = Future.value();
  AirPlayNoAnswer? _broken;

  /// Whether the connection broke or was closed: every request since
  /// answers [AirPlayNoAnswer] at once.
  bool get isBroken => _broken != null;

  /// From now on everything is sealed and opened with [cipher].
  // ignore: use_setters_to_change_properties
  void encrypt(AirPlayCipher cipher) => _cipher = cipher;

  /// Sends [request] once the one before it was answered, and waits up to
  /// [timeout] for the answer.
  Future<AirPlayExchange> send(
    Uint8List request, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final result = _queue.then((_) => _exchange(request, timeout));
    _queue = result.then((_) {});
    return result;
  }

  Future<AirPlayExchange> _exchange(Uint8List request, Duration timeout) async {
    if (_broken case final broken?) return broken;
    final waiting = _waiting = Completer<AirPlayExchange>();
    _socket.add(_cipher?.seal(request) ?? request);
    try {
      return await waiting.future.timeout(timeout);
    } on TimeoutException {
      return const AirPlayNoAnswer(AirPlayConnectionFailure.timedOut);
    } finally {
      if (identical(_waiting, waiting)) _waiting = null;
    }
  }

  void _onData(Uint8List data) {
    final cipher = _cipher;
    final plain = cipher == null ? data : cipher.open(data);
    if (plain == null) {
      _fail(AirPlayConnectionFailure.undecryptable);
      return;
    }
    for (final message in _reader.add(plain)) {
      final waiting = _waiting;
      _waiting = null;
      // An answer nobody asked for (a late one after a timeout) is dropped.
      if (waiting != null && !waiting.isCompleted) {
        waiting.complete(AirPlayAnswered(message));
      }
    }
  }

  void _fail(AirPlayConnectionFailure failure, [String? detail]) {
    _broken ??= AirPlayNoAnswer(failure, detail);
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete(_broken);
    if (failure == AirPlayConnectionFailure.undecryptable) _socket.destroy();
  }

  /// Closes the connection; the receiver ends what it plays for it.
  Future<void> close() async {
    _fail(AirPlayConnectionFailure.closed, 'closed here');
    await _subscription.cancel();
    _socket.destroy();
  }
}

/// This computer's address on [socket]'s network, which a receiver can
/// reach it at (the Cast transport's rule: dart:io names only the address
/// connected *to*).
Future<String> localAddressOn(Socket socket) async {
  final device = socket.remoteAddress;
  if (device.isLoopback) return device.address;
  try {
    final interfaces = await NetworkInterface.list(type: device.type);
    final own = [for (final each in interfaces) ...each.addresses];
    return pickLocalAddress(device, own)?.address ?? device.address;
  } on Object {
    return device.address;
  }
}
