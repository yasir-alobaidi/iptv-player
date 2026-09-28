import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/next_up.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:iptv_player/features/vod/presentation/details_state.dart';
import 'package:iptv_player/features/vod/presentation/vod_text.dart';

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
        AsyncData(value: Ok(value: final movie?)) => _MoviePage(movie: movie),
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
        AsyncData(value: Ok(value: final series?)) => _SeriesPage(
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

/// A movie's page as the canvas draws it: the backdrop, the poster, and
/// beside it the kind and genre, the title, year · runtime · ★ · genres
/// with the picture's and the sound's badges, the plot, Director and Cast,
/// the actions and, while it is being watched, the time left. What the
/// grid row knew shows at once; the fetched details join it (decision 2).
class _MoviePage extends ConsumerWidget {
  const new({required this.movie});

  final MovieItem movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.details;
    final details = ref
        .watch(movieDetailsProvider(movie.sourceId, movie.remoteKey))
        .value;
    final mark = ref.watch(watchMarkProvider(movie.ref)).value ?? movie.watch;
    final ready = switch (details) {
      DetailsReady(:final value) => value,
      _ => null,
    };
    final genre = ready?.genre?.split(',').first.trim();
    final resumable = mark != null && mark.resumable;

    Future<void> toggleFavorite() async {
      await ref
          .read(movieRepositoryProvider)
          .setFavorite(movie, on: !movie.isFavorite);
      ref.invalidate(movieItemProvider(movie.sourceId, movie.remoteKey));
    }

    void play({Duration? from}) =>
        unawaited(ref.read(vodLauncherProvider).playMovie(movie, from: from));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            unawaited(toggleFavorite()),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          DetailsBackdrop(
            backdropUrl: ready?.backdropUrl,
            posterUrl: movie.posterUrl,
          ),
          Positioned(
            left: layout.moviePadding,
            right: layout.moviePadding,
            bottom: layout.moviePadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DetailsPoster(
                  title: movie.name,
                  url: movie.posterUrl,
                  size: layout.moviePoster,
                ),
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
                            'MOVIE',
                            if (genre != null && genre.isNotEmpty) genre,
                          ].join('  /  ').toUpperCase(),
                          style: tokens.text.overline.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: tokens.spacing.s16),
                        Text(
                          movie.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.text.movieTitle.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: tokens.spacing.s16),
                        DetailsMetaLine(
                          year: movie.year,
                          runtime: switch (ready?.runtime ?? movie.runtime) {
                            final runtime? => formatRuntime(runtime),
                            null => null,
                          },
                          rating: movie.rating,
                          genre: ready?.genre,
                          badges: [
                            ?pictureBadge(ready?.videoHeight),
                            ?soundBadge(ready?.audioChannels),
                          ],
                          watched: mark?.completed ?? false,
                        ),
                        SizedBox(height: tokens.spacing.s16),
                        _About(
                          details: details,
                          plot: ready?.plot,
                          credits: [
                            if (ready?.director case final director?)
                              ('Director', director),
                            if (ready?.cast case final cast?) ('Cast', cast),
                          ],
                          onRetry: () => ref.invalidate(
                            movieDetailsProvider(
                              movie.sourceId,
                              movie.remoteKey,
                            ),
                          ),
                        ),
                        SizedBox(height: tokens.spacing.s24),
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
                              onPressed: () =>
                                  play(from: resumable ? mark.position : null),
                            ),
                            if (resumable)
                              AppButton(
                                label: 'Start over',
                                icon: AppIcons.retry,
                                variant: AppButtonVariant.secondary,
                                size: AppButtonSize.xl,
                                onPressed: play,
                              ),
                            AppIconButton(
                              icon: movie.isFavorite
                                  ? AppIcons.starFilled
                                  : AppIcons.star,
                              tooltip: movie.isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              shortcut: 'F',
                              selected: movie.isFavorite,
                              bordered: true,
                              size: layout.movieActionHeight,
                              onPressed: () => unawaited(toggleFavorite()),
                            ),
                          ],
                        ),
                        if (resumable) ...[
                          SizedBox(height: tokens.spacing.s12),
                          _TimeLeft(mark: mark),
                        ],
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

