import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// The timing port an AirPlay 2 SETUP names (`timingProtocol: NTP`): the
/// receiver asks it the time now and then, and it answers at once, as
/// pyatv's TimingServer does (ADR-067). Video sent by URL is timed by the
/// receiver itself; the answers only have to come.
final class AirPlayTimingServer {
  new _(this._socket) {
    _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket.receive();
      if (datagram == null) return;
      final reply = timingReply(datagram.data, DateTime.now());
      if (reply != null) _socket.send(reply, datagram.address, datagram.port);
    });
  }

  /// Listens on a free UDP port of [address] (this computer's address on
  /// the receiver's network).
  static Future<AirPlayTimingServer> start(InternetAddress address) async =>
      AirPlayTimingServer._(await RawDatagramSocket.bind(address, 0));

  final RawDatagramSocket _socket;

  int get port => _socket.port;

  void close() => _socket.close();
}

/// The answer to a timing request [request] received at [now]: 32 bytes,
/// big-endian — proto, type 0xD3, sequence 7, padding, then the request's
/// send time as the reference and [now] as both the receive and send
/// times. Null for anything shorter than a request.
Uint8List? timingReply(Uint8List request, DateTime now) {
  if (request.length < 32) return null;
  final asked = ByteData.sublistView(request);
  final (seconds, fraction) = ntpParts(now);
  return (ByteData(32)
        ..setUint8(0, asked.getUint8(0))
        ..setUint8(1, 0x53 | 0x80)
        ..setUint16(2, 7)
        ..setUint32(4, 0)
        ..setUint32(8, asked.getUint32(24))
        ..setUint32(12, asked.getUint32(28))
        ..setUint32(16, seconds)
        ..setUint32(20, fraction)
        ..setUint32(24, seconds)
        ..setUint32(28, fraction))
      .buffer
      .asUint8List();
}

/// [time] in NTP's seconds since 1900 and its 32-bit fraction.
(int, int) ntpParts(DateTime time) {
  final micros = time.microsecondsSinceEpoch;
  final seconds = micros ~/ Duration.microsecondsPerSecond;
  final rest = micros - seconds * Duration.microsecondsPerSecond;
  return (
    (seconds + _ntpEpochOffset) & 0xFFFFFFFF,
    (rest << 32) ~/ Duration.microsecondsPerSecond,
  );
}

/// Seconds from 1900 to 1970.
const _ntpEpochOffset = 0x83AA7E80;
