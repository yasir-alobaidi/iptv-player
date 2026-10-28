import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:iptv_player/data/airplay/hap_srp.dart';
import 'package:iptv_player/data/airplay/tlv8.dart';
import 'package:meta/meta.dart';

/// The headers pyatv sends with every POST to `/pair-pin-start`,
/// `/pair-setup` and `/pair-verify` (its `_AIRPLAY_HEADERS`):
/// `X-Apple-HKP: 3` asks for HomeKit pairing. A transient pair-setup
/// sends [airPlayTransientPairingHeaders] instead.
const airPlayPairingHeaders = <String, String>{
  'User-Agent': 'AirPlay/320.20',
  'Connection': 'keep-alive',
  'X-Apple-HKP': '3',
  'Content-Type': 'application/octet-stream',
};

/// [airPlayPairingHeaders] with `X-Apple-HKP: 4`: transient pairing.
const airPlayTransientPairingHeaders = <String, String>{
  'User-Agent': 'AirPlay/320.20',
  'Connection': 'keep-alive',
  'X-Apple-HKP': '4',
  'Content-Type': 'application/octet-stream',
};

/// The HKDF salts and infos AirPlay derives a connection's keys with
/// (pyatv's `airplay/auth/__init__.py` and `ap2_session.py`).
abstract final class AirPlayKeyInfo {
  static const controlSalt = 'Control-Salt';
  static const controlWrite = 'Control-Write-Encryption-Key';
  static const controlRead = 'Control-Read-Encryption-Key';
  static const eventsSalt = 'Events-Salt';
  static const eventsWrite = 'Events-Write-Encryption-Key';
  static const eventsRead = 'Events-Read-Encryption-Key';
}

/// Why a pairing step failed. The first seven are the device's own
/// Error item; the last two are this side's checks.
sealed class HapFailure {
  const new();

  /// A stable name for logs.
  String get code;

  @override
  String toString() => code;
}

/// The device's Error was Authentication: in pair-setup's M4 a wrong
/// PIN, in pair-verify a pairing it doesn't know (any more).
final class HapAuthenticationFailed extends HapFailure {
  const new();

  @override
  String get code => 'authentication';
}

/// The device wants [seconds] of quiet before the next attempt.
final class HapBackOff extends HapFailure {
  const new(this.seconds);

  final int seconds;

  @override
  String get code => 'back_off';

  @override
  String toString() => 'back_off: ${seconds}s';
}

/// The device keeps no more pairings.
final class HapMaxPeers extends HapFailure {
  const new();

  @override
  String get code => 'max_peers';
}

/// The device has refused too many wrong PINs.
final class HapMaxTries extends HapFailure {
  const new();

  @override
  String get code => 'max_tries';
}

/// The device can't pair now.
final class HapUnavailable extends HapFailure {
  const new();

  @override
  String get code => 'unavailable';
}

/// The device is pairing with someone else.
final class HapBusy extends HapFailure {
  const new();

  @override
  String get code => 'busy';
}

/// An Error code HAP doesn't name (or Unknown, 1).
final class HapUnknownError extends HapFailure {
  const new(this.errorCode);

  final int errorCode;

  @override
  String get code => 'device_error';

  @override
  String toString() => 'device_error: $errorCode';
}

/// The device's answer didn't prove what it must: a wrong SRP proof, a
/// signature that doesn't verify, data that doesn't decrypt, another
/// device's identifier.
final class HapVerificationFailed extends HapFailure {
  const new(this.reason);

  final String reason;

  @override
  String get code => 'verification';

  @override
  String toString() => 'verification: $reason';
}

/// The answer lacks an item the step needs, or a step came out of order,
/// or the stored credentials are unusable.
final class HapBadMessage extends HapFailure {
  const new(this.reason);

  final String reason;

  @override
  String get code => 'bad_message';

  @override
  String toString() => 'bad_message: $reason';
}

