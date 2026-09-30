import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/cast/dns_message.dart';

/// Living Room TV's answer to a direct `_googlecast._tcp.local` PTR
/// query (query id 0x1234), recorded on this network with its ids and
/// serials swapped for made-up ones of the same length, so every
/// compression pointer is where the TV put it.
Uint8List tvAnswer() =>
    File('test_fixtures/cast/tv_unicast_answer.bin').readAsBytesSync();

void main() {
  test('encodes a PTR query as a legacy unicast DNS-SD query', () {
    final query = encodeDnsQuery(0x1234, '_googlecast._tcp.local', DnsType.ptr);
    expect(query, [
      0x12, 0x34, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, //
      11, ...'_googlecast'.codeUnits,
      4, ...'_tcp'.codeUnits,
      5, ...'local'.codeUnits,
      0, 0, 12, 0, 1,
    ]);
  });

  group('the recorded answer', () {
    late List<DnsRecord> records;
    setUp(() => records = decodeDnsResponse(tvAnswer(), id: 0x1234));

    test('has the PTR, TXT, SRV and A the TV sends', () {
      expect(
        [for (final r in records) r.type],
        [DnsType.ptr, DnsType.txt, DnsType.srv, DnsType.a],
      );
    });

    test('PTR names the instance, through a compression pointer', () {
      expect(records[0].name, '_googlecast._tcp.local');
      expect(
        records[0].target,
        'Chromecast-4f1c9e27a0b35d68c2e71f094ab6d3e5._googlecast._tcp.local',
      );
    });

    test('TXT keeps each string whole', () {
      expect(records[1].strings, contains('fn=Living Room TV'));
      expect(records[1].strings, contains('md=Chromecast'));
      expect(records[1].strings, contains('ca=465413'));
      expect(records[1].strings, hasLength(14));
    });

    test('SRV gives the port and the host name', () {
      expect(records[2].port, 8009);
      expect(records[2].target, '4f1c9e27-a0b3-5d68-c2e7-1f094ab6d3e5.local');
    });

    test('A gives the address', () {
      expect(records[3].address, '192.168.1.60');
    });
  });

  test('another query id: nothing', () {
    expect(decodeDnsResponse(tvAnswer(), id: 0x4321), isEmpty);
  });

  test('a query rather than a response: nothing', () {
    final query = encodeDnsQuery(7, '_googlecast._tcp.local', DnsType.ptr);
    expect(decodeDnsResponse(query, id: 7), isEmpty);
  });

  test('AAAA reads as an IPv6 address', () {
    final message = Uint8List.fromList([
      0, 1, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, //
      2, ...'tv'.codeUnits, 0,
      0, 28, 0, 1, 0, 0, 0, 120, 0, 16,
      0x26, 0x00, 0x40, 0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x89, 0xc3,
    ]);
    final records = decodeDnsResponse(message);
    expect(records.single.address, '2600:4040:0:0:0:0:0:89c3');
  });

  group('never throws', () {
    test('on the recorded answer cut short at every length', () {
      final whole = tvAnswer();
      for (var length = 0; length < whole.length; length++) {
        final records = decodeDnsResponse(
          Uint8List.sublistView(whole, 0, length),
        );
        // Whatever it reads is from the start of the message.
        expect(records.length, lessThanOrEqualTo(4));
      }
    });

    test('on a compression pointer that points at itself', () {
      final message = Uint8List.fromList([
        0, 1, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, //
        0xC0, 12, // the name at 12 is a pointer to 12
        0, 12, 0, 1, 0, 0, 0, 120, 0, 2, 0xC0, 12,
      ]);
      expect(decodeDnsResponse(message), isEmpty);
    });

    test('on a pointer past the end, and a label past the end', () {
      final pointer = Uint8List.fromList([
        0,
        1,
        0x84,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0xC0,
        0xFF,
      ]);
      final label = Uint8List.fromList([
        0,
        1,
        0x84,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        40,
        65,
        65,
      ]);
      expect(decodeDnsResponse(pointer), isEmpty);
      expect(decodeDnsResponse(label), isEmpty);
    });

    test('on a record whose data runs past the end', () {
      final message = Uint8List.fromList([
        0, 1, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, //
        0, 0, 16, 0, 1, 0, 0, 0, 120, 0xFF, 0xFF, 3, 65, 65, 65,
      ]);
      expect(decodeDnsResponse(message), isEmpty);
    });

    test('on a TXT string longer than its record, and bad UTF-8', () {
      final message = Uint8List.fromList([
        0, 1, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, //
        0, 0, 16, 0, 1, 0, 0, 0, 120, 0, 8,
        3, 0xFF, 0xFE, 0x41, 9, 65, 65, 65, 65,
      ]);
      final txt = decodeDnsResponse(message).single;
      expect(txt.strings, ['\uFFFD\uFFFDA']);
    });

    test('on 20,000 random messages, some with a valid header', () {
      final random = Random(7);
      for (var i = 0; i < 20000; i++) {
        final bytes = Uint8List.fromList([
          for (var b = 0; b < random.nextInt(120); b++) random.nextInt(256),
        ]);
        if (bytes.length > 3 && i.isEven) bytes[2] |= 0x80;
        decodeDnsResponse(bytes);
      }
    });

    test('on random corruption of the recorded answer', () {
      final random = Random(11);
      for (var i = 0; i < 5000; i++) {
        final bytes = Uint8List.fromList(tvAnswer());
        for (var flips = 0; flips < 1 + random.nextInt(6); flips++) {
          bytes[12 + random.nextInt(bytes.length - 12)] = random.nextInt(256);
        }
        decodeDnsResponse(bytes, id: 0x1234);
      }
    });
  });
}
