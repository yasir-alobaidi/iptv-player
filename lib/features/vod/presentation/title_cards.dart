import 'package:flutter/material.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// A movie's poster as the grid and Home show it (canvas `Movies`):
/// NEW for a week, a favorite's star, the progress of one in progress,
/// and the runtime on the focused card's line once it is known.
class MovieCard extends StatelessWidget {
  const new({
    required this.movie,
    required this.focus,
    required this.width,
    required this.now,
    required this.onOpen,
    required this.onMenu,
    super.key,
  });

  final MovieItem movie;
  final FocusNode focus;
  final double width;
  final DateTime now;
  final VoidCallback onOpen;
  final void Function(BuildContext anchor) onMenu;

  @override
  Widget build(BuildContext context) {
    final watch = movie.watch;
    final year = movie.year;
    final runtime = movie.runtime;
    return PosterCard(
      title: movie.name,
      image: artworkFor(context, movie.posterUrl, width: width),
      meta: year == null ? null : '$year',
      focusedMeta: [
        if (year != null) '$year',
        if (runtime != null) formatRuntime(runtime),
      ].join(' · ').emptyAsNull,
      rating: movie.rating,
      progress:
          watch != null && !watch.completed && watch.position > Duration.zero
          ? watch.fraction
          : null,
      badge: movie.isNewAt(now)
          ? const AppBadge('NEW', tone: AppBadgeTone.accent)
          : null,
      cornerBadge: movie.isFavorite ? const FavoriteMark() : null,
      width: width,
      focusNode: focus,
      onPressed: onOpen,
      onMenu: () => onMenu(context),
    );
  }
}

/// A series' poster as the grid and Home show it.
class SeriesCard extends StatelessWidget {
  const new({
    required this.series,
    required this.focus,
    required this.width,
    required this.now,
    required this.onOpen,
    required this.onMenu,
    super.key,
  });

  final SeriesItem series;
  final FocusNode focus;
  final double width;
  final DateTime now;
  final VoidCallback onOpen;
  final void Function(BuildContext anchor) onMenu;

  @override
  Widget build(BuildContext context) {
    final year = series.year;
    final genre = series.genre?.split(',').first.trim();
    return PosterCard(
      title: series.name,
      image: artworkFor(context, series.posterUrl, width: width),
      meta: year == null ? null : '$year',
      focusedMeta: [
        if (year != null) '$year',
        if (genre != null && genre.isNotEmpty) genre,
      ].join(' · ').emptyAsNull,
      rating: series.rating,
      badge: series.isNewAt(now)
          ? const AppBadge('NEW', tone: AppBadgeTone.accent)
          : null,
      cornerBadge: series.isFavorite ? const FavoriteMark() : null,
      width: width,
      focusNode: focus,
      onPressed: onOpen,
      onMenu: () => onMenu(context),
    );
  }
}

/// The favorite's star, where the canvas pins the Downloaded mark.
class FavoriteMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.75),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppIcon(AppIcons.starFilled, size: 14, color: colors.warning),
    );
  }
}

extension on String {
  String? get emptyAsNull => isEmpty ? null : this;
}
