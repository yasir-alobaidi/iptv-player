import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/kbd.dart';
import 'package:iptv_player/design/focus/focus_pane.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// One entry in an [AppMenu].
@immutable
class AppMenuItem {
  const new({
    required this.label,
    this.icon,
    this.shortcut,
    this.onPressed,
    this.destructive = false,
    this.checked = false,
  });

  /// A divider between groups.
  const factory separator() = _MenuSeparator;

  final String label;
  final AppIcons? icon;

  /// Key hint on the right, e.g. `F`.
  final String? shortcut;
  final VoidCallback? onPressed;

  /// Delete and other irreversible entries are drawn in danger colors.
  final bool destructive;
  final bool checked;
}

class _MenuSeparator extends AppMenuItem {
  const new() : super(label: '');
}

/// The item menu, opened with the Menu key, Shift+F10, or right-click
/// (docs/05). Presentational: callers position it.
class AppMenu extends StatelessWidget {
  const new({
    required this.items,
    this.width = 240,
    this.autofocus = false,
    super.key,
  });

  final List<AppMenuItem> items;
  final double width;

  /// Focuses the first enabled item: a menu opened from the keyboard is
  /// walked with the arrows at once.
  final bool autofocus;

  AppMenuItem? get _firstEnabled => items
      .where((item) => item is! _MenuSeparator && item.onPressed != null)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return FocusPane(
      debugLabel: 'menu',
      child: Container(
        width: width,
        padding: EdgeInsets.all(tokens.spacing.s4 + 2),
        decoration: BoxDecoration(
          color: colors.surface3,
          borderRadius: tokens.radii.controlAll,
          border: Border.all(color: colors.border),
          boxShadow: tokens.elevation.overlay,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              if (item is _MenuSeparator)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: tokens.spacing.s4),
                  child: Divider(height: 1, color: colors.border),
                )
              else
                _MenuRow(
                  item: item,
                  autofocus: autofocus && identical(item, _firstEnabled),
                ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const new({required this.item, this.autofocus = false});

  final AppMenuItem item;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final foreground = item.destructive ? colors.danger : colors.textPrimary;

    return FocusableSurface(
      onPressed: item.onPressed,
      enabled: item.onPressed != null,
      autofocus: autofocus,
      hoverBackground: colors.bg.withValues(alpha: 0.4),
      borderRadius: tokens.radii.smAll,
      semanticLabel: item.label,
      builder: (context, states) => Opacity(
        opacity: states.disabled ? 0.4 : 1,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.s8 + 2,
            vertical: tokens.spacing.s8,
          ),
          child: Row(
            children: [
              if (item.icon != null) ...[
                AppIcon(item.icon!, size: 16, color: foreground),
                SizedBox(width: tokens.spacing.s8 + 2),
              ],
              Expanded(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.caption
                      .withWeight(600)
                      .copyWith(color: foreground),
                ),
              ),
              if (item.checked)
                AppIcon(AppIcons.check, size: 14, color: colors.accentBase),
              if (item.shortcut != null) ...[
                SizedBox(width: tokens.spacing.s8),
                Kbd(item.shortcut!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
