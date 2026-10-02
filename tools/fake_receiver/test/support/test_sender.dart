import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_receiver/fake_receiver.dart';

/// A bare Cast sender for the fake's tests: TLS, frames and JSON,
/// nothing else.
final class TestSender {
  new _(this._socket) {
    _socket.listen((data) {
      for (final body in _splitter.add(data) ?? const <List<int>>[]) {
        _inbox.add(WireMessage.decode(Uint8List.fromList(body)));
      }
    }, onDone: _inbox.close);
    // The fake closing the connection fails a write here; the reading
    // side reports it.
    _socket.done.ignore();
  }

  static Future<TestSender> connect(FakeReceiver receiver) async =>
      TestSender._(
        await SecureSocket.connect(
          receiver.host,
          receiver.port,
          onBadCertificate: (_) => true,
        ),
      );

  final SecureSocket _socket;
  final _splitter = FrameSplitter();
  final _inbox = StreamController<WireMessage>.broadcast();

  Stream<WireMessage> get inbox => _inbox.stream;

  void send(String destination, String namespace, Map<String, Object?> json) {
    _socket.add(
      frame(
        WireMessage.json(
          sourceId: 'sender-0',
          destinationId: destination,
          namespace: namespace,
          payload: json,
        ).encode(),
      ),
    );
  }

  void connectTo(String destination) =>
      send(destination, nsConnection, {'type': 'CONNECT'});

  /// The next message of [type] that [where] accepts, listened for
  /// before [then] runs.
  Future<WireMessage> next(
    String type, [
    void Function()? then,
    bool Function(WireMessage message)? where,
  ]) {
    final found = inbox
        .firstWhere(
          (m) => m.payload?['type'] == type && (where?.call(m) ?? true),
        )
        .timeout(const Duration(seconds: 3));
    then?.call();
    return found;
  }

  /// Every message of [type] within [window].
  Future<List<WireMessage>> collect(String type, Duration window) async {
    final seen = <WireMessage>[];
    final subscription = inbox
        .where((m) => m.payload?['type'] == type)
        .listen(seen.add);
    await Future<void>.delayed(window);
    await subscription.cancel();
    return seen;
  }

  Future<void> close() async => _socket.destroy();

  /// CONNECT, LAUNCH, CONNECT to the app, and a round trip so the fake has
  /// taken them all: the app's transport id.
  Future<String> launch() async {
    connectTo(receiverId);
    final launched = await next(
      'RECEIVER_STATUS',
      () => send(receiverId, nsReceiver, {
        'type': 'LAUNCH',
        'appId': defaultMediaReceiver,
        'requestId': 1,
      }),
      (m) => (m.payload?['status'] as Map?)?['applications'] != null,
    );
    final apps = (launched.payload!['status']! as Map)['applications']! as List;
    final transportId = (apps.single as Map)['transportId']! as String;
    connectTo(transportId);
    await next(
      'MEDIA_STATUS',
      () => send(transportId, nsMedia, {'type': 'GET_STATUS', 'requestId': 2}),
    );
    return transportId;
  }
}