/// The plot and the credits, or what stands in for them: skeleton lines
/// while a first fetch runs, the reason and Retry when it failed, "No
/// description" when the provider has none.
class _About extends StatelessWidget {
  const new({
    required this.details,
    required this.plot,
    required this.credits,
    required this.onRetry,
  });

  final Details<Object>? details;
  final String? plot;
  final List<(String, String)> credits;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final details = this.details;
    if (details == null || details is DetailsLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in const [0.95, 0.9, 0.6]) ...[
            FractionallySizedBox(
              widthFactor: width,
              child: const Skeleton(height: 14),
            ),
            SizedBox(height: tokens.spacing.s8 + 2),
          ],
        ],
      );
    }
    if (details case DetailsFailed(:final failure)) {
      return Row(
        children: [
          Flexible(
            child: Text(
              "Couldn't load the details. ${failureMessage(failure)}",
              style: tokens.text.body.copyWith(color: colors.textSecondary),
            ),
          ),
          SizedBox(width: tokens.spacing.s12),
          AppButton(
            label: 'Retry',
            icon: AppIcons.retry,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.s,
            onPressed: onRetry,
          ),
        ],
      );
    }
    final plot = this.plot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plot ?? 'No description from your provider.',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: tokens.text.body.copyWith(
            color: plot == null ? colors.textTertiary : colors.textSecondary,
          ),
        ),
        if (credits.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.s16),
          for (final (label, value) in credits)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.s4 + 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      label,
                      style: tokens.text.label.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.label
                          .withWeight(400)
                          .copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// "46 min left" beside the progress bar (canvas: 420 wide).
class _TimeLeft extends StatelessWidget {
  const new({required this.mark});

