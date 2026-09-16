import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// A loading placeholder. Skeletons match the shape of the content that
/// replaces them (docs/05) and stop shimmering when the user asked for
/// reduced motion.
class Skeleton extends StatefulWidget {
  const new({this.width, this.height = 16, this.borderRadius, super.key});

  /// A line of text; [width] is usually a fraction of the row.
  const factory text({double? width, double height, Key? key}) = Skeleton;

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final radius = widget.borderRadius ?? tokens.radii.smAll;
    final shimmer = tokens.motion.allowShimmer;

    if (shimmer && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shimmer && _controller.isAnimating) {
      _controller.stop();
    }

    final box = SizedBox(width: widget.width, height: widget.height);

    if (!shimmer) {
      return DecoratedBox(
        decoration: BoxDecoration(color: colors.surface3, borderRadius: radius),
        child: box,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t), 0),
              colors: [colors.surface2, colors.surface3, colors.surface2],
            ),
          ),
          child: child,
        );
      },
      child: box,
    );
  }
}

/// Skeleton for a channel or download row: square artwork plus two lines.
class SkeletonRow extends StatelessWidget {
  const new({this.height, super.key});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      height: height ?? tokens.density.rowHeight,
      child: Row(
        children: [
          Skeleton(
            width: 40,
            height: 40,
            borderRadius: tokens.radii.controlAll,
          ),
          SizedBox(width: tokens.spacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Skeleton(width: 180, height: 12),
                SizedBox(height: tokens.spacing.s8),
                const Skeleton(width: 96, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a 2:3 poster card.
class SkeletonPoster extends StatelessWidget {
  const new({this.width = 160, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(
          width: width,
          height: width * 3 / 2,
          borderRadius: tokens.radii.mdAll,
        ),
        SizedBox(height: tokens.spacing.s8),
        Skeleton(width: width * 0.8, height: 12),
      ],
    );
  }
}
