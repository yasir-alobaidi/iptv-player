import 'dart:convert';

import 'package:iptv_player/core/library/library_media.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';

/// docs/09: 20 s a file.
const libraryProbeTimeout = Duration(seconds: 20);

/// ffprobe's answer for a library file, read: its length, picture,
/// sound and subtitle tracks and title tag. Never throws: a file ffprobe
/// can't read, or doesn't answer for in time, is unreadable.
Future<LibraryMedia> probeLibraryFile(
  ProcessSupervisor supervisor,
  String ffprobe,
  String path, {
  Duration timeout = libraryProbeTimeout,
}) async {
  final run = await supervisor.run(
    ffprobe,
    [
      ...['-hide_banner', '-v', 'error'],
      ...['-print_format', 'json', '-show_format', '-show_streams'],
      ...['-i', path],
    ],
    owner: 'ffprobe',
    timeout: timeout,
  );
  if (run.exitCode != 0 || run.timedOut) {
    return const LibraryMedia.unreadable();
  }
  return readLibraryProbe(utf8.decode(run.stdout, allowMalformed: true));
}

/// `-print_format json -show_format -show_streams`, read tolerantly (hard
/// rule 1): numbers as numbers or strings, `N/A`, missing fields, stream
/// kinds it doesn't know. A file with neither a picture nor a sound is
/// unreadable.
LibraryMedia readLibraryProbe(String text) {
  Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return const LibraryMedia.unreadable();
  }
  if (json is! Map) return const LibraryMedia.unreadable();
  final streams = json['streams'];
  final format = json['format'] is Map
      ? json['format'] as Map
      : const <Object?, Object?>{};

  LibraryVideo? video;
  final audio = <LibraryAudio>[];
  final subtitles = <LibrarySubtitle>[];
  for (final stream in streams is List ? streams : const <Object?>[]) {
    if (stream is! Map) continue;
    final tags = stream['tags'] is Map
        ? stream['tags'] as Map
        : const <Object?, Object?>{};
    final disposition = stream['disposition'] is Map
        ? stream['disposition'] as Map
        : const <Object?, Object?>{};
    String? tag(String name) =>
        _text(tags[name]) ?? _text(tags[name.toUpperCase()]);
    switch (_text(stream['codec_type'])) {
      case 'video':
        // Cover art is a "video" of one picture.
        if (video != null ||
            _int(disposition['attached_pic']) == 1 ||
            _int(disposition['still_image']) == 1) {
          continue;
        }
        final transfer = _text(stream['color_transfer']);
        video = LibraryVideo(
          codec: _text(stream['codec_name']),
          width: _positive(_int(stream['width'])),
          height: _positive(_int(stream['height'])),
          fps: _rate(stream['avg_frame_rate']) ?? _rate(stream['r_frame_rate']),
          interlaced: switch (_text(stream['field_order'])) {
            'progressive' => false,
            'tt' || 'bb' || 'tb' || 'bt' => true,
            _ => null,
          },
          bitDepth:
              _bitDepth(_text(stream['pix_fmt'])) ??
              _positive(_int(stream['bits_per_raw_sample'])),
          hdr: transfer == 'smpte2084' || transfer == 'arib-std-b67',
        );
      case 'audio':
        audio.add(
          LibraryAudio(
            codec: _text(stream['codec_name']),
            channels: _positive(_int(stream['channels'])),
            language: _language(tag('language')),
            title: tag('title'),
            isDefault: _int(disposition['default']) == 1,
          ),
        );
      case 'subtitle':
        subtitles.add(
          LibrarySubtitle(
            codec: _text(stream['codec_name']),
            language: _language(tag('language')),
            title: tag('title'),
            forced: _int(disposition['forced']) == 1,
            isDefault: _int(disposition['default']) == 1,
          ),
        );
    }
  }
  if (video == null && audio.isEmpty) return const LibraryMedia.unreadable();
  final seconds = _double(format['duration']);
  final tags = format['tags'];
  final formatTags = tags is Map ? tags : const <Object?, Object?>{};
  return LibraryMedia(
    container: _text(format['format_name'])?.split(',').first,
    // Up to a year: anything longer is nonsense.
    duration: seconds == null || seconds <= 0 || seconds > 366 * 86400
        ? null
        : Duration(milliseconds: (seconds * 1000).round()),
    video: video,
    audio: audio,
    subtitles: subtitles,
    title: _text(formatTags['title']) ?? _text(formatTags['TITLE']),
  );
}

String? _text(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty || text == 'N/A' || text == 'unknown' ? null : text;
}

int? _int(Object? value) => switch (value) {
  final int v => v,
  final double v when v.isFinite => v.round(),
  final String v => int.tryParse(v.trim()),
  _ => null,
};

double? _double(Object? value) => switch (value) {
  final num v when v.isFinite => v.toDouble(),
  final String v => double.tryParse(v.trim()),
  _ => null,
};

int? _positive(int? value) => value != null && value > 0 ? value : null;

/// `25/1` → 25, `30000/1001` → 29.97.
double? _rate(Object? value) {
  final text = _text(value);
  if (text == null) return null;
  final parts = text.split('/');
  final top = double.tryParse(parts.first);
  final bottom = parts.length > 1 ? double.tryParse(parts[1]) : 1;
  if (top == null || bottom == null || bottom == 0 || top <= 0) return null;
  final rate = top / bottom;
  return rate > 0 && rate < 1000 ? double.parse(rate.toStringAsFixed(3)) : null;
}

int? _bitDepth(String? pixelFormat) {
  if (pixelFormat == null) return null;
  final match = RegExp(r'p(\d{2})(le|be)$').firstMatch(pixelFormat);
  if (match != null) return int.parse(match[1]!);
  return RegExp('^(yuv|nv|gray)').hasMatch(pixelFormat) ? 8 : null;
}

/// `und` says nothing.
String? _language(String? value) =>
    value == null || value.toLowerCase() == 'und' ? null : value;
