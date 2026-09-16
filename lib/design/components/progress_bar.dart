import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// A thin progress bar (docs/05: 3 px, rounded). [value] null makes it
/// indeterminate; with reduce motion on, an indeterminate bar sits still
/// at a low fill rather than animating.
class ProgressBar extends StatelessWidget {
  const new({
    this.value,
    this.height = 3,
    this.color,
    this.trackColor,
    this.semanticLabel,
    super.key,
  });

  /// 0..1, or null for indeterminate.
  final double? value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final fill = color ?? colors.accentBase;
    final track = trackColor ?? colors.border;
    final radius = BorderRadius.circular(height);

    if (value == null && tokens.motion.reduceMotion) {
      return _Track(
        height: height,
        radius: radius,
        track: track,
        child: FractionallySizedBox(
          widthFactor: 0.3,
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, borderRadius: radius),
          ),
        ),
      );
    }

    return Semantics(
      label: semanticLabel,
      value: value == null ? null : '${(value! * 100).round()}%',
      child: ClipRRect(
        borderRadius: radius,
        child: LinearProgressIndicator(
          value: value,
          minHeight: height,
          backgroundColor: track,
          valueColor: AlwaysStoppedAnimation(fill),
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const new({
    required this.height,
    required this.radius,
    required this.track,
    required this.child,
  });

  final double height;
  final BorderRadius radius;
  final Color track;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(color: track, borderRadius: radius),
      child: child,
    ),
  );
}
