import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/hap_pairing.dart';
import 'package:iptv_player/data/airplay/hap_srp.dart';
import 'package:iptv_player/data/airplay/tlv8.dart';

import 'airplay_vectors.dart';
import 'fake_hap_accessory.dart';

T _ok<T>(HapResult<T> result) => switch (result) {
  HapOk(:final value) => value,
  HapFailed(:final failure) => fail('failed: $failure'),
};

HapFailure _failed<T>(HapResult<T> result) => switch (result) {
  HapOk() => fail('expected a failure'),
  HapFailed(:final failure) => failure,
};

/// A whole PIN pair-setup against [accessory], as the main session runs
/// it over HTTP; the credentials.
Future<HapCredentials> _pair(
  FakeHapAccessory accessory, {
  String pin = fakeAccessoryPin,
  String? name,
}) async {
  final setup = HapPairSetup(name: name, random: Random(1));
  expect(setup.readM2(await accessory.pairSetup(setup.m1)), isNull);
  final m4 = await accessory.pairSetup(_ok(setup.m3(pin)));
  expect(setup.readM4(m4), isNull);
  final m6 = await accessory.pairSetup(_ok(await setup.m5()));
  return _ok<HapCredentials>(await setup.readM6(m6));
}

/// A whole pair-verify; the shared secret.
Future<HapResult<HapSharedSecret>> _verify(
  FakeHapAccessory accessory,
  HapCredentials credentials,
) async {
  final verify = HapPairVerify(credentials, random: Random(2));
  final m2 = await accessory.pairVerify(await verify.m1());
  if (await verify.readM2(m2) case final failure?) return HapFailed(failure);
  final m4 = await accessory.pairVerify(_ok(await verify.m3()));
  return verify.readM4(m4);
}

Future<Uint8List> _secretOf(HapSharedSecret secret) async =>
    (await secret.encryptionKeys('s', 'w', 'r')).writeKey;

