import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// A channel's picture quality after its name — SD, HD, FHD or 4K — as
/// the canvas draws it on Live TV's and Favorites' rows: a small grey tag,
/// quieter than `AppBadge`'s.
class ChannelBadge extends StatelessWidget {
  const new(this.label, {this.raised = false, super.key});

  final String label;

  /// On a row drawn raised (hovered, focused or selected, in `surface3`)
  /// the tag steps up to the border colour, so it still shows.
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s4 + 1,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: raised ? colors.border : colors.surface3,
        borderRadius: tokens.radii.xsAll,
      ),
      child: Text(
        label,
        style: tokens.text.micro
            .withWeight(700)
            .copyWith(color: colors.textSecondary),
      ),
    );
  }
}
