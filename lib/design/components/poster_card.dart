import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/progress_bar.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// A 2:3 poster for a movie or a series (canvas: radius 12, title 14/700,
/// year and rating below). Focus grows it to 1.03.
class PosterCard extends StatelessWidget {
  const new({
    required this.title,
    this.image,
    this.meta,
    this.rating,
    this.progress,
    this.badge,
    this.onPressed,
    this.onMenu,
    this.width = 160,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final String title;
  final ImageProvider? image;

  /// Year, runtime — whatever belongs under the title.
  final String? meta;

  /// Shown next to a star, e.g. 7.1.
  final double? rating;

  /// Watch progress, 0..1; null hides the bar.
  final double? progress;

  /// NEW, Downloaded, and so on, pinned to the top-left.
  final Widget? badge;
  final VoidCallback? onPressed;
  final VoidCallback? onMenu;
  final double width;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return FocusableSurface(
      onPressed: onPressed,
      onMenu: onMenu,
      autofocus: autofocus,
      focusNode: focusNode,
      growth: FocusGrowth.tile,
      borderRadius: tokens.radii.mdAll,
      semanticLabel: title,
      builder: (context, states) => SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: tokens.radii.mdAll,
              child: SizedBox(
                width: width,
                height: width * 3 / 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      Image(image: image!, fit: BoxFit.cover)
                    else
                      _ArtworkFallback(title: title),
                    if (badge != null)
                      Positioned(
                        top: tokens.spacing.s8,
                        left: tokens.spacing.s8,
                        child: badge!,
                      ),
                    if (progress != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ProgressBar(value: progress),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.s8 + 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.text.label
                  .withWeight(700)
                  .copyWith(color: colors.textPrimary),
            ),
            if (meta != null || rating != null) ...[
              SizedBox(height: tokens.spacing.s4 - 2),
              Row(
                children: [
                  if (meta != null)
                    Flexible(
                      child: Text(
                        rating == null ? meta! : '${meta!} ·',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.labelSmall
                            .withWeight(500)
                            .copyWith(color: colors.textTertiary),
                      ),
                    ),
                  if (rating != null) ...[
                    SizedBox(width: tokens.spacing.s4),
                    AppIcon(
                      AppIcons.starFilled,
                      size: 11,
                      color: colors.warning,
                    ),
                    SizedBox(width: tokens.spacing.s4 - 1),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: tokens.text.labelSmall
                          .withWeight(500)
                          .copyWith(color: colors.textTertiary),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Artwork stand-in: a gradient derived from the title, with the title
/// set across it, so a grid without images still reads as a grid.
class _ArtworkFallback extends StatelessWidget {
  const new({required this.title, this.landscape = false});

  final String title;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    var hash = 0;
    for (final unit in title.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final base = _palette[hash % _palette.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base, Color.lerp(base, tokens.colors.bg, 0.8)!],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s12 + 2),
        child: Align(
          alignment: landscape ? Alignment.bottomLeft : Alignment.bottomCenter,
          child: Text(
            title.toUpperCase(),
            maxLines: 2,
            textAlign: landscape ? TextAlign.left : TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.titleSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              letterSpacing: 1,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  static const _palette = <Color>[
    Color(0xFFC9A66B),
    Color(0xFF7A4E2D),
    Color(0xFF4E6B3A),
    Color(0xFF2D5E6B),
    Color(0xFF5A3346),
    Color(0xFF3D4E7A),
    Color(0xFF6B3F5A),
    Color(0xFF2F7A5A),
  ];
}

/// A 16:9 card for episodes and Continue Watching.
class LandscapeCard extends StatelessWidget {
  const new({
    required this.title,
    this.image,
    this.subtitle,
    this.progress,
    this.badge,
    this.onPressed,
    this.onMenu,
    this.width = 280,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final String title;
  final ImageProvider? image;

  /// "S1 · E3", a channel name, whatever identifies the item.
  final String? subtitle;
  final double? progress;
  final Widget? badge;
  final VoidCallback? onPressed;
  final VoidCallback? onMenu;
  final double width;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return FocusableSurface(
      onPressed: onPressed,
      onMenu: onMenu,
      autofocus: autofocus,
      focusNode: focusNode,
      growth: FocusGrowth.tile,
      borderRadius: tokens.radii.mdAll,
      semanticLabel: title,
      builder: (context, states) => SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: tokens.radii.mdAll,
              child: SizedBox(
                width: width,
                height: width * 9 / 16,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      Image(image: image!, fit: BoxFit.cover)
                    else
                      _ArtworkFallback(title: title, landscape: true),
                    if (badge != null)
                      Positioned(
                        top: tokens.spacing.s8,
                        left: tokens.spacing.s8,
                        child: badge!,
                      ),
                    if (progress != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ProgressBar(value: progress),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.s8 + 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.text.label
                  .withWeight(700)
                  .copyWith(color: colors.textPrimary),
            ),
            if (subtitle != null) ...[
              SizedBox(height: tokens.spacing.s4 - 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.labelSmall
                    .withWeight(500)
                    .copyWith(color: colors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
