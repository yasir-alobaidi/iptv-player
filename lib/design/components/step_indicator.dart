import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/tokens.dart';

/// Where a multi-step flow is: done steps get a green check, the current
/// one an accent number, later ones an outlined number (canvas,
/// onboarding header). Not interactive.
class StepIndicator extends StatelessWidget {
  const new({required this.steps, required this.current, super.key});

  final List<String> steps;

  /// Zero-based; every step before it counts as done.
  final int current;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final style = tokens.text.caption.withWeight(700);

    final children = <Widget>[];
    for (final (index, label) in steps.indexed) {
      if (index > 0) {
        children.add(Container(width: 28, height: 1, color: colors.border));
      }
      final done = index < current;
      final active = index == current;
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(number: index + 1, done: done, active: active),
            SizedBox(width: tokens.spacing.s4 + 2),
            Text(
              label,
              style: style.copyWith(
                color: active
                    ? colors.textPrimary
                    : done
                    ? colors.textSecondary
                    : colors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: 'Step ${current + 1} of ${steps.length}: ${steps[current]}',
      excludeSemantics: true,
      child: Wrap(
        spacing: tokens.spacing.s8 + 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const new({required this.number, required this.done, required this.active});

  final int number;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? colors.success
            : active
            ? colors.accentBase
            : null,
        border: done || active ? null : Border.all(color: colors.border),
      ),
      child: done
          ? AppIcon(AppIcons.check, size: 12, color: colors.bg)
          : Text(
              '$number',
              style: tokens.text.micro
                  .withWeight(700)
                  .copyWith(
                    letterSpacing: 0,
                    color: active ? colors.onAccent : colors.textTertiary,
                  ),
            ),
    );
  }
}
