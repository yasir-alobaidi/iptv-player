import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// Where a focus ring is drawn against its control's edge.
enum RingPlacement {
  /// Outside the edge, [AppFocusTokens.gap] off it: a control that stands
  /// alone, with room around it.
  outside,

  /// Inside the edge: a row that fills its list, whose list would clip a
  /// ring outside it and whose neighbours would cover it (ADR-029).
  inside,
}

/// The design system's focus ring around [child], drawn as the tokens say:
/// the accent (the text colour on an accent surface, [onAccent]) on the
/// desktop, white on a TV ([AppFocusTokens.light]).
class AppFocusRing extends StatelessWidget {
  const new({
    required this.visible,
    required this.borderRadius,
    required this.child,
    this.onAccent = false,
    this.placement = RingPlacement.outside,
    this.animated = true,
    super.key,
  });

  final bool visible;
  final BorderRadius borderRadius;
  final bool onAccent;
  final RingPlacement placement;

  /// False where the ring moves with the focus rather than fading in
  /// (the Guide's cells).
  final bool animated;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final focus = tokens.focus;
    final light = focus.light || onAccent;
    return FocusRing(
      visible: visible,
      borderRadius: borderRadius,
      ringColor: light ? colors.textPrimary : colors.accentBase,
      glowColor: colors.accentBase.withValues(
        alpha: onAccent ? focus.onAccentGlowOpacity : focus.glowOpacity,
      ),
      ringWidth: focus.ringWidth,
      glowWidth: onAccent ? focus.onAccentGlowWidth : focus.glowWidth,
      gap: focus.gap,
      placement: focus.inside ? RingPlacement.inside : placement,
      duration: animated ? tokens.motion.fast : Duration.zero,
      curve: tokens.motion.fastCurve,
      child: child,
    );
  }
}

/// Draws a focus ring around the child's bounds: a solid ring, then a
/// wider translucent glow, outside the edge or inside it ([placement]).
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
    this.gap = 0,
    this.placement = RingPlacement.outside,
    super.key,
  });

  final bool visible;
  final BorderRadius borderRadius;
  final Color ringColor;
  final Color glowColor;
  final double ringWidth;
  final double glowWidth;
  final double gap;
  final RingPlacement placement;
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
                gap: gap,
                placement: placement,
              ),
        child: child,
      ),
      child: child,
    );
  }
}

/// Paints the ring and its glow just outside the painted bounds, or the
/// ring just inside them.
@visibleForTesting
class FocusRingPainter extends CustomPainter {
  const new({
    required this.opacity,
    required this.borderRadius,
    required this.ringColor,
    required this.glowColor,
    required this.ringWidth,
    required this.glowWidth,
    this.gap = 0,
    this.placement = RingPlacement.outside,
  });

  final double opacity;
  final BorderRadius borderRadius;
  final Color ringColor;
  final Color glowColor;
  final double ringWidth;
  final double glowWidth;
  final double gap;
  final RingPlacement placement;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // [inset] is how far the stroke's middle lies outside the edge
    // (negative: inside it); the radius follows, so the ring stays
    // parallel to the corner.
    void stroke(Color color, double width, double inset) {
      if (width <= 0 || color.a == 0) return;
      final rect = bounds.inflate(inset);
      final radius = Radius.circular(
        (borderRadius.topLeft.x + inset).clamp(0, double.infinity),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: color.a * opacity),
      );
    }

    if (placement == RingPlacement.inside) {
      // Inside the edge there is no room for a glow; the ring alone.
      stroke(ringColor, ringWidth, -ringWidth / 2);
      return;
    }
    // Glow first, ring on top, so the ring stays solid.
    stroke(glowColor, glowWidth, gap + ringWidth + glowWidth / 2);
    stroke(ringColor, ringWidth, gap + ringWidth / 2);
  }

  @override
  bool shouldRepaint(FocusRingPainter oldDelegate) =>
      oldDelegate.opacity != opacity ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.ringWidth != ringWidth ||
      oldDelegate.glowWidth != glowWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.placement != placement ||
      oldDelegate.borderRadius != borderRadius;
}
