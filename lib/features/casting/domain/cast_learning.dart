import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

/// What a refusal taught about a device: what to keep ([learned]) and
/// why ([kind]).
@immutable
final class CastLesson {
  const new(this.kind, this.learned);

  final CastLessonKind kind;
  final CastLearned learned;

  @override
  String toString() => 'CastLesson(${kind.name})';
}

enum CastLessonKind {
  /// The source's streams can't be played directly: the relay from now on
  /// (docs/04 rule 1).
  direct,

  /// Nothing taller than 1080p: often an HDMI link at 1080p, which a TV
  /// setting may unlock (docs/04 "Learning" 1).
  height,

  /// The picture's codec (HEVC on an H.264-only device).
  videoCodec,

  /// Interlaced pictures sent as they are (docs/04 rule 2).
  interlaced,

  /// The sound's codec, sent as it was (MP3, or Dolby passed through).
  audioCodec,
}

/// What the device refusing [plan] teaches (docs/04 "Learning"), given
/// what it [learned] already; null when nothing in the plan can be blamed
/// that a new plan would change. Pure.
///
/// A refusal counts only soon after the LOAD (10 s for a direct play, 15
/// s for the relay's): the caller decides that. In order, as docs/04
/// lists them: a direct play goes through the relay; a picture above
/// 1080p is held at 1080p; a picture codec other than H.264 is
/// re-encoded; an interlaced picture is deinterlaced; a sound other than
/// AAC is converted.
CastLesson? learnFromRefusal({
  required CastPlan plan,
  required StreamFacts facts,
  required CastLearned learned,
  required String sourceId,
}) {
  if (plan.delivery.direct) {
    if (learned.directRefusedSources.contains(sourceId)) return null;
    return CastLesson(
      CastLessonKind.direct,
      learned.copyWith(
        directRefusedSources: {...learned.directRefusedSources, sourceId},
      ),
    );
  }
  final height = plan.output.height ?? 0;
  if (height > 1080 && (learned.maxHeight ?? height) > 1080) {
    return CastLesson(CastLessonKind.height, learned.copyWith(maxHeight: 1080));
  }
  if (plan.video is CastVideoCopy) {
    final codec = facts.video?.codec;
    if (codec != null &&
        codec != 'h264' &&
        !learned.refusedCodecs.contains(codec)) {
      return CastLesson(
        CastLessonKind.videoCodec,
        learned.copyWith(refusedCodecs: {...learned.refusedCodecs, codec}),
      );
    }
    if (plan.output.interlaced && !learned.refusedInterlaced) {
      return CastLesson(
        CastLessonKind.interlaced,
        learned.copyWith(refusedInterlaced: true),
      );
    }
  }
  if (plan.audio case CastAudioCopy(:final track)) {
    final codec = facts.audio.where((a) => a.index == track).firstOrNull?.codec;
    if (codec != null &&
        codec != 'aac' &&
        !learned.refusedCodecs.contains(codec)) {
      return CastLesson(
        CastLessonKind.audioCodec,
        learned.copyWith(refusedCodecs: {...learned.refusedCodecs, codec}),
      );
    }
  }
  return null;
}
