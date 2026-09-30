import 'dart:convert';
import 'dart:typed_data';

/// DNS record types the Cast address check reads.
abstract final class DnsType {
  static const a = 1;
  static const ptr = 12;
  static const txt = 16;
  static const aaaa = 28;
  static const srv = 33;
}

/// One resource record of a DNS answer, with the data the check reads.
final class DnsRecord {
  const new({
    required this.name,
    required this.type,
    this.target,
    this.strings = const [],
    this.address,
    this.port,
  });

  /// The owner name as sent, without the trailing dot. Compare names
  /// without case: DNS does.
  final String name;
  final int type;

  /// PTR: the name pointed to; SRV: the host name.
  final String? target;

  /// TXT: the character strings, as UTF-8 (malformed bytes replaced).
  final List<String> strings;

  /// A / AAAA: the address, as text.
  final String? address;

  /// SRV: the port.
  final int? port;
}

/// A DNS query for [name] of [type], with [id], as a legacy unicast
/// DNS-SD query sends it (RFC 6762 §6.7): no flags, one question, class
/// IN.
Uint8List encodeDnsQuery(int id, String name, int type) {
  final bytes = BytesBuilder()
    ..add([id >> 8 & 0xFF, id & 0xFF, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
  for (final label in name.split('.')) {
    if (label.isEmpty) continue;
    final encoded = utf8.encode(label);
    bytes
      ..addByte(encoded.length.clamp(0, 63))
      ..add(encoded.take(63).toList());
  }
  bytes.add([0, type >> 8 & 0xFF, type & 0xFF, 0, 1]);
  return bytes.takeBytes();
}

/// The records of a DNS response: answers, authority and additional
/// sections together. Never throws: a message cut short or malformed
/// gives the records read before the fault; one that isn't a response
/// to [id] (when given) gives none.
List<DnsRecord> decodeDnsResponse(Uint8List message, {int? id}) {
  if (message.length < 12) return const [];
  final data = ByteData.sublistView(message);
  if (id != null && data.getUint16(0) != id) return const [];
  if (message[2] & 0x80 == 0) return const []; // a query, not a response
  final questions = data.getUint16(4);
  final records = data.getUint16(6) + data.getUint16(8) + data.getUint16(10);
  final reader = _Reader(message, data);
  final result = <DnsRecord>[];
  try {
    for (var i = 0; i < questions; i++) {
      reader
        ..name()
        ..skip(4);
    }
    for (var i = 0; i < records; i++) {
      final name = reader.name();
      final type = reader.uint16();
      reader.skip(6); // class, TTL
      final length = reader.uint16();
      final end = reader.offset + length;
      if (end > message.length) break;
      final record = switch (type) {
        DnsType.ptr => DnsRecord(
          name: name,
          type: type,
          target: _Reader(message, data, reader.offset).name(),
        ),
        DnsType.srv when length >= 7 => DnsRecord(
          name: name,
          type: type,
          port: data.getUint16(reader.offset + 4),
          target: _Reader(message, data, reader.offset + 6).name(),
        ),
        DnsType.txt => DnsRecord(
          name: name,
          type: type,
          strings: _txtStrings(message, reader.offset, end),
        ),
        DnsType.a when length == 4 => DnsRecord(
          name: name,
          type: type,
          address: message.sublist(reader.offset, end).join('.'),
        ),
        DnsType.aaaa when length == 16 => DnsRecord(
          name: name,
          type: type,
          address: _ipv6(data, reader.offset),
        ),
        _ => null,
      };
      if (record != null) result.add(record);
      reader.offset = end;
    }
  } on _Malformed {
    // Keep what was read.
  }
  return result;
}

List<String> _txtStrings(Uint8List message, int start, int end) {
  final strings = <String>[];
  var at = start;
  while (at < end) {
    final length = message[at];
    final stop = at + 1 + length;
    if (stop > end) break;
    if (length > 0) {
      strings.add(
        utf8.decode(message.sublist(at + 1, stop), allowMalformed: true),
      );
    }
    at = stop;
  }
  return strings;
}

String _ipv6(ByteData data, int at) =>
    [for (var i = 0; i < 8; i++) data.getUint16(at + i * 2).toRadixString(16)]
        .join(':');

final class _Malformed implements Exception {
  const new();
}

final class _Reader {
  new(this._message, this._data, [this.offset = 12]);

  final Uint8List _message;
  final ByteData _data;
  int offset;

  void skip(int count) {
    if (offset + count > _message.length) throw const _Malformed();
    offset += count;
  }

  int uint16() {
    if (offset + 2 > _message.length) throw const _Malformed();
    final value = _data.getUint16(offset);
    offset += 2;
    return value;
  }

  /// A name at [offset], following compression pointers (at most 32, so
  /// a loop ends); [offset] moves past its bytes in place.
  String name() {
    final labels = <String>[];
    var at = offset;
    var jumped = false;
    var jumps = 0;
    while (true) {
      if (at >= _message.length) throw const _Malformed();
      final length = _message[at];
      if (length == 0) {
        if (!jumped) offset = at + 1;
        break;
      }
      if (length & 0xC0 == 0xC0) {
        if (at + 1 >= _message.length || ++jumps > 32) {
          throw const _Malformed();
        }
        if (!jumped) offset = at + 2;
        jumped = true;
        at = (length & 0x3F) << 8 | _message[at + 1];
        continue;
      }
      if (length & 0xC0 != 0) throw const _Malformed();
      final stop = at + 1 + length;
      if (stop > _message.length) throw const _Malformed();
      labels.add(
        utf8.decode(_message.sublist(at + 1, stop), allowMalformed: true),
      );
      at = stop;
    }
    return labels.join('.');
  }
}
