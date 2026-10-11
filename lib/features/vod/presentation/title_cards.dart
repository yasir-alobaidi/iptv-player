import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/downloads/presentation/download_actions.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// A movie's poster as the grid and Home show it (canvas `Movies`):
/// NEW for a week, the Downloaded mark of one on this computer, a
/// favorite's star, the progress of one in progress, and the runtime on
/// the focused card's line once it is known.
class MovieCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = movie.watch;
    final year = movie.year;
    final runtime = movie.runtime;
    final downloaded = isDownloaded(
      ref,
      VodType.movie,
      movie.sourceId,
      movie.remoteKey,
    );
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
      cornerBadge: PosterMarks(
        favorite: movie.isFavorite,
        downloaded: downloaded,
      ),
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

/// What a poster's top right says of its title: the Downloaded mark in
/// the corner, where the canvas pins it, and a favorite's star beside
/// it.
class PosterMarks extends StatelessWidget {
  const new({required this.favorite, required this.downloaded, super.key});

  final bool favorite;
  final bool downloaded;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (favorite) const FavoriteMark(),
      if (favorite && downloaded) SizedBox(width: context.tokens.spacing.s4),
      if (downloaded) const DownloadedMark(),
    ],
  );
}

/// The favorite's star, beside where the canvas pins the Downloaded
/// mark.
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
