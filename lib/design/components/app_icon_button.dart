import 'package:flutter/material.dart';
import 'package:iptv_player/design/components/app_tooltip.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// A square icon-only button (canvas: 40 × 40, radius 10). [tooltip] is
/// required because an icon alone never explains itself; pass [shortcut]
/// to show the key hint inside the tooltip.
class AppIconButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.shortcut,
    this.selected = false,
    this.bordered = false,
    this.size = 40,
    this.iconSize = 20,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Shown as a keycap in the tooltip, e.g. `Ctrl K`.
  final String? shortcut;
  final bool selected;
  final bool bordered;
  final double size;
  final double iconSize;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final enabled = onPressed != null;

    return AppTooltip(
      message: tooltip,
      shortcut: shortcut,
      child: FocusableSurface(
        onPressed: onPressed,
        enabled: enabled,
        autofocus: autofocus,
        focusNode: focusNode,
        background: selected ? colors.surface3 : null,
        hoverBackground: colors.surface3,
        borderRadius: tokens.radii.controlAll,
        semanticLabel: tooltip,
        builder: (context, states) => Opacity(
          opacity: states.disabled ? 0.4 : 1,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: tokens.radii.controlAll,
              border: bordered ? Border.all(color: colors.border) : null,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: selected ? colors.accentBase : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
