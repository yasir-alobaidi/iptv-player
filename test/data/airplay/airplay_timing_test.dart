import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/airplay_timing.dart';

void main() {
  test("NTP's seconds and fraction", () {
    final (seconds, fraction) = ntpParts(
      DateTime.utc(1970, 1, 1, 0, 0, 1, 500),
    );
    expect(seconds, 0x83AA7E80 + 1);
    expect(fraction, 0x80000000);
  });

  test('a reply carries the request back as the reference, and now twice', () {
    final request =
        (ByteData(32)
              ..setUint8(0, 0x80)
              ..setUint8(1, 0xD2)
              ..setUint32(24, 0x11223344)
              ..setUint32(28, 0x55667788))
            .buffer
            .asUint8List();
    final now = DateTime.utc(2026, 10, 27, 12);
    final reply = ByteData.sublistView(timingReply(request, now)!);
    final (seconds, fraction) = ntpParts(now);

    expect(reply.getUint8(0), 0x80);
    expect(reply.getUint8(1), 0xD3);
    expect(reply.getUint16(2), 7);
    expect(reply.getUint32(8), 0x11223344);
    expect(reply.getUint32(12), 0x55667788);
    expect(reply.getUint32(16), seconds);
    expect(reply.getUint32(20), fraction);
    expect(reply.getUint32(24), seconds);
    expect(reply.getUint32(28), fraction);
  });

  test('a short packet gets no answer', () {
    expect(timingReply(Uint8List(8), DateTime.now()), isNull);
  });

  test('the server answers on its port', () async {
    final server = await AirPlayTimingServer.start(
      InternetAddress.loopbackIPv4,
    );
    addTearDown(server.close);
    final client = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(client.close);
    final answer = client
        .where((event) => event == RawSocketEvent.read)
        .map((_) => client.receive())
        .first;
    client.send(Uint8List(32), InternetAddress.loopbackIPv4, server.port);
    expect((await answer)!.data, hasLength(32));
  });
}
