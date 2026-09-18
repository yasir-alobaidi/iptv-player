/// Keeping a playlist's credentials out of the stream URLs it contains
/// (hard rule 3).
///
/// An Xtream `get.php` export repeats the username and password in every
/// line's path (`/live/{u}/{p}/1.ts`). Stored as sent, a 50k-line playlist
/// would put the password in the database 50,000 times. So each known
/// value is swapped for a placeholder on the way in, and back at play
/// time from the secure store.
library;

/// The placeholder for a named secret, e.g. `{password}`. Braces can't
/// occur unescaped in a URL, so a placeholder never collides with data.
String placeholder(String name) => '{$name}';

/// Which query parameters carry which secret, by lower-cased name.
const _secretParams = <String, String>{
  'username': 'username',
  'user': 'username',
  'login': 'username',
  'password': 'password',
  'pass': 'password',
  'pwd': 'password',
  'passwd': 'password',
  'token': 'token',
};

const _priority = ['username', 'password', 'token'];

/// The secrets a playlist URL carries in its query:
/// `get.php?username=u&password=p` → `{username: u, password: p}`.
/// Values shorter than two characters are ignored: replacing every `1`
/// in every path would corrupt the URLs.
Map<String, String> playlistSecrets(String playlistUrl) {
  final uri = Uri.tryParse(playlistUrl.trim());
  if (uri == null) return const {};
  return {
    for (final MapEntry(:key, :value) in uri.queryParameters.entries)
      if (_secretParams[key.toLowerCase()] case final name?)
        if (value.length >= 2) name: value,
  };
}

/// [url] with each whole path segment or query value equal to a secret
/// replaced by that secret's placeholder. Only whole segments and values
/// are touched, so a secret that happens to be part of a channel id
/// doesn't mangle it. Everything else keeps its exact encoding.
String templateUrl(String url, Map<String, String> secrets) {
  if (secrets.isEmpty) return url;
  // One value, one placeholder: where two secrets share a value (a token
  // that is the password), the first in [_priority] names it, so the
  // result doesn't depend on map order.
  final byValue = <String, String>{};
  for (final name in [
    ..._priority.where(secrets.containsKey),
    ...secrets.keys.where((k) => !_priority.contains(k)),
  ]) {
    byValue.putIfAbsent(secrets[name]!, () => name);
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  // Uri.path is still percent-encoded; each part is decoded only to be
  // compared, and written back raw unless it is a secret.
  var changed = false;
  String swap(String raw) {
    final String decoded;
    try {
      decoded = Uri.decodeComponent(raw);
    } on Object {
      // Malformed percent-encoding: not a secret, leave it as it is.
      return raw;
    }
    final name = byValue[decoded];
    if (name == null) return raw;
    changed = true;
    return placeholder(name);
  }

  final path = uri.path.split('/').map(swap).join('/');
  final query = uri.hasQuery
      ? uri.query
            .split('&')
            .map((part) {
              final equals = part.indexOf('=');
              return equals < 0
                  ? part
                  : '${part.substring(0, equals + 1)}'
                        '${swap(part.substring(equals + 1))}';
            })
            .join('&')
      : null;
  if (!changed) return url;
  // Rebuilt by hand: Uri would percent-encode the braces.
  final authority = uri.hasAuthority ? '//${uri.authority}' : '';
  return '${uri.scheme}:$authority$path'
      '${query == null ? '' : '?$query'}'
      '${uri.hasFragment ? '#${uri.fragment}' : ''}';
}

/// The playable URL: each placeholder filled from [secrets], percent-
/// encoded for where it stands. A placeholder with no value is left as
/// it is, so the failure is visible rather than a silent wrong URL.
String fillUrl(String template, Map<String, String> secrets) {
  var url = template;
  for (final MapEntry(:key, :value) in secrets.entries) {
    url = url.replaceAll(placeholder(key), Uri.encodeComponent(value));
  }
  return url;
}
