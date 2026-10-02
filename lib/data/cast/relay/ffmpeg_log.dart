// Plain Dart: read in the relay's isolate.

/// FFmpeg's log levels, as `-loglevel repeat+level+…` prints them.
enum FfmpegLevel {
  panic,
  fatal,
  error,
  warning,
  info,
  verbose,
  debug,
  trace,

  /// A line without a level: a continuation, or an FFmpeg that doesn't
  /// print one.
  unknown;

  /// Bad enough to log: a warning or worse.
  bool get worrying => index <= warning.index;
}

/// One line of FFmpeg's standard error.
final class FfmpegLine {
  const new(this.level, this.text, {this.context});

  final FfmpegLevel level;

  /// The line without its context and level.
  final String text;

  /// What printed it (`mpegts`, `hls`, `h264`), without its address.
  final String? context;

  /// `mpegts: …`, for the log.
  @override
  String toString() => context == null ? text : '$context: $text';
}

final _line = RegExp(
  r'^(?:\[([^\]]*)\] )?\[(panic|fatal|error|warning|info|verbose|debug|trace)\] ?(.*)$',
);

/// Reads a line FFmpeg printed under `-loglevel repeat+level+…`:
/// `[mpegts @ 0x55d0] [warning] message`, `[info] message`.
FfmpegLine parseFfmpegLine(String line) {
  final match = _line.firstMatch(line);
  if (match == null) return FfmpegLine(FfmpegLevel.unknown, line);
  final level = FfmpegLevel.values.byName(match[2]!);
  final context = match[1]?.split(' @ ').first.trim();
  return FfmpegLine(
    level,
    match[3]!,
    context: context == null || context.isEmpty ? null : context,
  );
}

/// A stream appeared after FFmpeg started: a channel switched codec mid
/// stream (`New video stream with index 2 at pos:… and DTS:…s`). FFmpeg
/// keeps copying the stream it opened, so the TV may be left without a
/// picture (the plan's Risks).
bool isNewStreamLine(FfmpegLine line) =>
    RegExp(r'^New (video|audio) stream\b').hasMatch(line.text);

/// What FFmpeg says it opened: its input's description (Phase 7 decision
/// 4: the plan's facts, checked by the program that reads the stream).
final class FfmpegInputReport {
  const new({
    required this.container,
    this.duration,
    this.video,
    this.audio = const [],
  });

  /// FFmpeg's demuxer: `mpegts`, `hls`, `mov,mp4,m4a,3gp,3g2,mj2`,
  /// `matroska,webm`.
  final String container;

  /// Null for a live stream (`Duration: N/A`).
  final Duration? duration;

  /// The first picture that isn't a cover (`attached pic`).
  final FfmpegVideoStream? video;

  /// Every audio stream, in FFmpeg's `0:a:<n>` order.
  final List<FfmpegAudioStream> audio;

  @override
  String toString() =>
      'FfmpegInputReport($container, $video, '
      '${audio.map((a) => '$a').join(' + ')})';
}

final class FfmpegVideoStream {
  const new({
    required this.codec,
    this.profile,
    this.pixelFormat,
    this.width,
    this.height,
    this.fps,
    this.interlaced,
  });

  /// FFmpeg's name: `h264`, `hevc`, `mpeg2video`.
  final String codec;

  /// `High`, `Main 10`.
  final String? profile;

  /// `yuv420p`, `yuv420p10le`.
  final String? pixelFormat;
  final int? width;
  final int? height;
  final double? fps;

  /// Null when FFmpeg didn't say.
  final bool? interlaced;

  /// 10 for `yuv420p10le` or `p010le`, 12 for 12-bit, else 8.
  int? get bitDepth {
    final format = pixelFormat;
    if (format == null) return null;
    // yuv420p10le, yuv422p12be; then p010le, p016le; then 8-bit ones.
    final planar = RegExp(r'p(\d{2})(?:le|be)?$').firstMatch(format);
    if (planar != null) return int.parse(planar[1]!);
    final packed = RegExp(r'^p0(\d{2})').firstMatch(format);
    if (packed != null) return int.parse(packed[1]!);
    return 8;
  }

  @override
  String toString() =>
      '$codec${profile == null ? '' : ' ($profile)'} '
      '${height ?? '?'}${interlaced ?? false ? 'i' : 'p'}';
}

final class FfmpegAudioStream {
  const new({
    required this.codec,
    this.profile,
    this.layout,
    this.language,
    this.isDefault = false,
    this.bitRate,
  });

  /// `aac`, `ac3`, `eac3`, `mp2`.
  final String codec;
  final String? profile;

  /// The channel layout: `stereo`, `5.1(side)`, `mono`.
  final String? layout;

  /// As the stream says it (`eng`); null for none or `und`.
  final String? language;
  final bool isDefault;

  /// Bits per second.
  final int? bitRate;

  @override
  String toString() => '$codec ${layout ?? ''}'.trim();
}

/// Gathers the input's description from FFmpeg's info lines, which come
/// before any output: `Input #0, mpegts, from '…':`, its `Duration`, and a
/// `Stream #0:n` line per stream, up to `Stream mapping:` or `Output #0`.
final class FfmpegInputReader {
  String? _container;
  Duration? _duration;
  final _streams = <String>[];
  var _done = false;

