import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// What a [HapSession] read gave.
sealed class HapReadResult {
  const new();
}

/// The plaintext of every frame the bytes so far completed, in order;
/// empty while a frame is still arriving.
final class HapPlaintext extends HapReadResult {
  const new(this.bytes);

  final Uint8List bytes;
}

/// A frame's tag didn't check out (a wrong key, a lost or reordered
/// frame, corruption): nothing read after it can be trusted, so the
/// session stays failed.
final class HapReadFailed extends HapReadResult {
  const new(this.reason);

  final String reason;

  @override
  String toString() => 'HapReadFailed($reason)';
}

/// The encryption on an AirPlay connection once pair-verify (or a
/// transient pair-setup) is done, both ways (HAP §6.5.2; pyatv's
/// `HAPSession`).
///
/// What is sent goes in frames of at most [maxBlock] plaintext bytes:
/// the block's length as 2 bytes little-endian, then the block sealed
/// with ChaCha20-Poly1305 under the write key (that length as the additional
/// data), then the 16-byte tag. The 12-byte nonce is 4 zero bytes and a
/// 64-bit little-endian count of the frames sent so far (pyatv's
/// `Chacha20Cipher` with its 8-byte nonce). What arrives is read the
/// same way under the read key, with its own count, from any chunking
/// TCP gives: a frame across several reads, several frames in one.
final class HapSession {
  new({required List<int> writeKey, required List<int> readKey})
    : _writeKey = SecretKeyData(Uint8List.fromList(writeKey)),
      _readKey = SecretKeyData(Uint8List.fromList(readKey));

  /// The most plaintext one frame carries (HAP's 1024).
  static const maxBlock = 1024;
  static const tagLength = 16;

  final SecretKeyData _writeKey;
  final SecretKeyData _readKey;
  final _pending = BytesBuilder(copy: false);
  var _writeCount = 0;
  var _readCount = 0;
  var _failed = false;

  /// True once a frame failed to authenticate.
  bool get failed => _failed;

  /// [plaintext] as frames to send; nothing for nothing.
  Uint8List encrypt(List<int> plaintext) {
    final out = BytesBuilder(copy: false);
    for (var start = 0; start < plaintext.length; start += maxBlock) {
      final block = plaintext.sublist(
        start,
        min(start + maxBlock, plaintext.length),
      );
      final length = Uint8List(2)
        ..[0] = block.length & 0xFF
        ..[1] = block.length >> 8;
      final box = _aead.encryptSync(
        block,
        secretKey: _writeKey,
        nonce: _nonce(_writeCount++),
        aad: length,
      );
      out
        ..add(length)
        ..add(box.cipherText)
        ..add(box.mac.bytes);
    }
    return out.takeBytes();
  }

  /// Adds received [bytes] and returns the plaintext of every frame they
  /// complete.
  HapReadResult decrypt(List<int> bytes) {
    if (_failed) return const HapReadFailed('an earlier frame failed');
    _pending.add(bytes);
    final data = _pending.takeBytes();
    final out = BytesBuilder(copy: false);
    var offset = 0;
    while (data.length - offset >= 2) {
      final length = data[offset] | (data[offset + 1] << 8);
      final end = offset + 2 + length + tagLength;
      if (data.length < end) break;
      final cipherEnd = offset + 2 + length;
      try {
        out.add(
          _aead.decryptSync(
            SecretBox(
              Uint8List.sublistView(data, offset + 2, cipherEnd),
              nonce: _nonce(_readCount),
              mac: Mac(Uint8List.sublistView(data, cipherEnd, end)),
            ),
            secretKey: _readKey,
            aad: Uint8List.sublistView(data, offset, offset + 2),
          ),
        );
      } on SecretBoxAuthenticationError {
        _failed = true;
        return HapReadFailed('frame $_readCount did not authenticate');
      }
      _readCount++;
      offset = end;
    }
    if (offset < data.length) {
      _pending.add(Uint8List.sublistView(data, offset));
    }
    return HapPlaintext(out.takeBytes());
  }

  static Uint8List _nonce(int count) {
    final nonce = Uint8List(12);
    ByteData.sublistView(nonce).setUint64(4, count, Endian.little);
    return nonce;
  }

  @override
  String toString() => 'HapSession(<keys>)';
}

const _aead = DartChacha20.poly1305Aead();