void main() {
  group('pair-setup with a PIN', () {
    test('M1 is Method 0 and State 1, as pyatv sends it', () {
      expect(HapPairSetup().m1, [0x00, 0x01, 0x00, 0x06, 0x01, 0x01]);
    });

    test('pairs with the fake accessory; the credentials verify', () async {
      final accessory = FakeHapAccessory();
      final credentials = await _pair(accessory, name: 'Bijou');
      expect(credentials.deviceLtpk, unhex(ed25519PublicAA));
      expect(credentials.deviceId, utf8.encode(fakeAccessoryId));
      expect(credentials.ltsk, hasLength(32));
      // pyatv's pairing id: a random UUID's text.
      expect(
        utf8.decode(credentials.pairingId),
        matches(RegExp('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab]')),
      );
      expect(credentials.pairingId, hasLength(36));
      expect(accessory.paired.keys, [hexOf(credentials.pairingId)]);
      // The name as pyatv's OPACK {"name": "Bijou"}.
      expect(accessory.lastControllerName, [
        0xE1,
        0x44,
        ...'name'.codeUnits,
        0x45,
        ...'Bijou'.codeUnits,
      ]);

      final secret = _ok(await _verify(accessory, credentials));
      final ours = await secret.controlKeys();
      final theirs = await accessory.controlKeys();
      expect(ours.writeKey, theirs.readKey);
      expect(ours.readKey, theirs.writeKey);
      expect(ours.writeKey, isNot(ours.readKey));
    });

    test('M5 leaves the name out when there is none', () async {
      final accessory = FakeHapAccessory();
      await _pair(accessory);
      expect(accessory.lastControllerName, isNull);
    });

    test('given keys and ids are used as they are', () async {
      final accessory = FakeHapAccessory();
      final setup = HapPairSetup(
        longTermSeed: List.filled(32, 0x55),
        pairingId: utf8.encode('Bijou-test'),
        srpPrivateKey: BigInt.from(987654321),
      );
      setup.readM2(await accessory.pairSetup(setup.m1));
      setup.readM4(await accessory.pairSetup(_ok(setup.m3('1111'))));
      final m6 = await accessory.pairSetup(_ok(await setup.m5()));
      final credentials = _ok(await setup.readM6(m6));
      expect(credentials.ltsk, List.filled(32, 0x55));
      expect(credentials.pairingId, utf8.encode('Bijou-test'));
    });

    test('a wrong PIN is the device saying authentication', () async {
      final accessory = FakeHapAccessory();
      final setup = HapPairSetup();
      setup.readM2(await accessory.pairSetup(setup.m1));
      final m4 = await accessory.pairSetup(_ok(setup.m3('1234')));
      expect(setup.readM4(m4), isA<HapAuthenticationFailed>());
      expect(_failed(await setup.m5()), isA<HapBadMessage>());
    });

    test('a device proof that is wrong fails M4', () async {
      final accessory = FakeHapAccessory();
      final setup = HapPairSetup();
      setup.readM2(await accessory.pairSetup(setup.m1));
      final m4 = readTlv8(await accessory.pairSetup(_ok(setup.m3('1111'))));
      m4[TlvType.proof]![0] ^= 1;
      expect(setup.readM4(writeTlv8(m4)), isA<HapVerificationFailed>());
      expect(
        setup.readM4(
          writeTlv8({
            TlvType.state: [4],
          }),
        ),
        isA<HapBadMessage>(),
      );
    });

    test('a tampered M6 signature fails; unchecked, it passes', () async {
      final accessory = FakeHapAccessory()..tamperSetupSignature = true;
      for (final check in [true, false]) {
        final setup = HapPairSetup(checkDeviceSignature: check);
        setup.readM2(await accessory.pairSetup(setup.m1));
        setup.readM4(await accessory.pairSetup(_ok(setup.m3('1111'))));
        final m6 = await accessory.pairSetup(_ok(await setup.m5()));
        final result = await setup.readM6(m6);
        if (check) {
          expect(_failed(result), isA<HapVerificationFailed>());
        } else {
          expect(result, isA<HapOk<HapCredentials>>());
        }
      }
    });

    test('an M6 that does not decrypt fails', () async {
      final accessory = FakeHapAccessory();
      final setup = HapPairSetup();
      setup.readM2(await accessory.pairSetup(setup.m1));
      setup.readM4(await accessory.pairSetup(_ok(setup.m3('1111'))));
      final m6 = readTlv8(await accessory.pairSetup(_ok(await setup.m5())));
      m6[TlvType.encryptedData]![3] ^= 0x40;
      expect(
        _failed(await setup.readM6(writeTlv8(m6))),
        isA<HapVerificationFailed>(),
      );
    });

    test('back-off: the seconds the device asks for', () async {
      final accessory = FakeHapAccessory()..backOffSeconds = 300;
      final setup = HapPairSetup();
      final failure = setup.readM2(await accessory.pairSetup(setup.m1));
      expect(failure, isA<HapBackOff>());
      expect((failure! as HapBackOff).seconds, 300);
      expect(failure.toString(), 'back_off: 300s');
    });

    test('each Error code is its own failure', () {
      HapFailure? m2With(int code) => HapPairSetup().readM2(
        writeTlv8({
          TlvType.state: [2],
          TlvType.error: [code],
        }),
      );
      expect(
        m2With(TlvErrorCode.authentication),
        isA<HapAuthenticationFailed>(),
      );
      expect(
        m2With(TlvErrorCode.backOff),
        const TypeMatcher<HapBackOff>().having((f) => f.seconds, 'seconds', 0),
      );
      expect(m2With(TlvErrorCode.maxPeers), isA<HapMaxPeers>());
      expect(m2With(TlvErrorCode.maxTries), isA<HapMaxTries>());
      expect(m2With(TlvErrorCode.unavailable), isA<HapUnavailable>());
      expect(m2With(TlvErrorCode.busy), isA<HapBusy>());
      expect(m2With(TlvErrorCode.unknown), isA<HapUnknownError>());
      expect((m2With(0x42)! as HapUnknownError).errorCode, 0x42);
    });

    test('a busy device, end to end', () async {
      final accessory = FakeHapAccessory()..setupError = TlvErrorCode.busy;
      final setup = HapPairSetup();
      expect(setup.readM2(await accessory.pairSetup(setup.m1)), isA<HapBusy>());
    });

    test(
      'malformed answers and steps out of order fail, never throw',
      () async {
        final setup = HapPairSetup();
        expect(_failed(setup.m3('1111')), isA<HapBadMessage>());
        expect(setup.readM4([]), isA<HapBadMessage>());
        expect(_failed(await setup.m5()), isA<HapBadMessage>());
        expect(_failed(await setup.readM6([])), isA<HapBadMessage>());
        expect(setup.readM2([]), isA<HapBadMessage>());
        expect(setup.readM2([1, 2, 3, 4, 5]), isA<HapBadMessage>());
        expect(
          setup.readM2(
            writeTlv8({
              TlvType.salt: [1],
            }),
          ),
          isA<HapBadMessage>(),
        );
        // A B that is 0 mod N.
        setup.readM2(
          writeTlv8({
            TlvType.salt: [1],
            TlvType.publicKey: [0],
          }),
        );
        expect(_failed(setup.m3('1111')), isA<HapVerificationFailed>());
      },
    );
  });

  group('transient pair-setup', () {
    test('M1 adds Flags = transient, as pyatv', () {
      expect(HapTransientPairSetup().m1, [0, 1, 0, 6, 1, 1, 0x13, 1, 0x10]);
    });

    test('pairs with PIN 3939; K is the shared secret', () async {
      final accessory = FakeHapAccessory();
      final setup = HapTransientPairSetup();
      final m2 = await accessory.pairSetup(setup.m1, transient: true);
      expect(setup.readM2(m2), isNull);
      final m4 = await accessory.pairSetup(_ok(setup.m3()), transient: true);
      final secret = _ok(setup.readM4(m4));
      final ours = await secret.controlKeys();
      final theirs = await accessory.controlKeys();
      expect(ours.writeKey, theirs.readKey);
      expect(ours.readKey, theirs.writeKey);
    });

    test('the keys are HKDF-SHA512 of the 64-byte K, as pyatv', () async {
      // The Python run's K for its inputs, and its Control-Write key.
      final secret = HapSharedSecret(unhex(srpSessionKey));
      expect(hexOf((await secret.controlKeys()).writeKey), hkdfControlWrite);
    });

    test('a device on another PIN refuses it', () async {
      final accessory = FakeHapAccessory();
      final setup = HapTransientPairSetup();
      // The accessory takes the transient PIN only on a transient M1.
      setup.readM2(await accessory.pairSetup(setup.m1));
      final m4 = await accessory.pairSetup(_ok(setup.m3()));
      expect(_failed(setup.readM4(m4)), isA<HapAuthenticationFailed>());
    });
  });

  group('pair-verify', () {
    late FakeHapAccessory accessory;
    late HapCredentials credentials;

    setUp(() async {
      accessory = FakeHapAccessory();
      credentials = await _pair(accessory);
    });

    test('M1 is State 1 and a 32-byte X25519 key', () async {
      final m1 = readTlv8(await HapPairVerify(credentials).m1());
      expect(m1.keys, [TlvType.state, TlvType.publicKey]);
      expect(m1[TlvType.publicKey], hasLength(32));
    });

    test('both sides end with the same secret', () async {
      final secret = _ok(await _verify(accessory, credentials));
      final events = await secret.eventsKeys();
      final viaNames = await secret.encryptionKeys(
        AirPlayKeyInfo.eventsSalt,
        AirPlayKeyInfo.eventsRead,
        AirPlayKeyInfo.eventsWrite,
      );
      expect(events.writeKey, viaNames.writeKey);
      expect(events.readKey, viaNames.readKey);
      expect(
        await _secretOf(secret),
        await _secretOf(HapSharedSecret(accessory.sharedSecret!)),
      );
    });

    test('credentials survive their text form', () async {
      final again = HapCredentials.parse(credentials.serialize())!;
      expect(again, credentials);
      expect(_ok(await _verify(accessory, again)), isA<HapSharedSecret>());
    });

    test('a tampered M2 signature fails', () async {
      accessory.tamperVerifySignature = true;
      final failure = _failed(await _verify(accessory, credentials));
      expect(failure, isA<HapVerificationFailed>());
    });

    test('another device answering fails', () async {
      final other = HapCredentials(
        deviceLtpk: credentials.deviceLtpk,
        ltsk: credentials.ltsk,
        deviceId: utf8.encode('someone else'),
        pairingId: credentials.pairingId,
      );
      final failure = _failed(await _verify(accessory, other));
      expect(failure, isA<HapVerificationFailed>());
      expect(failure.toString(), contains('another device'));
    });

    test('a device that forgot us says authentication in M4', () async {
      final forgetful = FakeHapAccessory();
      final failure = _failed(await _verify(forgetful, credentials));
      expect(failure, isA<HapAuthenticationFailed>());
    });

    test('our wrong key fails at the device', () async {
      final wrong = HapCredentials(
        deviceLtpk: credentials.deviceLtpk,
        ltsk: Uint8List(32),
        deviceId: credentials.deviceId,
        pairingId: credentials.pairingId,
      );
      expect(
        _failed(await _verify(accessory, wrong)),
        isA<HapAuthenticationFailed>(),
      );
    });

    test('a degenerate device key and steps out of order fail', () async {
      final verify = HapPairVerify(credentials);
      expect(await verify.readM2([]), isA<HapBadMessage>());
      expect(_failed(await verify.m3()), isA<HapBadMessage>());
      expect(_failed(verify.readM4([])), isA<HapBadMessage>());
      await verify.m1();
      expect(await verify.readM2([]), isA<HapBadMessage>());
      expect(
        await verify.readM2(
          writeTlv8({
            TlvType.publicKey: Uint8List(32),
            TlvType.encryptedData: Uint8List(40),
          }),
        ),
        isA<HapVerificationFailed>(),
      );
      expect(
        await verify.readM2(
          writeTlv8({
            TlvType.state: [2],
            TlvType.error: [TlvErrorCode.authentication],
          }),
        ),
        isA<HapAuthenticationFailed>(),
      );
    });
  });

  group('HapCredentials', () {
    // pyatv's tests use these (pyatv/auth/server_auth.py).
    const pyatvCredentials =
        'E734EA6C2B6257DE72355E472AA05A4C487E6B463C029ED306DF2F01B5636B58:'
        '80FD8265B0748DA90BC5C5294DABE394D3D47199994AE96AC73EE45C783537B1:'
        '35443739374644332D333533382D343237452D413437422D41333246433643463'
        '3413641:34443739374644332D333533382D343237452D413437422D413332464'
        '336434633413641';

    test("reads pyatv's credentials string", () {
      final credentials = HapCredentials.parse(pyatvCredentials)!;
      expect(credentials.deviceLtpk, unhex(ed25519PublicAA));
      expect(utf8.decode(credentials.deviceId), fakeAccessoryId);
      expect(
        utf8.decode(credentials.pairingId),
        '4D797FD3-3538-427E-A47B-A32FC6CF3A6A',
      );
      expect(credentials.serialize(), pyatvCredentials.toLowerCase());
    });

    test('refuses anything else', () {
      expect(HapCredentials.parse(''), isNull);
      expect(HapCredentials.parse('aa:bb'), isNull); // pyatv's legacy form
      expect(HapCredentials.parse('aa:bb:cc:dd'), isNull); // short keys
      expect(HapCredentials.parse('zz:bb:cc:dd'), isNull);
      expect(HapCredentials.parse('${'a' * 64}:${'b' * 64}::dd'), isNull);
    });

    test('never shows the secret key', () {
      final credentials = HapCredentials.parse(pyatvCredentials)!;
      expect(credentials.toString(), isNot(contains('80fd')));
      expect(credentials.toString(), isNot(contains('80FD')));
      expect(
        HapSharedSecret([1, 2, 3]).toString(),
        'HapSharedSecret(<secret>)',
      );
    });
  });

  group('primitives against known answers', () {
    test(
      'RFC 8439 §2.8.2: ChaCha20-Poly1305 as the cryptography package does it',
      () async {
        final plaintext = utf8.encode(
          "Ladies and Gentlemen of the class of '99: If I could offer you "
          'only one tip for the future, sunscreen would be it.',
        );
        final box = await const DartChacha20.poly1305Aead().encrypt(
          plaintext,
          secretKey: SecretKey(List.generate(32, (i) => 0x80 + i)),
          nonce: unhex('07000000 4041424344454647'),
          aad: unhex('50515253c0c1c2c3c4c5c6c7'),
        );
        expect(
          hexOf(box.cipherText),
          'd31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d6'
          '3dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b36'
          '92ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc'
          '3ff4def08e4b7a9de576d26586cec64b6116',
        );
        expect(hexOf(box.mac.bytes), '1ae10b594f09e26a7e902ecbd0600691');
      },
    );

    test('HKDF-SHA512 and the 8-byte pairing nonce, as OpenSSL', () async {
      final key = await hapHkdf(
        unhex(srpSessionKey),
        'Pair-Setup-Encrypt-Salt',
        'Pair-Setup-Encrypt-Info',
      );
      expect(hexOf(key), hkdfPairSetupEncrypt);
      final sealed = hapSeal(key, 'PS-Msg05', utf8.encode('hello hap'));
      expect(hexOf(sealed), sealedHelloHap);
      expect(utf8.decode(hapOpen(key, 'PS-Msg05', sealed)!), 'hello hap');
      expect(hapOpen(key, 'PS-Msg06', sealed), isNull);
      expect(hapOpen(key, 'PS-Msg05', sealed.sublist(0, 10)), isNull);
    });

    test('Ed25519 from a seed, as OpenSSL', () async {
      final seed = List.filled(32, 0xAA);
      final keyPair = await DartEd25519().newKeyPairFromSeed(seed);
      final publicKey = (await keyPair.extractPublicKey()).bytes;
      expect(hexOf(publicKey), ed25519PublicAA);
      final message = utf8.encode('pair-verify message');
      final signature = await hapSign(seed, message);
      expect(hexOf(signature), ed25519SignatureAA);
      expect(await hapVerify(publicKey, message, signature), isTrue);
      expect(await hapVerify(publicKey, [...message, 0], signature), isFalse);
      expect(
        await hapVerify(publicKey, message, signature.sublist(1)),
        isFalse,
      );
      expect(await hapVerify([1, 2], message, signature), isFalse);
    });

    test('X25519, as OpenSSL', () async {
      const x25519 = DartX25519();
      final ours = await x25519.newKeyPairFromSeed(List.filled(32, 0xAA));
      final theirs = await x25519.newKeyPairFromSeed(List.filled(32, 0x55));
      expect(hexOf((await ours.extractPublicKey()).bytes), x25519PublicAA);
      expect(hexOf((await theirs.extractPublicKey()).bytes), x25519Public55);
      final shared = await x25519.sharedSecretKey(
        keyPair: ours,
        remotePublicKey: await theirs.extractPublicKey(),
      );
      expect(hexOf(await shared.extractBytes()), x25519Shared);
    });

    test('the transient M3 is SRP over PIN 3939 and the salt as sent', () {
      final setup = HapTransientPairSetup(srpPrivateKey: BigInt.from(7));
      final group = SrpGroup.hap;
      final salt = [0, 1, 2, 3];
      final b = group.serverPublic(
        group.verifier(group.passwordHash(salt, 'Pair-Setup', '3939')),
        BigInt.from(11),
      );
      setup.readM2(
        writeTlv8({TlvType.salt: salt, TlvType.publicKey: srpBytes(b)}),
      );
      final m3 = readTlv8(_ok(setup.m3()));
      expect(m3[TlvType.state], [3]);
      expect(
        m3[TlvType.publicKey],
        srpBytes(group.clientPublic(BigInt.from(7))),
      );
    });
  });
}