/// A pairing step's outcome: [HapOk] or [HapFailed], never a throw.
sealed class HapResult<T> {
  const new();
}

final class HapOk<T> extends HapResult<T> {
  const new(this.value);

  final T value;
}

final class HapFailed<T> extends HapResult<T> {
  const new(this.failure);

  final HapFailure failure;
}

/// What a PIN pair-setup leaves to keep: our long-term Ed25519 key and
/// pairing identifier, and the device's. Pair-verify needs all four.
@immutable
final class HapCredentials {
  const new({
    required this.deviceLtpk,
    required this.ltsk,
    required this.deviceId,
    required this.pairingId,
  });

  /// The device's long-term Ed25519 public key (pyatv's `ltpk`).
  final Uint8List deviceLtpk;

  /// Our long-term Ed25519 key's 32-byte seed (pyatv's `ltsk`). A secret:
  /// secure storage only, never a log (hard rule 3).
  final Uint8List ltsk;

  /// The device's pairing identifier (pyatv's `atv_id`).
  final Uint8List deviceId;

  /// Ours (pyatv's `client_id`): a random UUID's text.
  final Uint8List pairingId;

  /// pyatv's credentials string, `ltpk:ltsk:atv_id:client_id` in
  /// lower-case hex. It holds [ltsk]: secure storage only.
  String serialize() =>
      [deviceLtpk, ltsk, deviceId, pairingId].map(_hex).join(':');

