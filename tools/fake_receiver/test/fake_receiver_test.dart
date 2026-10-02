import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:test/test.dart';

/// A bare Cast sender: TLS, frames and JSON, nothing else.
final class _Client {
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

  static Future<_Client> connect(FakeReceiver receiver) async => _Client._(
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
}

Map<String, Object?> _status(WireMessage m) =>
    m.payload!['status']! as Map<String, Object?>;

Map<String, Object?> _media(WireMessage m) =>
    (m.payload!['status']! as List).first as Map<String, Object?>;

void main() {
  late FakeReceiver receiver;
  late _Client client;

  setUp(() async {
    receiver = await FakeReceiver.start(
      launchDelay: const Duration(milliseconds: 50),
      loadDelay: const Duration(milliseconds: 50),
      pingEvery: null,
    );
    client = await _Client.connect(receiver);
  });

  tearDown(() async {
    await client.close();
    await receiver.close();
  });

  /// CONNECT, LAUNCH, CONNECT to the app: its transport id.
  Future<String> launch() async {
    client.connectTo(receiverId);
    final launched = await client.next(
      'RECEIVER_STATUS',
      () => client.send(receiverId, nsReceiver, {
        'type': 'LAUNCH',
        'appId': defaultMediaReceiver,
        'requestId': 1,
      }),
    );
    final apps = _status(launched)['applications']! as List;
    final transportId =
        (apps.single as Map<String, Object?>)['transportId']! as String;
    client.connectTo(transportId);
    // A round trip, so the fake has taken the CONNECT before the test
    // goes on.
    await client.next(
      'MEDIA_STATUS',
      () => client.send(transportId, nsMedia, {
        'type': 'GET_STATUS',
        'requestId': 2,
      }),
    );
    return transportId;
  }

  bool lists(WireMessage status, String? app) {
    final apps = _status(status)['applications'] as List?;
    return app == null
        ? apps == null
        : (apps?.single as Map?)?['displayName'] == app;
  }

  test('answers nothing before CONNECT', () async {
    final answers = client.collect('RECEIVER_STATUS', 200.ms);
    client.send(receiverId, nsReceiver, {'type': 'GET_STATUS', 'requestId': 1});
    expect(await answers, isEmpty);
  });

  test('a device running nothing lists no applications', () async {
    client.connectTo(receiverId);
    final status = await client.next(
      'RECEIVER_STATUS',
      () => client.send(receiverId, nsReceiver, {
        'type': 'GET_STATUS',
        'requestId': 4,
      }),
    );
    expect(status.payload!['requestId'], 4);
    expect(_status(status).containsKey('applications'), isFalse);
    expect(_status(status)['volume'], containsPair('controlType', 'fixed'));
  });

  test('names itself in MULTIZONE_STATUS', () async {
    client.connectTo(receiverId);
    final zone = await client.next(
      'MULTIZONE_STATUS',
      () => client.send(receiverId, nsMultizone, {
        'type': 'GET_STATUS',
        'requestId': 2,
      }),
    );
    final device =
        (_status(zone)['devices']! as List).single as Map<String, Object?>;
    expect(device['name'], 'Fake TV');
    expect(device['deviceId'], 'fa4e7ec0-0000-0000-0000-000000000001');
  });

  test('LAUNCH: LAUNCH_STATUS first, then the app once it runs', () async {
    client.connectTo(receiverId);
    final launchStatus = client.next('LAUNCH_STATUS');
    final status = client.next('RECEIVER_STATUS');
    client.send(receiverId, nsReceiver, {
      'type': 'LAUNCH',
      'appId': defaultMediaReceiver,
      'requestId': 3,
    });
    expect((await launchStatus).payload!['launchRequestId'], 3);
    final apps = _status(await status)['applications']! as List;
    expect((apps.single as Map)['appId'], defaultMediaReceiver);
    expect(receiver.app?.appId, defaultMediaReceiver);
  });

  test('a refused LAUNCH is a LAUNCH_ERROR', () async {
    receiver.refuseLaunch = true;
    client.connectTo(receiverId);
    final error = await client.next(
      'LAUNCH_ERROR',
      () => client.send(receiverId, nsReceiver, {
        'type': 'LAUNCH',
        'appId': defaultMediaReceiver,
        'requestId': 3,
      }),
    );
    expect(error.payload!['requestId'], 3);
    expect(receiver.app, isNull);
  });

  test('LOAD: LOADING at once, then BUFFERING and PLAYING', () async {
    final transport = await launch();
    final updates = client.collect('MEDIA_STATUS', 300.ms);
    client.send(transport, nsMedia, {
      'type': 'LOAD',
      'requestId': 5,
      'media': {
        'contentId': 'http://127.0.0.1/a.mp4',
        'contentType': 'video/mp4',
        'streamType': 'BUFFERED',
      },
      'autoplay': true,
      'currentTime': 30,
    });
    final statuses = await updates;
    final first = _media(statuses.first);
    expect(statuses.first.payload!['requestId'], 5);
    expect(first['playerState'], 'IDLE');
    expect(first['extendedStatus'], containsPair('playerState', 'LOADING'));
    expect(first['media'], containsPair('contentId', 'http://127.0.0.1/a.mp4'));
    expect(
      [for (final s in statuses.skip(1)) _media(s)['playerState']],
      ['BUFFERING', 'PLAYING'],
    );
    // Updates leave `media` out, as the TV does.
    expect(_media(statuses.last).containsKey('media'), isFalse);
    expect(receiver.position, greaterThanOrEqualTo(30));
  });

  test('PAUSE, SEEK and STOP; then the session is gone', () async {
    final transport = await launch();
    final playing = client.collect('MEDIA_STATUS', 200.ms);
    client.send(transport, nsMedia, {
      'type': 'LOAD',
      'requestId': 5,
      'media': {'contentId': 'u', 'contentType': 'video/mp4'},
    });
    final id = _media((await playing).first)['mediaSessionId'];

    Future<Map<String, Object?>> command(
      String type, [
      Map<String, Object?> extra = const {},
    ]) async => _media(
      await client.next(
        'MEDIA_STATUS',
        () => client.send(transport, nsMedia, {
          'type': type,
          'mediaSessionId': id,
          'requestId': 9,
          ...extra,
        }),
      ),
    );

    expect((await command('PAUSE'))['playerState'], 'PAUSED');
    final seeked = await command('SEEK', {'currentTime': 120});
    expect(seeked['playerState'], 'PAUSED');
    expect(seeked['currentTime'], 120);
    final stopped = await command('STOP');
    expect(stopped['playerState'], 'IDLE');
    expect(stopped['idleReason'], 'CANCELLED');
    final invalid = await client.next(
      'INVALID_REQUEST',
      () => client.send(transport, nsMedia, {
        'type': 'PLAY',
        'mediaSessionId': id,
        'requestId': 10,
      }),
    );
    expect(invalid.payload!['reason'], 'INVALID_MEDIA_SESSION_ID');
  });

  test(
    'a refused LOAD: MEDIA_STATUS, then LOAD_FAILED and IDLE/ERROR',
    () async {
      receiver.refuseLoads((media) => media['contentId'] == 'bad');
      final transport = await launch();
      final failed = client.next('LOAD_FAILED');
      final statuses = client.collect('MEDIA_STATUS', 300.ms);
      client.send(transport, nsMedia, {
        'type': 'LOAD',
        'requestId': 6,
        'media': {'contentId': 'bad', 'contentType': 'video/mp4'},
      });
      expect((await failed).payload!['requestId'], 6);
      final last = _media((await statuses).last);
      expect(last['playerState'], 'IDLE');
      expect(last['idleReason'], 'ERROR');
      expect(receiver.loaded, isNull);
    },
  );

  test('the remote going Back closes the receiver', () async {
    final transport = await launch();
    final close = client.inbox.firstWhere(
      (m) => m.namespace == nsConnection && m.payload?['type'] == 'CLOSE',
    );
    final status = client.next(
      'RECEIVER_STATUS',
      receiver.remoteBack,
      (m) => lists(m, null),
    );
    expect((await close).sourceId, transport);
    await status;
  });

  test('another app takes the device', () async {
    await launch();
    await client.next(
      'RECEIVER_STATUS',
      receiver.startOtherApp,
      (m) => lists(m, 'YouTube'),
    );
    expect(receiver.app?.displayName, 'YouTube');
  });

  test('answers PINGs, and sends its own', () async {
    await client.close();
    await receiver.close();
    receiver = await FakeReceiver.start(pingEvery: 50.ms);
    client = await _Client.connect(receiver)
      ..connectTo(receiverId);
    final pong = client.next(
      'PONG',
      () => client.send(receiverId, nsHeartbeat, {'type': 'PING'}),
    );
    await pong;
    await client.next('PING');
    receiver.heartbeat = false;
    // A PING sent just before may still be on its way.
    await Future<void>.delayed(100.ms);
    expect(await client.collect('PING', 200.ms), isEmpty);
  });

  test('a dropped connection keeps the receiver running', () async {
    await launch();
    final app = receiver.app;
    receiver.dropConnections();
    await client.inbox.drain<void>();
    expect(receiver.app, same(app));
    expect(receiver.connections, 0);
  });
}

extension on int {
  Duration get ms => Duration(milliseconds: this);
}
