import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/details_state.dart';

/// A movie's page (canvas `Movie details`), inside the Movies branch.
class MovieDetailsScreen extends ConsumerWidget {
  const new({required this.sourceId, required this.remoteKey, super.key});

  final String sourceId;
  final String remoteKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref.watch(movieItemProvider(sourceId, remoteKey));
    return _DetailsFrame(
      back: 'Movies',
      child: switch (found) {
        AsyncData(value: Ok(value: final movie?)) => _MovieHeader(movie: movie),
        AsyncData(value: Ok(value: null)) => const _Gone(
          message: 'This movie is no longer available from your provider.',
        ),
        AsyncData(value: Err(:final Object failure)) ||
        AsyncError(error: final Object failure) => ErrorState(
          title: "Couldn't open this movie",
          details: '$failure',
          onRetry: () => ref.invalidate(movieItemProvider(sourceId, remoteKey)),
        ),
        _ => const _Loading(),
      },
    );
  }
}

/// A series' page (canvas `Series details`), inside the Series branch.
class SeriesDetailsScreen extends ConsumerWidget {
  const new({required this.sourceId, required this.remoteKey, super.key});

  final String sourceId;
  final String remoteKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref.watch(seriesItemProvider(sourceId, remoteKey));
    return _DetailsFrame(
      back: 'Series',
      child: switch (found) {
        AsyncData(value: Ok(value: final series?)) => _SeriesHeader(
          series: series,
        ),
        AsyncData(value: Ok(value: null)) => const _Gone(
          message: 'This series is no longer available from your provider.',
        ),
        AsyncData(value: Err(:final Object failure)) ||
        AsyncError(error: final Object failure) => ErrorState(
          title: "Couldn't open this series",
          details: '$failure',
          onRetry: () =>
              ref.invalidate(seriesItemProvider(sourceId, remoteKey)),
        ),
        _ => const _Loading(),
      },
    );
  }
}

/// What every details page has: the page's own focus group, Esc back to
/// the grid, and the canvas's "‹ Movies" chip over the artwork.
class _DetailsFrame extends StatelessWidget {
  const new({required this.back, required this.child});

  final String back;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    void leave() {
      if (context.canPop()) context.pop();
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): leave},
      child: FocusPane(
        debugLabel: 'title details',
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: tokens.spacing.s24,
              left: tokens.spacing.s40,
              child: _BackChip(label: back, onPressed: leave),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackChip extends StatelessWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      onPressed: onPressed,
      borderRadius: tokens.radii.pillAll,
      semanticLabel: 'Back to $label',
      builder: (context, states) => Container(
        height: tokens.details.backChipHeight,
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.s8 + 2,
          0,
          tokens.spacing.s12 + 2,
          0,
        ),
        decoration: BoxDecoration(
          color: (states.highlighted ? colors.surface3 : colors.surface1)
              .withValues(alpha: 0.7),
          borderRadius: tokens.radii.pillAll,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.chevronLeft,
              size: 16,
              color: colors.textSecondary,
            ),
            SizedBox(width: tokens.spacing.s4 + 2),
            Text(
              label,
              style: tokens.text.labelSmall
                  .withWeight(700)
                  .copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The artwork behind a page: the backdrop, or the poster blurred when
/// there is none (docs/05), under the canvas's two gradients.
class DetailsBackdrop extends StatelessWidget {
  const new({required this.backdropUrl, required this.posterUrl, super.key});

  final String? backdropUrl;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final size = MediaQuery.sizeOf(context);
    final backdrop = artworkFor(context, backdropUrl, width: size.width);
    final poster = backdrop == null
        ? artworkFor(context, posterUrl, width: size.width / 4)
        : null;
    final picture = backdrop ?? poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.surface1),
        if (picture != null)
          ImageFiltered(
            enabled: backdrop == null,
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: ArtworkImage(
              image: picture,
              fallback: const SizedBox.shrink(),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.bg,
                colors.bg.withValues(alpha: 0.92),
                colors.bg.withValues(alpha: 0.2),
                colors.bg.withValues(alpha: 0.35),
              ],
              stops: const [0, 0.38, 0.75, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [colors.bg, colors.bg.withValues(alpha: 0)],
              stops: const [0, 0.45],
            ),
          ),
        ),
      ],
    );
  }
}

