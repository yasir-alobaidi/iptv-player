/// The generated catalogue and its Xtream JSON shapes (docs/02 "Xtream
/// Codes API").
///
/// Value quirks (a mangled name, a junk icon, a dangling category) are baked
/// in by the generator, which knows each item's index. Representation quirks
/// (numbers as strings, `""` for null, `info: []`, episodes as a map) are
/// applied here by [JsonShape], so one item can be serialized either way.
library;

import 'dart:convert';

import 'package:fake_provider/artwork.dart';
import 'package:fake_provider/profile.dart';

/// Applies the representation quirks of one profile.
class JsonShape {
  const new(this.quirks, {this.origin});

  /// No quirks: what a well-behaved panel sends.
  static const clean = JsonShape(FakeQuirks());

  final FakeQuirks quirks;

  /// `http://host:port` as the client reached the server: artwork URLs
  /// point there. Without one they keep the generator's unresolvable host.
  final String? origin;

  /// An artwork URL that may be missing, on this server when it is ours.
  Object? image(String? url) =>
      text(origin == null ? url : artworkFor(url, origin!));

  /// A number, as an int/double or as its string form.
  Object number(num value) => quirks.numbersAsStrings ? '$value' : value;

  /// A number that may be missing.
  Object? maybeNumber(num? value) => value == null ? _absent : number(value);

  /// An Xtream boolean: `1`/`0`, or `"1"`/`"0"` with the quirk on.
  Object flag({required bool value}) =>
      quirks.numbersAsStrings ? (value ? '1' : '0') : (value ? 1 : 0);

  /// Text that may be missing.
  Object? text(String? value) => value ?? _absent;

  /// A unix-seconds timestamp. Xtream panels send these as strings even
  /// without the quirk, so `added` is a string either way.
  String timestamp(DateTime value) => '${value.millisecondsSinceEpoch ~/ 1000}';

  /// `get_vod_info.info` / `get_series_info.info`: a map, or `[]`.
  Object info(Map<String, Object?> value) =>
      quirks.infoAsEmptyList ? const <Object?>[] : value;

  Object? get _absent => quirks.emptyStringForNull ? '' : null;
}

/// Base64, as `get_short_epg` sends titles and descriptions.
String b64(String value) => base64.encode(utf8.encode(value));

