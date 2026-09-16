import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// A row title with an optional "See all" (docs/05).
class SectionHeader extends StatelessWidget {
  const new({
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  /// Anything else on the right (a sort control, a filter).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: tokens.text.titleSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: tokens.spacing.s4 - 2),
                Text(
                  subtitle!,
                  style: tokens.text.labelSmall.copyWith(
                    color: colors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          ?trailing,
          if (onSeeAll != null)
            FocusableSurface(
              onPressed: onSeeAll,
              borderRadius: tokens.radii.smAll,
              hoverBackground: colors.surface2,
              semanticLabel: '$seeAllLabel $title',
              builder: (context, states) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.s8,
                  vertical: tokens.spacing.s4 + 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seeAllLabel,
                      style: tokens.text.caption.copyWith(
                        color: states.highlighted
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.s4),
                    AppIcon(
                      AppIcons.chevronRight,
                      size: 14,
                      color: states.highlighted
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
