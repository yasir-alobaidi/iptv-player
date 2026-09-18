/// Cleaning for text and URLs as providers send them, shared by the Xtream
/// client and the M3U parser (docs/02 "Quirks the parser MUST tolerate").
library;

final _entity = RegExp('&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);');
final _whitespace = RegExp(r'[\s\u00a0\u2000-\u200b\u3000]+');

const _namedEntities = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

/// A provider's display text made presentable: HTML entities decoded
/// (`&amp;`, `&#39;`, `&#x2019;`), the U+FFFD that malformed UTF-8 decodes
/// to dropped, whitespace runs collapsed, the ends trimmed. Null when
/// nothing is left.
String? cleanText(String? input) {
  if (input == null || input.isEmpty) return null;
  final decoded = input.replaceAllMapped(_entity, (m) {
    final body = m[1]!;
    if (body.startsWith('#')) {
      final hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final code = int.tryParse(
        hex ? body.substring(2) : body.substring(1),
        radix: hex ? 16 : 10,
      );
      // Out of range, a surrogate, or NUL: leave the entity as it was.
      if (code == null ||
          code <= 0 ||
          code > 0x10ffff ||
          (code >= 0xd800 && code <= 0xdfff)) {
        return m[0]!;
      }
      return String.fromCharCode(code);
    }
    return _namedEntities[body.toLowerCase()] ?? m[0]!;
  });
  final cleaned = decoded
      .replaceAll('\ufffd', ' ')
      .replaceAll(_whitespace, ' ')
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

/// An artwork URL, or null when it isn't one worth requesting: not
/// http(s), no host, or a placeholder panels use for "none". The UI draws
/// a generated tile instead (docs/02 "junk stream_icon").
String? cleanImageUrl(String? input) {
  final text = input?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  // `http://host/` alone, with nothing to fetch.
  if (uri.path.isEmpty || uri.path == '/') return null;
  return text;
}
