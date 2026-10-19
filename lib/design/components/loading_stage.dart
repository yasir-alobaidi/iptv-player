import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:iptv_player/design/components/app_mark.dart';
import 'package:iptv_player/design/components/progress_bar.dart';
import 'package:iptv_player/design/tokens.dart';

/// A wait that is long by nature (a source's first sync filling a screen):
/// Bijou's jewel, its glow breathing and an arc going round it, what is
/// awaited, how far it has come, and a tip that changes every few seconds,
/// so the wait has something to read. With reduce motion on nothing in it
/// moves (a tip changes at once), and nothing in it takes the focus.
///
/// A short wait shows a skeleton of what is coming instead (docs/05).
class LoadingStage extends StatelessWidget {
  const new({
    required this.title,
    this.detail,
    this.bar = false,
    this.progress,
    this.tips = const [],
    super.key,
  });

  /// "Getting your channels…"
  final String title;

  /// How far it has come ("12,340 of 20,000 channels"), changed in place
  /// as it grows.
  final String? detail;

  /// A thin bar under the words: filled to [progress], or a sweep while
  /// [progress] is null. A [progress] shows the bar whatever this says.
  final bool bar;

  /// 0..1.
  final double? progress;

  /// Something to read meanwhile, one at a time in this order
  /// ([RotatingTip]).
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final loading = tokens.loading;
    final value = progress;

    // Scrolls rather than overflowing when the pane is short: Live TV's
    // channel list in the smallest window at 130 %.
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.s24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: loading.textMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(child: _StageMark()),
              SizedBox(height: tokens.spacing.s20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: tokens.text.titleSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (detail case final detail?) ...[
                SizedBox(height: tokens.spacing.s4),
                // Tabular figures (every token style has them): a count
                // that grows doesn't shake.
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: tokens.text.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              if (bar || value != null) ...[
                SizedBox(height: tokens.spacing.s16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: loading.barWidth),
                  child: SizedBox(
                    width: double.infinity,
                    child: _GlidingBar(value: value, label: title),
                  ),
                ),
              ],
              if (tips.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.s24),
                RotatingTip(tips: tips),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tips for a long wait, one at a time ("Tip · Press F on a channel…"),
/// the next every [AppLoadingTokens.tipInterval], crossfading. As tall as
/// its tallest tip at its width, so nothing round it moves when the tip
/// changes.
class RotatingTip extends StatefulWidget {
  const new({required this.tips, this.textAlign = TextAlign.center, super.key});

  final List<String> tips;

  /// Centred under a [LoadingStage]; at the start under a list.
  final TextAlign textAlign;

  @override
  State<RotatingTip> createState() => _RotatingTipState();
}

class _RotatingTipState extends State<RotatingTip> {
  Timer? _timer;
  Duration? _every;
  var _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(RotatingTip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.tips.length) _index = 0;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// One timer while there is more than one tip, at the tokens' pace.
  void _schedule() {
    final every = widget.tips.length > 1
        ? context.tokens.loading.tipInterval
        : null;
    if (every == _every) return;
    _every = every;
    _timer?.cancel();
    _timer = every == null
        ? null
        : Timer.periodic(every, (_) {
            if (!mounted || widget.tips.isEmpty) return;
            setState(() => _index = (_index + 1) % widget.tips.length);
          });
  }

  @override
  Widget build(BuildContext context) {
    final tips = widget.tips;
    if (tips.isEmpty) return const SizedBox.shrink();
    final tokens = context.tokens;
    final colors = tokens.colors;
    final style = DefaultTextStyle.of(context).style
        .merge(tokens.text.caption.copyWith(color: colors.textTertiary));
    final lead = style.withWeight(700).copyWith(color: colors.textSecondary);
    TextSpan line(String tip) => TextSpan(
      style: style,
      children: [
        TextSpan(text: 'Tip · ', style: lead),
        TextSpan(text: tip),
      ],
    );
    final centred = widget.textAlign == TextAlign.center;
    final motion = tokens.motion;

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.hasBoundedWidth ? double.infinity : null,
        height: _tallest(context, [
          for (final tip in tips) line(tip),
        ], constraints.maxWidth),
        child: AnimatedSwitcher(
          duration: motion.reduceMotion
              ? Duration.zero
              : tokens.loading.tipFade,
          switchInCurve: motion.slowCurve,
          switchOutCurve: motion.slowCurve,
          layoutBuilder: (current, previous) => Stack(
            alignment: centred
                ? Alignment.topCenter
                : AlignmentDirectional.topStart,
            children: [...previous, ?current],
          ),
          child: Text.rich(
            line(tips[_index]),
            key: ValueKey(_index),
            textAlign: widget.textAlign,
          ),
        ),
      ),
    );
  }