  /// Credentials from [serialize]'s text; null for anything else (pyatv's
  /// two-part legacy credentials included), or keys of the wrong length.
  static HapCredentials? parse(String text) {
    final parts = text.trim().split(':');
    if (parts.length != 4) return null;
    final bytes = parts.map(_unhex).toList();
    if (bytes.any((part) => part == null || part.isEmpty)) return null;
    final [ltpk!, ltsk!, deviceId!, pairingId!] = bytes;
    if (ltpk.length != 32 || ltsk.length != 32) return null;
    return HapCredentials(
      deviceLtpk: ltpk,
      ltsk: ltsk,
      deviceId: deviceId,
      pairingId: pairingId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HapCredentials && other.serialize() == serialize();

  @override
  int get hashCode => serialize().hashCode;

  @override
  String toString() => 'HapCredentials(<secret>)';
}

/// The keys a connection's encryption is derived from:
/// pair-verify's X25519 shared secret, or a transient pair-setup's SRP
/// session key K. Never log it.
final class HapSharedSecret {
  new(List<int> secret) : _secret = Uint8List.fromList(secret);

  final Uint8List _secret;

  /// The two 32-byte keys for one connection, each
  /// HKDF-SHA512(secret, [salt], info) (pyatv's `encryption_keys`):
  /// `writeKey` encrypts what this side sends, `readKey` decrypts what it
  /// receives.
  Future<HapKeys> encryptionKeys(
    String salt,
    String writeInfo,
    String readInfo,
  ) async => (
    writeKey: await hapHkdf(_secret, salt, writeInfo),
    readKey: await hapHkdf(_secret, salt, readInfo),
  );

  /// The keys for the connection pairing ran on (pyatv's
  /// `verify_connection`): Control-Write to send, Control-Read to read.
  Future<HapKeys> controlKeys() => encryptionKeys(
    AirPlayKeyInfo.controlSalt,
    AirPlayKeyInfo.controlWrite,
    AirPlayKeyInfo.controlRead,
  );

  /// The keys for the event connection. The names are the device's
  /// view, so they swap: this side sends with Events-Read and reads with
  /// Events-Write (pyatv's `ap2_session.py` passes them that way round).
  Future<HapKeys> eventsKeys() => encryptionKeys(
    AirPlayKeyInfo.eventsSalt,
    AirPlayKeyInfo.eventsRead,
    AirPlayKeyInfo.eventsWrite,
  );

  @override
  String toString() => 'HapSharedSecret(<secret>)';
}

/// A connection's two keys: `writeKey` for what this side sends,
/// `readKey` for what it receives.
typedef HapKeys = ({Uint8List writeKey, Uint8List readKey});

/// Pair-setup with the PIN the device shows (HAP §5.6; pyatv's
/// `AirPlayHapPairSetupProcedure` and `SRPAuthHandler`), message by
/// message with no I/O: POST an empty body to `/pair-pin-start` (the TV
/// shows its PIN), then POST [m1], [m3], [m5] to `/pair-setup` with
/// [airPlayPairingHeaders], handing each answer's body to the read step
/// after it. [readM6] gives the [HapCredentials] to keep.
///
/// Stricter than pyatv where HAP asks: M4's proof and M6's signature are
/// checked (pyatv reads neither). [checkDeviceSignature] turns the M6
/// check off, should a device sign differently.
final class HapPairSetup {
  new({
    this._name,
    List<int>? longTermSeed,
    List<int>? pairingId,
    BigInt? srpPrivateKey,
    this.checkDeviceSignature = true,
    Random? random,
  }) : _steps = _SrpSteps(srpPrivateKey),
       _seed = _bytesOr(longTermSeed, () => _randomBytes(random, 32)),
       _pairingId = _bytesOr(pairingId, () => utf8.encode(_randomUuid(random)));

  final String? _name;
  final _SrpSteps _steps;
  final Uint8List _seed;
  final Uint8List _pairingId;
  final bool checkDeviceSignature;
  Uint8List? _encryptKey;

  /// M1: Method = pair-setup, State = 1.
  Uint8List get m1 => writeTlv8({
    TlvType.method: [TlvMethod.pairSetup],
    TlvType.state: [1],
  });

  /// Reads M2 (the device's salt and SRP public key); null when it was
  /// usable. The device shows its PIN about now.
  HapFailure? readM2(List<int> body) => _steps.readM2(body);

  /// M3 for [pin] (the digits as the TV shows them): our SRP public key
  /// and proof.
  HapResult<Uint8List> m3(String pin) => _steps.m3(pin);

  /// Reads M4: the device's proof; null when it checked out. A wrong PIN
  /// is [HapAuthenticationFailed].
  HapFailure? readM4(List<int> body) => _steps.readM4(body);

  /// M5: our pairing identifier, long-term public key and signature (and
  /// the name given, as pyatv's OPACK `{"name": …}`), encrypted with
  /// "PS-Msg05".
  Future<HapResult<Uint8List>> m5() async {
    final key = _steps.sessionKey;
    if (key == null) return const HapFailed(HapBadMessage('M5 before M4'));
    final signSalt = await hapHkdf(
      key,
      'Pair-Setup-Controller-Sign-Salt',
      'Pair-Setup-Controller-Sign-Info',
    );
    final encryptKey = await hapHkdf(
      key,
      'Pair-Setup-Encrypt-Salt',
      'Pair-Setup-Encrypt-Info',
    );
    final keyPair = await _ed25519.newKeyPairFromSeed(_seed);
    final publicKey = (await keyPair.extractPublicKey()).bytes;
    final signature = await _ed25519.sign([
      ...signSalt,
      ..._pairingId,
      ...publicKey,
    ], keyPair: keyPair);
    final name = _name;
    final inner = writeTlv8({
      TlvType.identifier: _pairingId,
      TlvType.publicKey: publicKey,
      TlvType.signature: signature.bytes,
      if (name != null && name.isNotEmpty) TlvType.name: _opackName(name),
    });
    _encryptKey = encryptKey;
    return HapOk(
      writeTlv8({
        TlvType.state: [5],
        TlvType.encryptedData: hapSeal(encryptKey, 'PS-Msg05', inner),
      }),
    );
  }

  /// Reads M6: decrypts the device's identifier, long-term public key and
  /// signature ("PS-Msg06") and checks the signature; the credentials to
  /// keep.
  Future<HapResult<HapCredentials>> readM6(List<int> body) async {
    final key = _encryptKey;
    final sessionKey = _steps.sessionKey;
    if (key == null || sessionKey == null) {
      return const HapFailed(HapBadMessage('M6 before M5'));
    }
    final items = readTlv8(body);
    if (_deviceFailure(items) case final failure?) return HapFailed(failure);
    final encrypted = items[TlvType.encryptedData];
    if (encrypted == null) {
      return const HapFailed(HapBadMessage('M6 without encrypted data'));
    }
    final plain = hapOpen(key, 'PS-Msg06', encrypted);
    if (plain == null) {
      return const HapFailed(HapVerificationFailed("M6 doesn't decrypt"));
    }
    final inner = readTlv8(plain);
    final deviceId = inner[TlvType.identifier];
    final ltpk = inner[TlvType.publicKey];
    final signature = inner[TlvType.signature];
    if (deviceId == null || deviceId.isEmpty || ltpk?.length != 32) {
      return const HapFailed(HapBadMessage('M6 without an identifier or key'));
    }
    if (checkDeviceSignature) {
      final signSalt = await hapHkdf(
        sessionKey,
        'Pair-Setup-Accessory-Sign-Salt',
        'Pair-Setup-Accessory-Sign-Info',
      );
      final signed = await hapVerify(ltpk!, [
        ...signSalt,
        ...deviceId,
        ...ltpk,
      ], signature ?? const []);
      if (!signed) {
        return const HapFailed(
          HapVerificationFailed("the device's M6 signature is wrong"),
        );
      }
    }
    return HapOk(
      HapCredentials(
        deviceLtpk: ltpk!,
        ltsk: _seed,
        deviceId: deviceId,
        pairingId: _pairingId,
      ),
    );
  }
}

/// Transient pair-setup (pyatv's `hap_transient.py`): M1 … M4 with the
/// fixed PIN "3939" and Flags = transient, no PIN on screen, nothing to
/// keep. The SRP session key K is the [HapSharedSecret]. POST an empty
/// body to `/pair-pin-start`, then [m1] and [m3] to `/pair-setup`, all
/// with [airPlayTransientPairingHeaders].
final class HapTransientPairSetup {
  new({BigInt? srpPrivateKey}) : _steps = _SrpSteps(srpPrivateKey);

  /// The PIN every transient pairing uses (pyatv's `TRANSIENT_PIN`).
  static const pin = '3939';

  final _SrpSteps _steps;

  /// M1: Method = pair-setup, State = 1, Flags = transient.
  Uint8List get m1 => writeTlv8({
    TlvType.method: [TlvMethod.pairSetup],
    TlvType.state: [1],
    TlvType.flags: [TlvFlags.transient],
  });

  /// Reads M2; null when it was usable.
  HapFailure? readM2(List<int> body) => _steps.readM2(body);

  /// M3: our SRP public key and proof for [pin].
  HapResult<Uint8List> m3() => _steps.m3(pin);

  /// Reads M4 and checks the device's proof: the shared secret (K).
  HapResult<HapSharedSecret> readM4(List<int> body) {
    if (_steps.readM4(body) case final failure?) return HapFailed(failure);
    return HapOk(HapSharedSecret(_steps.sessionKey!));
  }
}

/// Pair-verify with stored [credentials] (HAP §5.7; pyatv's
/// `AirPlayHapPairVerifyProcedure`): POST [m1] and then [m3] to
/// `/pair-verify` with [airPlayPairingHeaders], handing the answers to
/// [readM2] and [readM4]. [readM4] gives the [HapSharedSecret]; every
/// byte after it on that connection is framed by a `HapSession` with its
/// [HapSharedSecret.controlKeys].
final class HapPairVerify {
  new(this.credentials, {List<int>? ephemeralSeed, Random? random})
    : _ephemeralSeed = _bytesOr(ephemeralSeed, () => _randomBytes(random, 32));

  final HapCredentials credentials;
  final Uint8List _ephemeralSeed;
  SimpleKeyPair? _keyPair;
  Uint8List? _publicKey;
  Uint8List? _devicePublic;
  Uint8List? _shared;
  Uint8List? _sessionKey;
  var _sentM3 = false;

  /// M1: State = 1 and a new X25519 public key.
  Future<Uint8List> m1() async {
    final keyPair = await _x25519.newKeyPairFromSeed(_ephemeralSeed);
    final publicKey = Uint8List.fromList(
      (await keyPair.extractPublicKey()).bytes,
    );
    _keyPair = keyPair;
    _publicKey = publicKey;
    return writeTlv8({
      TlvType.state: [1],
      TlvType.publicKey: publicKey,
    });
  }

  /// Reads M2: the device's X25519 key, and its identifier and signature
  /// encrypted with "PV-Msg02". Null when the identifier is the paired
  /// device's and the signature verifies with its stored key.
  Future<HapFailure?> readM2(List<int> body) async {
    final keyPair = _keyPair;
    final ourPublic = _publicKey;
    if (keyPair == null || ourPublic == null) {
      return const HapBadMessage('M2 before M1');
    }
    final items = readTlv8(body);
    if (_deviceFailure(items) case final failure?) return failure;
    final devicePublic = items[TlvType.publicKey];
    final encrypted = items[TlvType.encryptedData];
    if (devicePublic == null ||
        devicePublic.length != 32 ||
        encrypted == null) {
      return const HapBadMessage('M2 without a public key or encrypted data');
    }
    final shared = await (await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(devicePublic, type: KeyPairType.x25519),
    )).extractBytes();
    if (shared.every((byte) => byte == 0)) {
      return const HapVerificationFailed("the device's key is degenerate");
    }
    final sessionKey = await hapHkdf(
      shared,
      'Pair-Verify-Encrypt-Salt',
      'Pair-Verify-Encrypt-Info',
    );
    final plain = hapOpen(sessionKey, 'PV-Msg02', encrypted);
    if (plain == null) {
      return const HapVerificationFailed("M2 doesn't decrypt");
    }
    final inner = readTlv8(plain);
    final deviceId = inner[TlvType.identifier];
    final signature = inner[TlvType.signature];
    if (deviceId == null || signature == null) {
      return const HapBadMessage('M2 without an identifier or signature');
    }
    if (!sameBytes(deviceId, credentials.deviceId)) {
      return const HapVerificationFailed('another device answered');
    }
    final signed = await hapVerify(credentials.deviceLtpk, [
      ...devicePublic,
      ...deviceId,
      ...ourPublic,
    ], signature);
    if (!signed) {
      return const HapVerificationFailed("the device's M2 signature is wrong");
    }
    _devicePublic = devicePublic;
    _shared = Uint8List.fromList(shared);
    _sessionKey = sessionKey;
    return null;
  }

  /// M3: our pairing identifier and our signature over our key, that
  /// identifier and the device's key, encrypted with "PV-Msg03".
  Future<HapResult<Uint8List>> m3() async {
    final sessionKey = _sessionKey;
    final ourPublic = _publicKey;
    final devicePublic = _devicePublic;
    if (sessionKey == null || ourPublic == null || devicePublic == null) {
      return const HapFailed(HapBadMessage('M3 before M2'));
    }
    if (credentials.ltsk.length != 32) {
      return const HapFailed(HapBadMessage('the stored key is unusable'));
    }
    final signature = await hapSign(credentials.ltsk, [
      ...ourPublic,
      ...credentials.pairingId,
      ...devicePublic,
    ]);
    final inner = writeTlv8({
      TlvType.identifier: credentials.pairingId,
      TlvType.signature: signature,
    });
    _sentM3 = true;
    return HapOk(
      writeTlv8({
        TlvType.state: [3],
        TlvType.encryptedData: hapSeal(sessionKey, 'PV-Msg03', inner),
      }),
    );
  }

  /// Reads M4: the device took our signature (no Error item). The shared
  /// secret the connection's keys come from.
  HapResult<HapSharedSecret> readM4(List<int> body) {
    final shared = _shared;
    if (!_sentM3 || shared == null) {
      return const HapFailed(HapBadMessage('M4 before M3'));
    }
    if (_deviceFailure(readTlv8(body)) case final failure?) {
      return HapFailed(failure);
    }
    return HapOk(HapSharedSecret(shared));
  }
}

/// HKDF-SHA512 of [secret] with the ASCII [salt] and [info], 32 bytes
/// (pyatv's `hkdf_expand`).
Future<Uint8List> hapHkdf(List<int> secret, String salt, String info) async {
  final key = await _hkdf.deriveKey(
    secretKey: SecretKey(secret),
    nonce: utf8.encode(salt),
    info: utf8.encode(info),
  );
  return Uint8List.fromList(key.bytes);
}

/// [plaintext] sealed with ChaCha20-Poly1305 under [key] and the 8-byte
/// ASCII [nonce] ("PS-Msg05"), padded in front with 4 zero bytes to 12
/// (pyatv's `Chacha20Cipher8byteNonce`): the ciphertext, then the 16-byte
/// tag.
Uint8List hapSeal(List<int> key, String nonce, List<int> plaintext) {
  final box = _aead.encryptSync(
    plaintext,
    secretKey: SecretKeyData(key),
    nonce: _pairingNonce(nonce),
  );
  return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
}

/// [sealed] (ciphertext then tag) opened as [hapSeal] sealed it; null when
/// it is too short or its tag is wrong.
Uint8List? hapOpen(List<int> key, String nonce, List<int> sealed) {
  if (sealed.length < 16) return null;
  final split = sealed.length - 16;
  try {
    return Uint8List.fromList(
      _aead.decryptSync(
        SecretBox(
          sealed.sublist(0, split),
          nonce: _pairingNonce(nonce),
          mac: Mac(sealed.sublist(split)),
        ),
        secretKey: SecretKeyData(key),
      ),
    );
  } on SecretBoxAuthenticationError {
    return null;
  }
}

/// [message] signed with the Ed25519 key whose 32-byte seed is [seed].
Future<Uint8List> hapSign(List<int> seed, List<int> message) async {
  final keyPair = await _ed25519.newKeyPairFromSeed(seed);
  final signature = await _ed25519.sign(message, keyPair: keyPair);
  return Uint8List.fromList(signature.bytes);
}

/// Whether [signature] is [publicKey]'s Ed25519 signature of [message];
/// false for keys or signatures of the wrong shape, never a throw.
Future<bool> hapVerify(
  List<int> publicKey,
  List<int> message,
  List<int> signature,
) async {
  if (publicKey.length != 32 || signature.length != 64) return false;
  try {
    return await _ed25519.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  } on Object {
    return false;
  }
}

/// The SRP half both pair-setups share: M2, M3, M4.
final class _SrpSteps {
  new(this._privateKey);

