import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iptv_player/data/airplay/airplay_connection.dart';
import 'package:iptv_player/data/airplay/airplay_http.dart';

/// The event channel an AirPlay 2 SETUP opens (ADR-067): a second TCP
/// connection to the receiver's `eventPort`, sealed with the Events keys,
/// on which the *receiver* asks — the playback's state, as a plist in a
/// plist — and we answer each with 200, as pyatv does.
final class AirPlayEventChannel {
  new _(this._socket, this._cipher, this._decode) {
    _subscription = _socket.listen(
      _onData,
      onError: (_) => _end(),
      onDone: _end,
      cancelOnError: true,
    );
  }

  /// Connects to the receiver's [host]:[port]; tried a few times, a
  /// second apart, since a receiver can name the port a moment before it
  /// listens on it. Null when it never answers.
  static Future<AirPlayEventChannel?> open(
    String host,
    int port, {
    required AirPlayCipher cipher,
    required Object? Function(Uint8List bytes) decodePlist,
    int tries = 5,
  }) async {
    for (var attempt = 1; attempt <= tries; attempt++) {
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );
        socket.setOption(SocketOption.tcpNoDelay, true);
        return AirPlayEventChannel._(socket, cipher, decodePlist);
      } on Object {
        if (attempt < tries) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }
    return null;
  }

  final Socket _socket;
  final AirPlayCipher _cipher;
  final Object? Function(Uint8List bytes) _decode;
  late final StreamSubscription<Uint8List> _subscription;
  final _reader = AirPlayMessageReader();
  final _events = StreamController<Map<Object?, Object?>>.broadcast();

  /// Each event the receiver sent, its inner plist when it wrapped one in
  /// `params.data`. Ends when the channel closes.
  Stream<Map<Object?, Object?>> get events => _events.stream;

  void _onData(Uint8List data) {
    final plain = _cipher.open(data);
    if (plain == null) {
      _end();
      return;
    }
    for (final request in _reader.add(plain)) {
      if (eventIn(request.body, _decode) case final event?) _events.add(event);
      _socket.add(
        _cipher.seal(
          formatAirPlayResponse(
            protocol: request.requestProtocol ?? 'RTSP/1.0',
            status: 200,
            reason: 'OK',
            headers: {
              'Content-Length': '0',
              'Audio-Latency': '0',
              'Server': ?request.header('Server'),
              'CSeq': ?request.header('CSeq'),
            },
          ),
        ),
      );
    }
  }

  void _end() {
    if (!_events.isClosed) unawaited(_events.close());
  }

  Future<void> close() async {
    _end();
    await _subscription.cancel();
    _socket.destroy();
  }
}

/// The event in a request's [body]: its plist, or the plist in its
/// `params.data` when it carries one there. Null for anything else.
Map<Object?, Object?>? eventIn(
  Uint8List body,
  Object? Function(Uint8List bytes) decode,
) {
  final outer = decode(body);
  if (outer is! Map) return null;
  if (outer['params'] case {'data': final Uint8List inner}) {
    final event = decode(inner);
    return event is Map ? Map<Object?, Object?>.of(event) : null;
  }
  return Map<Object?, Object?>.of(outer);
}

/// The playback state an event names, lower-cased ("playing", "paused",
/// "loading", "stopped", "idle"), or null for an event of another kind.
String? playbackStateIn(Map<Object?, Object?> event) {
  if (event['type'] != 'playbackState') return null;
  final state = switch (event['params']) {
    {'playbackState': final String state} => state,
    _ => event['name'],
  };
  return state is String ? state.toLowerCase() : null;
}
