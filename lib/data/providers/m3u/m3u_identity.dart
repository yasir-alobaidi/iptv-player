/// Stable identities and episode numbering for M3U entries, which have no
/// ids of their own (docs/02).
library;

import 'dart:convert';

import 'package:iptv_player/data/providers/m3u/m3u_models.dart';

// Xtream-style stream paths: /live/{user}/{pass}/{rest}.
final _xtreamPath = RegExp(
  r'^/?(live|movie|series|timeshift)/[^/]+/[^/]+/(.+)$',
  caseSensitive: false,
);

/// The part of a stream URL that identifies it and nothing else: the
/// path, without the query, and with an Xtream path's two credential
/// segments dropped (`/live/u/p/42.ts` → `/live/42.ts`) whether or not
/// they were templated. So a new password, a rotated token or another
/// load-balanced host keeps the same identity.
String identityPath(String streamUrl) {
  final uri = Uri.tryParse(streamUrl);
  final path = uri?.path ?? streamUrl.split('?').first;
  final match = _xtreamPath.firstMatch(path);
  if (match != null) return '/${match[1]!.toLowerCase()}/${match[2]}';
  return path;
}

/// The entry's `remote_key`: FNV-1a (64-bit) over `tvg-id`, the name and
/// [identityPath], newline-separated (none of them can hold one), as 16
/// hex digits. FNV rather than a cryptographic hash: it is pure Dart,
/// stable across runs and platforms, fast enough for 250k lines, and a
/// collision within one playlist is vanishingly unlikely — and would show
/// up as a skipped duplicate, not as a wrong channel.
String entryIdentity({
  required String? tvgId,
  required String name,
  required String streamUrl,
}) {
  var hash = _fnvOffset;
  for (final byte in utf8.encode(
    '${tvgId ?? ''}\n$name\n${identityPath(streamUrl)}',
  )) {
    hash ^= byte;
    hash *= _fnvPrime;
  }
  // Two 32-bit halves: a VM int is signed, so a hash with the top bit set
  // would otherwise print as negative hex.
  String half(int bits) =>
      (bits & 0xffffffff).toRadixString(16).padLeft(8, '0');
  return '${half(hash >> 32)}${half(hash)}';
}

// 64-bit FNV-1a. Dart VM ints are 64-bit and wrap on overflow, which is
// exactly the arithmetic FNV wants (this code never runs on the web).
// ignore: avoid_js_rounded_ints
const _fnvOffset = 0xcbf29ce484222325;
const _fnvPrime = 0x100000001b3;

const _videoExtensions = {'mp4', 'mkv', 'avi', 'mov', 'm4v', 'wmv', 'webm'};

/// The kind of entry [streamUrl] points at: by path (docs/02), then by a
/// video-file extension (a plain VOD list has no `/movie/`).
M3uKind classify(String streamUrl) {
  final path = (Uri.tryParse(streamUrl)?.path ?? streamUrl).toLowerCase();
  if (path.contains('/series/')) return M3uKind.episode;
  if (path.contains('/movie/')) return M3uKind.movie;
  final dot = path.lastIndexOf('.');
  if (dot >= 0 && _videoExtensions.contains(path.substring(dot + 1))) {
    return M3uKind.movie;
  }
  return M3uKind.live;
}

// "Dark S01 E02", "Dark - S1E2", "Dark 1x02", "Dark Season 1 Episode 2".
final _numbering = <RegExp>[
  RegExp(r'^(.*?)[\s._-]*S(\d{1,3})[\s._-]*E(\d{1,4})\b', caseSensitive: false),
  RegExp(r'^(.*?)[\s._-]*\b(\d{1,2})x(\d{1,3})\b', caseSensitive: false),
  RegExp(
    r'^(.*?)[\s._-]*Season\s*(\d{1,3})\s*[,._-]?\s*Episode\s*(\d{1,4})\b',
    caseSensitive: false,
  ),
];

/// The series, season and episode an episode's name gives, or null when
/// it gives none.
({String series, int season, int episode})? parseEpisodeName(String name) {
  for (final pattern in _numbering) {
    final match = pattern.firstMatch(name);
    if (match == null) continue;
    final series = match[1]!.replaceAll(RegExp(r'[\s._-]+$'), '').trim();
    if (series.isEmpty) continue;
    return (
      series: series,
      season: int.parse(match[2]!),
      episode: int.parse(match[3]!),
    );
  }
  return null;
}
