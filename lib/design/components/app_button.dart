import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// Button emphasis (docs/05).
enum AppButtonVariant { primary, secondary, ghost, danger }

/// Button height (canvas: 36 / 44 / 48 px).
enum AppButtonSize {
  s(height: 36, padding: 14, gap: 8),
  m(height: 44, padding: 18, gap: 8),
  l(height: 48, padding: 22, gap: 10);

  new({required this.height, required this.padding, required this.gap});

  final double height;
  final double padding;
  final double gap;
}

/// The standard button. `onPressed: null` or `loading: true` disables it,
/// and a disabled button is skipped by keyboard traversal.
class AppButton extends StatelessWidget {
  const new({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.m,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final AppIcons? icon;

  /// After the label: the canvas's "Start sync →" for a step forward.
  final AppIcons? trailingIcon;

  /// Shows a spinner in place of the leading icon and blocks activation.
  final bool loading;

  /// Fills the available width (dialog footers, onboarding).
  final bool expand;
  final bool autofocus;
  final FocusNode? focusNode;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final filled =
        variant == AppButtonVariant.primary ||
        variant == AppButtonVariant.danger;

    final background = switch (variant) {
      AppButtonVariant.primary => colors.accentBase,
      AppButtonVariant.danger => colors.danger,
      AppButtonVariant.secondary => colors.surface2,
      AppButtonVariant.ghost => null,
    };
    final hoverBackground = switch (variant) {
      AppButtonVariant.primary => colors.accentHover,
      AppButtonVariant.danger => colors.danger,
      AppButtonVariant.secondary => colors.surface3,
      AppButtonVariant.ghost => colors.surface2,
    };
    final foreground = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.danger => colors.onAccent,
      AppButtonVariant.secondary => colors.textPrimary,
      AppButtonVariant.ghost => colors.textSecondary,
    };
    final border = variant == AppButtonVariant.secondary
        ? Border.all(color: colors.border)
        : null;

    final textStyle =
        (size == AppButtonSize.s ? tokens.text.buttonSmall : tokens.text.button)
            .copyWith(color: foreground);

    return FocusableSurface(
      onPressed: _enabled ? onPressed : null,
      enabled: _enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      onAccent: filled,
      background: background,
      hoverBackground: hoverBackground,
      borderRadius: tokens.radii.controlAll,
      semanticLabel: label,
      builder: (context, states) {
        final content = Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else if (icon != null)
              AppIcon(icon!, size: 18, color: foreground),
            if (loading || icon != null) SizedBox(width: size.gap),
            Text(label, style: textStyle),
            if (trailingIcon != null) ...[
              SizedBox(width: size.gap),
              AppIcon(trailingIcon!, size: 16, color: foreground),
            ],
          ],
        );

        return Opacity(
          opacity: states.disabled ? _disabledOpacity : 1,
          child: Container(
            height: size.height,
            padding: EdgeInsets.symmetric(horizontal: size.padding),
            decoration: BoxDecoration(
              // The surface paints the background; this paints the border
              // so it stays inside the focus ring.
              borderRadius: tokens.radii.controlAll,
              border: border,
            ),
            child: content,
          ),
        );
      },
    );
  }
}

/// Canvas: a disabled control is the same shape at 40 % opacity.
const _disabledOpacity = 0.4;
