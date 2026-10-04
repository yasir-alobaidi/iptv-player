import 'package:flutter/material.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// "Channels 8": a tab with its count, underlined when chosen (canvas
/// `Favorites`, `Library`). [highlightCount] draws the count as the
/// accent pill the Library's Downloads tab carries while downloads run.
class CountTab extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.count,
    this.highlightCount = false,
    super.key,
  });

  final String label;
  final int? count;
  final bool selected;
  final bool highlightCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      onPressed: onPressed,
      borderRadius: tokens.radii.smAll,
      semanticLabel: count == null ? label : '$label, $count',
      builder: (context, states) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.s4,
          vertical: tokens.spacing.s12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? colors.accentBase : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: tokens.text.label
                  .withWeight(700)
                  .copyWith(
                    color: selected || states.highlighted
                        ? colors.textPrimary
                        : colors.textSecondary,
                  ),
            ),
            if (count case final count?) ...[
              SizedBox(width: tokens.spacing.s4 + 2),
              if (highlightCount)
                Container(
                  constraints: BoxConstraints(minWidth: tokens.spacing.s16 + 2),
                  height: tokens.spacing.s16 + 2,
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.s4 + 1,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.accentBase,
                    borderRadius: tokens.radii.pillAll,
                  ),
                  child: Text(
                    formatCount(count),
                    style: tokens.text.micro
                        .withWeight(800)
                        .copyWith(color: colors.onAccent),
                  ),
                )
              else
                Text(
                  formatCount(count),
                  style: tokens.text.labelSmall.copyWith(
                    color: selected
                        ? colors.textSecondary
                        : colors.textTertiary,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
