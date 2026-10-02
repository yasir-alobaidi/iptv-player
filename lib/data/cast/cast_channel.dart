import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/cast/cast_frames.dart';
import 'package:iptv_player/data/cast/cast_transport.dart';
import 'package:iptv_player/data/cast/proto/cast_channel.pb.dart';
import 'package:iptv_player/data/providers/xtream/tolerant_json.dart';

/// The namespaces the app speaks (docs/04). The device sends others too
/// (multizone among them); they pass through and are ignored.
abstract final class CastNamespace {
  static const connection = 'urn:x-cast:com.google.cast.tp.connection';
  static const heartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const receiver = 'urn:x-cast:com.google.cast.receiver';
  static const media = 'urn:x-cast:com.google.cast.media';
  static const multizone = 'urn:x-cast:com.google.cast.multizone';
}

/// The device itself, as a destination: its receiver and heartbeat.
const castReceiverId = 'receiver-0';

/// A message from the device: a JSON object on a namespace.
final class CastMessageIn {
  const new({
    required this.source,
    required this.namespace,
    required this.payload,
  });

  /// `receiver-0`, or the transport id of an app on the device.
  final String source;
  final String namespace;
  final Map<String, Object?> payload;

  String? get type => readString(payload['type']);

  /// The request this answers; null or 0 for a message the device sent on
  /// its own.
  int? get requestId => readInt(payload['requestId']);

  @override
  String toString() => '${_short(namespace)} ${type ?? '?'} from $source';
}

/// One Cast v2 connection (docs/04): length-prefixed protobuf messages
/// with JSON payloads, request ids answered or timed out, and the
/// heartbeat — a PING every [heartbeat], the device's PINGs answered, and
/// the channel lost after [missedPings] intervals with nothing heard.
///
/// Reading is tolerant: a message that isn't protobuf, carries binary or
/// unreadable JSON, or arrives on an unknown namespace is skipped. A
/// length past 64 KiB loses the framing, and closes the channel.
final class CastChannel {
  new(
    this._transport, {
    this.log,
    this.heartbeat = const Duration(seconds: 5),
    this.missedPings = 3,
  }) {
    _input = _transport.input.listen(
      _onData,
      onError: (Object error) => _shutDown('the connection broke: $error'),
      onDone: () => _shutDown('the device closed the connection'),
    );
    _pinger = Timer.periodic(heartbeat, (_) => _ping());
  }

  final CastTransport _transport;
  final AppLog? log;
  final Duration heartbeat;
  final int missedPings;

  static const senderId = 'sender-0';
  static const _tag = 'cast.channel';

  final _reader = CastFrameReader();
  final _messages = StreamController<CastMessageIn>.broadcast();
  final _closed = Completer<String>();
  final _pending = <int, Completer<CastMessageIn?>>{};
  final _connected = <String>[];
  late final StreamSubscription<Uint8List> _input;
  late final Timer _pinger;
  var _nextId = 1;
  var _heard = false;
  var _missed = 0;

  /// Every message the device sends, replies included, in order.
  Stream<CastMessageIn> get messages => _messages.stream;

  /// Completes with the reason once the channel is closed, whichever side
  /// closed it.
  Future<String> get closed => _closed.future;

  bool get isOpen => !_closed.isCompleted;

  String get localAddress => _transport.localAddress;

  /// Opens a virtual connection to [destination] (`receiver-0`, or an
  /// app's transport id), which the device needs before it takes that
  /// destination's messages. Once per destination.
  void connectTo(String destination) {
    if (_connected.contains(destination)) return;
    _connected.add(destination);
    send(destination, CastNamespace.connection, const {
      'type': 'CONNECT',
      'origin': <String, Object?>{},
      'userAgent': 'IPTV Player',
      'senderInfo': {
        'sdkType': 2,
        'version': '1.0',
        'platform': 4,
        'connectionType': 1,
      },
    });
  }

  /// Whether a virtual connection to [destination] is open.
  bool isConnectedTo(String destination) => _connected.contains(destination);

