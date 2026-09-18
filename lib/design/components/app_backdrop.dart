import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// The full-window pages' background: the app background with a soft
/// accent glow from the top right (canvas, onboarding).
class AppBackdrop extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.7, -1),
            radius: 0.9,
            colors: [colors.accentSoft, colors.accentBase.withValues(alpha: 0)],
          ),
        ),
        child: child,
      ),
    );
  }
}
