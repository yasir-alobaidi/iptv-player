import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

/// Everything a cast's plan depends on.
@immutable
final class CastPlanRequest {
  const new({
    required this.facts,
    required this.source,
    required this.device,
    this.settings = const CastSettings(),
    this.audio = const CastAudioChoice(),
    this.softwareEncoderOnly = false,
  });

  final StreamFacts facts;
  final CastSourceInfo source;
  final CastDeviceProfile device;
  final CastSettings settings;
  final CastAudioChoice audio;

  /// No hardware encoder was found (step 4), so a re-encode runs on the
  /// processor and stays at 1080p or below (docs/04 rule 3).
  final bool softwareEncoderOnly;
}

/// What is cast, as far as the plan cares.
@immutable
final class CastSourceInfo {
  const new({
    required this.sourceId,
    required this.live,
    this.hls = false,
    this.customUserAgent = false,
    this.fileExtension,
  });

  /// The provider (`sources.id`): a direct play refused once is refused
  /// for the whole source (docs/04 rule 1).
  final String sourceId;

  /// A channel, or a file (a movie, an episode).
  final bool live;

  /// The provider's URL is an HLS playlist (`.m3u8`).
  final bool hls;

  /// The source needs a User-Agent of its own, which a TV fetching the
  /// stream itself can't send: never direct.
  final bool customUserAgent;

  /// A file's container as the provider names it (`mp4`, `mkv`), for
  /// when the facts don't say.
  final String? fileExtension;
}

/// Settings → Casting (sketch C).
@immutable
final class CastSettings {
  const new({
    this.dolbyPassthrough = false,
    this.lowLatency = false,
    this.smoothInterlaced = false,
  });

  /// Tolerant: anything missing or of another type reads as off.
  factory fromJson(Object? json) => json is Map
      ? CastSettings(
          dolbyPassthrough: json['dolby_passthrough'] == true,
          lowLatency: json['low_latency'] == true,
          smoothInterlaced: json['smooth_interlaced'] == true,
        )
      : const CastSettings();

  /// AC-3 and E-AC-3 go untouched, for a TV on an AV receiver.
  final bool dolbyPassthrough;

  /// One continuous stream for every channel: less delay, but a restart
  /// shows on the TV. No direct HLS either: that is HLS's delay too.
  final bool lowLatency;

  /// Interlaced pictures are re-encoded with deinterlacing.
  final bool smoothInterlaced;

  CastSettings copyWith({
    bool? dolbyPassthrough,
    bool? lowLatency,
    bool? smoothInterlaced,
  }) => CastSettings(
    dolbyPassthrough: dolbyPassthrough ?? this.dolbyPassthrough,
    lowLatency: lowLatency ?? this.lowLatency,
    smoothInterlaced: smoothInterlaced ?? this.smoothInterlaced,
  );

  Map<String, Object?> toJson() => {
    'dolby_passthrough': dolbyPassthrough,
    'low_latency': lowLatency,
    'smooth_interlaced': smoothInterlaced,
  };

  @override
  bool operator ==(Object other) =>
      other is CastSettings &&
      other.dolbyPassthrough == dolbyPassthrough &&
      other.lowLatency == lowLatency &&
      other.smoothInterlaced == smoothInterlaced;

  @override
  int get hashCode =>
      Object.hash(dolbyPassthrough, lowLatency, smoothInterlaced);
}

/// Which audio track to cast (docs/04 rule 6).
@immutable
final class CastAudioChoice {
  const new({this.track, this.languages = const []});

  /// The track the laptop's player had on, as an index into the facts'
  /// audio; it wins when there is one.
  final int? track;

  /// Settings → Playback's preferred languages, most wanted first.
  final List<String> languages;
}

/// [planCast]'s answer.
@immutable
sealed class CastPlanResult {
  const new();
}

final class CastPlanned extends CastPlanResult {
  const new(this.plan);

  final CastPlan plan;
}

/// Neither a picture nor a sound to send.
final class CastNothingToPlay extends CastPlanResult {
  const new();
}

