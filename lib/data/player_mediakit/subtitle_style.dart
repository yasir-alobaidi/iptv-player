import 'package:media_kit_video/media_kit_video.dart';

/// media_kit's subtitles at [scale] times their own size (Settings →
/// Playback → Subtitle size, ADR-038): its font, 32 px for a 1920×1080
/// picture and less in a smaller box, times [scale]. Nothing else changes:
/// where they sit, their colours and the box behind the text stay
/// media_kit's. At 1 it is media_kit's own configuration, so a desktop's
/// Medium looks as it always has.
SubtitleViewConfiguration subtitleConfiguration(double scale) {
  const own = SubtitleViewConfiguration();
  if (scale == 1) return own;
  final style = own.style;
  return SubtitleViewConfiguration(
    style: style.copyWith(fontSize: style.fontSize! * scale),
  );
}

/// One configuration per scale, kept: media_kit's `Video` takes a new
/// configuration for a change and builds its subtitles again, and its
/// configurations have no equality of their own. So the picture rebuilt
/// for something else (a state, a size) leaves its subtitles alone.
final class SubtitleStyles {
  final _byScale = <double, SubtitleViewConfiguration>{};

  SubtitleViewConfiguration at(double scale) =>
      _byScale[scale] ??= subtitleConfiguration(scale);
}
