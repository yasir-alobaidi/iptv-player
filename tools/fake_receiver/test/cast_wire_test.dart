import 'dart:typed_data';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:test/test.dart';

void main() {
  group('WireMessage', () {
    test('round-trips a JSON message', () {
      final message = WireMessage.json(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: nsReceiver,
        payload: {'type': 'GET_STATUS', 'requestId': 7, 'name': 'Salón ✓'},
      );
      final read = WireMessage.decode(message.encode());
      expect(read.sourceId, 'sender-0');
      expect(read.destinationId, 'receiver-0');
      expect(read.namespace, nsReceiver);
      expect(read.payload, {
        'type': 'GET_STATUS',
        'requestId': 7,
        'name': 'Salón ✓',
      });
    });

    test('matches protoc for a known message', () {
      // CastMessage{protocol_version: 0, source_id: "a", destination_id:
      // "b", namespace: "c", payload_type: STRING, payload_utf8: "{}"},
      // as protoc --encode writes it.
      const expected = [
        0x08, 0x00, 0x12, 0x01, 0x61, 0x1a, 0x01, 0x62, 0x22, 0x01, //
        0x63, 0x28, 0x00, 0x32, 0x02, 0x7b, 0x7d,
      ];
      const message = WireMessage(
        sourceId: 'a',
        destinationId: 'b',
        namespace: 'c',
        payloadUtf8: '{}',
      );
      expect(message.encode(), expected);
    });

    test('skips unknown fields of every wire type', () {
      final known = const WireMessage(
        sourceId: 's',
        destinationId: 'd',
        namespace: 'n',
        payloadUtf8: '{"type":"PING"}',
      ).encode();
      final extra = [
        // field 9 varint 300, field 10 fixed64, field 11 bytes, field 12
        // fixed32.
        0x48, 0xac, 0x02, //
        0x51, 1, 2, 3, 4, 5, 6, 7, 8,
        0x5a, 0x02, 0xff, 0xfe,
        0x65, 1, 2, 3, 4,
      ];
      final read = WireMessage.decode(Uint8List.fromList([...extra, ...known]));
      expect(read.payload, {'type': 'PING'});
    });

    test('a binary payload has no JSON', () {
      final read = WireMessage.decode(
        const WireMessage(
          sourceId: 's',
          destinationId: 'd',
          namespace: 'n',
          payloadType: payloadBinary,
          payloadBinary: [1, 2, 3],
        ).encode(),
      );
      expect(read.payload, isNull);
      expect(read.payloadBinary, [1, 2, 3]);
    });

    test('refuses truncated or incomplete messages', () {
      final whole = const WireMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: 'n',
        payloadUtf8: '{}',
      ).encode();
      // After the namespace come `28 00` (payload_type) and `32 02 7b 7d`
      // (the payload): a cut between those fields is a whole message.
      final whole1 = whole.length - 6;
      final whole2 = whole.length - 4;
      for (var cut = 1; cut < whole.length; cut++) {
        final head = Uint8List.sublistView(whole, 0, cut);
        if (cut == whole1 || cut == whole2) {
          expect(WireMessage.decode(head).payload, isNull);
        } else {
          expect(
            () => WireMessage.decode(head),
            throwsFormatException,
            reason: 'cut at $cut',
          );
        }
      }
    });
  });

  group('FrameSplitter', () {
    test('joins a frame split across reads and splits two in one', () {
      final a = frame([1, 2, 3]);
      final b = frame([4]);
      final all = [...a, ...b];
      final splitter = FrameSplitter();
      final seen = <List<int>>[];
      for (final byte in all) {
        seen.addAll(splitter.add([byte])!);
      }
      expect(seen, [
        [1, 2, 3],
        [4],
      ]);
      expect(FrameSplitter().add(all), [
        [1, 2, 3],
        [4],
      ]);
    });

    test('stops at a length over 64 KiB', () {
      final splitter = FrameSplitter();
      expect(splitter.add([0, 1, 0, 1]), isNull);
      expect(splitter.add(frame([1])), isNull);
    });
  });
}
