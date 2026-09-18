import 'package:flutter/material.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// One of a few large, mutually exclusive options: a title and a line
/// under it, outlined in accent when selected (canvas, onboarding source
/// types). Behaves as a radio button.
class ChoiceCard extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: FocusableSurface(
        onPressed: onPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        borderRadius: tokens.radii.mdAll,
        semanticLabel: '$title. $subtitle',
        builder: (context, states) => AnimatedContainer(
          duration: tokens.motion.fast,
          curve: tokens.motion.fastCurve,
          padding: EdgeInsets.all(tokens.spacing.s12 + 2),
          decoration: BoxDecoration(
            borderRadius: tokens.radii.mdAll,
            color: selected
                ? colors.accentBase.withValues(alpha: 0.10)
                : states.highlighted
                ? colors.surface2
                : colors.surface1,
            border: Border.all(
              color: selected ? colors.accentBase : colors.surface3,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.bodyStrong
                    .withWeight(selected ? 800 : 700)
                    .copyWith(
                      color: selected
                          ? colors.textPrimary
                          : colors.textEmphasis,
                    ),
              ),
              SizedBox(height: tokens.spacing.s4 + 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.labelSmall
                    .withWeight(500)
                    .copyWith(
                      color: selected
                          ? colors.textSecondary
                          : colors.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
