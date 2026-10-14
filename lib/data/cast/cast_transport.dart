import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// The byte stream a Cast channel runs on: TLS to the device, or a pipe in
/// tests.
abstract interface class CastTransport {
  /// What the device sends. Ends when the connection closes; an error
  /// means it broke.
  Stream<Uint8List> get input;

  /// This computer's address on the connection.
  String get localAddress;

  /// Sends [bytes]. A connection already gone drops them: [input] says so.
  void add(List<int> bytes);

  /// Sends what is queued, then closes.
  Future<void> close();

  /// Closes at once.
  void destroy();
}

/// Opens a [CastTransport] to a device.
typedef CastConnect = Future<CastTransport> Function(
  String host,
  int port,
  Duration timeout,
);

/// TLS to the device's port 8009. Cast devices present a self-signed
/// certificate that no authority signs, so any certificate is accepted
/// (Google's device authentication is not done). The relay's URLs carry a
/// token, not credentials; only a direct LOAD (docs/04 rule 1) sends a
/// provider's URL, which the device fetches in the clear anyway.
Future<CastTransport> connectCastSocket(
  String host,
  int port,
  Duration timeout,
) async {
  final raw = await Socket.connect(host, port, timeout: timeout);
  // The handshake gets its own timeout: a port that takes the connection
  // but never speaks TLS would otherwise hold it open for good.
  final securing = SecureSocket.secure(raw, onBadCertificate: (_) => true);
  final SecureSocket socket;
  try {
    socket = await securing.timeout(timeout);
  } on Object {
    securing.ignore();
    raw.destroy();
    rethrow;
  }
  socket.setOption(SocketOption.tcpNoDelay, true);
  return _SocketTransport(socket, await _localAddressFor(socket.remoteAddress));
}

/// This computer's address on the network [device] is on: where a TV
/// there can reach it, which is what a LOAD's URL must carry.
///
/// dart:io doesn't say which local address a connection left from —
/// `Socket.address` is the address it was connected *to*, which this
/// client took for its own until the first run on a real TV (2026-10-13):
/// the TV was told to fetch from its own address. Against the fake TV on
/// 127.0.0.1 the two are the same, which is how it passed every test.
Future<String> _localAddressFor(InternetAddress device) async {
  if (device.isLoopback) return device.address;
  try {
    final interfaces = await NetworkInterface.list(type: device.type);
    final own = [for (final each in interfaces) ...each.addresses];
    return pickLocalAddress(device, own)?.address ?? device.address;
  } on Object {
    // No list of interfaces: nothing better to say.
    return device.address;
  }
}

/// Which of this computer's addresses ([own]) is on [device]'s network:
/// the one that shares the most leading bits with it (a home network's
/// addresses differ in their last bits; another interface's, such as a
/// virtual bridge's, differ sooner). Null when [own] has none of
/// [device]'s kind.
InternetAddress? pickLocalAddress(
  InternetAddress device,
  Iterable<InternetAddress> own,
) {
  final target = device.rawAddress;
  InternetAddress? best;
  var bestBits = -1;
  for (final address in own) {
    if (address.type != device.type || address.isLoopback) continue;
    final raw = address.rawAddress;
    var bits = 0;
    for (var i = 0; i < raw.length && i < target.length; i++) {
      final differ = raw[i] ^ target[i];
      if (differ == 0) {
        bits += 8;
        continue;
      }
      // The equal bits at the top of the first byte that differs.
      bits += 8 - differ.bitLength;
      break;
    }
    if (bits > bestBits) {
      bestBits = bits;
      best = address;
    }
  }
  return best;
}

final class _SocketTransport implements CastTransport {
  new(this._socket, this.localAddress) {
    // A write to a connection that broke fails here, not in add(); the
    // reading side reports the break.
    _socket.done.ignore();
  }

  final SecureSocket _socket;
  var _closed = false;

  @override
  final String localAddress;

  @override
  Stream<Uint8List> get input => _socket;

  @override
  void add(List<int> bytes) {
    if (_closed) return;
    try {
      _socket.add(bytes);
    } on Object {
      // Closed under us; the input stream ends or errs on its own.
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _socket.flush().timeout(const Duration(seconds: 1));
      await _socket.close().timeout(const Duration(seconds: 1));
    } on Object {
      _socket.destroy();
    }
  }

  @override
  void destroy() {
    _closed = true;
    _socket.destroy();
  }
}
