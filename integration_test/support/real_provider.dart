// The login for the tests that play from the user's real provider
// (ADR-010 decision 1): opt-in, local only, and only after the user freed
// the account's one connection and said so.

import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

/// (server, username, password) when the login file
/// (~/.config/iptv-player-dev/real_provider.json or $IPTV_REAL_PROVIDER)
/// also says `"play": true`.
(String, String, String)? readPlayLogin() {
  final home = Platform.environment['HOME'] ?? '';
  final file = File(
    Platform.environment['IPTV_REAL_PROVIDER'] ??
        '$home/.config/iptv-player-dev/real_provider.json',
  );
  if (!file.existsSync()) return null;
  final json = jsonDecode(file.readAsStringSync());
  if (json is! Map || json['play'] != true) return null;
  final server = '${json['server'] ?? ''}'.trim();
  final username = '${json['username'] ?? ''}'.trim();
  final password = '${json['password'] ?? ''}';
  if ([server, username, password].any((v) => v.isEmpty)) return null;
  return (server, username, password);
}

/// The app log, already masked by `AppLog`, to a file.
final class LogFileOutput extends LogOutput {
  new(this._file) {
    _file.writeAsStringSync('');
  }

  final File _file;

  @override
  void output(OutputEvent event) => _file.writeAsStringSync(
    '${event.lines.join('\n')}\n',
    mode: FileMode.append,
  );
}
