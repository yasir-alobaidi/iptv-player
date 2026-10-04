import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/artwork_image.dart';
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
    this.focusedMeta,
    this.rating,
    this.progress,
    this.badge,
    this.cornerBadge,
    this.onPressed,
    this.onMenu,
    this.width = 160,
    this.autofocus = false,
    this.focusNode,
    this.metaIcon,
    this.metaTone = CardMetaTone.plain,
    this.dimmed = false,
    this.frame,
    super.key,
  });

  final String title;
  final ImageProvider? image;

  /// Year, runtime — whatever belongs under the title.
  final String? meta;

  /// An icon before [meta] (canvas `Library`: Downloaded, a folder, a
  /// drive not connected), drawn in [metaTone].
  final AppIcons? metaIcon;
  final CardMetaTone metaTone;

  /// Faded: an item on a drive that isn't connected.
  final bool dimmed;

  /// A 16:9 frame from the video, drawn across the poster's middle when
  /// there is no poster (a file of the user's own).
  final ImageProvider? frame;

  /// What the line says while the card has the focus: the canvas adds the
  /// runtime there ("2024 · 1 h 46 min").
  final String? focusedMeta;

  /// Shown next to a star, e.g. 7.1.
  final double? rating;

  /// Watch progress, 0..1; null hides the bar.
  final double? progress;

  /// NEW, and so on, pinned to the top-left.
  final Widget? badge;

  /// Downloaded, a favorite's star, pinned to the top-right.
  final Widget? cornerBadge;
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
      builder: (context, states) => _Dimmed(
        dimmed: dimmed,
        child: SizedBox(
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
                      ArtworkImage(
                        image: image,
                        fallback: frame == null
                            ? _ArtworkFallback(title: title)
                            : _FrameInPoster(frame: frame!, title: title),
                      ),
                      if (badge != null)
                        Positioned(
                          top: tokens.spacing.s8,
                          left: tokens.spacing.s8,
                          child: badge!,
                        ),
                      if (cornerBadge != null)
                        Positioned(
                          top: tokens.spacing.s8,
                          right: tokens.spacing.s8,
                          child: cornerBadge!,
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
                    if (metaIcon case final icon?) ...[
                      AppIcon(icon, size: 12, color: _metaIconColor(colors)),
                      SizedBox(width: tokens.spacing.s4 + 1),
                    ],
                    if (_metaFor(states) case final line?)
                      Flexible(
                        child: Text(
                          rating == null ? line : '$line ·',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _metaStyle(tokens),
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
      ),
    );
  }

  String? _metaFor(SurfaceStates states) =>
      states.focused ? focusedMeta ?? meta : meta;

  Color _metaIconColor(AppColors colors) => switch (metaTone) {
    CardMetaTone.plain => colors.textTertiary,
    CardMetaTone.success => colors.success,
    CardMetaTone.warning => colors.warning,
  };

  TextStyle _metaStyle(AppTokens tokens) => metaTone == CardMetaTone.warning
      ? tokens.text.labelSmall
            .withWeight(700)
            .copyWith(color: tokens.colors.warning)
      : tokens.text.labelSmall
            .withWeight(500)
            .copyWith(color: tokens.colors.textTertiary);
}

/// How a card's line under its title reads (canvas `Library`): plainly;
/// with a green icon (Downloaded); amber and bold (Drive not connected).
enum CardMetaTone { plain, success, warning }

/// A card faded as the canvas fades an item on a drive that isn't
/// connected.
class _Dimmed extends StatelessWidget {
  const new({required this.dimmed, required this.child});

  final bool dimmed;
  final Widget child;

  @override
  Widget build(BuildContext context) => dimmed
      ? Opacity(
          opacity: context.tokens.library.unavailableOpacity,
          child: child,
        )
      : child;
}

/// A poster's place with no poster: the video's own frame across its
/// middle, on the card's surface (canvas `Library`, "Harbor Walk").
class _FrameInPoster extends StatelessWidget {
  const new({required this.frame, required this.title});

  final ImageProvider frame;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface1),
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ArtworkImage(
            image: frame,
            fallback: _ArtworkFallback(title: title, landscape: true),
          ),
        ),
      ),
    );
  }
}

/// A poster's picture over its stand-in, for places that draw a poster
/// without a card around it (a details page).
class PosterArtwork extends StatelessWidget {
  const new({
    required this.title,
    this.image,
    this.showTitle = true,
    super.key,
  });

  final String title;
  final ImageProvider? image;

  /// False for a thumbnail too small to set the title in (search's
  /// 30 × 44): the stand-in is its gradient alone.
  final bool showTitle;

  @override
  Widget build(BuildContext context) => ArtworkImage(
    image: image,
    fallback: _ArtworkFallback(title: title, showTitle: showTitle),
  );
}

/// Artwork stand-in: a gradient derived from the title, with the title
/// set across it, so a grid without images still reads as a grid.
class _ArtworkFallback extends StatelessWidget {
  const new({
    required this.title,
    this.landscape = false,
    this.showTitle = true,
  });

  final String title;
  final bool landscape;
  final bool showTitle;

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
      child: !showTitle
          ? null
          : Padding(
              padding: EdgeInsets.all(tokens.spacing.s12 + 2),
              child: Align(
                alignment: landscape
                    ? Alignment.bottomLeft
                    : Alignment.bottomCenter,
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
    this.subtitleTone = CardMetaTone.plain,
    this.dimmed = false,
    super.key,
  });

  final String title;
  final ImageProvider? image;

  /// "S1 · E3", a channel name, whatever identifies the item.
  final String? subtitle;

  /// Amber and bold for a drive not connected (canvas `Library`).
  final CardMetaTone subtitleTone;

  /// Faded: an item on a drive that isn't connected.
  final bool dimmed;
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
      builder: (context, states) => _Dimmed(
        dimmed: dimmed,
        child: SizedBox(
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
                      ArtworkImage(
                        image: image,
                        fallback: _ArtworkFallback(
                          title: title,
                          landscape: true,
                        ),
                      ),
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
                  style: subtitleTone == CardMetaTone.warning
                      ? tokens.text.labelSmall
                            .withWeight(700)
                            .copyWith(color: colors.warning)
                      : tokens.text.labelSmall
                            .withWeight(500)
                            .copyWith(color: colors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
