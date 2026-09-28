import 'package:flutter/material.dart';
import 'package:iptv_player/design/components/channel_logo.dart';
import 'package:iptv_player/design/components/progress_bar.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// A channel as Home's rows show it (canvas `Home`): an 84 px tile with
/// the 44 px logo, the name, what is on now, and how far into it.
class ChannelTile extends StatelessWidget {
  const new({
    required this.name,
    this.image,
    this.programme,
    this.progress,
    this.onPressed,
    this.onMenu,
    this.width = 240,
    this.focusNode,
    super.key,
  });

  final String name;
  final ImageProvider? image;

  /// What is on now; null when the guide has nothing.
  final String? programme;

  /// How far into it, 0..1; null hides the bar.
  final double? progress;
  final VoidCallback? onPressed;
  final VoidCallback? onMenu;
  final double width;
  final FocusNode? focusNode;

  static const height = 84.0;
  static const logoSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      onPressed: onPressed,
      onMenu: onMenu,
      focusNode: focusNode,
      growth: FocusGrowth.tile,
      borderRadius: tokens.radii.mdAll,
      semanticLabel: name,
      builder: (context, states) => Container(
        width: width,
        height: height,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12 + 2),
        decoration: BoxDecoration(
          color: states.highlighted ? colors.surface2 : colors.surface1,
          borderRadius: tokens.radii.mdAll,
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            ChannelLogo(
              name: name,
              image: image,
              size: logoSize,
              borderRadius: tokens.radii.controlAll,
            ),
            SizedBox(width: tokens.spacing.s12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.label
                        .withWeight(700)
                        .copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: tokens.spacing.s4 + 1),
                  Text(
                    programme ?? 'No guide information',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.small.copyWith(
                      color: programme == null
                          ? colors.textTertiary
                          : colors.textSecondary,
                    ),
                  ),
                  if (progress != null) ...[
                    SizedBox(height: tokens.spacing.s4 + 1),
                    ProgressBar(
                      value: progress,
                      color: states.focused
                          ? colors.accentBase
                          : colors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
