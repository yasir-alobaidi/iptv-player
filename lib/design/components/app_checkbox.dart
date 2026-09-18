import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/tokens.dart';

/// A checkbox's three looks (canvas, Pick categories).
enum CheckState { on, mixed, off }

/// The canvas's 20 px checkbox: accent-filled with a check when on, with
/// a dash when some of a group is on, outlined when off. Only the mark:
/// the row or tile around it is what takes focus and toggles, so the
/// whole row is the target.
class AppCheckbox extends StatelessWidget {
  const new({required this.state, this.emphasized = false, super.key});

  final CheckState state;

  /// A brighter outline for the off state, as on a focused tile.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final filled = state != CheckState.off;
    return AnimatedContainer(
      duration: tokens.motion.fast,
      curve: tokens.motion.fastCurve,
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? colors.accentBase : null,
        borderRadius: tokens.radii.xsAll,
        border: filled
            ? null
            : Border.all(
                color: emphasized ? colors.textTertiary : colors.borderStrong,
                width: 2,
              ),
      ),
      child: switch (state) {
        CheckState.on => AppIcon(
          AppIcons.check,
          size: 14,
          color: colors.onAccent,
        ),
        CheckState.mixed => Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: colors.onAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        CheckState.off => null,
      },
    );
  }
}
