import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

/// Makes a file the TV can only take through the relay into an MP4 it
/// can read by itself (Phase 8 decision 12): the relay plays at once and
/// starts again at every seek; once the MP4 is whole, the next seek loads
/// it instead, and every seek after that is the TV's own. The data layer
/// makes it with the bundled FFmpeg, supervised (hard rule 8).
abstract interface class CastMp4Copies {
  /// Starts making the video at [video] into an MP4 with the streams
  /// [plan] sends the TV: the picture copied, the sound as the plan has
  /// it. [plan] is a relay's, with its picture copied. Never throws.
  CastMp4Copy make(
    String video, {
    required CastPlan plan,
    required StreamFacts facts,
  });
}

/// One MP4 in the making, until [delete].
abstract interface class CastMp4Copy {
  /// The MP4's path once it is whole and checked against the file it was
  /// made from. Null when there is none: no room for it, FFmpeg failed,
  /// or it was stopped.
  Future<String?> get ready;

  /// Stops the making, and deletes the MP4.
  Future<void> delete();
}

/// No MP4 is made: a relayed file's seeks stay the relay's (tests, a
/// build without FFmpeg).
final class NoCastMp4Copies implements CastMp4Copies {
  const new();

  @override
  CastMp4Copy make(
    String video, {
    required CastPlan plan,
    required StreamFacts facts,
  }) => const _NoCopy();
}

final class _NoCopy implements CastMp4Copy {
  const new();

  @override
  Future<String?> get ready async => null;

  @override
  Future<void> delete() async {}
}
