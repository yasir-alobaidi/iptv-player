/// The M3U playlist parser (docs/02 "M3U"). It streams: bytes in, one
/// entry at a time out, so a 50 MB playlist is never held whole — only the
/// line being read. Run it off the UI isolate (the sync engine's isolate,
/// or `readM3uInBackground`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iptv_player/data/providers/m3u/m3u_credentials.dart';
import 'package:iptv_player/data/providers/m3u/m3u_identity.dart';
import 'package:iptv_player/data/providers/m3u/m3u_models.dart';
import 'package:iptv_player/data/providers/provider_text.dart';

/// Parses [bytes] — plain or gzip, detected by its magic number rather
/// than by a name — calling [onEntry] for each playable line, in order.
///
/// Tolerant throughout (hard rule 1): a missing `#EXTM3U`, CRLF or lone CR
/// line ends, a BOM, invalid UTF-8, unclosed quotes, unquoted attributes,
/// commas in titles and unknown directives (`#KODIPROP`, `#EXT-X-…`) are
/// all read or ignored. An `#EXTINF` with no URL, a URL that isn't one,
/// and a repeated identity are counted in [M3uSummary.skipped].
///
/// When [onEntry] returns a future, reading pauses until it completes, so
/// a caller writing entries to the database in batches holds one batch,
/// not the whole playlist. An error from that future ends the parse with
/// the same error.
///
/// [secrets] are replaced by placeholders in every stream URL
/// (`templateUrl`). Throws [FormatException] only when the body is plainly
/// not a playlist — an HTML or JSON error page — and passes on whatever
/// error [bytes] ends with.
Future<M3uSummary> parseM3u(
  Stream<List<int>> bytes,
  FutureOr<void> Function(M3uEntry entry) onEntry, {
  Map<String, String> secrets = const {},
}) async {
  final state = _ParseState(secrets, onEntry);
  final lines = gunzipIfNeeded(bytes)
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  final done = Completer<void>();
  late final StreamSubscription<String> subscription;
  void fail(Object error, StackTrace stackTrace) {
    unawaited(subscription.cancel());
    if (!done.isCompleted) done.completeError(error, stackTrace);
  }

  subscription = lines.listen(
    (line) {
      final Future<void>? pending;
      try {
        pending = state.line(line);
      } on Object catch (error, stackTrace) {
        fail(error, stackTrace);
        return;
      }
      // Not `await for`: most lines complete synchronously, and a paused
      // subscription costs nothing until a batch is actually written.
      if (pending != null) subscription.pause(pending.catchError(fail));
    },
    onError: fail,
    onDone: () {
      if (!done.isCompleted) done.complete();
    },
    cancelOnError: true,
  );
  await done.future;
  return state.finish();
}

/// [source], gunzipped when it starts with gzip's magic number (a
/// `.m3u.gz`, or a server that gzips without saying so). A body sent with
/// `Content-Encoding: gzip` is already unpacked by the HTTP client.
Stream<List<int>> gunzipIfNeeded(Stream<List<int>> source) async* {
  final iterator = StreamIterator(source);
  final head = <int>[];
  while (head.length < 2 && await iterator.moveNext()) {
    head.addAll(iterator.current);
  }
  if (head.isEmpty) return;

  Stream<List<int>> rest() async* {
    yield head;
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }

  final gzipped = head.length >= 2 && head[0] == 0x1f && head[1] == 0x8b;
  yield* gzipped ? gzip.decoder.bind(rest()) : rest();
}

/// Longer lines are junk (a binary file, a runaway attribute), not
/// entries.
const int _maxLineLength = 32 * 1024;

final class _ParseState {
  new(this.secrets, this.onEntry);

  final Map<String, String> secrets;
  final FutureOr<void> Function(M3uEntry entry) onEntry;

  var _first = true;
  var _entries = 0;
  var _live = 0;
  var _movies = 0;
  var _episodes = 0;
  var _skipped = 0;
  final _epgUrls = <String>[];
  final _seen = <String>{};

  _Info? _info;
  String? _group;
  String? _userAgent;
  String? _referrer;

  /// A future while [onEntry] is still handling the entry this line
  /// completed; null otherwise.
  Future<void>? line(String raw) {
    var line = raw.trim();
    if (_first && line.isNotEmpty) {
      if (line.startsWith('\ufeff')) line = line.substring(1).trimLeft();
      _first = false;
      // An error page served in place of the playlist.
      if (line.startsWith('<') || line.startsWith('{')) {
        throw const FormatException('not an M3U playlist');
      }
    }
    if (line.isEmpty) return null;
    if (line.length > _maxLineLength) {
      _skipped++;
      _reset();
      return null;
    }

    if (line.startsWith('#')) {
      _directive(line);
      return null;
    }
    return _url(line);
  }

  void _directive(String line) {
    final upper = line.length >= 12
        ? line.substring(0, 12).toUpperCase()
        : line.toUpperCase();
    if (upper.startsWith('#EXTINF:')) {
      if (_info != null) _skipped++; // the previous one never got a URL
      _info = _Info.parse(line.substring(8));
    } else if (upper.startsWith('#EXTM3U')) {
      if (_entries == 0) {
        final attributes = _attributes(line.substring(7), 0).attributes;
        for (final key in const ['url-tvg', 'x-tvg-url', 'tvg-url']) {
          for (final url in (attributes[key] ?? '').split(',')) {
            final trimmed = url.trim();
            if (trimmed.isNotEmpty && !_epgUrls.contains(trimmed)) {
              _epgUrls.add(trimmed);
            }
          }
        }
      }
    } else if (upper.startsWith('#EXTGRP:')) {
      _group = cleanText(line.substring(8));
    } else if (upper.startsWith('#EXTVLCOPT:')) {
      final option = line.substring(11);
      final equals = option.indexOf('=');
      if (equals < 0) return;
      final key = option.substring(0, equals).trim().toLowerCase();
      final value = option.substring(equals + 1).trim();
      if (value.isEmpty) return;
      if (key == 'http-user-agent') _userAgent = value;
      if (key == 'http-referrer' || key == 'http-referer') _referrer = value;
    }
    // Anything else (#KODIPROP, #EXT-X-…, comments) is ignored.
  }

