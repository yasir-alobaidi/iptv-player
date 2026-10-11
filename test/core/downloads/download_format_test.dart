import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_format.dart';
import 'package:iptv_player/core/library/library_media.dart';

/// docs/09 "Format": which downloads are remade as MP4.
void main() {
  LibraryMedia media({
    String? container = 'matroska',
    String? video = 'h264',
    List<String?> audio = const ['aac'],
    List<String?> subtitles = const [],
  }) => LibraryMedia(
    container: container,
    duration: const Duration(minutes: 23),
    video: video == null ? null : LibraryVideo(codec: video),
    audio: [for (final codec in audio) LibraryAudio(codec: codec)],
    subtitles: [for (final codec in subtitles) LibrarySubtitle(codec: codec)],
  );

  test('what MP4 holds unchanged is remade as MP4', () {
    for (final fits in [
      media(),
      media(video: 'hevc', audio: ['eac3']),
      media(audio: ['ac3', 'aac', 'mp3']),
      media(audio: []),
      media(subtitles: ['subrip', 'subrip']),
      media(subtitles: ['webvtt']),
      media(container: 'mpegts'),
      media(container: 'flv'),
      media(video: 'H264', audio: ['AAC']),
    ]) {
      expect(mp4Obstacle(fits), isNull, reason: '${fits.toJson()}');
    }
  });

  test('anything MP4 would lose, or most players would not open in it, '
      'stays as it came', () {
    for (final (kept, why) in [
      (media(container: 'mov'), 'it is MP4 already'),
      (media(container: 'avi'), 'it came as avi'),
      (media(container: null), 'its container is unknown'),
      (media(video: null), 'it has no picture'),
      (media(video: 'mpeg4'), 'its picture is mpeg4'),
      (media(video: 'vp9'), 'its picture is vp9'),
      (media(audio: ['aac', 'dts']), 'a sound track is dts'),
      (media(audio: ['truehd']), 'a sound track is truehd'),
      (media(audio: ['opus']), 'a sound track is opus'),
      (media(audio: [null]), 'a sound track is unknown'),
      (media(subtitles: ['subrip', 'ass']), 'its subtitles are ass'),
      (
        media(subtitles: ['hdmv_pgs_subtitle']),
        'its subtitles are hdmv_pgs_subtitle',
      ),
      (media(subtitles: ['dvd_subtitle']), 'its subtitles are dvd_subtitle'),
      (const LibraryMedia.unreadable(), "it couldn't be read"),
    ]) {
      expect(mp4Obstacle(kept), why);
    }
  });

  test("MP4's name for a file", () {
    expect(
      mp4PathFor('/v/Film (2025)/Film (2025).mkv'),
      '/v/Film (2025)/Film (2025).mp4',
    );
    expect(mp4PathFor(r'C:\v\Show - S01E01.ts'), r'C:\v\Show - S01E01.mp4');
    expect(mp4PathFor('/v/Film.mp4'), '/v/Film.mp4');
    // A dot in a folder's name, or none at all, is no extension.
    expect(mp4PathFor('/v.d/Film'), '/v.d/Film.mp4');
    expect(mp4PathFor('/v/Mr. Fox.mkv'), '/v/Mr. Fox.mp4');
  });
}
