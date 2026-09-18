import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/tokens.dart';

/// The app's mark from the canvas: an accent tile with a play glyph,
/// optionally followed by the app's name.
class AppMark extends StatelessWidget {
  /// The nav rail's 40 px tile.
  const new({this.showName = false, super.key}) : _small = false;

  /// The onboarding header's 36 px tile, always named.
  const new small({super.key}) : showName = true, _small = true;

  final bool showName;
  final bool _small;

  static const appName = 'IPTV Player';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final size = _small ? 36.0 : 40.0;

    final mark = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: _small ? tokens.radii.controlAll : tokens.radii.mdAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accentBase, colors.accentDeep],
        ),
      ),
      child: AppIcon(
        AppIcons.play,
        size: _small ? 16 : 18,
        color: colors.onAccent,
      ),
    );
    if (!showName) return mark;

    final name = Text(
      appName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (_small ? tokens.text.titleSmall : tokens.text.bodyStrong)
          .copyWith(color: colors.textPrimary),
    );
    return Row(
      mainAxisSize: _small ? MainAxisSize.min : MainAxisSize.max,
      children: [
        mark,
        SizedBox(width: tokens.spacing.s12),
        if (_small) name else Expanded(child: name),
      ],
    );
  }
}
