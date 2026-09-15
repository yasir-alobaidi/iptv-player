/// Replaces every credential [redact] finds.
const redactionMask = '***';

/// Shorter secrets aren't matched as plain text: they would mask ordinary
/// words. URL patterns still catch them inside stream and API URLs.
const minSecretLength = 3;

// URL user-info: scheme://user:password@host
final _userInfo = RegExp(
  r'\b([a-z][a-z0-9+.\-]*://)[^\s/?#@]+@',
  caseSensitive: false,
);

// Xtream stream paths: /live/{user}/{password}/..., also movie, series,
// and timeshift.
final _xtreamPath = RegExp(
  r'(/(?:live|movie|series|timeshift)/)[^\s/?#]+/[^\s/?#]+/',
  caseSensitive: false,
);

// Credential query parameters, also after HTML-escaped "&amp;".
final _queryParam = RegExp(
  '([?&;](?:password|passwd|pass|pwd|username|user|token|access_token|auth'
  r'|api_?key|key|signature|sig)=)[^&#\s"<>]*',
  caseSensitive: false,
);

// Auth headers, as text or inside a printed map or JSON.
final _authHeader = RegExp(
  r'((?:proxy-)?authorization|set-cookie|cookie|x-api-key)("?\s*[:=]\s*"?)'
  r'[^\r\n,}"]*',
  caseSensitive: false,
);

// JSON string fields such as Xtream's user_info.password.
final _jsonField = RegExp(
  r'("(?:password|passwd|username|token|access_token)"\s*:\s*")'
  r'(?:[^"\\]|\\.)*"',
  caseSensitive: false,
);

// Printed Dart maps: {username: bob, password: 1234}
final _mapField = RegExp(
  r'([{,]\s*(?:password|passwd|username)\s*:\s*)[^,}]*',
  caseSensitive: false,
);

/// Removes credentials from [input] before it reaches a log, an error
/// message, or a diagnostics export.
///
/// Patterns cover Xtream stream paths, credential query parameters, URL
/// user-info, auth headers, and credential fields in JSON or printed maps.
/// [secrets] adds exact values, such as a source's password, for places no
/// pattern recognizes (for example a panel that uses `/{user}/{pass}/{id}`).
/// The result is stable: redacting it again changes nothing.
String redact(String input, {Iterable<String> secrets = const []}) {
  if (input.isEmpty) return input;
  var out = input;

  final exact = secrets.where((s) => s.length >= minSecretLength).toSet()
    ..remove(redactionMask);
  for (final secret
      in exact.toList()..sort((a, b) => b.length.compareTo(a.length))) {
    out = out.replaceAll(secret, redactionMask);
    final encoded = Uri.encodeComponent(secret);
    if (encoded != secret) out = out.replaceAll(encoded, redactionMask);
  }

  return out
      .replaceAllMapped(_userInfo, (m) => '${m[1]}$redactionMask@')
      .replaceAllMapped(
        _xtreamPath,
        (m) => '${m[1]}$redactionMask/$redactionMask/',
      )
      .replaceAllMapped(_queryParam, (m) => '${m[1]}$redactionMask')
      .replaceAllMapped(_authHeader, (m) => '${m[1]}${m[2]}$redactionMask')
      .replaceAllMapped(_jsonField, (m) => '${m[1]}$redactionMask"')
      .replaceAllMapped(_mapField, (m) => '${m[1]}$redactionMask');
}
