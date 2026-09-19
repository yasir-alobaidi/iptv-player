import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/app_button.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// How loud a banner is.
enum BannerTone { info, warning, error, success }

/// A persistent inline message at the top of a screen, e.g. "You're
/// offline — downloads and local files still play" (docs/05).
class AppBanner extends StatelessWidget {
  const new({
    required this.message,
    this.tone = BannerTone.info,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    super.key,
  });

  final String message;
  final BannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    final (accent, icon) = switch (tone) {
      BannerTone.info => (colors.accentBase, AppIcons.info),
      BannerTone.warning => (colors.warning, AppIcons.alertTriangle),
      BannerTone.error => (colors.danger, AppIcons.alertCircle),
      BannerTone.success => (colors.success, AppIcons.check),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s16,
        vertical: tokens.spacing.s12,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: tokens.radii.controlAll,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 18, color: accent),
          SizedBox(width: tokens.spacing.s12),
          Expanded(
            child: Text(
              message,
              style: tokens.text.caption.copyWith(color: colors.textPrimary),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(width: tokens.spacing.s12),
            AppButton(
              label: actionLabel!,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.s,
              onPressed: onAction,
            ),
          ],
          if (onDismiss != null) ...[
            SizedBox(width: tokens.spacing.s4),
            // Focusable like every other control (hard rule 5); the
            // padding keeps the icon where it was and gives it a ring.
            FocusableSurface(
              onPressed: onDismiss,
              borderRadius: tokens.radii.smAll,
              semanticLabel: 'Dismiss',
              builder: (context, states) => Padding(
                padding: EdgeInsets.all(tokens.spacing.s4),
                child: AppIcon(
                  AppIcons.close,
                  size: 16,
                  color: states.highlighted
                      ? colors.textPrimary
                      : colors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
