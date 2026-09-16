import 'package:flutter/material.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// A pill-shaped filter chip (canvas: 34 px tall; selected chips use the
/// accent at 16 % with a 50 % accent outline).
class AppChip extends StatelessWidget {
  const new({
    required this.label,
    this.onPressed,
    this.selected = false,
    this.count,
    this.icon,
    this.onRemove,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  /// Optional trailing count, e.g. the number of channels in a category.
  final int? count;
  final IconData? icon;

  /// Shows a remove affordance (active filters).
  final VoidCallback? onRemove;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final foreground = selected ? colors.accentBase : colors.textSecondary;

    return FocusableSurface(
      onPressed: enabled ? onPressed : null,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      background: selected ? colors.accentSoft : colors.surface2,
      hoverBackground: selected ? colors.accentSoft : colors.surface3,
      borderRadius: tokens.radii.pillAll,
      semanticLabel: label,
      builder: (context, states) => Opacity(
        opacity: states.disabled ? 0.4 : 1,
        child: Container(
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s16 - 2),
          decoration: BoxDecoration(
            borderRadius: tokens.radii.pillAll,
            border: Border.all(
              color: selected ? colors.accentSoftBorder : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                SizedBox(width: tokens.spacing.s4 + 2),
              ],
              Text(
                label,
                style: tokens.text.caption.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: tokens.spacing.s8 - 2),
                Text(
                  '$count',
                  style: tokens.text.labelSmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
              if (onRemove != null) ...[
                SizedBox(width: tokens.spacing.s4 + 2),
                Icon(Icons.close_rounded, size: 14, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
