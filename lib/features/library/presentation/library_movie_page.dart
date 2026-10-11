import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/presentation/title_details_screen.dart';

/// A movie of the library (sketch A; the Movie details layout): a file of
/// the user's own, or a download its provider no longer lists, which keeps
/// the poster and the plot it was downloaded with.
class LibraryMovieScreen extends ConsumerWidget {
  const new({required this.itemId, super.key});

  /// Null when the address named no item.
  final int? itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = itemId;
    final found = id == null
        ? const AsyncData<LibraryItem?>(null)
        : ref.watch(libraryItemProvider(id));
    return DetailsFrame(
      back: 'Library',
      loading: found is! AsyncData && found is! AsyncError,
      child: switch (found) {
        AsyncData(value: final item?) => _MoviePage(item: item),
        AsyncData() => const DetailsGone(
          message: 'This video is no longer in your library.',
        ),
        AsyncError(:final error) => ErrorState(
          title: "Couldn't open this video",
          details: '$error',
          onRetry: id == null
              ? null
              : () => ref.invalidate(libraryItemProvider(id)),
        ),
        _ => const DetailsPageLoading(),
      },
    );
  }
}

class _MoviePage extends ConsumerWidget {
  const new({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.details;
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final folder = folders.where((f) => f.id == item.folderId).firstOrNull;
    final mark = ref.watch(libraryMarkProvider(item)).value;
    final favorite = ref.watch(libraryFavoriteProvider(item)).value ?? false;
    final stored = item.details ?? const <String, Object?>{};
    String? text(String key) => switch (stored[key]) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => null,
    };

    // The poster beside the file, else the one it was downloaded with;
    // with neither, the video's own frame.
    final posterUrl = switch (item.artworkPath) {
      final path? => localArtworkUrl(path),
      null => text('poster_url'),
    };
    final framePath = posterUrl == null && item.available
        ? ref.watch(libraryThumbnailProvider(item.id)).value
        : null;
    final frameUrl = framePath == null ? null : localArtworkUrl(framePath);

    final resumable = mark != null && mark.resumable;
    final length =
        item.duration ??
        item.media?.duration ??
        switch (stored['runtime_minutes']) {
          final int minutes when minutes > 0 => Duration(minutes: minutes),
          _ => null,
        };
    final genre = text('genre');
    final plot = text('plot');
    final subtitles = librarySubtitleNames(item);

    void play({Duration? from}) => unawaited(
      ref.read(vodLauncherProvider).playLibraryItem(item, from: from),
    );
    void toggleFavorite() =>
        unawaited(ref.read(libraryFavoritesProvider).toggle(item));
    void away() => ref
        .read(appNoticesProvider)
        .show(AppNotice(driveAwayNotice(folder?.label)));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): toggleFavorite,
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          DetailsBackdrop(
            backdropUrl: text('backdrop_url'),
            posterUrl: posterUrl ?? frameUrl,
          ),
          Positioned(
            left: layout.moviePadding,
            right: layout.moviePadding,
            bottom: layout.moviePadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (posterUrl != null || frameUrl == null)
                  DetailsPoster(
                    title: item.title,
                    url: posterUrl,
                    size: layout.moviePoster,
                  )
                else
                  _Frame(url: frameUrl, width: layout.moviePoster.width * 1.5),
                SizedBox(width: layout.posterGap),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: layout.textMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            libraryKindWord(item.kind),
                            if (genre != null) genre.split(',').first.trim(),
                          ].join('  /  ').toUpperCase(),
                          style: tokens.text.overline.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: tokens.spacing.s16),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.text.movieTitle.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: tokens.spacing.s16),
                        DetailsMetaLine(
                          year: item.year,
                          runtime: length == null
                              ? null
                              : formatRuntime(length),
                          rating: switch (stored['rating']) {
                            final num rating when rating > 0 =>
                              rating.toDouble(),
                            _ => null,
                          },
                          more: item.media?.qualityParts ?? const [],
                          watched: mark?.completed ?? false,
                        ),
                        SizedBox(height: tokens.spacing.s12),
                        _Place(
                          item: item,
                          line: libraryFileLine(item, folder?.label),
                        ),
                        if (subtitles.isNotEmpty) ...[
                          SizedBox(height: tokens.spacing.s8),
                          Text(
                            'Subtitles: ${subtitles.join(' · ')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.text.label
                                .withWeight(400)
                                .copyWith(color: colors.textSecondary),
                          ),
                        ],
                        if (plot != null) ...[
                          SizedBox(height: tokens.spacing.s16),
                          Text(
                            plot,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.text.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        if (resumable) ...[
                          SizedBox(height: tokens.spacing.s24),
                          DetailsTimeLeft(mark: mark),
                        ],
                        SizedBox(
                          height: resumable
                              ? tokens.spacing.s16
                              : tokens.spacing.s24,
                        ),
                        Wrap(
                          spacing: tokens.spacing.s12,
                          runSpacing: tokens.spacing.s12,
                          children: [
                            AppButton(
                              label: resumable
                                  ? 'Resume from '
                                        '${formatPosition(mark.position)}'
                                  : 'Play',
                              icon: AppIcons.play,
                              size: AppButtonSize.xl,
                              autofocus: true,
                              // A drive that is away says so; Play stays
                              // where the keyboard expects it.
                              onPressed: !item.available
                                  ? away
                                  : () => play(
                                      from: resumable ? mark.position : null,
                                    ),
                            ),
                            if (resumable)
                              AppButton(
                                label: 'Start over',
                                icon: AppIcons.retry,
                                variant: AppButtonVariant.secondary,
                                size: AppButtonSize.xl,
                                onPressed: item.available ? play : away,
                              ),
                            AppIconButton(
                              icon: favorite
                                  ? AppIcons.starFilled
                                  : AppIcons.star,
                              tooltip: favorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              shortcut: 'F',
                              selected: favorite,
                              bordered: true,
                              size: layout.movieActionHeight,
                              onPressed: toggleFavorite,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A video with no poster: its own frame, where the poster would be.
class _Frame extends StatelessWidget {
  const new({required this.url, required this.width});

  final String url;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: width,
      height: width * 9 / 16,
      decoration: BoxDecoration(
        borderRadius: tokens.radii.mdAll,
        boxShadow: tokens.elevation.overlay,
      ),
      child: ClipRRect(
        borderRadius: tokens.radii.mdAll,
        child: ArtworkImage(
          image: artworkFor(context, url, width: width),
          fallback: ColoredBox(color: tokens.colors.surface1),
        ),
      ),
    );
  }
}

/// "Movies HDD · Paper Kites (2019)/Paper Kites (2019).mkv · 2.1 GB",
/// with the folder's mark, the green one of a download, or the amber
/// "Drive not connected".
class _Place extends StatelessWidget {
  const new({required this.item, required this.line});

  final LibraryItem item;
  final String line;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final away = !item.available;
    final color = away ? colors.warning : colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(
          away
              ? AppIcons.alertTriangle
              : item.isDownload
              ? AppIcons.download
              : AppIcons.folder,
          size: 14,
          color: away
              ? colors.warning
              : item.isDownload
              ? colors.success
              : colors.textTertiary,
        ),
        SizedBox(width: tokens.spacing.s8),
        Flexible(
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.label
                .withWeight(away ? 700 : 400)
                .copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
