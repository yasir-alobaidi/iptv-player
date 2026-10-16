import 'package:flutter/material.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/text_scale.dart';
import 'package:iptv_player/design/tokens.dart';

/// "Channels 8": a tab with its count, underlined when chosen (canvas
/// `Favorites`, `Library`; a series' seasons). [highlightCount] draws the
/// count as the accent pill the Library's Downloads tab carries while
/// downloads run. Focus rings the label with room round it; the
/// underline stays below the ring (ADR-029).
class CountTab extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.count,
    this.highlightCount = false,
    this.focusNode,
    super.key,
  });

  final String label;
  final int? count;
  final bool selected;
  final bool highlightCount;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final inset = tokens.spacing.s8 + 2;
    return FocusableSurface(
      onPressed: onPressed,
      focusNode: focusNode,
      borderRadius: tokens.radii.smAll,
      semanticLabel: count == null ? label : '$label, $count',
      ring: false,
      // As wide as its label: the underline spans the words.
      builder: (context, states) => IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFocusRing(
              visible: states.focused,
              borderRadius: tokens.radii.smAll,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: inset,
                  vertical: tokens.spacing.s8,
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
                          constraints: BoxConstraints(
                            minWidth: context.scaled(tokens.spacing.s16 + 2),
                          ),
                          height: context.scaled(tokens.spacing.s16 + 2),
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
            ),
            SizedBox(height: tokens.spacing.s4 + 2),
            // Under the words, not the ring's box.
            Container(
              height: 2,
              margin: EdgeInsets.symmetric(horizontal: inset),
              color: selected ? colors.accentBase : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
