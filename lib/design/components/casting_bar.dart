import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/app_button.dart';
import 'package:iptv_player/design/components/channel_logo.dart';
import 'package:iptv_player/design/components/progress_bar.dart';
import 'package:iptv_player/design/components/quality_badge.dart';
import 'package:iptv_player/design/tokens.dart';

/// The 64 px bar at the bottom of the shell while something is casting
/// (docs/05). Presentational: the coordinator passes state and callbacks.
class CastingBar extends StatelessWidget {
  const new({
    required this.title,
    required this.deviceName,
    this.subtitle,
    this.image,
    this.quality,
    this.qualityDetail,
    this.isPlaying = true,
    this.progress,
    this.reconnecting = false,
    this.onPlayPause,
    this.onStop,
    super.key,
  });

  final String title;

  /// "Playing on Living Room TV".
  final String deviceName;
  final String? subtitle;
  final ImageProvider? image;
  final StreamQuality? quality;
  final String? qualityDetail;
  final bool isPlaying;

  /// VOD progress, 0..1; null for live.
  final double? progress;
  final bool reconnecting;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s16),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          ChannelLogo(name: title, image: image),
          SizedBox(width: tokens.spacing.s12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.bodyStrong.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: tokens.spacing.s4 - 2),
                Row(
                  children: [
                    AppIcon(
                      AppIcons.castConnected,
                      size: 13,
                      color: colors.accentBase,
                    ),
                    SizedBox(width: tokens.spacing.s4 + 2),
                    Flexible(
                      child: Text(
                        reconnecting
                            ? 'Reconnecting to $deviceName…'
                            : 'Playing on $deviceName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.labelSmall.copyWith(
                          color: reconnecting
                              ? colors.warning
                              : colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(width: tokens.spacing.s8),
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.text.labelSmall.copyWith(
                            color: colors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (progress != null) ...[
                  SizedBox(height: tokens.spacing.s4 + 1),
                  ProgressBar(value: progress, height: 2),
                ],
              ],
            ),
          ),
          if (quality != null) ...[
            SizedBox(width: tokens.spacing.s12),
            QualityBadge(quality!, detail: qualityDetail),
          ],
          SizedBox(width: tokens.spacing.s12),
          AppButton(
            label: isPlaying ? 'Pause' : 'Play',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.s,
            onPressed: onPlayPause,
          ),
          SizedBox(width: tokens.spacing.s8),
          AppButton(
            label: 'Stop casting',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.s,
            onPressed: onStop,
          ),
        ],
      ),
    );
  }
}
