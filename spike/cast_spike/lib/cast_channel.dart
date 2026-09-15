import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'src/proto/cast_channel.pb.dart';

const nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
const nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
const nsReceiver = 'urn:x-cast:com.google.cast.receiver';
const nsMedia = 'urn:x-cast:com.google.cast.media';
const defaultMediaReceiver = 'CC1AD845';

typedef Json = Map<String, dynamic>;
typedef Log = void Function(String line);

class Incoming {
  Incoming(this.source, this.namespace, this.json);

  final String source;
  final String namespace;
  final Json json;

  String? get type => json['type'] as String?;
}

/// TLS socket to host:8009, 4-byte big-endian length + protobuf CastMessage
/// framing, JSON payloads, request ids, and the 5 s heartbeat.
class CastChannel {
  CastChannel._(this._socket, this._log) {
    _ping = Timer.periodic(const Duration(seconds: 5), (_) {
      if (DateTime.now().difference(_lastRx) > const Duration(seconds: 15)) {
        _fail('heartbeat lost (nothing received for 15 s)');
        return;
      }
      send('receiver-0', nsHeartbeat, {'type': 'PING'});
    });
    _socket.listen(
      _onData,
      onError: (Object e) => _fail('socket error: $e'),
      onDone: () => _fail('socket closed by the device'),
    );
  }

  static Future<CastChannel> connect(String host, int port, Log log) async {
    final socket = await SecureSocket.connect(
      host,
      port,
      // Cast devices present a self-signed certificate.
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 5),
    );
    log(
      'TLS connected to $host:$port (${socket.selectedProtocol ?? 'no ALPN'})',
    );
    return CastChannel._(socket, log);
  }

  final SecureSocket _socket;
  final Log _log;
  final _incoming = StreamController<Incoming>.broadcast();
  final _connected = <String>{};
  final _closed = Completer<String>();
  late final Timer _ping;
  var _rx = Uint8List(0);
  var _lastRx = DateTime.now();
  var _nextId = 1;

  Stream<Incoming> get messages => _incoming.stream;

  /// Completes with the reason when the channel dies.
  Future<String> get closed => _closed.future;

  bool get isOpen => !_closed.isCompleted;

  void send(String destination, String namespace, Json payload) {
    if (!isOpen) throw StateError('Cast channel is closed');
    final body =
        (CastMessage()
              ..protocolVersion = CastMessage_ProtocolVersion.CASTV2_1_0
              ..sourceId = 'sender-0'
              ..destinationId = destination
              ..namespace = namespace
              ..payloadType = CastMessage_PayloadType.STRING
              ..payloadUtf8 = jsonEncode(payload))
            .writeToBuffer();
    _socket.add((ByteData(4)..setUint32(0, body.length)).buffer.asUint8List());
    _socket.add(body);
    if (namespace != nsHeartbeat) {
      _log('→ ${_shortNs(namespace)} $destination ${jsonEncode(payload)}');
    }
  }

  /// Sends [payload] with a fresh requestId and returns the first message that
  /// echoes it (a status, or an error such as LOAD_FAILED).
  Future<Incoming> request(
    String destination,
    String namespace,
    Json payload, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    if (!isOpen) return Future.error(StateError('Cast channel is closed'));
    final id = _nextId++;
    final reply = messages
        .firstWhere((m) => m.json['requestId'] == id)
        .timeout(timeout);
    send(destination, namespace, {...payload, 'requestId': id});
    return reply;
  }

  void connectTo(String destination) {
    if (!_connected.add(destination)) return;
    send(destination, nsConnection, {
      'type': 'CONNECT',
      'origin': <String, dynamic>{},
      'userAgent': 'iptv-player cast_spike',
      'senderInfo': {
        'sdkType': 2,
        'version': '0.0.1',
        'platform': 4,
        'connectionType': 1,
      },
    });
  }

  void _onData(Uint8List data) {
    if (!isOpen) return;
    _lastRx = DateTime.now();
    final merged = Uint8List(_rx.length + data.length)
      ..setAll(0, _rx)
      ..setAll(_rx.length, data);
    var offset = 0;
    while (merged.length - offset >= 4) {
      final len = ByteData.sublistView(merged, offset).getUint32(0);
      if (merged.length - offset - 4 < len) break;
      final msg = CastMessage.fromBuffer(
        Uint8List.sublistView(merged, offset + 4, offset + 4 + len),
      );
      offset += 4 + len;
      _dispatch(msg);
    }
    _rx = Uint8List.fromList(Uint8List.sublistView(merged, offset));
  }

  void _dispatch(CastMessage msg) {
    if (msg.payloadType != CastMessage_PayloadType.STRING) {
      _log('← binary message on ${msg.namespace} (ignored)');
      return;
    }
    final Json json;
    try {
      json = jsonDecode(msg.payloadUtf8) as Json;
    } on FormatException {
      _log('← unparseable JSON on ${msg.namespace}');
      return;
    }
    if (msg.namespace == nsHeartbeat) {
      if (json['type'] == 'PING') {
        send(msg.sourceId, nsHeartbeat, {'type': 'PONG'});
      }
      return;
    }
    if (msg.namespace == nsConnection && json['type'] == 'CLOSE') {
      _connected.remove(msg.sourceId);
      _log('← CLOSE from ${msg.sourceId}');
    }
    _incoming.add(Incoming(msg.sourceId, msg.namespace, json));
  }

  void _fail(String reason) {
    if (_closed.isCompleted) return;
    _ping.cancel();
    _log('channel: $reason');
    _closed.complete(reason);
    unawaited(_incoming.close());
  }

  Future<void> close() async {
    if (!isOpen) return;
    for (final d in _connected.toList().reversed) {
      send(d, nsConnection, {'type': 'CLOSE'});
    }
    _connected.clear();
    await _socket.flush();
    _fail('closed by sender');
    await _socket.close();
  }
}

