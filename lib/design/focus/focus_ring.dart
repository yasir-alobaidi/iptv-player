import 'package:flutter/material.dart';

/// Draws the design system's focus ring *outside* the child's bounds: a
/// solid ring, then a wider translucent glow.
///
/// A box shadow would be wrong here — a shadow is a filled rounded rect
/// behind the box, so on a transparent surface (a ghost button) it shows
/// through the middle and fills the control instead of outlining it.
class FocusRing extends StatelessWidget {
  const new({
    required this.visible,
    required this.borderRadius,
    required this.ringColor,
    required this.glowColor,
    required this.ringWidth,
    required this.glowWidth,
    required this.duration,
    required this.curve,
    required this.child,
    super.key,
  });

  final bool visible;
  final BorderRadius borderRadius;
  final Color ringColor;
  final Color glowColor;
  final double ringWidth;
  final double glowWidth;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1.0 : 0.0),
      duration: duration,
      curve: curve,
      builder: (context, t, child) => CustomPaint(
        foregroundPainter: t == 0
            ? null
            : FocusRingPainter(
                opacity: t,
                borderRadius: borderRadius,
                ringColor: ringColor,
                glowColor: glowColor,
                ringWidth: ringWidth,
                glowWidth: glowWidth,
              ),
        child: child,
      ),
      child: child,
    );
  }
}

/// Paints the ring and its glow just outside the painted bounds.
@visibleForTesting
class FocusRingPainter extends CustomPainter {
  const new({
    required this.opacity,
    required this.borderRadius,
    required this.ringColor,
    required this.glowColor,
    required this.ringWidth,
    required this.glowWidth,
  });

  final double opacity;
  final BorderRadius borderRadius;
  final Color ringColor;
  final Color glowColor;
  final double ringWidth;
  final double glowWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    void stroke(Color color, double width, double inset) {
      final rect = bounds.inflate(inset);
      final radius = Radius.circular(borderRadius.topLeft.x + inset);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: color.a * opacity),
      );
    }

    // Glow first, ring on top, so the 2 px ring stays solid.
    stroke(glowColor, glowWidth, ringWidth + glowWidth / 2);
    stroke(ringColor, ringWidth, ringWidth / 2);
  }

  @override
  bool shouldRepaint(FocusRingPainter oldDelegate) =>
      oldDelegate.opacity != opacity ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.ringWidth != ringWidth ||
      oldDelegate.glowWidth != glowWidth ||
      oldDelegate.borderRadius != borderRadius;
}
