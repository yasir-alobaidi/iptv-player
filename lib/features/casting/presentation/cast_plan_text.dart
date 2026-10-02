import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/design/components/quality_badge.dart';

/// The casting view's badge for [plan] (docs/05).
StreamQuality castBadge(CastPlan plan) => switch (plan.quality) {
  CastQuality.original => StreamQuality.original,
  CastQuality.convertedAudio => StreamQuality.convertedAudio,
  CastQuality.transcoded => StreamQuality.transcoded,
};

/// The casting view's details line, as the canvas writes it: "1080p · 50
/// fps · H.264 · AAC 2.0". What isn't known is left out.
String castDetailsLine(CastOutput output) {
  final height = output.height;
  final fps = output.fps;
  final audio = output.audioCodec;
  final channels = output.audioChannels;
  return [
    if (height != null && height >= 2160 && !output.interlaced)
      '4K'
    else if (height != null)
      '$height${output.interlaced ? 'i' : 'p'}',
    if (fps != null) '${_number(fps)} fps',
    if (output.videoCodec case final codec?) videoCodecName(codec),
    if (audio != null)
      [
        audioCodecName(audio),
        if (channels != null) channelsName(channels),
      ].join(' '),
  ].join(' · ');
}

/// Why the cast is as it is, in a sentence or two, in the canvas's voice
/// ("Video and audio go to your TV untouched. Nothing is re-encoded.").
String castPlanSentence(CastPlan plan) {
  final video = plan.video;
  final audio = plan.audio;
  if (video is CastVideoTranscode) return _transcodeSentence(video);
  if (audio is CastAudioToAac) {
    final picture = video is CastNoVideo
        ? ''
        : 'Video goes to your TV untouched. ';
    return '$picture${_audioSentence(audio)}';
  }
  final what = switch ((video, audio)) {
    (CastNoVideo(), _) => 'Audio goes',
    (_, CastNoAudio()) => 'Video goes',
    _ => 'Video and audio go',
  };
  return plan.delivery.direct
      ? '$what to your TV untouched, straight from the provider. '
            'Nothing is re-encoded.'
      : '$what to your TV untouched. Nothing is re-encoded.';
}

String _transcodeSentence(CastVideoTranscode video) {
  final to = '${video.height}p';
  final first = switch (video.reasons.first) {
    TranscodeReason.hevcRefused =>
      'Your TV said no to HEVC, so the video is re-encoded to H.264.',
    TranscodeReason.hevcOff =>
      'HEVC is set to No for this TV, so the video is re-encoded to H.264.',
    TranscodeReason.codecUnsupported =>
      "Cast devices can't play this video format, so it's re-encoded to "
          'H.264.',
    TranscodeReason.codecUnknown =>
      "The video's format couldn't be read, so it's re-encoded to H.264 "
          'to be safe.',
    TranscodeReason.profileUnsupported =>
      "Cast devices can't play this kind of video (10-bit or high colour), "
          "so it's re-encoded to H.264.",
    TranscodeReason.aboveLearnedHeight =>
      "Your TV refused a taller picture, so it's re-encoded to $to. Its "
          'HDMI input may be limited to HD: a TV setting (Input Signal Plus '
          'on Samsung) may unlock 4K.',
    TranscodeReason.aboveModelHeight =>
      'Your TV shows at most $to, so the picture is re-encoded to fit.',
    TranscodeReason.smoothInterlaced =>
      'Smooth interlaced is on, so the picture is deinterlaced and '
          're-encoded.',
    TranscodeReason.interlacedRefused =>
      "Your TV refused this interlaced picture, so it's deinterlaced and "
          're-encoded.',
  };
  return video.softwareCapped
      ? "$first With no hardware encoder, it's made at $to at most."
      : first;
}

String _audioSentence(CastAudioToAac audio) => switch (audio.reason) {
  AudioConversionReason.dolby =>
    'Dolby audio is converted to AAC stereo, which every TV plays. Dolby '
        'passthrough in Settings sends it untouched, for an AV receiver.',
  AudioConversionReason.codecUnsupported =>
    "Cast devices can't play this audio format, so it's converted to AAC "
        'stereo.',
  AudioConversionReason.codecUnknown =>
    "The audio's format couldn't be read, so it's converted to AAC stereo "
        'to be safe.',
  AudioConversionReason.refused =>
    "Your TV said no to this audio format, so it's converted to AAC stereo.",
};

/// "H.264", "HEVC", "MPEG-2" for ffprobe's names.
String videoCodecName(String codec) => switch (codec) {
  'h264' => 'H.264',
  'hevc' => 'HEVC',
  'mpeg2video' => 'MPEG-2',
  'mpeg4' => 'MPEG-4',
  'vc1' => 'VC-1',
  'vp8' => 'VP8',
  'vp9' => 'VP9',
  'av1' => 'AV1',
  _ => codec.toUpperCase(),
};

/// "AAC", "Dolby Digital", "Dolby Digital Plus" for ffprobe's names.
String audioCodecName(String codec) => switch (codec) {
  'aac' => 'AAC',
  'mp3' => 'MP3',
  'mp2' => 'MP2',
  'ac3' => 'Dolby Digital',
  'eac3' => 'Dolby Digital Plus',
  'dts' => 'DTS',
  'opus' => 'Opus',
  'flac' => 'FLAC',
  _ => codec.toUpperCase(),
};

/// "2.0", "5.1", "7.1"; mono is "1.0".
String channelsName(int channels) => switch (channels) {
  1 => '1.0',
  2 => '2.0',
  3 => '2.1',
  6 => '5.1',
  8 => '7.1',
  _ => '$channels ch',
};

/// 25, 29.97, 23.976: whole numbers without decimals.
String _number(double value) {
  final whole = value.roundToDouble();
  if ((value - whole).abs() < 0.005) return whole.toInt().toString();
  var text = value.toStringAsFixed(3);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
