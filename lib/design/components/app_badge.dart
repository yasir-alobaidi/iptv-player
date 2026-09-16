import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// Badge emphasis. [live] is the red LIVE pill, [outline] is the quality
/// badge on artwork, [neutral] is everything else (docs/05).
enum AppBadgeTone { neutral, outline, accent, live, success, warning }

/// A small status label: LIVE, 4K, Original, NEW, Downloaded (docs/05:
/// 11 px, uppercase, +0.4 tracking).
class AppBadge extends StatelessWidget {
  const new(
    this.label, {
    this.tone = AppBadgeTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    final (background, foreground, border) = switch (tone) {
      AppBadgeTone.neutral => (colors.surface3, colors.textSecondary, null),
      AppBadgeTone.outline => (null, colors.textEmphasis, colors.borderStrong),
      AppBadgeTone.accent => (colors.accentBase, colors.onAccent, null),
      AppBadgeTone.live => (colors.live, colors.onAccent, null),
      AppBadgeTone.success => (
        colors.success.withValues(alpha: 0.14),
        colors.success,
        null,
      ),
      AppBadgeTone.warning => (
        colors.warning.withValues(alpha: 0.14),
        colors.warning,
        null,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: tokens.radii.xsAll,
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: foreground),
            SizedBox(width: tokens.spacing.s4 + 1),
          ],
          Text(
            label.toUpperCase(),
            style: tokens.text.micro.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
