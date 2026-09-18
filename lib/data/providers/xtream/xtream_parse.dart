/// Xtream responses → models. Pure top-level functions, so the client can
/// run them in a background isolate for big bodies (hard rule 2).
///
/// A row that can't be used (not an object, no id, a repeated id) is
/// counted in `skipped` and dropped. A row with a bad field keeps the row
/// and loses the field. Nothing here throws except [decodeJsonBytes] on a
/// body that isn't JSON at all, which the client reports as a
/// `ParseFailure`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/provider_text.dart';
import 'package:iptv_player/data/providers/xtream/tolerant_json.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';

/// UTF-8 with malformed sequences replaced, not rejected (docs/02), then
/// JSON. A leading BOM is ignored. Throws [FormatException] for a body
/// that isn't JSON — an HTML error page served with a 200, say.
Object? decodeJsonBytes(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('\ufeff')) text = text.substring(1);
  return jsonDecode(text);
}

/// The account call. `auth: 0` is how a panel says the username or
/// password is wrong — with a 200 (docs/02, ADR-008).
Result<XtreamAccount> parseAccount(Object? json) {
  final root = readMap(json);
  final user = readMap(root['user_info']);
  if (user.isEmpty) {
    return Err(ParseFailure('no user_info: not an Xtream panel'));
  }
  if (readBool(user['auth']) == false) {
    return Err(AuthFailure('the panel answered auth: 0'));
  }
  final server = readMap(root['server_info']);
  final formats = user['allowed_output_formats'];
  return Ok(
    XtreamAccount(
      status: readText(user['status']),
      expiresAt: readUnixTime(user['exp_date']),
      isTrial: readBool(user['is_trial']) ?? false,
      activeConnections: readInt(user['active_cons']),
      maxConnections: readInt(user['max_connections']),
      createdAt: readUnixTime(user['created_at']),
      allowedOutputFormats: [
        if (formats is List<Object?>)
          for (final format in formats)
            if (readString(format) case final f?) f.toLowerCase(),
      ],
      serverTimezone: readString(server['timezone']),
      serverTime: readUnixTime(server['timestamp_now']),
    ),
  );
}

XtreamRows<XtreamCategory> parseCategories(Object? json) => _rows(
  json,
  'category_id',
  (row, id) => XtreamCategory(
    id: id,
    name: readText(row['category_name']) ?? 'Category $id',
  ),
);

XtreamRows<XtreamChannel> parseChannels(Object? json) =>
    _rows(json, 'stream_id', (row, id) {
      final number = readInt(row['num']);
      final archive = readBool(row['tv_archive']) ?? false;
      return XtreamChannel(
        streamId: id,
        name: readText(row['name']) ?? 'Channel ${number ?? id}',
        number: number,
        iconUrl: cleanImageUrl(readString(row['stream_icon'])),
        epgChannelId: readString(row['epg_channel_id']),
        categoryId: readString(row['category_id']),
        archiveDays: archive
            ? (readInt(row['tv_archive_duration']) ?? 0).clamp(0, 365)
            : 0,
        addedAt: readUnixTime(row['added']),
      );
    });

XtreamRows<XtreamMovie> parseMovies(Object? json) =>
    _rows(json, 'stream_id', (row, id) {
      final name = readText(row['name']) ?? 'Movie $id';
      return XtreamMovie(
        streamId: id,
        name: name,
        number: readInt(row['num']),
        posterUrl: cleanImageUrl(readString(row['stream_icon'])),
        rating: _rating(row['rating']),
        year:
            readYear(row['year']) ??
            readYear(row['releaseDate'] ?? row['release_date']) ??
            _yearInName(name),
        ext: _extension(row['container_extension']),
        categoryId: readString(row['category_id']),
        addedAt: readUnixTime(row['added']),
      );
    });

XtreamRows<XtreamSeries> parseSeries(Object? json) =>
    _rows(json, 'series_id', (row, id) {
      final name = readText(row['name']) ?? 'Series $id';
      return XtreamSeries(
        seriesId: id,
        name: name,
        number: readInt(row['num']),
        posterUrl: cleanImageUrl(readString(row['cover'])),
        rating: _rating(row['rating']),
        year:
            readYear(row['year']) ??
            readYear(row['releaseDate'] ?? row['release_date']) ??
            _yearInName(name),
        plot: readText(row['plot']),
        genre: readText(row['genre']),
        categoryId: readString(row['category_id']),
        lastModified: readUnixTime(row['last_modified']),
      );
    });

/// `{}` for an unknown movie and `info: []` for one without metadata both
/// read as an info with nothing in it.
XtreamMovieInfo parseMovieInfo(Object? json) {
  final root = readMap(json);
  final info = readMap(root['info']);
  final data = readMap(root['movie_data']);
  return XtreamMovieInfo(
    plot: readText(info['plot'] ?? info['description']),
    cast: readText(info['cast'] ?? info['actors']),
    director: readText(info['director']),
    genre: readText(info['genre']),
    runtimeMinutes: _runtimeMinutes(info),
    backdropUrl: readImage(info['backdrop_path']),
    posterUrl: readImage(info['movie_image'] ?? info['cover_big']),
    year: readYear(info['releasedate'] ?? info['release_date'] ?? info['year']),
    rating: _rating(info['rating']),
    ext: _extension(data['container_extension']),
  );
}

