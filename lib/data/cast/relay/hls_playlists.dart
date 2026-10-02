// Plain Dart: used in the relay's isolate.

/// A provider's HLS playlist with every URI it names replaced by
/// [proxied]'s, so the segments, the variants and their keys come through
/// the relay's proxy too (Phase 7 decision 3). Relative URIs are resolved
/// against [base], the playlist's own URL after redirects. Lines that
/// aren't URIs pass as they are.
String rewritePlaylist(
  String text,
  Uri base,
  String Function(Uri absolute) proxied,
) {
  String resolve(String uri) {
    try {
      return proxied(base.resolve(uri.trim()));
    } on FormatException {
      return uri;
    }
  }

  final lines = text.split('\n');
  final out = StringBuffer();
  for (final (i, raw) in lines.indexed) {
    final crlf = raw.endsWith('\r');
    final line = crlf ? raw.substring(0, raw.length - 1) : raw;
    String rewritten;
    if (line.trim().isEmpty) {
      rewritten = line;
    } else if (line.startsWith('#')) {
      // EXT-X-KEY, EXT-X-MAP, EXT-X-MEDIA, EXT-X-I-FRAME-STREAM-INF…
      rewritten = line.replaceAllMapped(
        RegExp('URI="([^"]*)"'),
        (m) => 'URI="${resolve(m[1]!)}"',
      );
    } else {
      rewritten = resolve(line);
    }
    out.write(rewritten);
    if (crlf) out.write('\r');
    if (i < lines.length - 1) out.write('\n');
  }
  return out.toString();
}

/// Whether [text] is an HLS playlist (`#EXTM3U` first, a BOM allowed).
bool looksLikePlaylist(String text) =>
    text.replaceFirst('\ufeff', '').trimLeft().startsWith('#EXTM3U');

/// What the relay needs from the playlist FFmpeg writes: how many segments
/// it lists, and the newest.
final class HlsProgress {
  const new({required this.segments, this.newest, this.mediaSequence = 0});

  static const empty = HlsProgress(segments: 0);

  final int segments;

  /// The last segment's URI.
  final String? newest;
  final int mediaSequence;

  /// A new segment since [before].
  bool movedOn(HlsProgress before) =>
      newest != null &&
      (newest != before.newest || mediaSequence != before.mediaSequence);

  @override
  String toString() => 'HlsProgress($segments, newest $newest)';
}

/// Reads [text], a media playlist; tolerant, as FFmpeg 4.4 writes
/// `#EXT-X-PROGRAM-DATE-TIME` between a segment's `#EXTINF` and its URI
/// after an `append_list`.
HlsProgress readHlsProgress(String text) {
  var segments = 0;
  String? newest;
  var sequence = 0;
  var expectUri = false;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
      sequence = int.tryParse(line.substring(22).trim()) ?? 0;
    } else if (line.startsWith('#EXTINF')) {
      expectUri = true;
    } else if (!line.startsWith('#') && expectUri) {
      segments++;
      newest = line;
      expectUri = false;
    }
  }
  return HlsProgress(
    segments: segments,
    newest: newest,
    mediaSequence: sequence,
  );
}
