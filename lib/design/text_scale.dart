import 'package:flutter/widgets.dart';
import 'package:iptv_player/design/appearance.dart';

/// The text-scale rule (Phase 9 decision 3): a height that holds text
/// grows with the text; pictures, icons and widths don't. Every row,
/// button, chip and bar asks here, so no screen does its own sum.
extension AppTextScaleX on BuildContext {
  /// The app's text scale: 1.0 at the canvas's sizes, up to 1.3.
  double get textScale => MediaQuery.textScalerOf(this).scale(1);

  /// [height] as tall as it must be for the text inside it: itself at
  /// 100 %, 1.3 times that at 130 %. For a height that holds text only.
  double scaled(double height) {
    final scale = textScale;
    // Itself, to the bit: at 100 % nothing may move.
    return scale == 1 ? height : height * scale;
  }

  /// A [box] whose text sits beside or under a picture of [fixed] px
  /// that keeps its size: only the rest of it grows.
  double scaledAround(double box, {required double fixed}) {
    final scale = textScale;
    return scale == 1 ? box : fixed + (box - fixed) * scale;
  }
}

/// Sets the text scale for everything under it: the system's or the one
/// chosen in Settings → Appearance, already capped by
/// [AppearanceSettings.resolve].
class AppTextScale extends StatelessWidget {
  const new({required this.scale, required this.child, super.key});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: scale == 1 ? TextScaler.noScaling : TextScaler.linear(scale),
    ),
    child: child,
  );
}