/// Episodes arrive as a list, or as a map keyed by season number; in a
/// map the key stands in for a missing `season`.
XtreamSeriesInfo parseSeriesInfo(Object? json) {
  final root = readMap(json);
  final raw = root['episodes'];
  final groups = <(int?, Object?)>[
    if (raw is Map<String, Object?>)
      for (final MapEntry(:key, :value) in raw.entries) (readInt(key), value)
    else
      (null, raw),
  ];

  final episodes = <XtreamEpisode>[];
  final seen = <String>{};
  var skipped = 0;
  for (final (seasonKey, rows) in groups) {
    for (final (index, row) in readRows(rows).indexed) {
      if (row is! Map<String, Object?>) {
        skipped++;
        continue;
      }
      final id = readString(row['id']);
      if (id == null || !seen.add(id)) {
        skipped++;
        continue;
      }
      final info = readMap(row['info']);
      final number = readInt(row['episode_num']) ?? index + 1;
      final duration = readInt(info['duration_secs']);
      episodes.add(
        XtreamEpisode(
          id: id,
          season: readInt(row['season']) ?? seasonKey ?? 1,
          episode: number,
          title: readText(row['title']) ?? 'Episode $number',
          ext: _extension(row['container_extension']),
          durationSeconds: duration != null && duration > 0 ? duration : null,
          plot: readText(info['plot']),
          stillUrl: readImage(info['movie_image']),
        ),
      );
    }
  }
  episodes.sort(
    (a, b) => a.season != b.season
        ? a.season.compareTo(b.season)
        : a.episode.compareTo(b.episode),
  );
  return XtreamSeriesInfo(episodes: episodes, skipped: skipped);
}

/// `get_short_epg`: titles and descriptions are base64 (docs/02). Times
/// come from the unix timestamps; the formatted strings are the panel's
/// local time, which the client can't know.
XtreamRows<XtreamEpgEntry> parseShortEpg(Object? json) {
  final items = <XtreamEpgEntry>[];
  var skipped = 0;
  for (final row in readRows(readMap(json)['epg_listings'])) {
    if (row is! Map<String, Object?>) {
      skipped++;
      continue;
    }
    final start = readUnixTime(row['start_timestamp']);
    final end = readUnixTime(row['stop_timestamp'] ?? row['end_timestamp']);
    final title = cleanText(_base64Text(readString(row['title'])));
    if (start == null || end == null || !end.isAfter(start) || title == null) {
      skipped++;
      continue;
    }
    items.add(
      XtreamEpgEntry(
        title: title,
        start: start,
        end: end,
        description: cleanText(_base64Text(readString(row['description']))),
      ),
    );
  }
  items.sort((a, b) => a.start.compareTo(b.start));
  return XtreamRows(items: items, skipped: skipped);
}

XtreamRows<T> _rows<T>(
  Object? json,
  String idKey,
  T Function(Map<String, Object?> row, String id) build,
) {
  final items = <T>[];
  final seen = <String>{};
  var skipped = 0;
  for (final row in readRows(json)) {
    if (row is! Map<String, Object?>) {
      skipped++;
      continue;
    }
    final id = readString(row[idKey]);
    // Panels repeat rows; the first one wins, as the provider lists it.
    if (id == null || !seen.add(id)) {
      skipped++;
      continue;
    }
    try {
      items.add(build(row, id));
    } on Object {
      // The readers don't throw; this is the backstop for hard rule 1.
      skipped++;
    }
  }
  return XtreamRows(items: items, skipped: skipped);
}

/// Out of 10. Panels send 0 or `""` for unrated, and a few send nonsense.
double? _rating(Object? value) {
  final rating = readDouble(value);
  return rating == null || rating <= 0 || rating > 10 ? null : rating;
}

final _extensionPattern = RegExp(r'^[a-z0-9]{2,5}$');

String? _extension(Object? value) {
  final ext = readString(value)?.toLowerCase().replaceFirst('.', '');
  return ext != null && _extensionPattern.hasMatch(ext) ? ext : null;
}

final _trailingYear = RegExp(r'[(\[](1[89]\d\d|2[01]\d\d)[)\]]\s*$');

int? _yearInName(String name) {
  final match = _trailingYear.firstMatch(name);
  return match == null ? null : int.parse(match[1]!);
}

int? _runtimeMinutes(Map<String, Object?> info) {
  final seconds = readInt(info['duration_secs']);
  if (seconds != null && seconds > 0) return (seconds / 60).round();
  final clock = readString(info['duration']);
  if (clock != null) {
    final parts = clock.split(':').map(int.tryParse).toList();
    if (parts.length == 3 && !parts.contains(null)) {
      final minutes = parts[0]! * 60 + parts[1]! + (parts[2]! >= 30 ? 1 : 0);
      if (minutes > 0) return minutes;
    }
  }
  final minutes = readInt(info['episode_run_time'] ?? info['runtime']);
  return minutes != null && minutes > 0 ? minutes : null;
}

/// Base64 when it is base64, the text itself when it isn't: some panels
/// forget to encode. Decoding is strict on purpose — plain text such as
/// `News` is valid base64 too, and what gives it away is that its bytes
/// aren't valid UTF-8.
String? _base64Text(String? value) {
  if (value == null) return null;
  try {
    return utf8.decode(base64.decode(value));
  } on FormatException {
    return value;
  }
}
