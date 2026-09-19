import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/channel_logo.dart';
import 'package:iptv_player/design/components/progress_bar.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// One channel in the Live TV list: number, logo, name, what's on now, a
/// thin progress bar for the current programme, and a favorite star.
class ChannelRow extends StatelessWidget {
  const new({
    required this.name,
    this.number,
    this.image,
    this.nowTitle,
    this.guideKnown = true,
    this.progress,
    this.badges = const [],
    this.isFavorite = false,
    this.selected = false,
    this.onPressed,
    this.onMenu,
    this.onToggleFavorite,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final String name;
  final int? number;
  final ImageProvider? image;

  /// The programme on now; null shows "No guide data".
  final String? nowTitle;

  /// False while nothing was looked up for this channel yet: the second
  /// line stays empty rather than claiming there is no guide.
  final bool guideKnown;

  /// How far through the current programme, 0..1.
  final double? progress;
  final List<Widget> badges;
  final bool isFavorite;

  /// The row the preview pane is showing.
  final bool selected;
  final VoidCallback? onPressed;
  final VoidCallback? onMenu;
  final VoidCallback? onToggleFavorite;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final height = tokens.density.rowHeight;

    return FocusableSurface(
      onPressed: onPressed,
      onMenu: onMenu,
      autofocus: autofocus,
      focusNode: focusNode,
      background: selected ? colors.surface3 : null,
      hoverBackground: colors.surface3,
      borderRadius: tokens.radii.controlAll,
      semanticLabel: name,
      builder: (context, states) => SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12 + 2),
          child: Row(
            children: [
              if (number != null) ...[
                SizedBox(
                  width: 32,
                  child: Text(
                    '$number',
                    style: tokens.text.caption
                        .withWeight(700)
                        .copyWith(
                          color: selected
                              ? colors.accentBase
                              : colors.textTertiary,
                        ),
                  ),
                ),
                SizedBox(width: tokens.spacing.s4),
              ],
              ChannelLogo(name: name, image: image),
              SizedBox(width: tokens.spacing.s12 + 2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.text.bodyStrong.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        for (final badge in badges) ...[
                          SizedBox(width: tokens.spacing.s8 - 2),
                          badge,
                        ],
                      ],
                    ),
                    if (guideKnown || nowTitle != null) ...[
                      SizedBox(height: tokens.spacing.s4 - 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nowTitle ?? (guideKnown ? 'No guide data' : ''),
                              overflow: TextOverflow.ellipsis,
                              style: tokens.text.caption.copyWith(
                                color: nowTitle == null
                                    ? colors.textTertiary
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                          // The canvas puts the programme's progress on
                          // this line, after the title: a 72 px bar with
                          // a 10 px gap. It rode the row's bottom edge
                          // until the step 7 golden showed it striking
                          // through the title in both densities.
                          if (progress != null) ...[
                            SizedBox(width: tokens.spacing.s8 + 2),
                            SizedBox(
                              width: 72,
                              child: ProgressBar(value: progress),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onToggleFavorite != null) ...[
                SizedBox(width: tokens.spacing.s8),
                _FavoriteStar(
                  isFavorite: isFavorite,
                  onPressed: onToggleFavorite!,
                  visible: states.highlighted || isFavorite,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteStar extends StatelessWidget {
  const new({
    required this.isFavorite,
    required this.onPressed,
    required this.visible,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  /// The star only appears on hover, focus, or when it is already set —
  /// a star on every row is noise.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: tokens.motion.fast,
      child: Semantics(
        button: true,
        label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
        child: GestureDetector(
          onTap: visible ? onPressed : null,
          child: AppIcon(
            isFavorite ? AppIcons.starFilled : AppIcons.star,
            size: 18,
            color: isFavorite
                ? tokens.colors.warning
                : tokens.colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
