/// Cast v2's wire format, written by hand: the `CastMessage` protobuf
/// (Chromium's cast_channel.proto) and its 4-byte length prefix.
///
/// The app encodes with protoc's generated code; the fake reads and writes
/// the bytes itself, so a mistake on either side shows in the tests
/// rather than cancelling out.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Payload types (`CastMessage.PayloadType`).
const payloadString = 0;
const payloadBinary = 1;

/// The largest message a Cast device takes: 64 KiB.
const maxFrame = 65536;

/// One `CastMessage`.
final class WireMessage {
  const new({
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    this.protocolVersion = 0,
    this.payloadType = payloadString,
    this.payloadUtf8,
    this.payloadBinary,
  });

  /// A JSON payload, as every namespace the app uses sends.
  factory json({
    required String sourceId,
    required String destinationId,
    required String namespace,
    required Map<String, Object?> payload,
  }) => WireMessage(
    sourceId: sourceId,
    destinationId: destinationId,
    namespace: namespace,
    payloadUtf8: jsonEncode(payload),
  );

  /// Reads a `CastMessage`; unknown fields are skipped by their wire
  /// type. Throws [FormatException] for anything that isn't one.
  factory decode(Uint8List data) {
    var offset = 0;
    int varint() {
      var result = 0;
      var shift = 0;
      while (true) {
        if (offset >= data.length) {
          throw const FormatException('truncated varint');
        }
        final byte = data[offset++];
        result |= (byte & 0x7F) << shift;
        if (byte < 0x80) return result;
        shift += 7;
        if (shift > 63) throw const FormatException('varint too long');
      }
    }

    Uint8List lengthDelimited() {
      final length = varint();
      if (length < 0 || offset + length > data.length) {
        throw const FormatException('truncated field');
      }
      final value = Uint8List.sublistView(data, offset, offset + length);
      offset += length;
      return value;
    }

    var version = 0;
    String? source;
    String? destination;
    String? namespace;
    var type = payloadString;
    String? text;
    List<int>? binary;
    while (offset < data.length) {
      final tag = varint();
      final field = tag >> 3;
      switch ((field, tag & 7)) {
        case (1, 0):
          version = varint();
        case (2, 2):
          source = utf8.decode(lengthDelimited());
        case (3, 2):
          destination = utf8.decode(lengthDelimited());
        case (4, 2):
          namespace = utf8.decode(lengthDelimited());
        case (5, 0):
          type = varint();
        case (6, 2):
          text = utf8.decode(lengthDelimited());
        case (7, 2):
          binary = lengthDelimited();
        case (_, 0):
          varint();
        case (_, 1):
          offset += 8;
        case (_, 2):
          lengthDelimited();
        case (_, 5):
          offset += 4;
        default:
          throw FormatException('wire type ${tag & 7}');
      }
      if (offset > data.length) throw const FormatException('truncated');
    }
    if (source == null || destination == null || namespace == null) {
      throw const FormatException('a required field is missing');
    }
    return WireMessage(
      protocolVersion: version,
      sourceId: source,
      destinationId: destination,
      namespace: namespace,
      payloadType: type,
      payloadUtf8: text,
      payloadBinary: binary,
    );
  }

  final int protocolVersion;
  final String sourceId;
  final String destinationId;
  final String namespace;
  final int payloadType;
  final String? payloadUtf8;
  final List<int>? payloadBinary;

  Uint8List encode() {
    final out = BytesBuilder();
    void varint(int value) {
      var v = value;
      while (v >= 0x80) {
        out.addByte((v & 0x7F) | 0x80);
        v >>= 7;
      }
      out.addByte(v);
    }

    void bytes(int field, List<int> value) {
      varint(field << 3 | 2);
      varint(value.length);
      out.add(value);
    }

    varint(1 << 3);
    varint(protocolVersion);
    bytes(2, utf8.encode(sourceId));
    bytes(3, utf8.encode(destinationId));
    bytes(4, utf8.encode(namespace));
    varint(5 << 3);
    varint(payloadType);
    if (payloadUtf8 case final text?) bytes(6, utf8.encode(text));
    if (payloadBinary case final data?) bytes(7, data);
    return out.takeBytes();
  }

  /// The JSON payload, or null for a binary or unreadable one.
  Map<String, Object?>? get payload {
    if (payloadType != payloadString || payloadUtf8 == null) return null;
    try {
      final value = jsonDecode(payloadUtf8!);
      return value is Map<String, Object?> ? value : null;
    } on FormatException {
      return null;
    }
  }
}

/// [body] with its 4-byte big-endian length in front.
Uint8List frame(List<int> body) {
  final out = Uint8List(4 + body.length);
  ByteData.sublistView(out).setUint32(0, body.length);
  out.setRange(4, out.length, body);
  return out;
}

/// Splits a byte stream into message bodies. Null from [add] once a
/// length past [maxFrame] arrived: the stream can't be read any further.
final class FrameSplitter {
  final _pending = BytesBuilder(copy: false);
  var _broken = false;

  List<Uint8List>? add(List<int> bytes) {
    if (_broken) return null;
    _pending.add(bytes);
    final data = _pending.takeBytes();
    final frames = <Uint8List>[];
    var offset = 0;
    while (data.length - offset >= 4) {
      final length = ByteData.sublistView(data, offset).getUint32(0);
      if (length > maxFrame) {
        _broken = true;
        return null;
      }
      if (data.length - offset - 4 < length) break;
      frames.add(Uint8List.sublistView(data, offset + 4, offset + 4 + length));
      offset += 4 + length;
    }
    if (offset < data.length) _pending.add(Uint8List.sublistView(data, offset));
    return frames;
  }
}
