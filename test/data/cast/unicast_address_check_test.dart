import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/data/cast/unicast_address_check.dart';

Uint8List _fixture(String name) =>
    File('test_fixtures/cast/$name').readAsBytesSync();

/// A device's mDNS port on loopback: answers each query with [reply]'s
/// bytes, given the query's id, or not at all.
final class _Responder {
  new _(this._socket);

  static Future<_Responder> start() async => _Responder._(
    await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0),
  ).._listen();

  final RawDatagramSocket _socket;
  Uint8List? Function(int query)? reply;
  int queries = 0;

  int get port => _socket.port;

  void _listen() {
    _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket.receive();
      if (datagram == null) return;
      final id = datagram.data[0] << 8 | datagram.data[1];
      queries++;
      final answer = reply?.call(queries);
      if (answer == null) return;
      final bytes = Uint8List.fromList(answer)
        ..[0] = id >> 8
        ..[1] = id & 0xFF;
      _socket.send(bytes, datagram.address, datagram.port);
    });
  }

  void close() => _socket.close();
}

void main() {
  late _Responder responder;
  late UnicastCastAddressCheck check;

  setUp(() async {
    responder = await _Responder.start();
    check = UnicastCastAddressCheck(
      mdnsPort: responder.port,
      timeout: const Duration(milliseconds: 600),
      resend: const Duration(milliseconds: 150),
    );
  });
  tearDown(() => responder.close());

  test('a TV answers with its name, model, id and port', () async {
    responder.reply = (_) => _fixture('tv_unicast_answer.bin');

    final answer = await check.check(const CastAddress('127.0.0.1'));

    final device = (answer as CastDeviceAnswered).device;
    expect(device.id, '4f1c9e27a0b35d68c2e71f094ab6d3e5');
    expect(device.name, 'Living Room TV');
    expect(device.model, 'Chromecast');
    expect(device.port, 8009);
    expect(device.manual, isTrue);
    expect(responder.queries, 1);
  });

  test('the address that answered, not the one its records list', () async {
    responder.reply = (_) => _fixture('tv_unicast_answer.bin');

    final answer = await check.check(const CastAddress('127.0.0.1'));

    // The recorded A record says 192.168.1.60.
    expect((answer as CastDeviceAnswered).device.host, '127.0.0.1');
  });

  test('a port typed with the address is kept (a test receiver)', () async {
    responder.reply = (_) => _fixture('tv_unicast_answer.bin');

    final answer = await check.check(const CastAddress('127.0.0.1', 41234));

    expect((answer as CastDeviceAnswered).device.port, 41234);
  });

  test('a speaker is audio only, by its name', () async {
    responder.reply = (_) => _fixture('speaker_unicast_answer.bin');

    final answer = await check.check(const CastAddress('127.0.0.1'));

    expect((answer as CastAudioOnlyAnswered).name, 'Living Room speaker');
  });

  test('nothing answering: no answer, after one resend', () async {
    final clock = Stopwatch()..start();

    final answer = await check.check(const CastAddress('127.0.0.1'));

    expect(answer, isA<CastNoAnswer>());
    expect(responder.queries, 2);
    expect(
      clock.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 600)),
    );
  });

  test('the first query lost on the way: the resend is answered', () async {
    responder.reply = (query) =>
        query == 1 ? null : _fixture('tv_unicast_answer.bin');

    final answer = await check.check(const CastAddress('127.0.0.1'));

    expect(answer, isA<CastDeviceAnswered>());
    expect(responder.queries, 2);
  });

  test('garbage and a wrong id are ignored while it waits', () async {
    responder.reply = (query) => switch (query) {
      1 => Uint8List.fromList(List.filled(40, 0xC0)),
      _ => _fixture('tv_unicast_answer.bin'),
    };

    final answer = await check.check(const CastAddress('127.0.0.1'));

    expect(answer, isA<CastDeviceAnswered>());
  });

  test('an answer about something other than a Cast device: none', () async {
    // A PTR with no TXT for its instance.
    responder.reply = (_) => Uint8List.fromList([
      0, 0, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, //
      11, ...'_googlecast'.codeUnits, 4, ...'_tcp'.codeUnits,
      5, ...'local'.codeUnits, 0,
      0, 12, 0, 1, 0, 0, 0, 120, 0, 5, 2, ...'tv'.codeUnits, 0xC0, 12,
    ]);

    final answer = await check.check(const CastAddress('127.0.0.1'));

    expect(answer, isA<CastNoAnswer>());
  });

  test('a name that does not resolve: no answer', () async {
    final answer = await check.check(const CastAddress('nothing.invalid'));

    expect(answer, isA<CastNoAnswer>());
    expect(responder.queries, 0);
  });
}
