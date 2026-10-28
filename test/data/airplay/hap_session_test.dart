import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/hap_session.dart';

import 'airplay_vectors.dart';
import 'fake_hap_accessory.dart' show hexOf, unhex;

final List<int> _key = List.filled(32, 0x01);
final List<int> _otherKey = List.filled(32, 0x02);

Uint8List _plain(HapReadResult result) => switch (result) {
  HapPlaintext(:final bytes) => bytes,
  HapReadFailed(:final reason) => fail('failed: $reason'),
};

/// Our side and the device's: what one writes, the other reads.
(HapSession, HapSession) _pair() => (
  HapSession(writeKey: _key, readKey: _otherKey),
  HapSession(writeKey: _otherKey, readKey: _key),
);

void main() {
  // The Python run framed these with OpenSSL's ChaCha20-Poly1305 under
  // 32 × 0x01: nonce 4 zero bytes + the 64-bit little-endian count, the
  // 2-byte little-endian length as additional data.
  const request = 'GET /info RTSP/1.0\r\nCSeq: 1\r\n\r\n';
  final body = Uint8List.fromList([for (var i = 0; i < 1500; i++) i % 251]);

  test('frames exactly as pyatv/OpenSSL do, the count running on', () {
    final session = HapSession(writeKey: _key, readKey: _otherKey);
    expect(hexOf(session.encrypt(utf8.encode(request))), sessionFrames1);
    final frames = session.encrypt(body);
    expect(hexOf(frames), sessionFrames2);
    // 1500 bytes are two frames: 1024 and 476.
    expect(frames.sublist(0, 2), [0x00, 0x04]);
    expect(frames.sublist(2 + 1024 + 16, 2 + 1024 + 16 + 2), [0xDC, 0x01]);
  });

  test("reads the Python run's frames", () {
    final session = HapSession(writeKey: _otherKey, readKey: _key);
    expect(
      utf8.decode(_plain(session.decrypt(unhex(sessionFrames1)))),
      request,
    );
    expect(_plain(session.decrypt(unhex(sessionFrames2))), body);
  });

  test('a 3000-byte message across odd TCP chunks comes out whole', () {
    final (ours, theirs) = _pair();
    final message = Uint8List.fromList(
      List.generate(3000, (i) => (i * 7 + 3) % 256),
    );
    final wire = ours.encrypt(message);
    expect(wire, hasLength(3000 + 3 * (2 + 16)));
    final received = BytesBuilder();
    var offset = 0;
    for (final size in [1, 1, 7, 13, 1031, 3, 2, 17, 999, 5000]) {
      final end = min(offset + size, wire.length);
      received.add(_plain(theirs.decrypt(wire.sublist(offset, end))));
      offset = end;
    }
    expect(offset, wire.length);
    expect(received.takeBytes(), message);
  });

  test('several messages in one read', () {
    final (ours, theirs) = _pair();
    final wire = [
      ...ours.encrypt('one'.codeUnits),
      ...ours.encrypt('two'.codeUnits),
      ...ours.encrypt('three'.codeUnits),
    ];
    expect(utf8.decode(_plain(theirs.decrypt(wire))), 'onetwothree');
  });

  test('a stream split at every point reads the same', () {
    final message = List.generate(1100, (i) => i % 256);
    final wire = _pair().$1.encrypt(message);
    for (var cut = 0; cut <= wire.length; cut += 37) {
      final reader = HapSession(writeKey: _otherKey, readKey: _key);
      final first = _plain(reader.decrypt(wire.sublist(0, cut)));
      final second = _plain(reader.decrypt(wire.sublist(cut)));
      expect([...first, ...second], message, reason: 'cut at $cut');
    }
  });

  test('each direction counts its own frames', () {
    final (ours, theirs) = _pair();
    for (var i = 0; i < 3; i++) {
      final ask = ours.encrypt('ask $i'.codeUnits);
      expect(utf8.decode(_plain(theirs.decrypt(ask))), 'ask $i');
      final answer = theirs.encrypt('answer $i, longer'.codeUnits);
      expect(utf8.decode(_plain(ours.decrypt(answer))), 'answer $i, longer');
    }
  });

  test('a changed byte fails, and the session stays failed', () {
    final (ours, theirs) = _pair();
    final wire = ours.encrypt('hello'.codeUnits)..[4] ^= 0x01;
    expect(theirs.decrypt(wire), isA<HapReadFailed>());
    expect(theirs.failed, isTrue);
    expect(
      theirs.decrypt(ours.encrypt('again'.codeUnits)),
      isA<HapReadFailed>(),
    );
  });

  test('a changed length (the additional data) fails', () {
    final (ours, theirs) = _pair();
    final wire = ours.encrypt(List.filled(20, 1));
    // Claim 4 fewer bytes: the frame ends early and its tag is wrong.
    wire[0] = 16;
    expect(theirs.decrypt(wire), isA<HapReadFailed>());
  });

  test('the wrong key fails', () {
    final writer = HapSession(writeKey: _key, readKey: _key);
    final reader = HapSession(writeKey: _key, readKey: _otherKey);
    expect(reader.decrypt(writer.encrypt([1, 2, 3])), isA<HapReadFailed>());
  });

  test('a frame out of order fails', () {
    final (ours, theirs) = _pair();
    final first = ours.encrypt('first'.codeUnits);
    final second = ours.encrypt('second'.codeUnits);
    expect(theirs.decrypt(second), isA<HapReadFailed>());
    expect(first, isNotEmpty);
  });

  test('nothing in, nothing out', () {
    final (ours, theirs) = _pair();
    expect(ours.encrypt(const []), isEmpty);
    expect(_plain(theirs.decrypt(const [])), isEmpty);
    expect(_plain(theirs.decrypt([5])), isEmpty);
    expect(ours.toString(), 'HapSession(<keys>)');
  });
}
