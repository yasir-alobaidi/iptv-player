import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:iptv_player/data/airplay/hap_pairing.dart';
import 'package:iptv_player/data/airplay/hap_srp.dart';
import 'package:iptv_player/data/airplay/tlv8.dart';

/// pyatv's fake receiver's identifier and PIN (`pyatv/auth/server_auth.py`).
const fakeAccessoryId = '5D797FD3-3538-427E-A47B-A32FC6CF3A6A';
const fakeAccessoryPin = '1111';

/// The receiver's side of AirPlay's HAP pairing, ported from pyatv's
/// `BaseAirPlayServerAuth` (`pyatv/protocols/airplay/server_auth.py`):
/// pair-setup with a PIN or transient, and pair-verify, one TLV8 body in
/// and one out. Stricter than pyatv's: it checks the controller's M5 and
/// pair-verify M3 signatures, which pyatv's fake takes on trust.
///
/// Its long-term Ed25519 key and its X25519 pair-verify key both come
/// from one seed, 32 × 0xAA by default (pyatv's
/// `generate_keys(32 * b"\xaa")`).
final class FakeHapAccessory {
  new({
    this.pin = fakeAccessoryPin,
    this.identifier = fakeAccessoryId,
    List<int>? seed,
    this._salt,
    this._srpPrivateKey,
    Random? random,
  }) : _seed = Uint8List.fromList(seed ?? List.filled(32, 0xAA)),
       _random = random ?? Random(7);

  final String pin;
  final String identifier;
  final Uint8List _seed;
  final List<int>? _salt;
  final BigInt? _srpPrivateKey;
  final Random _random;

  /// Answer pair-setup M1 with Error = BackOff and these seconds.
  int? backOffSeconds;

  /// Answer every pair-setup M1 with this Error code.
  int? setupError;

  /// Break the signature in pair-setup M6.
  bool tamperSetupSignature = false;

  /// Break the signature in pair-verify M2.
  bool tamperVerifySignature = false;

  /// Controllers paired by M5: pairing identifier (hex) → long-term key.
  final paired = <String, Uint8List>{};

  /// The OPACK name item the last M5 carried, if any.
  Uint8List? lastControllerName;

  /// The SRP session key (transient) or X25519 secret (pair-verify) the
  /// connection's keys come from, once the exchange succeeded.
  Uint8List? sharedSecret;

  final SrpGroup _group = SrpGroup.hap;
  late Uint8List _setupSalt;
  late BigInt _verifier;
  late BigInt _b;
  late BigInt _serverPublic;
  late Uint8List _sessionKey;
  late Uint8List _verifyPublic;
  late Uint8List _clientVerifyPublic;
  late Uint8List _verifySessionKey;
  late Uint8List _pendingShared;

  Uint8List get _id => utf8.encode(identifier);

  /// The accessory's long-term public key.
  Future<Uint8List> publicKey() async {
    final keyPair = await DartEd25519().newKeyPairFromSeed(_seed);
    return Uint8List.fromList((await keyPair.extractPublicKey()).bytes);
  }

  /// The receiver's view of the control connection's keys: it writes
  /// with Control-Read and reads with Control-Write (pyatv's fake).
  Future<HapKeys> controlKeys() =>
      HapSharedSecret(sharedSecret!).encryptionKeys(
        AirPlayKeyInfo.controlSalt,
        AirPlayKeyInfo.controlRead,
        AirPlayKeyInfo.controlWrite,
      );

  /// One `/pair-setup` request; [transient] is `X-Apple-HKP: 4`.
  Future<Uint8List> pairSetup(List<int> body, {bool transient = false}) async {
    final items = readTlv8(body);
    return switch (readTlvInt(items[TlvType.state])) {
      1 => _m1Setup(items, transient: transient),
      3 => _m3Setup(items, transient: transient),
      5 => await _m5Setup(items),
      _ => _error(0, TlvErrorCode.unknown),
    };
  }

  /// One `/pair-verify` request.
  Future<Uint8List> pairVerify(List<int> body) async {
    final items = readTlv8(body);
    return switch (readTlvInt(items[TlvType.state])) {
      1 => await _m1Verify(items),
      3 => await _m3Verify(items),
      _ => _error(0, TlvErrorCode.unknown),
    };
  }

  Uint8List _m1Setup(Map<int, Uint8List> items, {required bool transient}) {
    if (backOffSeconds case final seconds?) {
      return writeTlv8({
        TlvType.state: [2],
        TlvType.error: [TlvErrorCode.backOff],
        TlvType.backOff: [seconds & 0xFF, seconds >> 8],
      });
    }
    if (setupError case final code?) return _error(2, code);
    final salt = Uint8List.fromList(_salt ?? _bytes(16));
    final x = _group.passwordHash(
      salt,
      'Pair-Setup',
      transient ? HapTransientPairSetup.pin : pin,
    );
    final verifier = _group.verifier(x);
    final b = _srpPrivateKey ?? srpInt(_bytes(64));
    final serverPublic = _group.serverPublic(verifier, b);
    _setupSalt = salt;
    _verifier = verifier;
    _b = b;
    _serverPublic = serverPublic;
    return writeTlv8({
      TlvType.state: [2],
      TlvType.salt: salt,
      TlvType.publicKey: srpBytes(serverPublic),
    });
  }