  /// Sends [payload]; false when the channel is closed or the message is
  /// too large to send.
  bool send(
    String destination,
    String namespace,
    Map<String, Object?> payload,
  ) {
    if (!isOpen) return false;
    final body =
        (CastMessage()
              ..protocolVersion = CastMessage_ProtocolVersion.CASTV2_1_0
              ..sourceId = senderId
              ..destinationId = destination
              ..namespace = namespace
              ..payloadType = CastMessage_PayloadType.STRING
              ..payloadUtf8 = jsonEncode(payload))
            .writeToBuffer();
    if (body.length > castMaxFrame) {
      log?.warning(
        _tag,
        'not sending ${_describe(namespace, payload)}: too large',
      );
      return false;
    }
    _transport.add(castFrame(body));
    if (namespace != CastNamespace.heartbeat) {
      // The type only: a LOAD's URL can carry a provider's credentials.
      log?.debug(_tag, '→ ${_describe(namespace, payload)} to $destination');
    }
    return true;
  }

  /// Sends [payload] with a fresh request id and returns the first message
  /// that answers it, or null when none came within [timeout] or the
  /// channel closed first.
  Future<CastMessageIn?> request(
    String destination,
    String namespace,
    Map<String, Object?> payload, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!isOpen) return null;
    final id = _nextId++;
    final reply = Completer<CastMessageIn?>();
    _pending[id] = reply;
    final timer = Timer(timeout, () {
      if (_pending.remove(id) != null) reply.complete(null);
    });
    if (!send(destination, namespace, {...payload, 'requestId': id})) {
      _pending.remove(id);
      timer.cancel();
      return null;
    }
    final answer = await reply.future;
    timer.cancel();
    return answer;
  }

  /// Closes every virtual connection, then the connection.
  Future<void> close() async {
    if (!isOpen) return;
    for (final destination in _connected.reversed.toList()) {
      send(destination, CastNamespace.connection, const {'type': 'CLOSE'});
    }
    _connected.clear();
    _shutDown('closed by this app', destroy: false);
    await _transport.close();
  }

  /// Closes at once, without telling the device.
  void destroy(String reason) => _shutDown(reason);

  void _ping() {
    if (!isOpen) return;
    _missed = _heard ? 0 : _missed + 1;
    _heard = false;
    if (_missed >= missedPings) {
      _shutDown('the device stopped answering (heartbeat)');
      return;
    }
    send(castReceiverId, CastNamespace.heartbeat, const {'type': 'PING'});
  }

  void _onData(Uint8List data) {
    if (!isOpen) return;
    _heard = true;
    for (final frame in _reader.add(data)) {
      _onFrame(frame);
      if (!isOpen) return;
    }
    if (_reader.failed) _shutDown('the device sent a message over 64 KiB');
  }

  void _onFrame(Uint8List frame) {
    final CastMessage message;
    try {
      message = CastMessage.fromBuffer(frame);
    } on Object catch (error) {
      log?.warning(_tag, 'skipped a message that is not a CastMessage: $error');
      return;
    }
    if (message.payloadType != CastMessage_PayloadType.STRING ||
        !message.hasPayloadUtf8()) {
      log?.debug(_tag, '← binary message on ${message.namespace} (skipped)');
      return;
    }
    final Object? json;
    try {
      json = jsonDecode(message.payloadUtf8);
    } on FormatException {
      log?.warning(_tag, '← unreadable JSON on ${message.namespace} (skipped)');
      return;
    }
    if (json is! Map<String, Object?>) {
      log?.warning(
        _tag,
        '← JSON that is not an object on ${message.namespace}',
      );
      return;
    }
    final incoming = CastMessageIn(
      source: message.sourceId,
      namespace: message.namespace,
      payload: json,
    );
    if (incoming.namespace == CastNamespace.heartbeat) {
      if (incoming.type == 'PING') {
        send(incoming.source, CastNamespace.heartbeat, const {'type': 'PONG'});
      }
      return;
    }
    if (incoming.namespace == CastNamespace.connection &&
        incoming.type == 'CLOSE') {
      _connected.remove(incoming.source);
    }
    log?.debug(_tag, '← $incoming');
    _messages.add(incoming);
    final id = incoming.requestId;
    if (id != null && id != 0) _pending.remove(id)?.complete(incoming);
  }

  void _shutDown(String reason, {bool destroy = true}) {
    if (!isOpen) return;
    log?.info(_tag, 'closed: $reason');
    _closed.complete(reason);
    _pinger.cancel();
    unawaited(_input.cancel());
    for (final reply in _pending.values) {
      reply.complete(null);
    }
    _pending.clear();
    unawaited(_messages.close());
    if (destroy) _transport.destroy();
  }

  static String _describe(String namespace, Map<String, Object?> payload) =>
      '${_short(namespace)} ${payload['type'] ?? '?'}';
}

String _short(String namespace) =>
    namespace.substring(namespace.lastIndexOf('.') + 1);
