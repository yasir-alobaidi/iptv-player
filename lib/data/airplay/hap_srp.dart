import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The numbers an SRP-6a exchange runs on (RFC 5054): the group's prime
/// N and generator g, and the hash H.
///
/// Every formula is the one pyatv gets from srptools 1.0.1, the version
/// it pins, byte for byte, because pyatv pairs with real AirPlay devices:
///
/// - k = H(N | PAD(g)), u = H(PAD(A) | PAD(B)): padded to N's length;
/// - x = H(s | H(I | ":" | P)): the salt's bytes exactly as the device
///   sent them, leading zeros kept;
/// - K = H(S), M1 = H(H(N) xor H(g) | H(I) | s | A | B | K) and
///   M2 = H(A | M1 | K): every number (S, A, B, the xor, H(I)) in its
///   shortest big-endian bytes (srptools' `int_to_bytes`), the salt and K
///   as bytes.
///
/// The shortest bytes and the padded ones differ only for a number whose
/// top byte is zero (1 in 256). [SrpClient] picks its private key so that
/// A and S never have one, which leaves both readings agreeing on
/// everything but the device's own B.
final class SrpGroup {
  new({required this.prime, required this.generator, required this.hash})
    : length = (prime.bitLength + 7) ~/ 8;

  /// RFC 5054's 3072-bit group (appendix A, group 4), g = 5, with SHA-512:
  /// HAP pair-setup's (pyatv's `constants.PRIME_3072`).
  static final hap = SrpGroup(
    prime: BigInt.parse(_prime3072, radix: 16),
    generator: BigInt.from(5),
    hash: sha512,
  );

  final BigInt prime;
  final BigInt generator;
  final Hash hash;

  /// N's length in bytes: what PAD() pads to.
  final int length;

  /// [value]'s big-endian bytes left-padded with zeros to N's [length]
  /// (PAD()).
  Uint8List pad(BigInt value) {
    final bytes = srpBytes(value);
    if (bytes.length >= length) return bytes;
    return Uint8List(length)..setRange(length - bytes.length, length, bytes);
  }

  /// H of [parts] one after another.
  Uint8List digest(List<List<int>> parts) {
    final all = BytesBuilder(copy: false);
    parts.forEach(all.add);
    return Uint8List.fromList(hash.convert(all.takeBytes()).bytes);
  }

  /// k = H(N | PAD(g)).
  late final BigInt multiplier = srpInt(
    digest([srpBytes(prime), pad(generator)]),
  );

  /// x = H(s | H(I | ":" | P)).
  BigInt passwordHash(List<int> salt, String username, String password) {
    final inner = digest([utf8.encode('$username:$password')]);
    return srpInt(digest([salt, inner]));
  }

  /// v = g^x mod N.
  BigInt verifier(BigInt passwordHash) => generator.modPow(passwordHash, prime);

  /// A = g^a mod N.
  BigInt clientPublic(BigInt privateKey) => generator.modPow(privateKey, prime);

  /// B = (k·v + g^b) mod N.
  BigInt serverPublic(BigInt verifier, BigInt privateKey) =>
      (multiplier * verifier + generator.modPow(privateKey, prime)) % prime;

  /// u = H(PAD(A) | PAD(B)).
  BigInt scrambler(BigInt clientPublic, BigInt serverPublic) =>
      srpInt(digest([pad(clientPublic), pad(serverPublic)]));

  /// The client's S = (B − k·g^x)^(a + u·x) mod N.
  BigInt clientSecret({
    required BigInt serverPublic,
    required BigInt privateKey,
    required BigInt passwordHash,
    required BigInt scrambler,
  }) {
    final base = (serverPublic - multiplier * verifier(passwordHash)) % prime;
    return base.modPow(privateKey + scrambler * passwordHash, prime);
  }

  /// The server's S = (A·v^u)^b mod N.
  BigInt serverSecret({
    required BigInt clientPublic,
    required BigInt verifier,
    required BigInt privateKey,
    required BigInt scrambler,
  }) => (clientPublic * verifier.modPow(scrambler, prime) % prime).modPow(
    privateKey,
    prime,
  );

  /// K = H(S).
  Uint8List sessionKey(BigInt secret) => digest([srpBytes(secret)]);

  /// M1 = H(H(N) xor H(g) | H(I) | s | A | B | K): the client's proof.
  Uint8List clientProof({
    required String username,
    required List<int> salt,
    required BigInt clientPublic,
    required BigInt serverPublic,
    required List<int> sessionKey,
  }) => digest([
    srpBytes(_groupHash),
    srpBytes(srpInt(digest([utf8.encode(username)]))),
    salt,
    srpBytes(clientPublic),
    srpBytes(serverPublic),
    sessionKey,
  ]);

