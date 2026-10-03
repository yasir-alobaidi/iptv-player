import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/tokens.dart';

/// Something is under way ("Looking for devices…", "Connecting…"): a ring
/// that turns, or a still loading icon with reduce motion on.
class AppSpinner extends StatelessWidget {
  const new({this.size = 16, this.color, super.key});

  final double size;

  /// The accent when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tone = color ?? tokens.colors.accentBase;
    return SizedBox(
      width: size,
      height: size,
      child: tokens.motion.reduceMotion
          ? AppIcon(AppIcons.loading, size: size, color: tone)
          : CircularProgressIndicator(strokeWidth: 2, color: tone),
    );
  }
}