  static const _username = 'Pair-Setup';

  final BigInt? _privateKey;
  Uint8List? _salt;
  Uint8List? _serverPublic;
  SrpSession? _session;
  var _proven = false;

  /// K, once the device's M4 proof checked out.
  Uint8List? get sessionKey => _proven ? _session?.sessionKey : null;

  HapFailure? readM2(List<int> body) {
    final items = readTlv8(body);
    if (_deviceFailure(items) case final failure?) return failure;
    final salt = items[TlvType.salt];
    final serverPublic = items[TlvType.publicKey];
    if (salt == null || salt.isEmpty || serverPublic == null) {
      return const HapBadMessage('M2 without a salt or public key');
    }
    _salt = salt;
    _serverPublic = serverPublic;
    return null;
  }

  HapResult<Uint8List> m3(String pin) {
    final salt = _salt;
    final serverPublic = _serverPublic;
    if (salt == null || serverPublic == null) {
      return const HapFailed(HapBadMessage('M3 before M2'));
    }
    final session = SrpClient(
      username: _username,
      password: pin,
      privateKey: _privateKey,
    ).answer(salt, serverPublic);
    if (session == null) {
      return const HapFailed(
        HapVerificationFailed("the device's SRP key is unusable"),
      );
    }
    _session = session;
    _proven = false;
    return HapOk(
      writeTlv8({
        TlvType.state: [3],
        TlvType.publicKey: session.publicKey,
        TlvType.proof: session.proof,
      }),
    );
  }

