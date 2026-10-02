import 'dart:convert';

import 'package:iptv_player/core/cast/stream_facts.dart';

/// ffprobe's `-print_format json -show_format -show_streams`, read
/// tolerantly (hard rule 1): numbers as numbers or strings, `N/A`, fields
/// missing or of the wrong type, stream types it doesn't know. Null when
/// it isn't a JSON object at all; facts with neither a picture nor a
/// sound when it lists none.
StreamFacts? readFfprobeJson(String text) {
  Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (json is! Map) return null;
  final streams = json['streams'];
  final format = json['format'];

  VideoFacts? video;
  final audio = <AudioFacts>[];
  for (final stream in streams is List ? streams : const <Object?>[]) {
    if (stream is! Map) continue;
    switch (_text(stream['codec_type'])) {
      case 'video':
        // Cover art in an MP4, MKV or MP3 is a "video" of one picture.
        final disposition = stream['disposition'];
        final cover =
            disposition is Map &&
            (_int(disposition['attached_pic']) == 1 ||
                _int(disposition['still_image']) == 1);
        if (video == null && !cover) video = _video(stream);
      case 'audio':
        // Every audio stream counts, readable or not: FFmpeg's `0:a:<n>`
        // numbers them all.
        audio.add(_audio(stream, audio.length));
    }
  }

  final formatMap = format is Map ? format : const <Object?, Object?>{};
  final seconds = _double(formatMap['duration']);
  return StreamFacts(
    origin: StreamFactsOrigin.probe,
    container: _container(_text(formatMap['format_name'])),
    video: video,
    audio: audio,
    // Up to a year: anything longer is nonsense.
    duration: seconds == null || seconds <= 0 || seconds > 366 * 86400
        ? null
        : Duration(milliseconds: (seconds * 1000).round()),
    bitRate: _positive(_int(formatMap['bit_rate'])),
  );
}

VideoFacts _video(Map<Object?, Object?> stream) {
  final pixelFormat = _text(stream['pix_fmt']);
  return VideoFacts(
    codec: _codec(stream['codec_name']),
    profile: _profile(stream['profile']),
    width: _positive(_int(stream['width'])),
    height: _positive(_int(stream['height'])),
    fps: _rate(stream['avg_frame_rate']) ?? _rate(stream['r_frame_rate']),
    interlaced: switch (_text(stream['field_order'])) {
      'progressive' => false,
      'tt' || 'bb' || 'tb' || 'bt' => true,
      _ => null,
    },
    bitDepth:
        _bitDepth(pixelFormat) ??
        _positive(_int(stream['bits_per_raw_sample'])),
    bitRate: _positive(_int(stream['bit_rate'])),
  );
}

AudioFacts _audio(Map<Object?, Object?> stream, int index) {
  final tags = stream['tags'];
  final disposition = stream['disposition'];
  String? tag(String name) {
    if (tags is! Map) return null;
    // Matroska writes some tags in upper case.
    return _text(tags[name]) ?? _text(tags[name.toUpperCase()]);
  }

  final language = tag('language')?.toLowerCase();
  return AudioFacts(
    index: index,
    codec: _codec(stream['codec_name']),
    channels:
        _positive(_int(stream['channels'])) ??
        channelCount(_text(stream['channel_layout'])),
    language: language == 'und' ? null : language,
    title: tag('title'),
    isDefault: disposition is Map && _int(disposition['default']) == 1,
    bitRate: _positive(_int(stream['bit_rate'])),
  );
}

MediaContainer? _container(String? formatName) {
  if (formatName == null) return null;
  final names = formatName.toLowerCase().split(',').map((n) => n.trim());
  if (names.contains('mpegts')) return MediaContainer.mpegTs;
  if (names.contains('hls') || names.contains('applehttp')) {
    return MediaContainer.hls;
  }
  if (names.contains('mp4') || names.contains('mov')) {
    return MediaContainer.mp4;
  }
  if (names.contains('matroska') || names.contains('webm')) {
    return MediaContainer.matroska;
  }
  return MediaContainer.other;
}

String? _codec(Object? value) {
  final name = _text(value)?.toLowerCase();
  return name == 'none' ? null : name;
}

String? _profile(Object? value) {
  final profile = _text(value);
  return profile?.toLowerCase() == 'unknown' ? null : profile;
}

/// `yuv420p10le` → 10, `p010le` → 10; any other pixel format is 8 bits.
int? _bitDepth(String? pixelFormat) {
  if (pixelFormat == null) return null;
  final deep = RegExp(r'(9|10|12|14|16)(le|be)$').firstMatch(pixelFormat);
  return deep == null ? 8 : int.parse(deep.group(1)!);
}

/// `50/1`, `30000/1001`; `0/0` and nonsense are null.
double? _rate(Object? value) {
  final text = _text(value);
  if (text == null) return null;
  final parts = text.split('/');
  final top = double.tryParse(parts.first.trim());
  final bottom = parts.length == 2 ? double.tryParse(parts[1].trim()) : 1.0;
  if (top == null || bottom == null || bottom == 0) return null;
  final rate = top / bottom;
  if (!rate.isFinite || rate <= 0 || rate > 300) return null;
  return (rate * 1000).round() / 1000;
}

/// A string with something in it, trimmed; `N/A` is nothing.
String? _text(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty || text == 'N/A' ? null : text;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is double) return _finite(value)?.round();
  final text = _text(value);
  if (text == null) return null;
  return int.tryParse(text) ?? _finite(double.tryParse(text))?.round();
}

double? _double(Object? value) {
  if (value is num) return _finite(value.toDouble());
  final text = _text(value);
  return text == null ? null : _finite(double.tryParse(text));
}

/// Within ±2⁵³, where a double is still a whole number exactly.
double? _finite(double? value) =>
    value == null || !value.isFinite || value.abs() > 9007199254740992
    ? null
    : value;

int? _positive(int? value) => value == null || value <= 0 ? null : value;
