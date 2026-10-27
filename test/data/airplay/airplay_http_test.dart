import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/airplay_http.dart';

void main() {
  group('formatAirPlayRequest', () {
    test("the start line, User-Agent, the body's type and length, then the "
        'headers in order', () {
      final bytes = formatAirPlayRequest(
        method: 'SETUP',
        uri: 'rtsp://192.168.1.254/123',
        headers: {'CSeq': 0, 'DACP-ID': 'ABC'},
        contentType: 'application/x-apple-binary-plist',
        body: [1, 2, 3],
      );
      final text = latin1.decode(bytes);
      expect(
        text,
        'SETUP rtsp://192.168.1.254/123 RTSP/1.0\r\n'
        'User-Agent: AirPlay/550.10\r\n'
        'Content-Type: application/x-apple-binary-plist\r\n'
        'Content-Length: 3\r\n'
        'CSeq: 0\r\n'
        'DACP-ID: ABC\r\n'
        '\r\n'
        '\x01\x02\x03',
      );
    });

    test('a User-Agent of its own replaces the default, and no body sends '
        'no length', () {
      final text = latin1.decode(
        formatAirPlayRequest(
          method: 'GET',
          uri: '/info',
          protocol: 'HTTP/1.1',
          headers: {'User-Agent': 'AirPlay/870.14.1'},
        ),
      );
      expect(
        text,
        'GET /info HTTP/1.1\r\nUser-Agent: AirPlay/870.14.1\r\n\r\n',
      );
    });
  });

  group('AirPlayMessageReader', () {
    test('a response split across reads, and two in one read', () {
      final reader = AirPlayMessageReader();
      const first =
          'RTSP/1.0 200 OK\r\nContent-Length: 5\r\nCSeq: 1\r\n\r\nhello';
      const second =
          'RTSP/1.0 470 Connection Authorization Required\r\n'
          'cseq: 2\r\n\r\n';
      final bytes = latin1.encode(first + second);

      expect(reader.add(bytes.sublist(0, 10)), isEmpty);
      expect(reader.add(bytes.sublist(10, 40)), isEmpty);
      final messages = reader.add(bytes.sublist(40));

      expect(messages, hasLength(2));
      expect(messages[0].status, 200);
      expect(utf8.decode(messages[0].body), 'hello');
      expect(messages[0].header('cseq'), '1');
      expect(messages[1].status, 470);
      expect(messages[1].header('CSeq'), '2');
      expect(messages[1].body, isEmpty);
    });

    test('a request from the receiver: its method and protocol', () {
      final reader = AirPlayMessageReader();
      final messages = reader.add(
        latin1.encode('POST /command RTSP/1.0\r\nContent-Length: 2\r\n\r\nab'),
      );
      expect(messages.single.method, 'POST');
      expect(messages.single.requestProtocol, 'RTSP/1.0');
      expect(messages.single.status, isNull);
    });

    test("a body that hasn't all come waits for the rest", () {
      final reader = AirPlayMessageReader();
      expect(
        reader.add(
          latin1.encode('HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nab'),
        ),
        isEmpty,
      );
      expect(utf8.decode(reader.add(latin1.encode('cd')).single.body), 'abcd');
    });

    test('nonsense is dropped, never thrown', () {
      final reader = AirPlayMessageReader();
      expect(
        reader.add(List.filled(AirPlayMessageReader.maxHead + 10, 65)),
        isEmpty,
      );
      expect(
        reader.add(
          latin1.encode('RTSP/1.0 200 OK\r\nContent-Length: -3\r\n\r\n'),
        ),
        isEmpty,
      );
      // And the reader still reads what comes after.
      expect(
        reader.add(latin1.encode('RTSP/1.0 200 OK\r\n\r\n')).single.status,
        200,
      );
    });
  });
}
