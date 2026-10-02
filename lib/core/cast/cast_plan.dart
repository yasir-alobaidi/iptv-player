import 'package:flutter/foundation.dart';

/// How a cast is made (docs/04's planner rules, Phase 7 decision 1): who
/// serves the TV, what happens to the picture and the sound, and the
/// badge it earns. The planner makes it; the relay and the coordinator
/// carry it out.
@immutable
final class CastPlan {
  const new({
    required this.delivery,
    required this.video,
    required this.audio,
    required this.live,
    required this.output,
  });

  final CastDelivery delivery;
  final CastVideo video;
  final CastAudio audio;

  /// A live stream (`LIVE`), or a file with a length (`BUFFERED`).
  final bool live;

  /// What the TV gets, for the casting view's details line.
  final CastOutput output;

  /// The casting view's badge (docs/05): a re-encoded picture outranks
  /// converted sound.
  CastQuality get quality => switch ((video, audio)) {
    (CastVideoTranscode(), _) => CastQuality.transcoded,
    (_, CastAudioToAac()) => CastQuality.convertedAudio,
    _ => CastQuality.original,
  };

  @override
  bool operator ==(Object other) =>
      other is CastPlan &&
      other.delivery == delivery &&
      other.video == video &&
      other.audio == audio &&
      other.live == live &&
      other.output == output;

  @override
  int get hashCode => Object.hash(delivery, video, audio, live, output);

  @override
  String toString() =>
      'CastPlan(${delivery.name}, $video, $audio, '
      '${live ? 'live' : 'file'}, $output)';
}

/// Who serves the TV, and in what.
enum CastDelivery {
  /// The TV fetches the provider's own HLS stream (docs/04 rule 1).
  directHls,

  /// The TV reads the provider's file with Range requests and seeks in it
  /// itself (Phase 7 decision 1).
  directFile,

  /// The relay's HLS with MPEG-TS segments: H.264 (docs/04 rule 5).
  relayHls,

  /// The relay's one continuous fragmented MP4: HEVC, Low-latency mode,
  /// and files that can't go direct (docs/04 rule 5, decision 1).
  relayContinuous;

  bool get direct => this == directHls || this == directFile;

  /// The LOAD's `contentType` (docs/04).
  String get contentType => switch (this) {
    directHls || relayHls => 'application/x-mpegurl',
    directFile || relayContinuous => 'video/mp4',
  };
}

/// The casting view's badge (docs/05).
enum CastQuality { original, convertedAudio, transcoded }

/// What happens to the picture.
@immutable
sealed class CastVideo {
  const new();
}

/// Sent as it is: original quality (ADR-007).
final class CastVideoCopy extends CastVideo {
  const new();

  @override
  bool operator ==(Object other) => other is CastVideoCopy;

  @override
  int get hashCode => (CastVideoCopy).hashCode;

  @override
  String toString() => 'video copy';
}

/// Re-encoded to H.264 (docs/04 rules 2 and 3).
final class CastVideoTranscode extends CastVideo {
  const new({
    required this.height,
    required this.bitRate,
    required this.reasons,
    this.fps,
    this.deinterlace = false,
    this.softwareCapped = false,
  });

  /// The picture's height on the TV: the source's, or lower, never more.
  final int height;

  /// Bits per second for the encoder.
  final int bitRate;

  /// Why, most telling first. Never empty.
  final List<TranscodeReason> reasons;

  /// Pictures per second out: twice the source's when deinterlacing, one
  /// picture per field (null when the source didn't say).
  final double? fps;

  /// The source is interlaced; the TV gets progressive pictures.
  final bool deinterlace;

  /// Held at 1080p because only the processor can encode (docs/04 rule 3:
  /// libx264 for 1080p and below only).
  final bool softwareCapped;

  @override
  bool operator ==(Object other) =>
      other is CastVideoTranscode &&
      other.height == height &&
      other.bitRate == bitRate &&
      listEquals(other.reasons, reasons) &&
      other.fps == fps &&
      other.deinterlace == deinterlace &&
      other.softwareCapped == softwareCapped;

  @override
  int get hashCode => Object.hash(
    height,
    bitRate,
    Object.hashAll(reasons),
    fps,
    deinterlace,
    softwareCapped,
  );

