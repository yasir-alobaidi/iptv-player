import 'package:iptv_player/core/result.dart';

/// The one place secrets are kept (hard rule 3): the system keyring on
/// desktop. Values are opaque strings under keys the caller chooses; the
/// source repository stores one JSON document per source.
///
/// Nothing throws across this boundary: a keyring that is missing, locked
/// or refuses access comes back as a [SecureStorageFailure]. There is
/// deliberately no fallback to a file.
abstract interface class CredentialStore {
  Future<Result<String?>> read(String key);

  Future<Result<void>> write(String key, String value);

  /// Deleting a key that isn't there succeeds.
  Future<Result<void>> delete(String key);

  /// Every key this app has stored, for pruning orphans.
  Future<Result<Set<String>>> keys();
}

/// Holds secrets in memory only. For tests and CI, which have no keyring;
/// the app itself always uses the system store.
final class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = {};

  /// Makes every call fail as a locked keyring would.
  bool locked = false;

  /// A snapshot, so tests can assert what was stored.
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<Result<String?>> read(String key) async =>
      _unlessLocked(() => _values[key]);

  @override
  Future<Result<void>> write(String key, String value) async =>
      _unlessLocked(() => _values[key] = value);

  @override
  Future<Result<void>> delete(String key) async =>
      _unlessLocked(() => _values.remove(key));

  @override
  Future<Result<Set<String>>> keys() async =>
      _unlessLocked(() => _values.keys.toSet());

  Result<T> _unlessLocked<T>(T Function() body) => locked
      ? Err(SecureStorageFailure('the in-memory store is locked'))
      : Ok(body());
}