  HapFailure? readM4(List<int> body) {
    final session = _session;
    if (session == null) return const HapBadMessage('M4 before M3');
    final items = readTlv8(body);
    if (_deviceFailure(items) case final failure?) return failure;
    final proof = items[TlvType.proof];
    if (proof == null) return const HapBadMessage('M4 without a proof');
    if (!session.checkServerProof(proof)) {
      return const HapVerificationFailed("the device's SRP proof is wrong");
    }
    _proven = true;
    return null;
  }
}

/// The device's Error item, if it sent one, as a failure.
HapFailure? _deviceFailure(Map<int, Uint8List> items) {
  final error = items[TlvType.error];
  if (error == null) return null;
  final code = readTlvInt(error) ?? 0;
  return switch (code) {
    TlvErrorCode.authentication => const HapAuthenticationFailed(),
    TlvErrorCode.backOff => HapBackOff(readTlvInt(items[TlvType.backOff]) ?? 0),
    TlvErrorCode.maxPeers => const HapMaxPeers(),
    TlvErrorCode.maxTries => const HapMaxTries(),
    TlvErrorCode.unavailable => const HapUnavailable(),
    TlvErrorCode.busy => const HapBusy(),
    _ => HapUnknownError(code),
  };
}

/// pyatv's OPACK `{"name": name}`: a one-entry dictionary (0xE1) of short
/// strings (0x40 + length, or 0x61/0x62 and a little-endian length), a
/// value equal to the key written as a back-reference to it (0xA0).
Uint8List _opackName(String name) {
  final List<int> value;
  if (name == 'name') {
    value = const [0xA0];
  } else {
    var text = utf8.encode(name);
    if (text.length > 0xFFFF) text = text.sublist(0, 0xFFFF);
    value = text.length <= 0x20
        ? [0x40 + text.length, ...text]
        : text.length <= 0xFF
        ? [0x61, text.length, ...text]
        : [0x62, text.length & 0xFF, text.length >> 8, ...text];
  }
  return Uint8List.fromList([0xE1, 0x44, ...utf8.encode('name'), ...value]);
}

List<int> _pairingNonce(String nonce) => [0, 0, 0, 0, ...ascii.encode(nonce)];

Uint8List _bytesOr(List<int>? given, List<int> Function() otherwise) =>
    Uint8List.fromList(given ?? otherwise());

List<int> _randomBytes(Random? random, int length) {
  final source = random ?? Random.secure();
  return [for (var i = 0; i < length; i++) source.nextInt(256)];
}

/// A random (version 4) UUID's lower-case text, as Python's
/// `str(uuid.uuid4())`.
String _randomUuid(Random? random) {
  final bytes = _randomBytes(random, 16);
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final hex = _hex(bytes);
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List? _unhex(String text) {
  final hex = text.trim();
  if (hex.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(hex)) {
    return null;
  }
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

final _ed25519 = DartEd25519();
const _x25519 = DartX25519();
const _aead = DartChacha20.poly1305Aead();
const _hkdf = DartHkdf(hmac: DartHmac(DartSha512()), outputLength: 32);
