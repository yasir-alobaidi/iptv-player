import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/player/player_engine.dart';

part 'stream_facts.freezed.dart';

/// What the cast planner knows about a stream (docs/04's probe): its
/// container, its picture and its sound. Any of it can be unknown.
@freezed
abstract class StreamFacts with _$StreamFacts {
  const factory({
    /// Where the facts came from (Phase 7 decision 4).
    required StreamFactsOrigin origin,

    /// Null when not known (the laptop's player doesn't say).
    MediaContainer? container,

    /// The first picture that isn't a cover image; null when there is
    /// none (a radio channel).
    VideoFacts? video,

    /// Every audio track, in the stream's order.
    @Default(<AudioFacts>[]) List<AudioFacts> audio,

    /// A file's length.
    Duration? duration,

    /// The whole stream's bits per second.
    int? bitRate,
  }) = _StreamFacts;
}

/// Phase 7 decision 4, in the order they are asked.
enum StreamFactsOrigin {
  /// The laptop's player, which was playing it.
  player,

  /// Facts found earlier in this run of the app.
  remembered,

  /// ffprobe.
  probe,

  /// The relay's FFmpeg: what it opened (Phase 7 step 5).
  relay,
}

/// The stream's container, as far as casting cares.
enum MediaContainer {
  mpegTs,
  hls,

  /// MP4, M4V or MOV: ffprobe can't tell them apart, and the TV plays all
  /// three (Phase 7 decision 1).
  mp4,

  /// Matroska or WebM: ffprobe can't tell them apart either.
  matroska,
  other,
}

@freezed
abstract class VideoFacts with _$VideoFacts {
  const factory({
    /// ffprobe's codec name in lower case: `h264`, `hevc`, `mpeg2video`…
    String? codec,

    /// ffprobe's profile, such as `High`, `High 10` or `Main 10`.
    String? profile,
    int? width,
    int? height,

    /// Pictures per second: 25 for 1080i50, whose fields come at 50.
    double? fps,

    /// Null when not known, which reads as progressive.
    bool? interlaced,

    /// Bits per sample, from the pixel format: 8, 10, 12.
    int? bitDepth,
    int? bitRate,
  }) = _VideoFacts;
}

@freezed
abstract class AudioFacts with _$AudioFacts {
  const factory({
    /// Its place among the audio tracks, from 0: FFmpeg's `0:a:<index>`.
    required int index,

    /// ffprobe's codec name in lower case: `aac`, `ac3`, `eac3`, `mp2`…
    String? codec,
    int? channels,

    /// ISO 639 code, lower case.
    String? language,
    String? title,
    @Default(false) bool isDefault,
    int? bitRate,
  }) = _AudioFacts;
}

/// The facts the laptop's player has about what it plays (Phase 7
/// decision 4's first source), or null when it has too few to plan with
/// (no codec read yet). Ask once it has shown a picture.
StreamFacts? streamFactsFromPlayer(StreamInfo info, {PlayerTracks? tracks}) {
  final videoCodec = _firstWord(info.videoCodec);
  final audio = <AudioFacts>[
    if (tracks != null && tracks.audio.isNotEmpty)
      for (final (i, track) in tracks.audio.indexed)
        AudioFacts(
          index: i,
          codec: _firstWord(track.codec),
          channels: channelCount(track.channels),
          language: _language(track.language),
          title: track.title,
        )
    else if (info.audioCodec != null)
      AudioFacts(
        index: 0,
        codec: _firstWord(info.audioCodec),
        channels: info.audioChannels,
      ),
  ];
  if (videoCodec == null && audio.every((a) => a.codec == null)) return null;
  return StreamFacts(
    origin: StreamFactsOrigin.player,
    video: videoCodec == null
        ? null
        : VideoFacts(
            codec: videoCodec,
            width: info.width,
            height: info.height,
            fps: info.fps,
            interlaced: info.interlaced,
            bitRate: info.videoBitrate,
          ),
    audio: audio,
  );
}

/// The audio track the laptop's player has on, as an index into
/// [streamFactsFromPlayer]'s audio; null when it says none.
int? playerAudioIndex(PlayerTracks tracks) {
  final id = tracks.audioId;
  if (id == null) return null;
  final i = tracks.audio.indexWhere((t) => t.id == id);
  return i < 0 ? null : i;
}

/// Channels from a layout's name, as mpv and ffprobe write them:
/// `mono`, `stereo`, `5.1`, `5.1(side)`, `7.1`, `6 channels`…
int? channelCount(String? layout) {
  if (layout == null) return null;
  final text = layout.trim().toLowerCase();
  if (text.isEmpty) return null;
  const named = {
    'mono': 1,
    'stereo': 2,
    'downmix': 2,
    '2.1': 3,
    '3.0': 3,
    'quad': 4,
    '4.0': 4,
    '5.0': 5,
  };
  final base = text.split('(').first.trim();
  if (named[base] case final n?) return n;
  final dotted = RegExp(r'^(\d+)\.(\d+)$').firstMatch(base);
  if (dotted != null) {
    return int.parse(dotted.group(1)!) + int.parse(dotted.group(2)!);
  }
  final counted = RegExp(r'^(\d+)\s*(?:ch|channels?)?$').firstMatch(base);
  if (counted != null) return int.parse(counted.group(1)!);
  return null;
}

/// mpv names a codec `h264 (H.264 / AVC / …)`; its first word is
/// ffprobe's name.
String? _firstWord(String? text) {
  final word = text?.trim().split(RegExp(r'\s')).first.toLowerCase();
  return word == null || word.isEmpty ? null : word;
}

String? _language(String? text) {
  final code = text?.trim().toLowerCase();
  return code == null || code.isEmpty || code == 'und' ? null : code;
}