  /// M2 = H(A | M1 | K): the server's proof.
  Uint8List serverProof({
    required BigInt clientPublic,
    required List<int> clientProof,
    required List<int> sessionKey,
  }) => digest([srpBytes(clientPublic), clientProof, sessionKey]);

  /// H(N) xor H(g), each hashed from its shortest bytes.
  late final BigInt _groupHash =
      srpInt(digest([srpBytes(prime)])) ^ srpInt(digest([srpBytes(generator)]));
}

/// [value]'s big-endian bytes with no leading zeros; zero is one zero
/// byte (srptools' `int_to_bytes`).
Uint8List srpBytes(BigInt value) {
  if (value <= BigInt.zero) return Uint8List(1);
  final bytes = Uint8List((value.bitLength + 7) ~/ 8);
  var rest = value;
  final mask = BigInt.from(0xFF);
  for (var i = bytes.length - 1; i >= 0; i--) {
    bytes[i] = (rest & mask).toInt();
    rest >>= 8;
  }
  return bytes;
}

/// [bytes] read as a big-endian unsigned number.
BigInt srpInt(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte & 0xFF);
  }
  return value;
}

/// The client side of one SRP-6a exchange, as HAP pair-setup runs it
/// (pyatv's `SRPAuthHandler` over srptools): [username] is "Pair-Setup",
/// the password the PIN the device shows ("3939" for transient pairing).
final class SrpClient {
  new({
    required this.username,
    required this._password,
    SrpGroup? group,
    this._privateKey,
    Random? random,
  }) : _group = group ?? SrpGroup.hap,
       _random = random ?? Random.secure();

  final String username;
  final String _password;
  final SrpGroup _group;
  final BigInt? _privateKey;
  final Random _random;

  /// Answers the device's [salt] and public key B ([serverPublic], its
  /// bytes as sent); null when B is no use (B mod N is zero, which
  /// srptools refuses too).
  ///
  /// With no private key given, a new 32-byte one (pyatv's size) is
  /// drawn, again (up to 32 times, so a B that makes S small for every
  /// key can't stall it) until A and S both fill N's length.
  SrpSession? answer(List<int> salt, List<int> serverPublic) {
    final group = _group;
    final b = srpInt(serverPublic);
    if (b % group.prime == BigInt.zero) return null;
    final x = group.passwordHash(salt, username, _password);
    for (var draw = 1; ; draw++) {
      final a = _privateKey ?? _drawPrivateKey();
      final publicKey = group.clientPublic(a);
      final u = group.scrambler(publicKey, b);
      final secret = group.clientSecret(
        serverPublic: b,
        privateKey: a,
        passwordHash: x,
        scrambler: u,
      );
      final full =
          srpBytes(publicKey).length == group.length &&
          srpBytes(secret).length == group.length;
      if (!full && _privateKey == null && draw < 32) continue;
      final key = group.sessionKey(secret);
      final proof = group.clientProof(
        username: username,
        salt: salt,
        clientPublic: publicKey,
        serverPublic: b,
        sessionKey: key,
      );
      return SrpSession._(
        publicKey: srpBytes(publicKey),
        proof: proof,
        sessionKey: key,
        serverProof: group.serverProof(
          clientPublic: publicKey,
          clientProof: proof,
          sessionKey: key,
        ),
      );
    }
  }

  BigInt _drawPrivateKey() =>
      srpInt([for (var i = 0; i < 32; i++) _random.nextInt(256)]);
}

/// The client's half of a finished SRP exchange.
final class SrpSession {
  new _({
    required this.publicKey,
    required this.proof,
    required this.sessionKey,
    required this._serverProof,
  });

  /// A, in its shortest bytes (as pyatv sends it).
  final Uint8List publicKey;

  /// M1.
  final Uint8List proof;

  /// K, the 64-byte secret both sides now share. Never log it.
  final Uint8List sessionKey;

  final Uint8List _serverProof;

  /// Whether [serverProof] is the device's M2 = H(A | M1 | K), compared
  /// in constant time.
  bool checkServerProof(List<int> serverProof) =>
      sameBytes(serverProof, _serverProof);

  @override
  String toString() => 'SrpSession(<secret>)';
}

/// Whether [a] and [b] hold the same bytes, in time that depends only on
/// their lengths.
bool sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= (a[i] ^ b[i]) & 0xFF;
  }
  return difference == 0;
}

const _prime3072 =
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74'
    '020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437'
    '4FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
    'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF05'
    '98DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB'
    '9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B'
    'E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718'
    '3995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33'
    'A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7'
    'ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864'
    'D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E2'
    '08E24FA074E5AB3143DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF';
