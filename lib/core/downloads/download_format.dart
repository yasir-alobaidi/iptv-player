import 'package:iptv_player/core/library/library_media.dart';

/// docs/09 "Format": a download is kept as MP4 — the container nearly
/// every player, phone and TV opens — whenever MP4 holds everything in the
/// file as it is. The picture and the sound are copied, never encoded
/// again, so nothing about them changes and it takes seconds.
///
/// The answer is why [media] stays in the container it came in, or null
/// when it is remade as MP4:
/// - it came as Matroska (MKV), MPEG-TS or FLV (an MP4 is one already; an
///   AVI's old codecs don't go);
/// - its picture is H.264 or HEVC;
/// - every sound track is AAC, MP3, AC-3 or E-AC-3 (DTS, TrueHD, Opus and
///   FLAC play from MP4 in too few players);
/// - its subtitles, if it has any, are plain text (SubRip, WebVTT): styled
///   ASS and picture subtitles (PGS, DVD, DVB) can't be kept in MP4.
String? mp4Obstacle(LibraryMedia media) {
  if (media.failed) return "it couldn't be read";
  final container = media.container?.toLowerCase();
  if (container == null) return 'its container is unknown';
  if (_mp4Family.contains(container)) return 'it is MP4 already';
  if (!_remade.contains(container)) return 'it came as $container';
  final video = media.video?.codec?.toLowerCase();
  if (video == null) return 'it has no picture';
  if (!_video.contains(video)) return 'its picture is $video';
  for (final track in media.audio) {
    final codec = track.codec?.toLowerCase();
    if (codec == null || !_audio.contains(codec)) {
      return 'a sound track is ${codec ?? 'unknown'}';
    }
  }
  for (final track in media.subtitles) {
    final codec = track.codec?.toLowerCase();
    if (codec == null || !_subtitles.contains(codec)) {
      return 'its subtitles are ${codec ?? 'unknown'}';
    }
  }
  return null;
}

/// [path] with MP4's extension: `…/Film (2025).mkv` → `…/Film (2025).mp4`.
String mp4PathFor(String path) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  return '${dot > slash + 1 ? path.substring(0, dot) : path}.mp4';
}

/// ffprobe's names (the first of `mov,mp4,m4a,3gp,3g2,mj2`).
const _mp4Family = {'mov', 'mp4', 'm4v', 'm4a', '3gp', '3g2', 'mj2'};
const _remade = {'matroska', 'mpegts', 'flv'};
const _video = {'h264', 'hevc'};
const _audio = {'aac', 'mp3', 'ac3', 'eac3'};
const _subtitles = {'subrip', 'srt', 'webvtt', 'mov_text', 'text'};
