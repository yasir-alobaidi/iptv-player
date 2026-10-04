import 'package:meta/meta.dart';

/// What ffprobe said of a library file (docs/09 "File probe"), kept in
/// `library_items.probe_json`: its length, its picture, its sound and
/// subtitle tracks, and an embedded title. Read tolerantly: a field of
/// the wrong kind is unknown, never an error.
@immutable
final class LibraryMedia {
  const new({
    this.container,
    this.duration,
    this.video,
    this.audio = const [],
    this.subtitles = const [],
    this.title,
    this.failed = false,
  });

  /// ffprobe couldn't read the file: it isn't asked again until the file
  /// changes.
  const new unreadable() : this(failed: true);

  factory fromJson(Object? json) {
    if (json is! Map) return const LibraryMedia.unreadable();
    if (json['failed'] == true) return const LibraryMedia.unreadable();
    final video = json['video'];
    final audio = json['audio'];
    final subtitles = json['subtitles'];
    return LibraryMedia(
      container: _string(json['container']),
      duration: switch (_int(json['duration_ms'])) {
        final ms? when ms > 0 => Duration(milliseconds: ms),
        _ => null,
      },
      video: video is Map ? LibraryVideo.fromJson(video) : null,
      audio: [
        if (audio is List)
          for (final track in audio)
            if (track is Map) LibraryAudio.fromJson(track),
      ],
      subtitles: [
        if (subtitles is List)
          for (final track in subtitles)
            if (track is Map) LibrarySubtitle.fromJson(track),
      ],
      title: _string(json['title']),
    );
  }

  /// `matroska`, `mov`, `mpegts`, `avi` … (ffprobe's first format name).
  final String? container;
  final Duration? duration;
  final LibraryVideo? video;
  final List<LibraryAudio> audio;
  final List<LibrarySubtitle> subtitles;

  /// The file's own title tag.
  final String? title;
  final bool failed;