  @override
  String toString() =>
      'video transcode(${height}p, $bitRate b/s, '
      '${reasons.map((r) => r.name).join('+')}'
      '${deinterlace ? ', deinterlace' : ''}'
      '${softwareCapped ? ', software cap' : ''})';
}

/// The stream has no picture (a radio channel).
final class CastNoVideo extends CastVideo {
  const new();

  @override
  bool operator ==(Object other) => other is CastNoVideo;

  @override
  int get hashCode => (CastNoVideo).hashCode;

  @override
  String toString() => 'no video';
}

/// Why a picture is re-encoded, for the badge's sentence.
enum TranscodeReason {
  /// Not a codec Cast devices play: MPEG-2, VC-1, VP9…
  codecUnsupported,

  /// The probe couldn't name the codec.
  codecUnknown,

  /// A kind of H.264 or HEVC Cast devices don't decode: 10-bit H.264,
  /// 4:2:2, HEVC range extensions.
  profileUnsupported,

  /// The device refused HEVC before.
  hevcRefused,

  /// HEVC is set to No for the device in Settings → Casting.
  hevcOff,

  /// The device refused a picture this tall before (docs/04 learning:
  /// often an HDMI link at 1080p, which a TV setting may unlock).
  aboveLearnedHeight,

  /// Taller than the device's model shows (docs/04's table).
  aboveModelHeight,

  /// Settings → Casting → Smooth interlaced is on.
  smoothInterlaced,

  /// The device refused an interlaced picture before.
  interlacedRefused,
}

/// What happens to the sound.
@immutable
sealed class CastAudio {
  const new();
}

/// Sent as it is: AAC or MP3, or Dolby with Dolby passthrough on.
final class CastAudioCopy extends CastAudio {
  const new(this.track);

  /// The audio track, FFmpeg's `0:a:<track>`.
  final int track;

  @override
  bool operator ==(Object other) =>
      other is CastAudioCopy && other.track == track;

  @override
  int get hashCode => Object.hash(CastAudioCopy, track);

  @override
  String toString() => 'audio copy a:$track';
}

/// Converted to AAC stereo at 192 kbps (docs/04 rule 4).
final class CastAudioToAac extends CastAudio {
  const new(this.track, this.reason);

  final int track;
  final AudioConversionReason reason;

  @override
  bool operator ==(Object other) =>
      other is CastAudioToAac && other.track == track && other.reason == reason;

  @override
  int get hashCode => Object.hash(CastAudioToAac, track, reason);

  @override
  String toString() => 'audio to AAC a:$track (${reason.name})';
}

/// The stream has no sound.
final class CastNoAudio extends CastAudio {
  const new();

  @override
  bool operator ==(Object other) => other is CastNoAudio;

  @override
  int get hashCode => (CastNoAudio).hashCode;

  @override
  String toString() => 'no audio';
}

enum AudioConversionReason {
  /// Dolby Digital or Dolby Digital Plus, with Dolby passthrough off.
  dolby,

  /// Not a codec Cast devices play: MP2, DTS, Opus, PCM…
  codecUnsupported,

  /// The probe couldn't name the codec.
  codecUnknown,

  /// The device refused this codec before.
  refused,
}

/// What reaches the TV: the casting view's "1080p · 50 fps · H.264 · AAC
/// 2.0". Anything not known is null and left out.
@immutable
final class CastOutput {
  const new({
    this.height,
    this.interlaced = false,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.audioChannels,
  });

  final int? height;

  /// Sent interlaced, as the source was ("1080i").
  final bool interlaced;
  final double? fps;

  /// ffprobe's names: `h264`, `hevc`; `aac`, `mp3`, `ac3`, `eac3`.
  final String? videoCodec;
  final String? audioCodec;
  final int? audioChannels;

  @override
  bool operator ==(Object other) =>
      other is CastOutput &&
      other.height == height &&
      other.interlaced == interlaced &&
      other.fps == fps &&
      other.videoCodec == videoCodec &&
      other.audioCodec == audioCodec &&
      other.audioChannels == audioChannels;

  @override
  int get hashCode => Object.hash(
    height,
    interlaced,
    fps,
    videoCodec,
    audioCodec,
    audioChannels,
  );

  @override
  String toString() =>
      'out(${height ?? '?'}${interlaced ? 'i' : 'p'}, ${fps ?? '?'} fps, '
      '${videoCodec ?? '-'}, ${audioCodec ?? '-'} ${audioChannels ?? ''})';
}
