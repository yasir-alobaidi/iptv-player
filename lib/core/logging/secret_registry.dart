import 'package:iptv_player/core/logging/redact.dart';

/// Exact secret values (source usernames, passwords, tokens) that logs
/// remove even where no pattern recognizes them. The source repository
/// adds values whenever it handles them. Removing a source does not take
/// them out again: another source may share a value, and masking too much
/// is harmless where masking too little is not.
final class SecretRegistry {
  final Set<String> _values = {};

  Iterable<String> get values => _values;

  /// Values shorter than [minSecretLength] are ignored.
  void add(String value) {
    if (value.length >= minSecretLength) _values.add(value);
  }

  void remove(String value) => _values.remove(value);
}
