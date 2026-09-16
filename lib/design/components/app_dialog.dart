import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/app_button.dart';
import 'package:iptv_player/design/focus/focus_pane.dart';
import 'package:iptv_player/design/tokens.dart';

/// A modal dialog (docs/05: radius 16, shadow, Esc closes). Content is
/// whatever the caller passes; the footer holds up to two buttons.
class AppDialog extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.subtitle,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.onClose,
    this.destructive = false,
    this.width = 520,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onClose;

  /// Makes the primary button a danger button (Delete file, Remove
  /// source).
  final bool destructive;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return FocusPane(
      debugLabel: 'dialog',
      child: Center(
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: 640),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: tokens.radii.lgAll,
            border: Border.all(color: colors.border),
            boxShadow: tokens.elevation.overlay,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.s20,
                  tokens.spacing.s20,
                  tokens.spacing.s12,
                  tokens.spacing.s12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: tokens.text.h3.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: tokens.spacing.s4),
                            Text(
                              subtitle!,
                              style: tokens.text.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onClose != null)
                      Semantics(
                        button: true,
                        label: 'Close',
                        child: GestureDetector(
                          onTap: onClose,
                          child: Padding(
                            padding: EdgeInsets.all(tokens.spacing.s8),
                            child: AppIcon(
                              AppIcons.close,
                              size: 18,
                              color: colors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s20),
                  child: child,
                ),
              ),
              if (primaryLabel != null || secondaryLabel != null)
                Padding(
                  padding: EdgeInsets.all(tokens.spacing.s20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (secondaryLabel != null) ...[
                        AppButton(
                          label: secondaryLabel!,
                          variant: AppButtonVariant.secondary,
                          onPressed: onSecondary,
                        ),
                        SizedBox(width: tokens.spacing.s8),
                      ],
                      if (primaryLabel != null)
                        AppButton(
                          label: primaryLabel!,
                          variant: destructive
                              ? AppButtonVariant.danger
                              : AppButtonVariant.primary,
                          autofocus: true,
                          onPressed: onPrimary,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A panel that slides in from the right (programme details, item info).
/// Same surface as [AppDialog], anchored to the edge.
class AppSheet extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.onClose,
    this.width = 420,
    this.footer,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final double width;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return FocusPane(
      debugLabel: 'sheet',
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: colors.surface1,
            border: Border(left: BorderSide(color: colors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.s20,
                  tokens.spacing.s20,
                  tokens.spacing.s12,
                  tokens.spacing.s12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: tokens.text.h3.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (onClose != null)
                      Semantics(
                        button: true,
                        label: 'Close',
                        child: GestureDetector(
                          onTap: onClose,
                          child: Padding(
                            padding: EdgeInsets.all(tokens.spacing.s8),
                            child: AppIcon(
                              AppIcons.close,
                              size: 18,
                              color: colors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s20),
                  child: child,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: EdgeInsets.all(tokens.spacing.s20),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