/// Receiver + media namespaces on top of a [CastChannel].
class CastSession {
  CastSession(this.channel, this._log);

  final CastChannel channel;
  final Log _log;
  String? transportId;
  String? sessionId;
  int? mediaSessionId;

  Future<void> launch(String appId) async {
    channel.connectTo('receiver-0');
    var status = await channel.request('receiver-0', nsReceiver, {
      'type': 'GET_STATUS',
    });
    var app = appFrom(status.json, appId);
    if (app == null) {
      _log('launching $appId (accept any prompt on the TV)');
      status = await channel.request('receiver-0', nsReceiver, {
        'type': 'LAUNCH',
        'appId': appId,
      }, timeout: const Duration(seconds: 90));
      if (status.type != 'RECEIVER_STATUS') {
        throw StateError('LAUNCH failed: ${jsonEncode(status.json)}');
      }
      app = appFrom(status.json, appId);
    } else {
      _log('$appId is already running; reusing it');
    }
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (app?['transportId'] == null) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('no transportId for $appId');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      status = await channel.request('receiver-0', nsReceiver, {
        'type': 'GET_STATUS',
      });
      app = appFrom(status.json, appId);
    }
    transportId = app!['transportId'] as String;
    sessionId = app['sessionId'] as String?;
    channel.connectTo(transportId!);
  }

  static Json? appFrom(Json receiverStatus, String appId) {
    final status = receiverStatus['status'];
    final apps = status is Json ? status['applications'] : null;
    if (apps is! List) return null;
    return apps.whereType<Json>().where((a) => a['appId'] == appId).firstOrNull;
  }

  static Json? mediaStatusFrom(Json json) {
    final list = json['status'];
    return list is List && list.isNotEmpty && list.first is Json
        ? list.first as Json
        : null;
  }

  Future<Incoming> media(
    Json payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final reply = await channel.request(transportId!, nsMedia, {
      if (payload['type'] != 'LOAD' && mediaSessionId != null)
        'mediaSessionId': mediaSessionId,
      ...payload,
    }, timeout: timeout);
    final id = mediaStatusFrom(reply.json)?['mediaSessionId'];
    if (id is int) mediaSessionId = id;
    return reply;
  }

  Future<void> stopApp() async {
    if (sessionId == null) return;
    try {
      await channel.request('receiver-0', nsReceiver, {
        'type': 'STOP',
        'sessionId': sessionId,
      }, timeout: const Duration(seconds: 5));
    } on Object catch (e) {
      _log('receiver STOP: $e');
    }
  }
}

String _shortNs(String ns) => ns.substring(ns.lastIndexOf('.') + 1);