class FakeCategory {
  const new({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson(JsonShape shape) => {
    'category_id': id,
    'category_name': name,
    'parent_id': shape.number(0),
  };
}

class FakeChannel {
  const new({
    required this.streamId,
    required this.number,
    required this.name,
    required this.icon,
    required this.epgChannelId,
    required this.categoryId,
    required this.added,
    required this.archiveDays,
    required this.sample,
  });

  final int streamId;
  final int number;
  final String name;

  /// `null` when the provider has no icon for the channel.
  final String? icon;

  /// `null` for a channel with no EPG.
  final String? epgChannelId;

  /// `null` → Uncategorized, or a category no list contains (a quirk).
  final String? categoryId;

  final DateTime added;

  /// 0 means no catch-up.
  final int archiveDays;

  /// The media sample this channel's stream loops, e.g.
  /// `h264_1080p50_aac.ts` (tools/media_samples).
  final String sample;

  Map<String, Object?> toJson(JsonShape shape) => {
    'num': shape.number(number),
    'name': name,
    'stream_type': 'live',
    'stream_id': shape.number(streamId),
    'stream_icon': shape.image(icon),
    'epg_channel_id': shape.text(epgChannelId),
    'added': shape.timestamp(added),
    'category_id': shape.text(categoryId),
    'custom_sid': shape.text(null),
    'tv_archive': shape.flag(value: archiveDays > 0),
    'direct_source': '',
    'tv_archive_duration': shape.number(archiveDays),
  };
}

class FakeMovie {
  const new({
    required this.streamId,
    required this.number,
    required this.name,
    required this.icon,
    required this.rating,
    required this.categoryId,
    required this.added,
    required this.containerExtension,
    required this.year,
    required this.plot,
    required this.cast,
    required this.director,
    required this.genre,
    required this.durationSecs,
    required this.sample,
    this.backdrop,
    this.probed = true,
  });

  final int streamId;
  final int number;
  final String name;
  final String? icon;

  /// `null` when the panel has none (`backdrop_path: []`).
  final String? backdrop;

  /// Whether `get_vod_info` carries the `video` / `audio` blocks a panel
  /// writes after probing the file; many movies have none.
  final bool probed;

  /// 0–10, `null` for an unrated movie.
  final double? rating;
  final String? categoryId;
  final DateTime added;

  /// `mp4` or `mkv`.
  final String containerExtension;
  final int year;
  final String plot;
  final String cast;
  final String director;
  final String genre;
  final int durationSecs;

  /// The VOD sample this movie serves (tools/media_samples).
  final String sample;

  String get duration {
    final h = durationSecs ~/ 3600;
    final m = (durationSecs % 3600) ~/ 60;
    final s = durationSecs % 60;
    return '$h:${'$m'.padLeft(2, '0')}:${'$s'.padLeft(2, '0')}';
  }

  Map<String, Object?> toJson(JsonShape shape) => {
    'num': shape.number(number),
    'name': name,
    'stream_type': 'movie',
    'stream_id': shape.number(streamId),
    'stream_icon': shape.image(icon),
    'rating': shape.maybeNumber(rating),
    'rating_5based': shape.maybeNumber(
      rating == null ? null : (rating! / 2 * 10).round() / 10,
    ),
    'added': shape.timestamp(added),
    'category_id': shape.text(categoryId),
    'container_extension': containerExtension,
    'custom_sid': shape.text(null),
    'direct_source': '',
  };

  /// `action=get_vod_info`: `info` plus the list row as `movie_data`. A
  /// probed movie carries ffprobe's `video` and `audio` streams and a
  /// `bitrate` (kb/s), as panels store them; an unprobed one `[]` and 0.
  Map<String, Object?> toInfoJson(JsonShape shape) {
    final probe = probed ? vodProbes[sample] : null;
    return {
      'info': shape.info({
        'movie_image': shape.image(icon),
        'plot': plot,
        'cast': cast,
        'director': director,
        'genre': genre,
        'releasedate': '$year-01-01',
        'rating': shape.maybeNumber(rating),
        'duration_secs': shape.number(durationSecs),
        'duration': duration,
        'backdrop_path': [if (backdrop != null) shape.image(backdrop)],
        'youtube_trailer': '',
        'video': probe?.videoJson(shape) ?? const <Object?>[],
        'audio': probe?.audioJson(shape) ?? const <Object?>[],
        'bitrate': shape.number(probe?.bitrateKbps ?? 0),
      }),
      'movie_data': toJson(shape),
    };
  }
}

class FakeSeries {
  const new({
    required this.seriesId,
    required this.number,
    required this.name,
    required this.cover,
    required this.rating,
    required this.categoryId,
    required this.year,
    required this.plot,
    required this.genre,
    required this.cast,
    required this.director,
    required this.lastModified,
    required this.seasonCount,
    this.backdrop,
  });

  final int seriesId;
  final int number;
  final String name;
  final String? cover;

  /// `null` when the panel has none (`backdrop_path: []`).
  final String? backdrop;
  final double? rating;
  final String? categoryId;
  final int year;
  final String plot;
  final String genre;
  final String cast;
  final String director;
  final DateTime lastModified;
  final int seasonCount;

  Map<String, Object?> toJson(JsonShape shape) => {
    'num': shape.number(number),
    'name': name,
    'series_id': shape.number(seriesId),
    'cover': shape.image(cover),
    'plot': plot,
    'cast': cast,
    'director': director,
    'genre': genre,
    'releaseDate': '$year-01-01',
    'last_modified': shape.timestamp(lastModified),
    'rating': shape.maybeNumber(rating),
    'rating_5based': shape.maybeNumber(
      rating == null ? null : (rating! / 2 * 10).round() / 10,
    ),
    'backdrop_path': [if (backdrop != null) shape.image(backdrop)],
    'youtube_trailer': '',
    'episode_run_time': shape.number(45),
    'category_id': shape.text(categoryId),
  };

  Map<String, Object?> seasonJson(JsonShape shape, int season, int episodes) =>
      {
        'air_date': '$year-0${season.clamp(1, 9)}-01',
        'episode_count': shape.number(episodes),
        'id': shape.number(seriesId * 100 + season),
        'name': 'Season $season',
        'overview': '',
        'season_number': shape.number(season),
        'cover': shape.image(cover),
      };
}

class FakeEpisode {
  const new({
    required this.id,
    required this.season,
    required this.episode,
    required this.title,
    required this.containerExtension,
    required this.durationSecs,
    required this.plot,
    required this.still,
    required this.added,
    required this.sample,
  });

  final int id;
  final int season;
  final int episode;
  final String title;
  final String containerExtension;
  final int durationSecs;
  final String plot;
  final String? still;
  final DateTime added;
  final String sample;

  Map<String, Object?> toJson(JsonShape shape) => {
    'id': '$id',
    'episode_num': shape.number(episode),
    'title': title,
    'container_extension': containerExtension,
    'info': shape.info({
      'duration_secs': shape.number(durationSecs),
      'duration':
          '${durationSecs ~/ 3600}:'
          '${'${(durationSecs % 3600) ~/ 60}'.padLeft(2, '0')}:'
          '${'${durationSecs % 60}'.padLeft(2, '0')}',
      'plot': plot,
      'movie_image': shape.image(still),
      'rating': shape.number(0),
    }),
    'custom_sid': shape.text(null),
    'added': shape.timestamp(added),
    'season': shape.number(season),
    'direct_source': '',
  };
}

/// What ffprobe says about a VOD sample, in the `get_vod_info` shape
/// panels store (tools/media_samples/generate.sh makes these files).
class VodProbe {
  const new({
    required this.videoCodec,
    required this.width,
    required this.height,
    required this.audioCodec,
    required this.channels,
    required this.channelLayout,
    required this.bitrateKbps,
  });

  final String videoCodec;
  final int width;
  final int height;
  final String audioCodec;
  final int channels;
  final String channelLayout;
  final int bitrateKbps;

  Map<String, Object?> videoJson(JsonShape shape) => {
    'index': shape.number(0),
    'codec_name': videoCodec,
    'codec_type': 'video',
    'width': shape.number(width),
    'height': shape.number(height),
    'display_aspect_ratio': '16:9',
    'pix_fmt': 'yuv420p',
    'r_frame_rate': '25/1',
  };

  Map<String, Object?> audioJson(JsonShape shape) => {
    'index': shape.number(1),
    'codec_name': audioCodec,
    'codec_type': 'audio',
    'sample_rate': '48000',
    'channels': shape.number(channels),
    'channel_layout': channelLayout,
  };
}

/// The VOD samples, as ffprobe reads them.
const vodProbes = <String, VodProbe>{
  'vod_h264_aac_10min.mp4': VodProbe(
    videoCodec: 'h264',
    width: 1920,
    height: 1080,
    audioCodec: 'aac',
    channels: 2,
    channelLayout: 'stereo',
    bitrateKbps: 2628,
  ),
  'vod_h264_ac3_10min.mkv': VodProbe(
    videoCodec: 'h264',
    width: 1920,
    height: 1080,
    audioCodec: 'ac3',
    channels: 6,
    channelLayout: '5.1(side)',
    bitrateKbps: 2884,
  ),
  'vod_hevc_eac3_subs.mkv': VodProbe(
    videoCodec: 'hevc',
    width: 1920,
    height: 1080,
    audioCodec: 'eac3',
    channels: 6,
    channelLayout: '5.1(side)',
    bitrateKbps: 2884,
  ),
};

class FakeProgramme {
  const new({
    required this.id,
    required this.epgChannelId,
    required this.streamId,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  final int id;
  final String epgChannelId;
  final int streamId;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  /// `action=get_short_epg` — title and description are base64 (docs/02).
  Map<String, Object?> toShortEpgJson(JsonShape shape, {required bool now}) {
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();
    return {
      'id': '$id',
      'epg_id': '1',
      'title': b64(title),
      'lang': 'en',
      'start': _fmt(startUtc),
      'end': _fmt(endUtc),
      'description': b64(description),
      'channel_id': epgChannelId,
      'start_timestamp': '${startUtc.millisecondsSinceEpoch ~/ 1000}',
      'stop_timestamp': '${endUtc.millisecondsSinceEpoch ~/ 1000}',
      'now_playing': shape.flag(value: now),
      'has_archive': shape.flag(value: false),
    };
  }

  static String _fmt(DateTime utc) {
    String p(int v) => '$v'.padLeft(2, '0');
    return '${utc.year}-${p(utc.month)}-${p(utc.day)} '
        '${p(utc.hour)}:${p(utc.minute)}:${p(utc.second)}';
  }
}
