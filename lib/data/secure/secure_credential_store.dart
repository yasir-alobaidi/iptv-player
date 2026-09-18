import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';

/// [CredentialStore] over flutter_secure_storage: libsecret (the GNOME
/// keyring or KWallet) on Linux; on Windows, an encrypted file whose AES
/// key lives in Credential Manager.
///
/// Every platform error — no secret service running, a locked keyring the
/// user declined to unlock, a denied prompt — becomes a
/// [SecureStorageFailure]. The detail is the plugin's message, which names
/// the failure but never the value.
final class SecureCredentialStore implements CredentialStore {
  new([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<Result<String?>> read(String key) =>
      _guard(() => _storage.read(key: key), 'read');

  @override
  Future<Result<void>> write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value), 'write');

  @override
  Future<Result<void>> delete(String key) =>
      _guard(() => _storage.delete(key: key), 'delete');

  @override
  Future<Result<Set<String>>> keys() =>
      _guard(() async => (await _storage.readAll()).keys.toSet(), 'list');

  Future<Result<T>> _guard<T>(Future<T> Function() body, String what) async {
    try {
      return Ok(await body());
    } on Object catch (error) {
      // Only the error's type and message: a PlatformException's `details`
      // could echo arguments back, and one of them is the secret.
      return Err(SecureStorageFailure('$what: ${_describe(error)}'));
    }
  }

  static String _describe(Object error) => switch (error) {
    PlatformException(:final code, :final message) => '$code $message',
    _ => error.runtimeType.toString(),
  };
}