  /// Takes one line; answers the report once the input's description is
  /// complete (once only), else null.
  FfmpegInputReport? add(FfmpegLine line) {
    if (_done) return null;
    final text = line.text;
    final input = RegExp('^Input #0, ([^,]+(?:,[^ ,]+)*), from ')
        .firstMatch(text);
    if (input != null) {
      _container = input[1];
      return null;
    }
    if (_container == null) return null;
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('Duration:')) {
      _duration = _readDuration(trimmed);
      return null;
    }
    if (RegExp(r'^Stream #0:\d+').hasMatch(trimmed)) {
      _streams.add(trimmed);
      return null;
    }
    if (trimmed.startsWith('Stream mapping:') ||
        trimmed.startsWith('Output #') ||
        RegExp('^Input #[1-9]').hasMatch(trimmed)) {
      _done = true;
      return _report();
    }
    return null;
  }

  FfmpegInputReport _report() {
    FfmpegVideoStream? video;
    final audio = <FfmpegAudioStream>[];
    for (final stream in _streams) {
      final kind = RegExp(': (Video|Audio): ').firstMatch(stream);
      if (kind == null) continue;
      final head = stream.substring(0, kind.start);
      final body = stream.substring(kind.end);
      final language = RegExp(r'\((\w{2,3})\)$').firstMatch(head)?[1];
      if (body.trim().split(' ').first.replaceAll(',', '').isEmpty) continue;
      if (kind[1] == 'Video') {
        if (video != null || body.contains('(attached pic)')) continue;
        video = _readVideo(body);
      } else {
        audio.add(
          _readAudio(body, language: language == 'und' ? null : language),
        );
      }
    }
    return FfmpegInputReport(
      container: _container!,
      duration: _duration,
      video: video,
      audio: audio,
    );
  }
}

/// `Duration: 00:01:00.02, start: …`; null for `N/A`.
Duration? _readDuration(String text) {
  final match = RegExp(r'Duration: (\d+):(\d\d):(\d\d)(?:\.(\d+))?')
      .firstMatch(text);
  if (match == null) return null;
  final fraction = (match[4] ?? '0').padRight(6, '0').substring(0, 6);
  return Duration(
    hours: int.parse(match[1]!),
    minutes: int.parse(match[2]!),
    seconds: int.parse(match[3]!),
    microseconds: int.parse(fraction),
  );
}

/// `h264 (High) ([27][0][0][0] / 0x001B), yuv420p(tv, bt709, progressive),
/// 1920x1080 [SAR 1:1 DAR 16:9], 50 fps, 50 tbr, 90k tbn`.
FfmpegVideoStream _readVideo(String body) {
  final parts = _topLevel(body);
  final (codec, profile) = _codecAndProfile(parts.first);
  String? pixelFormat;
  bool? interlaced;
  int? width;
  int? height;
  double? fps;
  double? tbr;
  for (final part in parts.skip(1)) {
    final size = RegExp(r'^(\d{2,5})x(\d{2,5})\b').firstMatch(part);
    if (size != null && width == null) {
      width = int.parse(size[1]!);
      height = int.parse(size[2]!);
      continue;
    }
    final rate = RegExp(r'^([\d.]+)(k?) (fps|tbr)$').firstMatch(part);
    if (rate != null) {
      final value = double.tryParse(rate[1]!);
      final scaled = value == null ? null : value * (rate[2] == 'k' ? 1000 : 1);
      if (rate[3] == 'fps') {
        fps = scaled;
      } else {
        tbr = scaled;
      }
      continue;
    }
    final format = RegExp(r'^([a-z][a-z0-9_]*)(?:\((.*)\))?$').firstMatch(part);
    if (format != null && pixelFormat == null && width == null) {
      pixelFormat = format[1];
      final notes = format[2]?.split(',').map((n) => n.trim()) ?? const [];
      for (final note in notes) {
        if (note == 'progressive') interlaced = false;
        if (note.contains('first')) interlaced = true;
      }
    }
  }
  return FfmpegVideoStream(
    codec: codec,
    profile: profile,
    pixelFormat: pixelFormat,
    width: width,
    height: height,
    // tbr is FFmpeg's guess; fps, when printed, is the stream's own.
    fps: fps ?? (tbr != null && tbr <= 240 ? tbr : null),
    interlaced: interlaced,
  );
}

/// `ac3, 48000 Hz, 5.1(side), fltp, 384 kb/s (default)`.
FfmpegAudioStream _readAudio(String body, {String? language}) {
  final parts = _topLevel(body);
  final (codec, profile) = _codecAndProfile(parts.first);
  String? layout;
  int? bitRate;
  for (final (i, part) in parts.indexed) {
    if (i > 0 && RegExp(r'^\d+ Hz$').hasMatch(parts[i - 1]) && layout == null) {
      layout = part;
    }
    final rate = RegExp(r'^(\d+) kb/s').firstMatch(part);
    if (rate != null) bitRate = int.parse(rate[1]!) * 1000;
  }
  return FfmpegAudioStream(
    codec: codec,
    profile: profile,
    layout: layout,
    language: language,
    isDefault: body.contains('(default)'),
    bitRate: bitRate,
  );
}

/// `h264 (High) ([27][0][0][0] / 0x001B)`: the codec, and the first
/// parenthesis that isn't the container's codec tag.
(String, String?) _codecAndProfile(String text) {
  final codec = text.split(' ').first.trim();
  for (final group in RegExp(r'\(([^()]*)\)').allMatches(text)) {
    final inside = group[1]!.trim();
    if (inside.isEmpty || inside.contains('0x')) continue;
    return (codec, inside);
  }
  return (codec, null);
}

/// Splits on commas outside parentheses and brackets:
/// `yuv420p(tv, bt709, progressive)` stays one part.
List<String> _topLevel(String text) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '(' || c == '[') depth++;
    if ((c == ')' || c == ']') && depth > 0) depth--;
    if (c == ',' && depth == 0) {
      parts.add(text.substring(start, i).trim());
      start = i + 1;
    }
  }
  parts.add(text.substring(start).trim());
  return parts;
}
