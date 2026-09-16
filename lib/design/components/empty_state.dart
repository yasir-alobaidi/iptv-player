import 'package:flutter/material.dart';
import 'package:iptv_player/design/components/app_button.dart';
import 'package:iptv_player/design/tokens.dart';

/// "No dead ends" (docs/05): an empty screen says what is missing and
/// offers the next action.
class EmptyState extends StatelessWidget {
  const new({
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tighter spacing for empty panes inside a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    // Scrolls rather than overflowing when the pane is short — with
    // the details open this can be taller than its container.
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: compact ? 44 : 56,
                height: compact ? 44 : 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: tokens.radii.mdAll,
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  icon,
                  size: compact ? 20 : 24,
                  color: colors.textTertiary,
                ),
              ),
              SizedBox(height: tokens.spacing.s16),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: (compact ? tokens.text.titleSmall : tokens.text.h3)
                  .copyWith(color: colors.textPrimary),
            ),
            if (message != null) ...[
              SizedBox(height: tokens.spacing.s8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: tokens.text.body.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: tokens.spacing.s20),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
