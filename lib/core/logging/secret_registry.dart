import 'package:iptv_player/core/logging/redact.dart';

/// Exact secret values (source usernames, passwords, tokens) that logs
/// remove even where no pattern recognizes them. The credential store adds
/// values when it loads them and removes them when a source is deleted.
final class SecretRegistry {
  final Set<String> _values = {};

  Iterable<String> get values => _values;

  /// Values shorter than [minSecretLength] are ignored.
  void add(String value) {
    if (value.length >= minSecretLength) _values.add(value);
  }

  void remove(String value) => _values.remove(value);
}