/// docs/04's planner rules, with Phase 7 decision 1's file rule. Pure:
/// the same request always plans the same.
CastPlanResult planCast(CastPlanRequest request) {
  final facts = request.facts;
  final device = request.device;
  final settings = request.settings;
  final source = request.source;
  final track = pickAudioTrack(facts.audio, request.audio);
  final videoFacts = facts.video;
  if (videoFacts == null && track == null) return const CastNothingToPlay();

  final video = videoFacts == null
      ? const CastNoVideo()
      : _video(
          videoFacts,
          facts: facts,
          device: device,
          settings: settings,
          softwareOnly: request.softwareEncoderOnly,
        );
  final audio = track == null
      ? const CastNoAudio()
      : _audio(track, device: device, settings: settings);
  final outVideoCodec = switch (video) {
    CastVideoCopy() => videoFacts?.codec,
    CastVideoTranscode() => 'h264',
    CastNoVideo() => null,
  };

  final CastDelivery delivery;
  final direct =
      !source.customUserAgent &&
      !device.learned.directRefusedSources.contains(source.sourceId) &&
      video is! CastVideoTranscode &&
      audio is! CastAudioToAac &&
      // The TV plays the stream's first audio track itself.
      (track == null || track.index == 0);
  if (source.live) {
    final directHls =
        direct &&
        source.hls &&
        !settings.lowLatency &&
        outVideoCodec == 'h264' &&
        (track == null || track.codec == 'aac');
    delivery = directHls
        ? CastDelivery.directHls
        : outVideoCodec == 'hevc' || settings.lowLatency
        ? CastDelivery.relayContinuous
        : CastDelivery.relayHls;
  } else {
    final directFile =
        direct &&
        _isMp4(facts.container, source.fileExtension) &&
        (track == null || const {'aac', 'mp3'}.contains(track.codec));
    delivery = directFile
        ? CastDelivery.directFile
        : CastDelivery.relayContinuous;
  }

  return CastPlanned(
    CastPlan(
      delivery: delivery,
      video: video,
      audio: audio,
      live: source.live,
      output: CastOutput(
        height: switch (video) {
          CastVideoTranscode(:final height) => height,
          CastVideoCopy() => videoFacts?.height,
          CastNoVideo() => null,
        },
        interlaced: video is CastVideoCopy && videoFacts?.interlaced == true,
        fps: switch (video) {
          CastVideoTranscode(:final fps) => fps,
          CastVideoCopy() => videoFacts?.fps,
          CastNoVideo() => null,
        },
        videoCodec: outVideoCodec,
        audioCodec: switch (audio) {
          CastAudioCopy() => track?.codec,
          CastAudioToAac() => 'aac',
          CastNoAudio() => null,
        },
        audioChannels: switch (audio) {
          CastAudioCopy() => track?.channels,
          CastAudioToAac() => 2,
          CastNoAudio() => null,
        },
      ),
    ),
  );
}

