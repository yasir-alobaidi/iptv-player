import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/hap_srp.dart';

import 'airplay_vectors.dart';
import 'fake_hap_accessory.dart' show hexOf, unhex;

BigInt _int(String hex) => srpInt(unhex(hex));

/// RFC 5054 appendix A, group 1 (1024-bit), g = 2.
const _prime1024 =
    'EEAF0AB9 ADB38DD6 9C33F80A FA8FC5E8 60726187 75FF3C0B 9EA2314C '
    '9C256576 D674DF74 96EA81D3 383B4813 D692C6E0 E0D5D8E2 50B98BE4 '
    '8E495C1D 6089DAD1 5DC7D7B4 6154D6B6 CE8EF4AD 69B15D49 82559B29 '
    '7BCF1885 C529F566 660E57EC 68EDBC3C 05726CC0 2FD4CBF4 976EAA9A '
    'FD5138FE 8376435B 9FC61D2F C0EB06E3';

void main() {
  group('RFC 5054 appendix B (1024-bit group, SHA-1)', () {
    final group = SrpGroup(
      prime: _int(_prime1024),
      generator: BigInt.two,
      hash: sha1,
    );
    final salt = unhex('BEB25379 D1A8581E B5A72767 3A2441EE');
    final a = _int(
      '60975527 035CF2AD 1989806F 0407210B C81EDC04 E2762A56 AFD529DD '
      'DA2D4393',
    );
    final b = _int(
      'E487CB59 D31AC550 471E81F0 0F6928E0 1DDA08E9 74A004F4 9E61F5D1 '
      '05284D20',
    );
    final x = group.passwordHash(salt, 'alice', 'password123');
    final v = group.verifier(x);
    final publicA = group.clientPublic(a);
    final publicB = group.serverPublic(v, b);
    final u = group.scrambler(publicA, publicB);

    test('k', () {
      expect(
        group.multiplier,
        _int('7556AA04 5AEF2CDD 07ABAF0F 665C3E81 8913186F'),
      );
    });

    test('x', () {
      expect(x, _int('94B7555A ABE9127C C58CCF49 93DB6CF8 4D16C124'));
    });

    test('v', () {
      expect(
        v,
        _int(
          '7E273DE8 696FFC4F 4E337D05 B4B375BE B0DDE156 9E8FA00A 9886D812 '
          '9BADA1F1 822223CA 1A605B53 0E379BA4 729FDC59 F105B478 7E5186F5 '
          'C671085A 1447B52A 48CF1970 B4FB6F84 00BBF4CE BFBB1681 52E08AB5 '
          'EA53D15C 1AFF87B2 B9DA6E04 E058AD51 CC72BFC9 033B564E 26480D78 '
          'E955A5E2 9E7AB245 DB2BE315 E2099AFB',
        ),
      );
    });

    test('A', () {
      expect(
        publicA,
        _int(
          '61D5E490 F6F1B795 47B0704C 436F523D D0E560F0 C64115BB 72557EC4 '
          '4352E890 3211C046 92272D8B 2D1A5358 A2CF1B6E 0BFCF99F 921530EC '
          '8E393561 79EAE45E 42BA92AE ACED8251 71E1E8B9 AF6D9C03 E1327F44 '
          'BE087EF0 6530E69F 66615261 EEF54073 CA11CF58 58F0EDFD FE15EFEA '
          'B349EF5D 76988A36 72FAC47B 0769447B',
        ),
      );
    });

    test('B', () {
      expect(
        publicB,
        _int(
          'BD0C6151 2C692C0C B6D041FA 01BB152D 4916A1E7 7AF46AE1 05393011 '
          'BAF38964 DC46A067 0DD125B9 5A981652 236F99D9 B681CBF8 7837EC99 '
          '6C6DA044 53728610 D0C6DDB5 8B318885 D7D82C7F 8DEB75CE 7BD4FBAA '
          '37089E6F 9C6059F3 88838E7A 00030B33 1EB76840 910440B1 B27AAEAE '
          'EB4012B7 D7665238 A8E3FB00 4B117B58',
        ),
      );
    });

    test('u', () {
      expect(u, _int('CE38B959 3487DA98 554ED47D 70A7AE5F 462EF019'));
    });

    test('S, from both sides', () {
      final premaster = _int(
        'B0DC82BA BCF30674 AE450C02 87745E79 90A3381F 63B387AA F271A10D '
        '233861E3 59B48220 F7C4693C 9AE12B0A 6F67809F 0876E2D0 13800D6C '
        '41BB59B6 D5979B5C 00A172B4 A2A5903A 0BDCAF8A 709585EB 2AFAFA8F '
        '3499B200 210DCC1F 10EB3394 3CD67FC8 8A2F39A4 BE5BEC4E C0A3212D '
        'C346D7E4 74B29EDE 8A469FFE CA686E5A',
      );
      expect(
        group.clientSecret(
          serverPublic: publicB,
          privateKey: a,
          passwordHash: x,
          scrambler: u,
        ),
        premaster,
      );
      expect(
        group.serverSecret(
          clientPublic: publicA,
          verifier: v,
          privateKey: b,
          scrambler: u,
        ),
        premaster,
      );
    });
  });

  group('HAP group (3072-bit, SHA-512), against a Python run', () {
    // Inputs of the vectors: PIN 1111, salt A0…AF, a = 0x11 × 32 bytes,
    // b = 0x22 × 64 bytes.
    final group = SrpGroup.hap;
    final salt = List.generate(16, (i) => 0xA0 + i);
    final a = srpInt(List.filled(32, 0x11));
    final b = srpInt(List.filled(64, 0x22));
    final x = group.passwordHash(salt, 'Pair-Setup', '1111');
    final v = group.verifier(x);
    final publicA = group.clientPublic(a);
    final publicB = group.serverPublic(v, b);

    test('N is 3072 bits, g is 5', () {
      expect(group.prime.bitLength, 3072);
      expect(group.length, 384);
      expect(group.generator, BigInt.from(5));
    });

    test('k, x, v, A, B, u, S', () {
      expect(hexOf(srpBytes(group.multiplier)), srpK);
      expect(hexOf(srpBytes(x)), srpX);
      expect(hexOf(srpBytes(v)), srpV);
      expect(hexOf(srpBytes(publicA)), srpA);
      expect(hexOf(srpBytes(publicB)), srpB);
      final u = group.scrambler(publicA, publicB);
      expect(hexOf(srpBytes(u)), srpU);
      final s = group.clientSecret(
        serverPublic: publicB,
        privateKey: a,
        passwordHash: x,
        scrambler: u,
      );
      expect(hexOf(srpBytes(s)), srpS);
      expect(
        group.serverSecret(
          clientPublic: publicA,
          verifier: v,
          privateKey: b,
          scrambler: u,
        ),
        s,
      );
    });

    test('SrpClient: A, M1 and K; M2 checks', () {
      final session = SrpClient(
        username: 'Pair-Setup',
        password: '1111',
        privateKey: a,
      ).answer(salt, srpBytes(publicB))!;
      expect(hexOf(session.publicKey), srpA);
      expect(hexOf(session.sessionKey), srpSessionKey);
      expect(hexOf(session.proof), srpM1);
      expect(session.checkServerProof(unhex(srpM2)), isTrue);
      final wrong = unhex(srpM2)..[63] ^= 1;
      expect(session.checkServerProof(wrong), isFalse);
      expect(session.checkServerProof(unhex(srpM2).sublist(1)), isFalse);
    });

    test('a B with a leading zero goes into M1 in its shortest bytes', () {
      // b = 0x22 × 64 bytes + 273 makes B 383 bytes long.
      final serverPublic = unhex(shortB);
      expect(serverPublic, hasLength(383));
      // Sent padded to 384 bytes or not, it is the same number.
      for (final sent in [
        serverPublic,
        [0, ...serverPublic],
      ]) {
        final session = SrpClient(
          username: 'Pair-Setup',
          password: '1111',
          privateKey: a,
        ).answer(salt, sent)!;
        expect(hexOf(session.sessionKey), shortSessionKey);
        expect(hexOf(session.proof), shortM1);
        expect(session.checkServerProof(unhex(shortM2)), isTrue);
      }
    });

    test('the server side agrees: the same M1 and M2', () {
      final u = group.scrambler(publicA, publicB);
      final key = group.sessionKey(
        group.serverSecret(
          clientPublic: publicA,
          verifier: v,
          privateKey: b,
          scrambler: u,
        ),
      );
      final m1 = group.clientProof(
        username: 'Pair-Setup',
        salt: salt,
        clientPublic: publicA,
        serverPublic: publicB,
        sessionKey: key,
      );
      expect(hexOf(m1), srpM1);
      expect(
        hexOf(
          group.serverProof(
            clientPublic: publicA,
            clientProof: m1,
            sessionKey: key,
          ),
        ),
        srpM2,
      );
    });

    test('a wrong PIN gives another proof', () {
      final session = SrpClient(
        username: 'Pair-Setup',
        password: '1112',
        privateKey: a,
      ).answer(salt, srpBytes(publicB))!;
      expect(hexOf(session.proof), isNot(srpM1));
    });

    test('a B that is 0 mod N is refused', () {
      final client = SrpClient(username: 'Pair-Setup', password: '1111');
      expect(client.answer(salt, srpBytes(group.prime)), isNull);
      expect(client.answer(salt, [0]), isNull);
      expect(client.answer(salt, const []), isNull);
    });

    test('a drawn private key gives an A and S of full length', () {
      final client = SrpClient(
        username: 'Pair-Setup',
        password: '1111',
        random: Random(5),
      );
      for (var i = 0; i < 3; i++) {
        final session = client.answer(salt, srpBytes(publicB))!;
        expect(session.publicKey, hasLength(384));
        expect(session.sessionKey, hasLength(64));
      }
    });

    test('a B whose S is tiny for every key still answers', () {
      // B = k·v + 1 makes the base of S 1, so S is 1 for any private key.
      final client = SrpClient(
        username: 'Pair-Setup',
        password: '1111',
        random: Random(1),
      );
      final degenerate = (group.multiplier * v + BigInt.one) % group.prime;
      expect(client.answer(salt, srpBytes(degenerate)), isNotNull);
    });
  });

  group('bytes', () {
    test('srpBytes is the shortest big-endian form', () {
      expect(srpBytes(BigInt.zero), [0]);
      expect(srpBytes(BigInt.from(5)), [5]);
      expect(srpBytes(BigInt.from(0x0100)), [1, 0]);
      expect(srpInt([0, 0, 1, 0]), BigInt.from(256));
    });

    test('pad fills to N', () {
      expect(SrpGroup.hap.pad(BigInt.from(5)), [...List.filled(383, 0), 5]);
    });

    test('sameBytes', () {
      expect(sameBytes([1, 2], [1, 2]), isTrue);
      expect(sameBytes([1, 2], [1, 3]), isFalse);
      expect(sameBytes([1, 2], [1]), isFalse);
    });

    test("SrpSession's text keeps the key out", () {
      final session = SrpClient(
        username: 'Pair-Setup',
        password: '1111',
        privateKey: BigInt.from(12345),
      ).answer([1], [2])!;
      expect(session.toString(), isNot(contains(hexOf(session.sessionKey))));
    });
  });
}