  Uint8List _m3Setup(Map<int, Uint8List> items, {required bool transient}) {
    final clientPublic = srpInt(items[TlvType.publicKey] ?? const []);
    final proof = items[TlvType.proof] ?? Uint8List(0);
    if (clientPublic % _group.prime == BigInt.zero) {
      return _error(4, TlvErrorCode.authentication);
    }
    final u = _group.scrambler(clientPublic, _serverPublic);
    final secret = _group.serverSecret(
      clientPublic: clientPublic,
      verifier: _verifier,
      privateKey: _b,
      scrambler: u,
    );
    final key = _group.sessionKey(secret);
    final expected = _group.clientProof(
      username: 'Pair-Setup',
      salt: _setupSalt,
      clientPublic: clientPublic,
      serverPublic: _serverPublic,
      sessionKey: key,
    );
    if (!sameBytes(expected, proof)) {
      return _error(4, TlvErrorCode.authentication);
    }
    _sessionKey = key;
    if (transient) sharedSecret = key;
    return writeTlv8({
      TlvType.proof: _group.serverProof(
        clientPublic: clientPublic,
        clientProof: proof,
        sessionKey: key,
      ),
      TlvType.state: [4],
    });
  }

  Future<Uint8List> _m5Setup(Map<int, Uint8List> items) async {
    final key = _sessionKey;
    final encryptKey = await hapHkdf(
      key,
      'Pair-Setup-Encrypt-Salt',
      'Pair-Setup-Encrypt-Info',
    );
    final plain = hapOpen(
      encryptKey,
      'PS-Msg05',
      items[TlvType.encryptedData] ?? const [],
    );
    if (plain == null) return _error(6, TlvErrorCode.authentication);
    final inner = readTlv8(plain);
    final controllerId = inner[TlvType.identifier]!;
    final controllerKey = inner[TlvType.publicKey]!;
    final controllerSalt = await hapHkdf(
      key,
      'Pair-Setup-Controller-Sign-Salt',
      'Pair-Setup-Controller-Sign-Info',
    );
    final signed = await hapVerify(controllerKey, [
      ...controllerSalt,
      ...controllerId,
      ...controllerKey,
    ], inner[TlvType.signature] ?? const []);
    if (!signed) return _error(6, TlvErrorCode.authentication);
    paired[_hex(controllerId)] = controllerKey;
    lastControllerName = inner[TlvType.name];

    final accessorySalt = await hapHkdf(
      key,
      'Pair-Setup-Accessory-Sign-Salt',
      'Pair-Setup-Accessory-Sign-Info',
    );
    final ltpk = await publicKey();
    final signature = await hapSign(_seed, [...accessorySalt, ..._id, ...ltpk]);
    if (tamperSetupSignature) signature[0] ^= 0x01;
    final reply = writeTlv8({
      TlvType.identifier: _id,
      TlvType.publicKey: ltpk,
      TlvType.signature: signature,
    });
    return writeTlv8({
      TlvType.state: [6],
      TlvType.encryptedData: hapSeal(encryptKey, 'PS-Msg06', reply),
    });
  }

  Future<Uint8List> _m1Verify(Map<int, Uint8List> items) async {
    final clientPublic = items[TlvType.publicKey]!;
    const x25519 = DartX25519();
    final keyPair = await x25519.newKeyPairFromSeed(_seed);
    final serverPublic = Uint8List.fromList(
      (await keyPair.extractPublicKey()).bytes,
    );
    final shared = Uint8List.fromList(
      await (await x25519.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: SimplePublicKey(
          clientPublic,
          type: KeyPairType.x25519,
        ),
      )).extractBytes(),
    );
    final sessionKey = await hapHkdf(
      shared,
      'Pair-Verify-Encrypt-Salt',
      'Pair-Verify-Encrypt-Info',
    );
    final signature = await hapSign(_seed, [
      ...serverPublic,
      ..._id,
      ...clientPublic,
    ]);
    if (tamperVerifySignature) signature[10] ^= 0x80;
    final inner = writeTlv8({
      TlvType.identifier: _id,
      TlvType.signature: signature,
    });
    _verifyPublic = serverPublic;
    _clientVerifyPublic = Uint8List.fromList(clientPublic);
    _verifySessionKey = sessionKey;
    _pendingShared = shared;
    return writeTlv8({
      TlvType.state: [2],
      TlvType.publicKey: serverPublic,
      TlvType.encryptedData: hapSeal(sessionKey, 'PV-Msg02', inner),
    });
  }

  Future<Uint8List> _m3Verify(Map<int, Uint8List> items) async {
    final plain = hapOpen(
      _verifySessionKey,
      'PV-Msg03',
      items[TlvType.encryptedData] ?? const [],
    );
    if (plain == null) return _error(4, TlvErrorCode.authentication);
    final inner = readTlv8(plain);
    final controllerId = inner[TlvType.identifier] ?? Uint8List(0);
    final controllerKey = paired[_hex(controllerId)];
    if (controllerKey == null) return _error(4, TlvErrorCode.authentication);
    final signed = await hapVerify(controllerKey, [
      ..._clientVerifyPublic,
      ...controllerId,
      ..._verifyPublic,
    ], inner[TlvType.signature] ?? const []);
    if (!signed) return _error(4, TlvErrorCode.authentication);
    sharedSecret = _pendingShared;
    return writeTlv8({
      TlvType.state: [4],
    });
  }

  Uint8List _error(int state, int code) => writeTlv8({
    TlvType.error: [code],
    TlvType.state: [state],
  });

  List<int> _bytes(int length) => [
    for (var i = 0; i < length; i++) _random.nextInt(256),
  ];
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

/// [hex] digits as bytes (whitespace allowed between them).
Uint8List unhex(String hex) {
  final digits = hex.replaceAll(RegExp(r'\s'), '');
  return Uint8List.fromList([
    for (var i = 0; i < digits.length; i += 2)
      int.parse(digits.substring(i, i + 2), radix: 16),
  ]);
}

/// [bytes] as lower-case hex.
String hexOf(List<int> bytes) => _hex(bytes);