  /// The line under a library page's title: `1080p · H.264 · AC-3 5.1`.
  String? get qualityLine {
    final parts = [
      ?video?.label,
      ?video?.codecName,
      if (audio.isNotEmpty) audio.first.label,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Map<String, Object?> toJson() => failed
      ? {'failed': true}
      : {
          'container': ?container,
          'duration_ms': ?duration?.inMilliseconds,
          'video': ?video?.toJson(),
          if (audio.isNotEmpty) 'audio': [for (final a in audio) a.toJson()],
          if (subtitles.isNotEmpty)
            'subtitles': [for (final s in subtitles) s.toJson()],
          'title': ?title,
        };

  @override
  bool operator ==(Object other) =>
      other is LibraryMedia &&
      other.container == container &&
      other.duration == duration &&
      other.video == video &&
      _listEquals(other.audio, audio) &&
      _listEquals(other.subtitles, subtitles) &&
      other.title == title &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(
    container,
    duration,
    video,
    Object.hashAll(audio),
    Object.hashAll(subtitles),
    title,
    failed,
  );
}

@immutable
final class LibraryVideo {
  const new({
    this.codec,
    this.width,
    this.height,
    this.fps,
    this.interlaced,
    this.bitDepth,
    this.hdr = false,
  });

  factory fromJson(Map<Object?, Object?> json) => LibraryVideo(
    codec: _string(json['codec']),
    width: _int(json['width']),
    height: _int(json['height']),
    fps: _double(json['fps']),
    interlaced: json['interlaced'] is bool ? json['interlaced']! as bool : null,
    bitDepth: _int(json['bit_depth']),
    hdr: json['hdr'] == true,
  );

  /// ffprobe's codec name: `h264`, `hevc`, `mpeg2video` …
  final String? codec;
  final int? width;
  final int? height;
  final double? fps;
  final bool? interlaced;
  final int? bitDepth;

  /// PQ or HLG.
  final bool hdr;

  /// `4K`, `1080p`, `720p`, `576i` … by its height (a scope's letterbox
  /// keeps its width's name).
  String? get label {
    final h = height;
    final w = width;
    if (h == null) return null;
    final scan = interlaced ?? false ? 'i' : 'p';
    if (h >= 1600 || (w != null && w >= 3200)) return hdr ? '4K HDR' : '4K';
    if (h >= 800 || (w != null && w >= 1700)) return '1080$scan';
    if (h >= 600 || (w != null && w >= 1200)) return '720$scan';
    return '$h$scan';
  }

  String? get codecName => switch (codec) {
    null => null,
    'h264' => 'H.264',
    'hevc' => 'HEVC',
    'mpeg2video' => 'MPEG-2',
    'mpeg4' => 'MPEG-4',
    'av1' => 'AV1',
    'vp9' => 'VP9',
    final other => other.toUpperCase(),
  };

  Map<String, Object?> toJson() => {
    'codec': ?codec,
    'width': ?width,
    'height': ?height,
    'fps': ?fps,
    'interlaced': ?interlaced,
    'bit_depth': ?bitDepth,
    if (hdr) 'hdr': true,
  };

  @override
  bool operator ==(Object other) =>
      other is LibraryVideo &&
      other.codec == codec &&
      other.width == width &&
      other.height == height &&
      other.fps == fps &&
      other.interlaced == interlaced &&
      other.bitDepth == bitDepth &&
      other.hdr == hdr;

  @override
  int get hashCode =>
      Object.hash(codec, width, height, fps, interlaced, bitDepth, hdr);
}

@immutable
final class LibraryAudio {
  const new({
    this.codec,
    this.channels,
    this.language,
    this.title,
    this.isDefault = false,
  });

  factory fromJson(Map<Object?, Object?> json) => LibraryAudio(
    codec: _string(json['codec']),
    channels: _int(json['channels']),
    language: _string(json['language']),
    title: _string(json['title']),
    isDefault: json['default'] == true,
  );

  final String? codec;
  final int? channels;

  /// ISO 639 as the file has it (`eng`, `fr`).
  final String? language;
  final String? title;
  final bool isDefault;

  /// `AC-3 5.1`, `AAC 2.0`.
  String get label {
    final name = switch (codec) {
      null => 'Audio',
      'ac3' => 'AC-3',
      'eac3' => 'E-AC-3',
      'aac' => 'AAC',
      'mp2' => 'MP2',
      'mp3' => 'MP3',
      'dts' => 'DTS',
      'truehd' => 'TrueHD',
      'flac' => 'FLAC',
      'opus' => 'Opus',
      final other => other.toUpperCase(),
    };
    final layout = switch (channels) {
      null => null,
      1 => '1.0',
      2 => '2.0',
      6 => '5.1',
      8 => '7.1',
      final n => '$n ch',
    };
    return layout == null ? name : '$name $layout';
  }

  Map<String, Object?> toJson() => {
    'codec': ?codec,
    'channels': ?channels,
    'language': ?language,
    'title': ?title,
    if (isDefault) 'default': true,
  };

  @override
  bool operator ==(Object other) =>
      other is LibraryAudio &&
      other.codec == codec &&
      other.channels == channels &&
      other.language == language &&
      other.title == title &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(codec, channels, language, title, isDefault);
}

/// A subtitle track inside the file.
@immutable
final class LibrarySubtitle {
  const new({
    this.codec,
    this.language,
    this.title,
    this.forced = false,
    this.isDefault = false,
  });

  factory fromJson(Map<Object?, Object?> json) => LibrarySubtitle(
    codec: _string(json['codec']),
    language: _string(json['language']),
    title: _string(json['title']),
    forced: json['forced'] == true,
    isDefault: json['default'] == true,
  );

  /// `subrip`, `ass`, `webvtt`, `mov_text`; `hdmv_pgs_subtitle`,
  /// `dvd_subtitle` …
  final String? codec;
  final String? language;
  final String? title;
  final bool forced;
  final bool isDefault;

  /// Text the TV can be sent as WebVTT (docs/04); pictures (PGS, VobSub)
  /// can't.
  bool get isText => switch (codec) {
    'subrip' ||
    'srt' ||
    'ass' ||
    'ssa' ||
    'webvtt' ||
    'mov_text' ||
    'text' => true,
    _ => false,
  };

  Map<String, Object?> toJson() => {
    'codec': ?codec,
    'language': ?language,
    'title': ?title,
    if (forced) 'forced': true,
    if (isDefault) 'default': true,
  };

  @override
  bool operator ==(Object other) =>
      other is LibrarySubtitle &&
      other.codec == codec &&
      other.language == language &&
      other.title == title &&
      other.forced == forced &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(codec, language, title, forced, isDefault);
}

String? _string(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

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

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
