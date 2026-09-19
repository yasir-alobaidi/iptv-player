import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/app_badge.dart';
import 'package:iptv_player/design/components/app_tooltip.dart';
import 'package:iptv_player/design/tokens.dart';

/// What the relay is doing to a cast stream (docs/04, docs/05).
enum StreamQuality {
  original('Original', 'Sent to the TV untouched'),
  convertedAudio('Converted audio', 'Audio re-encoded to AAC; video untouched'),
  transcoded('Transcoded', 'Re-encoded for the TV, which costs CPU');

  new(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// Says whether a cast is a straight copy or a re-encode, with the reason
/// in a tooltip.
class QualityBadge extends StatelessWidget {
  const new(this.quality, {this.detail, super.key});

  final StreamQuality quality;

  /// Extra context, e.g. "HEVC is not supported by this TV".
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final tone = switch (quality) {
      StreamQuality.original => AppBadgeTone.success,
      StreamQuality.convertedAudio => AppBadgeTone.neutral,
      StreamQuality.transcoded => AppBadgeTone.warning,
    };

    return AppTooltip(
      message: detail == null
          ? quality.explanation
          : '${quality.explanation}. $detail',
      child: AppBadge(quality.label, tone: tone),
    );
  }
}

/// "Reconnecting…" over the player, top centre (docs/05).
class ReconnectingPill extends StatelessWidget {
  const new({this.message = 'Reconnecting…', this.attempt, super.key});

  final String message;

  /// Retry number, shown as "· try 2" so a loop is visible.
  final int? attempt;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s12,
        vertical: tokens.spacing.s8 - 2,
      ),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.75),
        borderRadius: tokens.radii.pillAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: tokens.motion.reduceMotion
                ? AppIcon(AppIcons.loading, size: 14, color: colors.warning)
                : CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.warning,
                  ),
          ),
          SizedBox(width: tokens.spacing.s8),
          Text(
            attempt == null ? message : '$message · try $attempt',
            style: tokens.text.caption
                .withWeight(600)
                .copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