CastVideo _video(
  VideoFacts video, {
  required StreamFacts facts,
  required CastDeviceProfile device,
  required CastSettings settings,
  required bool softwareOnly,
}) {
  final reasons = <TranscodeReason>[];
  switch (video.codec) {
    case null:
      reasons.add(TranscodeReason.codecUnknown);
    case 'h264':
      if (_h264Unsupported(video)) {
        reasons.add(TranscodeReason.profileUnsupported);
      }
    case 'hevc':
      if (device.playsHevc == false) {
        reasons.add(
          device.hevc == HevcSupport.no
              ? TranscodeReason.hevcOff
              : TranscodeReason.hevcRefused,
        );
      } else if (_hevcUnsupported(video)) {
        reasons.add(TranscodeReason.profileUnsupported);
      }
    default:
      reasons.add(TranscodeReason.codecUnsupported);
  }
  final maxHeight = device.maxHeight;
  final height = video.height;
  if (maxHeight != null && height != null && height > maxHeight) {
    final learned = device.learned.maxHeight;
    reasons.add(
      learned != null && learned == maxHeight
          ? TranscodeReason.aboveLearnedHeight
          : TranscodeReason.aboveModelHeight,
    );
  }
  final interlaced = video.interlaced ?? false;
  if (interlaced) {
    if (settings.smoothInterlaced) {
      reasons.add(TranscodeReason.smoothInterlaced);
    } else if (device.learned.refusedInterlaced) {
      reasons.add(TranscodeReason.interlacedRefused);
    }
  }
  if (reasons.isEmpty) return const CastVideoCopy();

  // An unknown height is held at 1080p: every Cast device shows that.
  var target = math.min(height ?? 1080, maxHeight ?? 1 << 30);
  var capped = false;
  if (softwareOnly && target > 1080) {
    target = 1080;
    capped = true;
  }
  final fps = video.fps;
  return CastVideoTranscode(
    height: target,
    bitRate: transcodeBitRate(
      sourceBitRate: _videoBitRate(video, facts),
      sourceHeight: height,
      targetHeight: target,
    ),
    reasons: reasons,
    // One picture per field (FFmpeg's bwdif `send_field`), up to 60.
    fps: fps == null
        ? null
        : interlaced
        ? math.min(fps * 2, 60)
        : fps,
    deinterlace: interlaced,
    softwareCapped: capped,
  );
}

/// H.264 that Cast devices don't decode: more than 8 bits, or not 4:2:0
/// (ffprobe's profiles `High 10`, `High 4:2:2`, `High 4:4:4 Predictive`
/// and their Intra kinds).
bool _h264Unsupported(VideoFacts video) {
  if ((video.bitDepth ?? 8) > 8) return true;
  final profile = video.profile?.toLowerCase() ?? '';
  return profile.contains('10') ||
      profile.contains('4:2:2') ||
      profile.contains('4:4:4');
}

/// HEVC beyond Main and Main 10 (range extensions, 12-bit, 4:2:2): the
/// TVs that play HEVC decode those two.
bool _hevcUnsupported(VideoFacts video) {
  if ((video.bitDepth ?? 8) > 10) return true;
  final profile = video.profile?.toLowerCase();
  if (profile == null || profile == 'unknown') return false;
  return !const {'main', 'main 10', 'main still picture'}.contains(profile);
}

CastAudio _audio(
  AudioFacts track, {
  required CastDeviceProfile device,
  required CastSettings settings,
}) {
  final codec = track.codec;
  if (codec == null) {
    return CastAudioToAac(track.index, AudioConversionReason.codecUnknown);
  }
  if (device.refusedAudio(codec)) {
    return CastAudioToAac(track.index, AudioConversionReason.refused);
  }
  if (codec == 'aac' || codec == 'mp3') return CastAudioCopy(track.index);
  if (codec == 'ac3' || codec == 'eac3') {
    return settings.dolbyPassthrough
        ? CastAudioCopy(track.index)
        : CastAudioToAac(track.index, AudioConversionReason.dolby);
  }
  return CastAudioToAac(track.index, AudioConversionReason.codecUnsupported);
}

bool _isMp4(MediaContainer? container, String? extension) {
  if (container != null) return container == MediaContainer.mp4;
  return const {
    'mp4',
    'm4v',
    'mov',
  }.contains(extension?.trim().toLowerCase().replaceFirst('.', ''));
}

/// The picture's own bits per second: ffprobe's, else the whole stream's
/// less its sound's.
int? _videoBitRate(VideoFacts video, StreamFacts facts) {
  final own = video.bitRate;
  if (own != null && own > 0) return own;
  final whole = facts.bitRate;
  if (whole == null || whole <= 0) return null;
  final sound = facts.audio.fold<int>(0, (sum, a) => sum + (a.bitRate ?? 0));
  final rest = whole - sound;
  return rest > 0 ? rest : null;
}

