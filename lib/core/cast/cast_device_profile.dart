import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/cast/cast_device.dart';

/// What a device plays, as the planner sees it (docs/04's profiles): its
/// model where docs/04's table is sure of it, then the user's choice in
/// Settings → Casting, then what it refused before.
@immutable
final class CastDeviceProfile {
  const new({
    this.model,
    this.hevc = HevcSupport.auto,
    this.learned = const CastLearned(),
  });

  /// A kept device, with its setting and what it taught the app.
  factory fromKnown(KnownCastDevice device) => CastDeviceProfile(
    model: device.model,
    hevc: device.hevc,
    learned: device.learned,
  );

  /// TXT `md`, such as "Chromecast".
  final String? model;

  /// The user's choice in Settings → Casting.
  final HevcSupport hevc;
  final CastLearned learned;

  /// docs/04's table, by the model's name exactly.
  CastModelSeed? get seed => castModelSeeds[model?.trim().toLowerCase() ?? ''];

  /// Whether it plays HEVC: true, false, or null when not known, which the
  /// planner tries (a refusal teaches it).
  bool? get playsHevc => switch (hevc) {
    HevcSupport.yes => true,
    HevcSupport.no => false,
    HevcSupport.auto when learned.refusedCodecs.contains('hevc') => false,
    HevcSupport.auto => seed?.hevc,
  };

  /// The tallest picture to send it; null when not known, which the
  /// planner tries (a refusal teaches it).
  int? get maxHeight {
    final learnedMax = learned.maxHeight;
    final seededMax = seed?.maxHeight;
    if (learnedMax == null) return seededMax;
    if (seededMax == null) return learnedMax;
    return math.min(learnedMax, seededMax);
  }

  /// An audio codec it refused (ffprobe's name), converted from then on.
  bool refusedAudio(String? codec) =>
      codec != null && learned.refusedCodecs.contains(codec);
}

/// What a model is known to play (docs/04's table).
@immutable
final class CastModelSeed {
  const new({this.hevc, this.maxHeight});

  final bool? hevc;
  final int? maxHeight;
}

/// docs/04's table, only the rows whose `md` is unambiguous: the
/// Chromecast with Google TV 4K says `Chromecast` like the 1080p
/// generations, and the HD model's and the Streamer's `md` haven't been
/// seen. Keys are lower case.
const castModelSeeds = <String, CastModelSeed>{
  'chromecast ultra': CastModelSeed(hevc: true, maxHeight: 2160),
};
