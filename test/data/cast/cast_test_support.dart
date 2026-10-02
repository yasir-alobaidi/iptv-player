import 'dart:async';
import 'dart:typed_data';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:iptv_player/data/cast/cast_transport.dart';

/// A [CastTransport] in memory: what the channel writes is read back with
/// the fake receiver's own decoder (not the app's generated code), and
/// what the test delivers goes in as the device's bytes.
final class PipeTransport implements CastTransport {
  final _input = StreamController<Uint8List>();
  final _splitter = FrameSplitter();

  /// Every message the channel sent, decoded.
  final sent = <WireMessage>[];
  bool closed = false;
  bool destroyed = false;

  @override
  Stream<Uint8List> get input => _input.stream;

  @override
  String get localAddress => '192.168.1.254';

  /// The JSON payloads sent on [namespace], in order.
  List<Map<String, Object?>> sentOn(String namespace) => [
    for (final m in sent)
      if (m.namespace == namespace) m.payload!,
  ];

  @override
  void add(List<int> bytes) {
    for (final body in _splitter.add(bytes)!) {
      sent.add(WireMessage.decode(Uint8List.fromList(body)));
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await _input.close();
  }

  /// Like a socket destroyed under a device still sending: the bytes
  /// keep coming, and nobody reads them.
  @override
  void destroy() => destroyed = true;

  /// [payload] on [namespace] from [source], as the device sends it.
  void deliver(
    String namespace,
    Map<String, Object?> payload, {
    String source = receiverId,
  }) => deliverBytes(
    frame(
      WireMessage.json(
        sourceId: source,
        destinationId: 'sender-0',
        namespace: namespace,
        payload: payload,
      ).encode(),
    ),
  );

  void deliverBytes(List<int> bytes) {
    if (!_input.isClosed) _input.add(Uint8List.fromList(bytes));
  }

  void fail(Object error) => _input.addError(error);

  /// The device closes the connection.
  void end() => unawaited(_input.close());
}