/// docs/04 rule 3: 1.3 × the source, at least 6 Mbps at 1080p. A picture
/// made smaller keeps the source's bits per pixel; each height has a floor
/// and a ceiling, and an unknown source gets the floor.
int transcodeBitRate({
  required int targetHeight,
  int? sourceBitRate,
  int? sourceHeight,
}) {
  final (floor, ceiling) = switch (targetHeight) {
    <= 480 => (1500000, 4000000),
    <= 576 => (2000000, 5000000),
    <= 720 => (4000000, 8000000),
    <= 1080 => (6000000, 15000000),
    <= 1440 => (10000000, 25000000),
    _ => (16000000, 40000000),
  };
  if (sourceBitRate == null || sourceBitRate <= 0) return floor;
  var base = sourceBitRate.toDouble();
  if (sourceHeight != null && sourceHeight > targetHeight) {
    final ratio = targetHeight / sourceHeight;
    base *= ratio * ratio;
  }
  final wanted = (base * 1.3).clamp(floor, ceiling).toDouble();
  // Whole 100 kbps: the same source always asks the same.
  return (wanted / 100000).round() * 100000;
}

/// docs/04 rule 6: the track the laptop's player had on, else the first
/// in a preferred language, else the stream's default, else the first.
AudioFacts? pickAudioTrack(List<AudioFacts> tracks, CastAudioChoice choice) {
  if (tracks.isEmpty) return null;
  final chosen = choice.track;
  if (chosen != null) {
    for (final track in tracks) {
      if (track.index == chosen) return track;
    }
  }
  for (final wanted in choice.languages) {
    for (final track in tracks) {
      if (sameLanguage(track.language, wanted)) return track;
    }
  }
  for (final track in tracks) {
    if (track.isDefault) return track;
  }
  return tracks.first;
}

/// Whether two ISO 639 codes name one language: `en` and `eng`, `de`,
/// `ger` and `deu`. Streams write the three-letter codes, Settings
/// whichever the user typed.
bool sameLanguage(String? a, String? b) {
  final x = a?.trim().toLowerCase();
  final y = b?.trim().toLowerCase();
  if (x == null || y == null || x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  final xs = _languageCodes[x] ?? {x};
  return xs.contains(y) || (_languageCodes[y]?.contains(x) ?? false);
}

/// ISO 639-1 → its 639-2 codes (bibliographic and terminology), for the
/// languages IPTV streams carry most. Each group lists all its codes.
final Map<String, Set<String>> _languageCodes = () {
  const groups = [
    {'en', 'eng'},
    {'de', 'ger', 'deu'},
    {'fr', 'fre', 'fra'},
    {'es', 'spa'},
    {'it', 'ita'},
    {'pt', 'por'},
    {'nl', 'dut', 'nld'},
    {'ar', 'ara'},
    {'tr', 'tur'},
    {'ru', 'rus'},
    {'pl', 'pol'},
    {'ro', 'rum', 'ron'},
    {'el', 'gre', 'ell'},
    {'sv', 'swe'},
    {'no', 'nor'},
    {'nb', 'nob'},
    {'da', 'dan'},
    {'fi', 'fin'},
    {'cs', 'cze', 'ces'},
    {'sk', 'slo', 'slk'},
    {'hu', 'hun'},
    {'hr', 'hrv'},
    {'sr', 'srp'},
    {'bg', 'bul'},
    {'uk', 'ukr'},
    {'sq', 'alb', 'sqi'},
    {'fa', 'per', 'fas'},
    {'ku', 'kur'},
    {'he', 'heb'},
    {'hi', 'hin'},
    {'ur', 'urd'},
    {'pa', 'pan'},
    {'bn', 'ben'},
    {'ta', 'tam'},
    {'zh', 'chi', 'zho'},
    {'ja', 'jpn'},
    {'ko', 'kor'},
    {'vi', 'vie'},
    {'th', 'tha'},
    {'id', 'ind'},
    {'ms', 'may', 'msa'},
  ];
  return {
    for (final group in groups)
      for (final code in group) code: group,
  };
}();