  Future<void>? _url(String line) {
    final uri = Uri.tryParse(line);
    if (uri == null || !uri.hasScheme || !line.contains('://')) {
      _skipped++;
      _reset();
      return null;
    }
    final info = _info;
    final position = _entries;
    final name =
        cleanText(info?.title) ??
        cleanText(info?.attributes['tvg-name']) ??
        _fileName(uri) ??
        'Channel ${position + 1}';
    final tvgId = _blank(info?.attributes['tvg-id']);
    final streamUrl = templateUrl(line, secrets);
    final identity = entryIdentity(
      tvgId: tvgId,
      name: name,
      streamUrl: streamUrl,
    );
    if (!_seen.add(identity)) {
      _skipped++;
      _reset();
      return null;
    }

    final kind = classify(line);
    final numbering = kind == M3uKind.episode ? parseEpisodeName(name) : null;
    final attributes = info?.attributes ?? const {};
    final pending = onEntry(
      M3uEntry(
        identity: identity,
        kind: kind,
        name: name,
        streamUrl: streamUrl,
        position: position,
        tvgId: tvgId,
        tvgName: cleanText(attributes['tvg-name']),
        logoUrl: cleanImageUrl(attributes['tvg-logo']),
        group: cleanText(attributes['group-title']) ?? _group,
        channelNumber: int.tryParse(attributes['tvg-chno']?.trim() ?? ''),
        catchup: _blank(attributes['catchup'])?.toLowerCase(),
        catchupDays: int.tryParse(
          (attributes['catchup-days'] ?? attributes['timeshift'] ?? '').trim(),
        ),
        catchupSource: _blank(attributes['catchup-source']),
        userAgent: _userAgent,
        referrer: _referrer,
        seriesName: numbering?.series,
        season: numbering?.season,
        episode: numbering?.episode,
      ),
    );
    _entries++;
    switch (kind) {
      case M3uKind.live:
        _live++;
      case M3uKind.movie:
        _movies++;
      case M3uKind.episode:
        _episodes++;
    }
    _reset();
    return pending is Future<void> ? pending : null;
  }

  void _reset() {
    _info = null;
    _group = null;
    _userAgent = null;
    _referrer = null;
  }

  M3uSummary finish() {
    if (_info != null) _skipped++; // truncated after its last #EXTINF
    return M3uSummary(
      epgUrls: List.unmodifiable(_epgUrls),
      entries: _entries,
      live: _live,
      movies: _movies,
      episodes: _episodes,
      skipped: _skipped,
    );
  }

  static String? _fileName(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    if (segments.isEmpty) return null;
    final last = segments.last;
    final dot = last.lastIndexOf('.');
    return cleanText(dot > 0 ? last.substring(0, dot) : last);
  }

  static String? _blank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// A parsed `#EXTINF:` line: its attributes and its title.
final class _Info {
  const new(this.attributes, this.title);

  factory parse(String body) {
    // The duration comes first, up to a space or the title's comma.
    var i = 0;
    while (i < body.length && body[i] != ' ' && body[i] != ',') {
      i++;
    }
    final parsed = _attributes(body, i);
    return _Info(parsed.attributes, parsed.title);
  }

  final Map<String, String> attributes;
  final String? title;
}

/// `key="value"` pairs from [start], up to the first comma outside quotes;
/// what follows that comma is the title, commas and all. Keys are
/// lower-cased. Tolerated: single quotes, no quotes (`key=value`), and an
/// unclosed quote, which ends at the next comma instead of swallowing the
/// title.
({Map<String, String> attributes, String? title}) _attributes(
  String text,
  int start,
) {
  final attributes = <String, String>{};
  var i = start;
  final length = text.length;
  while (i < length) {
    final char = text[i];
    if (char == ',') {
      return (attributes: attributes, title: text.substring(i + 1));
    }
    if (char == ' ' || char == '\t') {
      i++;
      continue;
    }
    final keyStart = i;
    while (i < length &&
        text[i] != '=' &&
        text[i] != ' ' &&
        text[i] != ',' &&
        text[i] != '\t') {
      i++;
    }
    final key = text.substring(keyStart, i).toLowerCase();
    if (i >= length || text[i] != '=') continue; // a bare word: ignore it
    i++; // '='
    String value;
    if (i < length && (text[i] == '"' || text[i] == "'")) {
      final quote = text[i];
      final close = text.indexOf(quote, i + 1);
      if (close < 0) {
        // Unclosed: the value runs to the next comma, which starts the
        // title as usual.
        final comma = text.indexOf(',', i + 1);
        final end = comma < 0 ? length : comma;
        value = text.substring(i + 1, end);
        i = end;
      } else {
        value = text.substring(i + 1, close);
        i = close + 1;
      }
    } else {
      final valueStart = i;
      while (i < length &&
          text[i] != ' ' &&
          text[i] != ',' &&
          text[i] != '\t') {
        i++;
      }
      value = text.substring(valueStart, i);
    }
    if (key.isNotEmpty) attributes.putIfAbsent(key, () => value);
  }
  return (attributes: attributes, title: null);
}
