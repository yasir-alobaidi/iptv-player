import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// Whether the app draws key hints ([Kbd]): off on a TV, whose remote has
/// none of those keys (docs/07). Above everything the router draws, so
/// menus and tooltips see it too; with none above, hints are drawn.
class KeyHints extends InheritedWidget {
  const new({required this.shown, required super.child, super.key});

  final bool shown;

  static bool shownIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KeyHints>()?.shown ?? true;

  @override
  bool updateShouldNotify(KeyHints oldWidget) => oldWidget.shown != shown;
}

/// A keycap, e.g. `Ctrl K` or `Esc` (canvas: mono 11 px in a bordered
/// pill on surface2).
class Kbd extends StatelessWidget {
  const new(this.keys, {this.onDark = false, super.key});

  /// The key label as it should read, e.g. `Ctrl K`.
  final String keys;

  /// Over video, where the surface colors don't apply.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s4 + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: onDark ? Colors.transparent : colors.surface2,
        borderRadius: tokens.radii.xsAll,
        border: Border.all(
          color: onDark
              ? colors.textPrimary.withValues(alpha: 0.25)
              : colors.border,
        ),
      ),
      child: Text(
        keys,
        style: tokens.text.monoMicro.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
