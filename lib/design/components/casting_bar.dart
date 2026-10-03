import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/app_icon_button.dart';
import 'package:iptv_player/design/components/channel_logo.dart';
import 'package:iptv_player/design/components/quality_badge.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// The bar under the content while something is casting (canvas
/// `Casting`, docs/05): the picture, the title, "Casting to Living Room TV
/// · Original quality", play/pause for a file, and Stop. Pressing the bar
/// itself opens the casting view. Presentational: the caller passes state
/// and callbacks.
class CastingBar extends StatelessWidget {
  const new({
    required this.title,
    required this.deviceName,
    this.imageName,
    this.image,
    this.quality,
    this.status,
    this.isPlaying = true,
    this.reconnecting = false,
    this.onOpen,
    this.onPlayPause,
    this.onStop,
    super.key,
  });

  final String title;

  /// "Living Room TV".
  final String deviceName;

  /// Whose monogram stands in for a missing [image]: the channel's, not
  /// the programme's; [title] when null.
  final String? imageName;
  final ImageProvider? image;

  /// The badge's word after the device's name; null while it isn't known.
  final StreamQuality? quality;

  /// Said instead of the quality: "Connecting…", "Preparing…", what
  /// failed.
  final String? status;
  final bool isPlaying;
  final bool reconnecting;
  final VoidCallback? onOpen;

  /// Null for live: a paused live relay would run out of segments.
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final cast = tokens.cast;
    final line = reconnecting
        ? 'Reconnecting to $deviceName…'
        : [
            'Casting to $deviceName',
            if (status case final status?)
              status
            else if (quality case final quality?)
              quality.sentenceLabel,
          ].join(' · ');

    return Container(
      height: cast.barHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(cast.barRadius),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: FocusableSurface(
              onPressed: onOpen,
              borderRadius: tokens.radii.controlAll,
              semanticLabel: 'Open the casting view: $title, $line',
              builder: (context, states) => Padding(
                padding: EdgeInsets.all(tokens.spacing.s4),
                child: Row(
                  children: [
                    ChannelLogo(
                      name: imageName ?? title,
                      image: image,
                      size: cast.barLogo,
                    ),
                    SizedBox(width: tokens.spacing.s12 + 2),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.text.label
                                .withWeight(700)
                                .copyWith(color: colors.textPrimary),
                          ),
                          SizedBox(height: tokens.spacing.s4 / 2),
                          Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.text.small
                                .withWeight(500)
                                .copyWith(
                                  color: reconnecting
                                      ? colors.warning
                                      : colors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onPlayPause != null) ...[
            SizedBox(width: tokens.spacing.s12),
            AppIconButton(
              icon: isPlaying ? AppIcons.pause : AppIcons.play,
              tooltip: isPlaying ? 'Pause' : 'Play',
              filled: true,
              iconSize: 16,
              onPressed: onPlayPause,
            ),
          ],
          SizedBox(width: tokens.spacing.s12),
          AppIconButton(
            icon: AppIcons.stop,
            tooltip: 'Stop casting',
            filled: true,
            danger: true,
            iconSize: 16,
            onPressed: onStop,
          ),
        ],
      ),
    );
  }
}
