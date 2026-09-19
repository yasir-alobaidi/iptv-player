import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/tokens.dart';

/// A transient message, bottom centre, three seconds, with an optional
/// action (docs/05). The shell hosts these; step 4 feeds it from the
/// error reporter.
class AppToast extends StatelessWidget {
  const new({
    required this.message,
    this.tone = ToastTone.neutral,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final ToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// How long a toast stays up (docs/05).
  static const defaultDuration = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    final (accent, icon) = switch (tone) {
      ToastTone.neutral => (colors.textSecondary, null),
      ToastTone.success => (colors.success, AppIcons.check),
      ToastTone.error => (colors.danger, AppIcons.alertCircle),
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s16,
        vertical: tokens.spacing.s12,
      ),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: tokens.radii.controlAll,
        border: Border.all(color: colors.border),
        boxShadow: tokens.elevation.overlay,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 16, color: accent),
            SizedBox(width: tokens.spacing.s8 + 2),
          ],
          Flexible(
            child: Text(
              message,
              style: tokens.text.caption.copyWith(color: colors.textPrimary),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(width: tokens.spacing.s16),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: tokens.text.caption
                      .withWeight(700)
                      .copyWith(color: colors.accentBase),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Toast emphasis.
enum ToastTone { neutral, success, error }