/// The movie as the grid row knows it; the fetched details join it in
/// step 5.
class _MovieHeader extends StatelessWidget {
  const new({required this.movie});

  final MovieItem movie;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final details = tokens.details;
    return Stack(
      fit: StackFit.expand,
      children: [
        DetailsBackdrop(backdropUrl: null, posterUrl: movie.posterUrl),
        Positioned(
          left: details.moviePadding,
          right: details.moviePadding,
          bottom: details.moviePadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DetailsPoster(
                title: movie.name,
                url: movie.posterUrl,
                size: details.moviePoster,
              ),
              SizedBox(width: details.posterGap),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: details.textMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOVIE',
                        style: tokens.text.overline.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.s16),
                      Text(
                        movie.name,
                        style: tokens.text.movieTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.s16),
                      DetailsMetaLine(year: movie.year, rating: movie.rating),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeriesHeader extends StatelessWidget {
  const new({required this.series});

  final SeriesItem series;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final details = tokens.details;
    return Stack(
      fit: StackFit.expand,
      children: [
        DetailsBackdrop(
          backdropUrl: series.backdropUrl,
          posterUrl: series.posterUrl,
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: details.seriesColumnWidth,
          child: Padding(
            padding: details.seriesPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                DetailsPoster(
                  title: series.name,
                  url: series.posterUrl,
                  size: details.seriesPoster,
                ),
                SizedBox(height: tokens.spacing.s16 + 2),
                Text(
                  series.name,
                  style: tokens.text.seriesTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: tokens.spacing.s16 + 2),
                DetailsMetaLine(
                  year: series.year,
                  rating: series.rating,
                  genre: series.genre,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The poster on a details page, with the canvas's drop shadow.
class DetailsPoster extends StatelessWidget {
  const new({
    required this.title,
    required this.url,
    required this.size,
    super.key,
  });

  final String title;
  final String? url;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: tokens.radii.mdAll,
        boxShadow: tokens.elevation.overlay,
      ),
      child: ClipRRect(
        borderRadius: tokens.radii.mdAll,
        child: PosterArtwork(
          title: title,
          image: artworkFor(context, url, width: size.width),
        ),
      ),
    );
  }
}

/// "2024 · ★ 7.8 · Drama" — what is known of it.
class DetailsMetaLine extends StatelessWidget {
  const new({this.year, this.rating, this.genre, this.runtime, super.key});

  final int? year;
  final double? rating;
  final String? genre;
  final String? runtime;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final style = tokens.text.body
        .withWeight(600)
        .copyWith(color: colors.textSecondary);
    final dot = Text('·', style: style.copyWith(color: colors.textDisabled));
    final parts = <Widget>[
      if (year != null) Text('$year', style: style),
      if (runtime != null) Text(runtime!, style: style),
      if (rating != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.starFilled, size: 15, color: colors.warning),
            SizedBox(width: tokens.spacing.s4 + 1),
            Text(rating!.toStringAsFixed(1), style: style),
          ],
        ),
      if (genre != null && genre!.trim().isNotEmpty)
        Text(genre!.trim(), style: style),
    ];
    return Wrap(
      spacing: tokens.spacing.s12 + 2,
      runSpacing: tokens.spacing.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, part) in parts.indexed) ...[if (i > 0) dot, part],
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.all(tokens.details.moviePadding),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Skeleton(
          width: tokens.details.moviePoster.width,
          height: tokens.details.moviePoster.height,
          borderRadius: tokens.radii.mdAll,
        ),
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: AppIcons.movies,
    title: 'Not available',
    message: message,
    actionLabel: 'Back',
    onAction: () {
      if (context.canPop()) context.pop();
    },
  );
}
