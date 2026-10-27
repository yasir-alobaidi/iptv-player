import 'dart:convert';
import 'dart:typed_data';

/// AirPlay's messages (ADR-067): HTTP/1.1 and RTSP/1.0 with the same
/// shape — a start line, headers, an optional body sized by
/// Content-Length. The sender asks on the control connection and the
/// receiver answers; on the event channel the receiver asks and we answer.
///
/// Header names are kept as sent, and looked up without regard to case.
final class AirPlayMessage {
  const new({
    required this.startLine,
    required this.headers,
    required this.body,
  });

  /// "POST /command HTTP/1.1", or "RTSP/1.0 200 OK".
  final String startLine;
  final Map<String, String> headers;
  final Uint8List body;

  /// The header [name], whatever its case; null when it wasn't sent.
  String? header(String name) {
    final wanted = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == wanted) return entry.value;
    }
    return null;
  }

  /// A response's status code; null for a request or a line that isn't
  /// one ("RTSP/1.0 200 OK" → 200).
  int? get status {
    final parts = startLine.split(' ');
    if (parts.length < 2 || !parts[0].contains('/')) return null;
    return int.tryParse(parts[1]);
  }

  /// A request's method ("POST"); null for a response.
  String? get method {
    final parts = startLine.split(' ');
    if (parts.length < 3 || parts[0].contains('/')) return null;
    return parts[0];
  }

  /// A request's protocol ("HTTP/1.1", "RTSP/1.0"); null for a response.
  String? get requestProtocol {
    final parts = startLine.split(' ');
    if (parts.length < 3 || parts[0].contains('/')) return null;
    return parts.last;
  }

  @override
  String toString() => 'AirPlayMessage($startLine, ${body.length} bytes)';
}

/// The bytes of a request, as pyatv sends them: the start line, then
/// User-Agent, Content-Type and Content-Length when there is a body, then
/// [headers] in order, a blank line and the body.
Uint8List formatAirPlayRequest({
  required String method,
  required String uri,
  String protocol = 'RTSP/1.0',
  Map<String, Object> headers = const {},
  String? contentType,
  List<int>? body,
  String userAgent = airPlayUserAgent,
}) {
  final out = StringBuffer('$method $uri $protocol');
  if (!headers.keys.any((name) => name.toLowerCase() == 'user-agent')) {
    out.write('\r\nUser-Agent: $userAgent');
  }
  if (contentType != null) out.write('\r\nContent-Type: $contentType');
  if (body != null && body.isNotEmpty) {
    out.write('\r\nContent-Length: ${body.length}');
  }
  for (final entry in headers.entries) {
    out.write('\r\n${entry.key}: ${entry.value}');
  }
  out.write('\r\n\r\n');
  final head = utf8.encode(out.toString());
  if (body == null || body.isEmpty) return head;
  return Uint8List(head.length + body.length)
    ..setRange(0, head.length, head)
    ..setRange(head.length, head.length + body.length, body);
}

/// The bytes of a response to a request on the event channel: [status]
/// with [headers] and no body.
Uint8List formatAirPlayResponse({
  required String protocol,
  required int status,
  required String reason,
  Map<String, String> headers = const {},
}) {
  final out = StringBuffer('$protocol $status $reason');
  for (final entry in headers.entries) {
    out.write('\r\n${entry.key}: ${entry.value}');
  }
  out.write('\r\n\r\n');
  return utf8.encode(out.toString());
}

/// The User-Agent AirPlay's senders give; receivers check its version.
const airPlayUserAgent = 'AirPlay/550.10';

/// Splits a byte stream into [AirPlayMessage]s, however the bytes arrive:
/// a message across several reads, several in one. Tolerant (hard rule 1):
/// a head it can't read is dropped with the rest of what came, never
/// thrown.
final class AirPlayMessageReader {
  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);

  /// The heads longer than this are not AirPlay's: dropped.
  static const int maxHead = 64 * 1024;

  /// Takes [bytes] and returns every message they complete, in order.
  List<AirPlayMessage> add(List<int> bytes) {
    _buffer
      ..add(_pending)
      ..add(bytes);
    var data = _buffer.takeBytes();
    final messages = <AirPlayMessage>[];
    while (true) {
      final end = _headEnd(data);
      if (end < 0) {
        if (data.length > maxHead) data = Uint8List(0);
        break;
      }
      final head = latin1.decode(data.sublist(0, end), allowInvalid: true);
      final lines = head.split('\r\n');
      final headers = <String, String>{};
      for (final line in lines.skip(1)) {
        final colon = line.indexOf(':');
        if (colon <= 0) continue;
        headers[line.substring(0, colon).trim()] = line
            .substring(colon + 1)
            .trim();
      }
      final length =
          int.tryParse(
            headers.entries
                    .where((e) => e.key.toLowerCase() == 'content-length')
                    .map((e) => e.value)
                    .firstOrNull ??
                '0',
          ) ??
          0;
      final bodyStart = end + 4;
      if (length < 0) {
        data = Uint8List(0);
        break;
      }
      if (data.length < bodyStart + length) break;
      messages.add(
        AirPlayMessage(
          startLine: lines.first,
          headers: headers,
          body: Uint8List.fromList(data.sublist(bodyStart, bodyStart + length)),
        ),
      );
      data = Uint8List.sublistView(data, bodyStart + length);
    }
    _pending = Uint8List.fromList(data);
    return messages;
  }

  static int _headEnd(Uint8List data) {
    for (var i = 0; i + 3 < data.length; i++) {
      if (data[i] == 13 &&
          data[i + 1] == 10 &&
          data[i + 2] == 13 &&
          data[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }
}