  final WatchMark mark;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final remaining = mark.remaining;
    return SizedBox(
      width: tokens.details.progressWidth,
      child: Row(
        children: [
          Expanded(child: ProgressBar(value: mark.fraction, height: 4)),
          if (remaining != null) ...[
            SizedBox(width: tokens.spacing.s12),
            Text(
              formatTimeLeft(remaining),
              style: tokens.text.labelSmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A series' page as the canvas draws it: the left column (the poster,
/// the title, year · seasons · ★ · genre, the plot, Continue and the
/// favorite) and the episodes by season on the right.
class _SeriesPage extends ConsumerStatefulWidget {
  const new({required this.series});

  final SeriesItem series;

  @override
  ConsumerState<_SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends ConsumerState<_SeriesPage> {
  final _episodes = FocusPaneController();
  final _tabs = FocusPaneController();
  final _rows = <String, FocusNode>{};
  final _rowKeys = <String, GlobalKey>{};

  /// The season shown; the continue episode's until the user picks one.
  int? _season;

  /// Whether the list was already placed on the episode to continue.
  bool _placed = false;

  SeriesItem get series => widget.series;

  @override
  void dispose() {
    _episodes.dispose();
    _tabs.dispose();
    for (final node in _rows.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _rowNode(String key) =>
      _rows.putIfAbsent(key, () => FocusNode(debugLabel: 'episode $key'));

  GlobalKey _rowKey(String key) => _rowKeys.putIfAbsent(key, GlobalKey.new);

  Future<void> _toggleFavorite() async {
    await ref
        .read(seriesRepositoryProvider)
        .setFavorite(series, on: !series.isFavorite);
    ref.invalidate(seriesItemProvider(series.sourceId, series.remoteKey));
  }

  void _play(EpisodeItem episode, {Duration? from}) => unawaited(
    ref.read(vodLauncherProvider).playEpisode(series, episode, from: from),
  );

  /// The list lands on the episode to continue: it is shown, and the
  /// list's first Tab stop.
  void _placeOn(EpisodeItem episode) {
    if (_placed) return;
    _placed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _episodes.remember(_rowNode(episode.remoteKey));
      final row = _rowKey(episode.remoteKey).currentContext;
      if (row != null) {
        Scrollable.ensureVisible(row, alignment: 0.3);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.details;
    final state = ref
        .watch(seriesDetailsProvider(series.sourceId, series.remoteKey))
        .value;
    final marks =
        ref
            .watch(seriesMarksProvider(series.sourceId, series.remoteKey))
            .value ??
        const <String, WatchMark>{};
    final details = switch (state) {
      DetailsReady(:final value) => value,
      _ => null,
    };
    final nextUp = details == null ? null : nextUpFor(details, marks);
    if (nextUp != null) _placeOn(nextUp.episode);
    final seasons = details?.seasons ?? const <Season>[];
    final wanted = _season ?? nextUp?.episode.season;
    final shown =
        seasons.where((s) => s.number == wanted).firstOrNull ??
        seasons.firstOrNull;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            unawaited(_toggleFavorite()),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.bg),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: layout.seriesColumnWidth + tokens.spacing.s64,
            child: DetailsBackdrop(
              backdropUrl: details?.backdropUrl ?? series.backdropUrl,
              posterUrl: series.posterUrl,
              fadeRight: true,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: layout.seriesColumnWidth,
                child: Padding(
                  padding: layout.seriesPadding,
                  child: _SeriesColumn(
                    series: series,
                    details: details,
                    state: state,
                    nextUp: nextUp,
                    onPlay: _play,
                    onFavorite: () => unawaited(_toggleFavorite()),
                    onRetry: () => ref.invalidate(
                      seriesDetailsProvider(series.sourceId, series.remoteKey),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.s8,
                    tokens.spacing.s32,
                    tokens.spacing.s40,
                    tokens.spacing.s32,
                  ),
                  child: _episodesArea(
                    context,
                    state: state,
                    seasons: seasons,
                    shown: shown,
                    marks: marks,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _episodesArea(
    BuildContext context, {
    required Details<SeriesDetails>? state,
    required List<Season> seasons,
    required Season? shown,
    required Map<String, WatchMark> marks,
  }) {
    final tokens = context.tokens;
    void retry() => ref.invalidate(
      seriesDetailsProvider(series.sourceId, series.remoteKey),
    );
    if (state == null || state is DetailsLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.all(tokens.spacing.s8 + 2),
              child: Row(
                children: [
                  Skeleton(
                    width: tokens.details.episodeStill.width,
                    height: tokens.details.episodeStill.height,
                    borderRadius: tokens.radii.smAll,
                  ),
                  SizedBox(width: tokens.spacing.s16 + 2),
                  const Expanded(child: Skeleton()),
                ],
              ),
            ),
        ],
      );
    }
    if (state case DetailsFailed(:final failure)) {
      return EmptyState(
        compact: true,
        icon: AppIcons.alertCircle,
        title: "Couldn't load the episodes",
        message: failureMessage(failure),
        actionLabel: 'Retry',
        onAction: retry,
      );
    }
    if (shown == null) {
      return EmptyState(
        compact: true,
        icon: AppIcons.series,
        title: 'Your provider lists no episodes for this series yet',
        actionLabel: 'Retry',
        onAction: retry,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SeasonTabs(
          seasons: seasons,
          shown: shown,
          controller: _tabs,
          onPick: (season) => setState(() => _season = season.number),
        ),
        SizedBox(height: tokens.spacing.s16),
        Expanded(
          child: FocusPane(
            debugLabel: 'episodes',
            controller: _episodes,
            tabStop: true,
            child: ListView.builder(
              itemCount: shown.episodes.length,
              itemBuilder: (context, index) {
                final episode = shown.episodes[index];
                return _EpisodeRow(
                  key: _rowKey(episode.remoteKey),
                  episode: episode,
                  mark: marks[episode.remoteKey],
                  focus: _rowNode(episode.remoteKey),
                  onPlay: _play,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesColumn extends StatelessWidget {
  const new({
    required this.series,
    required this.details,
    required this.state,
    required this.nextUp,
    required this.onPlay,
    required this.onFavorite,
    required this.onRetry,
  });

  final SeriesItem series;
  final SeriesDetails? details;
  final Details<SeriesDetails>? state;
  final NextUp? nextUp;
  final void Function(EpisodeItem episode, {Duration? from}) onPlay;
  final VoidCallback onFavorite;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.details;
    final seasons = details?.seasons.length;
    final nextUp = this.nextUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        DetailsPoster(
          title: series.name,
          url: series.posterUrl,
          size: layout.seriesPoster,
        ),
        SizedBox(height: tokens.spacing.s16 + 2),
        Text(
          series.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tokens.text.seriesTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: tokens.spacing.s16 + 2),
        DetailsMetaLine(
          year: series.year,
          runtime: switch (seasons) {
            null || 0 => null,
            1 => '1 season',
            final n => '$n seasons',
          },
          rating: series.rating,
          genre: (details?.genre ?? series.genre)?.split(',').first,
        ),
        SizedBox(height: tokens.spacing.s16 + 2),
        _About(
          details: state,
          plot: details?.plot ?? series.plot,
          credits: const [],
          onRetry: onRetry,
        ),
        SizedBox(height: tokens.spacing.s16 + 2),
        Row(
          children: [
            if (nextUp != null) ...[
              Flexible(
                child: AppButton(
                  label: switch (nextUp.kind) {
                    NextUpKind.again => 'Play again',
                    NextUpKind.start => 'Play ${_episodeLabel(nextUp.episode)}',
                    _ => 'Continue ${_episodeLabel(nextUp.episode)}',
                  },
                  icon: AppIcons.play,
                  size: AppButtonSize.xl,
                  autofocus: true,
                  onPressed: () => onPlay(nextUp.episode, from: nextUp.from),
                ),
              ),
              SizedBox(width: tokens.spacing.s12),
            ],
            AppIconButton(
              icon: series.isFavorite ? AppIcons.starFilled : AppIcons.star,
              tooltip: series.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              shortcut: 'F',
              selected: series.isFavorite,
              bordered: true,
              // Only once the page knows there is nothing to play: the
              // Play button, arriving with the episodes, takes it then.
              autofocus: nextUp == null && state is DetailsReady,
              size: layout.movieActionHeight,
              onPressed: onFavorite,
            ),
          ],
        ),
      ],
    );
  }
}

/// "S2 · E4".
String _episodeLabel(EpisodeItem episode) =>
    'S${episode.season} · E${episode.episode}';

/// Season 1, Season 2… with the shown one underlined, and its episode
/// count at the right (canvas). One Tab stop; ←/→ inside, Enter shows a
/// season.
class _SeasonTabs extends StatelessWidget {
  const new({
    required this.seasons,
    required this.shown,
    required this.controller,
    required this.onPick,
  });

  final List<Season> seasons;
  final Season shown;
  final FocusPaneController controller;
  final void Function(Season season) onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final count = shown.episodes.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: Row(
        children: [
          Flexible(
            child: FocusPane(
              debugLabel: 'seasons',
              controller: controller,
              tabStop: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final season in seasons)
                      FocusableSurface(
                        onPressed: () => onPick(season),
                        borderRadius: tokens.radii.smAll,
                        semanticLabel: 'Season ${season.number}',
                        builder: (context, states) {
                          final active = season.number == shown.number;
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacing.s4,
                              vertical: tokens.spacing.s12,
                            ),
                            margin: EdgeInsets.only(right: tokens.spacing.s16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: active
                                      ? colors.accentBase
                                      : colors.accentBase.withValues(alpha: 0),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              'Season ${season.number}',
                              style: tokens.text.label
                                  .withWeight(700)
                                  .copyWith(
                                    color: active || states.highlighted
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                  ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.s12),
          Text(
            count == 1 ? '1 episode' : '$count episodes',
            style: tokens.text.labelSmall.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// One episode (canvas): the still with its progress line, E4 and the
/// title, a ✓ once watched; under them the runtime and "Watched" or the
/// time left; the focused row adds the description. Enter plays it —
/// from where it was left, when it was (decision 3); its menu starts over
/// or marks it.
class _EpisodeRow extends ConsumerWidget {
  const new({
    required this.episode,
    required this.mark,
    required this.focus,
    required this.onPlay,
    super.key,
  });

  final EpisodeItem episode;
  final WatchMark? mark;
  final FocusNode focus;
  final void Function(EpisodeItem episode, {Duration? from}) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final still = tokens.details.episodeStill;
    final mark = this.mark;
    final watched = mark?.completed ?? false;
    final resumable = mark != null && mark.resumable;
    final remaining = resumable ? mark.remaining : null;
    final runtime = episode.duration == null
        ? null
        : formatRuntime(episode.duration!);
    final line = [
      if (remaining == null) ?runtime,
      if (watched) 'Watched',
      if (remaining != null) formatTimeLeft(remaining),
    ].join(' · ');

    Future<void> menu() => showAppMenu(
      context,
      items: [
        AppMenuItem(
          label: resumable ? 'Resume' : 'Play',
          icon: AppIcons.play,
          onPressed: () =>
              onPlay(episode, from: resumable ? mark.position : null),
        ),
        if (resumable)
          AppMenuItem(
            label: 'Start over',
            icon: AppIcons.retry,
            onPressed: () => onPlay(episode),
          ),
        AppMenuItem(
          label: watched ? 'Mark as unwatched' : 'Mark as watched',
          icon: AppIcons.check,
          onPressed: () => unawaited(
            ref
                .read(watchProgressProvider)
                .setWatched(episode.ref, watched: !watched),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.s4),
      child: FocusableSurface(
        focusNode: focus,
        borderRadius: tokens.radii.mdAll,
        semanticLabel: 'Episode ${episode.episode}, ${episode.title}',
        onPressed: () =>
            onPlay(episode, from: resumable ? mark.position : null),
        onMenu: () => unawaited(menu()),
        builder: (context, states) => Container(
          padding: EdgeInsets.all(tokens.spacing.s8 + 2),
          decoration: BoxDecoration(
            color: states.highlighted
                ? colors.surface3
                : colors.surface3.withValues(alpha: 0),
            borderRadius: tokens.radii.mdAll,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: tokens.radii.smAll,
                child: SizedBox(
                  width: still.width,
                  height: still.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PosterArtwork(
                        title: '',
                        image: artworkFor(
                          context,
                          episode.stillUrl,
                          width: still.width,
                        ),
                      ),
                      if (mark != null && mark.position > Duration.zero)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ProgressBar(
                            value: watched ? 1 : mark.fraction,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.s16 + 2),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'E${episode.episode}',
                            style: tokens.text.labelSmall
                                .withWeight(700)
                                .copyWith(
                                  color: states.focused
                                      ? colors.accentBase
                                      : colors.textTertiary,
                                ),
                          ),
                          SizedBox(width: tokens.spacing.s8 + 2),
                          Expanded(
                            child: Text(
                              episode.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tokens.text.bodyStrong.copyWith(
                                color: watched && !states.focused
                                    ? colors.textSecondary
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                          if (watched)
                            AppIcon(
                              AppIcons.check,
                              size: 18,
                              color: colors.success,
                            ),
                        ],
                      ),
                      if (line.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing.s4),
                        Text(
                          line,
                          style: tokens.text.labelSmall.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                      if (states.focused && episode.plot != null) ...[
                        SizedBox(height: tokens.spacing.s4 + 2),
                        Text(
                          episode.plot!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.text.label
                              .withWeight(400)
                              .copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The artwork behind a page: the backdrop, or the poster blurred when
/// there is none (docs/05), under the canvas's gradients. [fadeRight] fades
/// it into the page on the right too (a series' left column).
class DetailsBackdrop extends StatelessWidget {
  const new({
    required this.backdropUrl,
    required this.posterUrl,
    this.fadeRight = false,
    super.key,
  });

  final String? backdropUrl;
  final String? posterUrl;
  final bool fadeRight;

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
                colors.bg.withValues(alpha: fadeRight ? 1 : 0.35),
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

/// "2024 · 1 h 58 min · ★ 7.8 · Drama, Mystery  FHD  5.1" — what is known
/// of it, and "Watched" once it was.
class DetailsMetaLine extends StatelessWidget {
  const new({
    this.year,
    this.rating,
    this.genre,
    this.runtime,
    this.badges = const [],
    this.watched = false,
    super.key,
  });

  final int? year;
  final double? rating;
  final String? genre;
  final String? runtime;
  final List<String> badges;
  final bool watched;

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
      if (watched)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.check, size: 15, color: colors.success),
            SizedBox(width: tokens.spacing.s4 + 1),
            Text('Watched', style: style),
          ],
        ),
    ];
    return Wrap(
      spacing: tokens.spacing.s12 + 2,
      runSpacing: tokens.spacing.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, part) in parts.indexed) ...[if (i > 0) dot, part],
        for (final badge in badges) AppBadge(badge, tone: AppBadgeTone.outline),
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
