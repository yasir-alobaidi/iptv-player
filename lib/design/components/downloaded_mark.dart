import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/tokens.dart';

/// That a title is on this computer, on its poster (canvas `Movies`,
/// `Home`): a dark circle with the green download arrow, pinned to the
/// poster's top right.
class DownloadedMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final library = tokens.library;
    return Semantics(
      label: 'Downloaded',
      child: Container(
        width: library.markSize,
        height: library.markSize,
        decoration: BoxDecoration(
          color: colors.bg.withValues(alpha: library.markScrimOpacity),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AppIcon(
          AppIcons.download,
          size: library.markIconSize,
          color: colors.success,
        ),
      ),
    );
  }
}

/// The same with the word, where there is room for it: over a landscape
/// card's artwork (canvas `Home`'s Continue watching), or, with
/// [onArtwork] false, on a row's own surface (canvas `Search`).
class DownloadedPill extends StatelessWidget {
  const new({this.onArtwork = true, super.key});

  final bool onArtwork;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final library = tokens.library;
    return Container(
      height: onArtwork ? library.pillHeight : null,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s8,
        vertical: onArtwork ? 0 : tokens.spacing.s4 - 1,
      ),
      decoration: BoxDecoration(
        color: onArtwork
            ? colors.bg.withValues(alpha: library.markScrimOpacity)
            : colors.success.withValues(alpha: 0.14),
        borderRadius: tokens.radii.xsAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            AppIcons.download,
            size: library.pillIconSize,
            color: colors.success,
          ),
          SizedBox(width: library.pillIconGap),
          Text(
            'DOWNLOADED',
            style: tokens.text.micro
                .withWeight(800)
                .copyWith(color: colors.success, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
