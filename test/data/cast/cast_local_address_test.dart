import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/cast/cast_transport.dart';

/// Which of this computer's addresses a TV is told to fetch from. The
/// Cast client once took the TV's own address for it (dart:io's
/// `Socket.address` is the address a socket was connected to), which the
/// fake TV on 127.0.0.1 could never show: found on the first real TV.
void main() {
  InternetAddress ip(String address) => InternetAddress(address);
  String? pick(String device, List<String> own) =>
      pickLocalAddress(ip(device), own.map(ip))?.address;

  test("the address on the TV's own network, not a virtual bridge's", () {
    // This laptop on 2026-10-13: Wi-Fi and two Docker bridges.
    const own = ['172.17.0.1', '192.168.1.254', '172.18.0.1'];
    expect(pick('192.168.1.231', own), '192.168.1.254');
    expect(pick('192.168.1.155', own), '192.168.1.254');
  });

  test("never the TV's own address", () {
    for (final device in ['192.168.1.231', '10.0.0.7', '172.17.0.9']) {
      expect(
        pick(device, ['172.17.0.1', '192.168.1.254', '10.0.0.2']),
        isNot(device),
      );
    }
  });

  test('two home networks: the one the TV is on', () {
    const own = ['192.168.1.20', '192.168.26.14'];
    expect(pick('192.168.26.90', own), '192.168.26.14');
    expect(pick('192.168.1.90', own), '192.168.1.20');
  });

  test('a network wider than /24: still the nearest address', () {
    expect(pick('10.4.9.200', ['10.4.0.3', '192.168.1.5']), '10.4.0.3');
  });

  test('loopback is never offered to a TV on the network', () {
    expect(
      pick('192.168.1.231', ['127.0.0.1', '192.168.1.254']),
      '192.168.1.254',
    );
    expect(pickLocalAddress(ip('192.168.1.231'), [ip('127.0.0.1')]), isNull);
  });

  test('an IPv6 TV gets an IPv6 address, an IPv4 TV an IPv4 one', () {
    const own = ['192.168.1.254', '2600:4040:26c0:5f00::10', 'fe80::1'];
    expect(
      pick('2600:4040:26c0:5f00:b719:dd27:d10c:851f', own),
      '2600:4040:26c0:5f00::10',
    );
    expect(pick('192.168.1.231', own), '192.168.1.254');
  });

  test('none of the right kind: nothing to offer', () {
    expect(pickLocalAddress(ip('192.168.1.231'), [ip('fe80::1')]), isNull);
    expect(pickLocalAddress(ip('192.168.1.231'), const []), isNull);
  });
}
