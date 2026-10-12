/// What the cast runs FFmpeg for beside the relay, for a file on this
/// computer (Phase 8 decision 12): its subtitles as WebVTT, and the MP4
/// the TV can seek in by itself. Plain Dart, so the process a test kills
/// (`cast_helpers_victim.dart`) runs the very commands the app does.
library;

/// The owners their processes run under: the supervisor's PID files
/// (hard rule 8), which the launch sweep goes by.
const castMp4Owner = 'cast-mp4';
const castSubtitlesOwner = 'cast-subtitles';
const castStartOwner = 'cast-start';

/// Before every command of the cast's own: quiet, never waiting for a
/// key, writing over what an earlier try left.
const castFfmpegFlags = ['-hide_banner', '-v', 'error', '-nostdin', '-y'];

/// FFmpeg's arguments for the MP4 of [video] at [output]: [streams] are
/// the relay's own for the plan (which streams, copied or converted), and
/// the index goes at the front (`+faststart`).
List<String> castMp4Arguments({
  required String video,
  required List<String> streams,
  required String output,
}) => [
  ...castFfmpegFlags,
  ...['-i', video],
  ...streams,
  ...['-max_muxing_queue_size', '1024'],
  ...['-movflags', '+faststart'],
  ...['-f', 'mp4', output],
];

/// FFmpeg's arguments for the text tracks [tracks] of [video] (each its
/// place among the file's subtitle streams, `0:s:<n>`), every one into
/// the WebVTT file [output] names for it, in one reading of the file.
List<String> castOwnSubtitlesArguments({
  required String video,
  required List<int> tracks,
  required String Function(int track) output,
}) => [
  ...castFfmpegFlags,
  ...['-i', video],
  for (final track in tracks) ...[
    ...['-map', '0:s:$track', '-c:s', 'webvtt'],
    ...['-f', 'webvtt', output(track)],
  ],
];

/// FFmpeg's arguments for the subtitle file [file] beside a video as
/// WebVTT at [output], read in [codePage] when it isn't Unicode.
List<String> castSubtitleFileArguments({
  required String file,
  required String output,
  String? codePage,
}) => [
  ...castFfmpegFlags,
  if (codePage != null) ...['-sub_charenc', codePage],
  ...['-i', file],
  ...['-map', '0:s:0', '-c:s', 'webvtt', '-f', 'webvtt', output],
];