  /// The height of the tallest of [lines] at [width], laid out as the
  /// [Text] that shows it lays it out.
  double _tallest(BuildContext context, List<InlineSpan> lines, double width) {
    final defaults = DefaultTextStyle.of(context);
    var tallest = 0.0;
    for (final line in lines) {
      final painter = TextPainter(
        text: line,
        textAlign: widget.textAlign,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        textHeightBehavior:
            defaults.textHeightBehavior ??
            DefaultTextHeightBehavior.maybeOf(context),
        textWidthBasis: defaults.textWidthBasis,
      )..layout(maxWidth: width);
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return tallest;
  }
}

/// The bar under the words: a fill that glides to each new value rather
/// than jumping, or the sweep while there is none.
class _GlidingBar extends StatelessWidget {
  const new({required this.value, required this.label});

  final double? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null) return ProgressBar(semanticLabel: label);
    final tokens = context.tokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1).toDouble()),
      duration: tokens.motion.reduceMotion
          ? Duration.zero
          : tokens.loading.barGlide,
      curve: tokens.motion.baseCurve,
      builder: (context, fill, _) =>
          ProgressBar(value: fill, semanticLabel: label),
    );
  }
}

/// The jewel on its accent tile, in a ring: the tile's glow breathes and
/// an arc goes round the ring; both are still with reduce motion on.
class _StageMark extends StatefulWidget {
  const new();

  @override
  State<_StageMark> createState() => _StageMarkState();
}

class _StageMarkState extends State<_StageMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final loading = tokens.loading;
    final moving = !tokens.motion.reduceMotion;

    _clock.duration = loading.cycle;
    if (moving && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!moving && _clock.isAnimating) {
      _clock.stop();
    }

    final side = loading.markSize;
    // Its own layer: the frames of the glow and the arc repaint the mark
    // alone, not the screen round it.
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: loading.orbitSize,
        child: CustomPaint(
          painter: _StagePainter(
            clock: _clock,
            moving: moving,
            loading: loading,
            radius: tokens.radii.lg,
            accent: colors.accentBase,
            track: colors.borderSubtle,
          ),
          child: Center(
            child: Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                borderRadius: tokens.radii.lgAll,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accentBase, colors.accentDeep],
                ),
              ),
              child: CustomPaint(
                painter: JewelPainter(
                  jewel: colors.onAccent,
                  deep: colors.accentDeep,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Under the tile: its glow and the ring, and the arc going round it, a
/// tail fading in behind its head.
class _StagePainter extends CustomPainter {
  new({
    required this.clock,
    required this.moving,
    required this.loading,
    required this.radius,
    required this.accent,
    required this.track,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final bool moving;
  final AppLoadingTokens loading;

  /// The tile's corners.
  final double radius;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final t = moving ? clock.value : 0.0;

    // In and out once a cycle, easing at both ends.
    final breath = moving
        ? 0.5 - 0.5 * math.cos(2 * math.pi * t)
        : loading.glowStill;
    final blur = lerpDouble(loading.glowBlurLow, loading.glowBlurHigh, breath)!;
    final opacity = lerpDouble(
      loading.glowOpacityLow,
      loading.glowOpacityHigh,
      breath,
    )!;
    final tile = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: loading.markSize,
        height: loading.markSize,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..color = accent.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          Shadow.convertRadiusToSigma(blur),
        ),
    );

    final stroke = loading.orbitStroke;
    final ring = (size.shortestSide - stroke) / 2;
    canvas.drawCircle(
      center,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (!moving) return;

    final sweep = loading.orbitSweep * 2 * math.pi;
    final start = 2 * math.pi * t * loading.orbitTurns - math.pi / 2;
    final bounds = Rect.fromCircle(center: center, radius: ring);
    canvas.drawArc(
      bounds,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          endAngle: sweep,
          colors: [accent.withValues(alpha: 0), accent],
          transform: GradientRotation(start),
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.moving != moving ||
      old.loading != loading ||
      old.radius != radius ||
      old.accent != accent ||
      old.track != track;
}
