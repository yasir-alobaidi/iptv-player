import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/presentation/cast_actions.dart';
import 'package:iptv_player/features/downloads/presentation/download_actions.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/next_up.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:iptv_player/features/vod/presentation/compact_layout.dart';
import 'package:iptv_player/features/vod/presentation/details_state.dart';
import 'package:iptv_player/features/vod/presentation/vod_text.dart';

/// A movie's page (canvas `Movie details`), inside the Movies branch
/// (or the Library's, for a download: [back] says "Library").
class MovieDetailsScreen extends ConsumerWidget {
  const new({
    required this.sourceId,
    required this.remoteKey,
    this.back = 'Movies',
    super.key,
  });

  final String sourceId;
  final String remoteKey;
  final String back;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref.watch(movieItemProvider(sourceId, remoteKey));
    return DetailsFrame(
      back: back,
      loading: found is! AsyncData && found is! AsyncError,
      child: switch (found) {
        AsyncData(value: Ok(value: final movie?)) => _MoviePage(movie: movie),
        AsyncData(value: Ok(value: null)) => const DetailsGone(
          message: 'This movie is no longer available from your provider.',
        ),
        AsyncData(value: Err(:final Object failure)) ||
        AsyncError(error: final Object failure) => ErrorState(
          title: "Couldn't open this movie",
          details: '$failure',
          onRetry: () => ref.invalidate(movieItemProvider(sourceId, remoteKey)),
        ),
        _ => const DetailsPageLoading(),
      },
    );
  }
}

/// A series' page (canvas `Series details`), inside the Series branch
/// (or the Library's, for downloaded episodes: [back] says "Library").
class SeriesDetailsScreen extends ConsumerWidget {
  const new({
    required this.sourceId,
    required this.remoteKey,
    this.back = 'Series',
    super.key,
  });

  final String sourceId;
  final String remoteKey;
  final String back;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref.watch(seriesItemProvider(sourceId, remoteKey));
    return DetailsFrame(
      back: back,
      loading: found is! AsyncData && found is! AsyncError,
      child: switch (found) {
        AsyncData(value: Ok(value: final series?)) => _SeriesPage(
          series: series,
        ),
        AsyncData(value: Ok(value: null)) => const DetailsGone(
          message: 'This series is no longer available from your provider.',
        ),
        AsyncData(value: Err(:final Object failure)) ||
        AsyncError(error: final Object failure) => ErrorState(
          title: "Couldn't open this series",
          details: '$failure',
          onRetry: () =>
              ref.invalidate(seriesItemProvider(sourceId, remoteKey)),
        ),
        _ => const DetailsPageLoading(),
      },
    );
  }
}

/// What every details page has: the page's own focus group, Esc back to
/// the grid, and the canvas's "‹ Movies" chip over the artwork (the
/// Library's pages too).
class DetailsFrame extends StatelessWidget {
  const new({
    required this.back,
    required this.child,
    this.loading = false,
    super.key,
  });

  final String back;
  final Widget child;

  /// While the title is read, the chip takes no focus: a jump here
  /// (Enter on a Home poster) would put the focus on it, the page's only
  /// control, and the page's own first focus (Play's autofocus) arriving
  /// with the title would then be ignored.
  final bool loading;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Over a phone's backdrop, nearer its corner and a finger's
            // height (ADR-068).
            final stacked = detailsStacked(constraints.biggest);
            return Stack(
              fit: StackFit.expand,
              children: [
                child,
                Positioned(
                  top: stacked ? tokens.spacing.s12 : tokens.spacing.s24,
                  left: stacked ? tokens.spacing.s16 : tokens.spacing.s40,
                  child: ExcludeFocus(
                    excluding: loading,
                    child: _BackChip(
                      label: back,
                      onPressed: leave,
                      touch: stacked,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Whether a title's page in a [size] box is one column that scrolls
/// (ADR-068): the backdrop across the top, the poster beside the title,
/// the actions the page's width, the plot, and a series' seasons and
/// episodes under them. A phone's page, upright or on its side, and a
/// tablet's held upright; a box as wide as a desktop window's (1024 ×
/// 640 at least) or a TV's canvas has the canvas's page.
bool detailsStacked(Size size) =>
    CompactLayout.fits(size) ||
    (size.width < _stackedUprightWidth && size.width < size.height);

/// A box narrower than this and taller than wide (a tablet held
/// upright) has the stacked page.
const _stackedUprightWidth = 840.0;

class _BackChip extends StatelessWidget {
  const new({required this.label, required this.onPressed, this.touch = false});

  final String label;
  final VoidCallback onPressed;

  /// A finger's target tall (a phone's page).
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      onPressed: onPressed,
      borderRadius: tokens.radii.pillAll,
      semanticLabel: 'Back to $label',
      builder: (context, states) => Container(
        height: touch
            ? math.max(
                context.scaled(tokens.details.backChipHeight),
                CompactLayout.touchTarget,
              )
            : context.scaled(tokens.details.backChipHeight),
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

    final download = ref.watch(
      titleDownloadProvider(VodType.movie, movie.sourceId, movie.remoteKey),
    );
    final downloadFace = downloadButtonFace(download);
    final request = movieDownloadRequest(movie);

    final overline = Text(
      [
        'MOVIE',
        if (genre != null && genre.isNotEmpty) genre,
      ].join('  /  ').toUpperCase(),
      style: tokens.text.overline.copyWith(color: colors.textSecondary),
    );
    final meta = DetailsMetaLine(
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
    );
    Widget about({bool stacked = false}) => _About(
      details: details,
      plot: ready?.plot,
      credits: [
        if (ready?.director case final director?) ('Director', director),
        if (ready?.cast case final cast?) ('Cast', cast),
      ],
      stacked: stacked,
      onRetry: () =>
          ref.invalidate(movieDetailsProvider(movie.sourceId, movie.remoteKey)),
    );
    Widget playButton({bool expand = false}) => AppButton(
      label: resumable
          ? 'Resume from '
                '${formatPosition(mark.position)}'
          : 'Play',
      icon: AppIcons.play,
      size: AppButtonSize.xl,
      autofocus: true,
      expand: expand,
      onPressed: () => play(from: resumable ? mark.position : null),
    );
    Widget startOver({bool expand = false}) => AppButton(
      label: 'Start over',
      icon: AppIcons.retry,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.xl,
      expand: expand,
      onPressed: play,
    );
    // Sketch E: Download, its progress, or Downloaded; Enter on one under
    // way or done opens its menu. Not on a TV or a phone.
    Widget? downloadButton({bool expand = false}) =>
        !ref.watch(downloadsHereProvider)
        ? null
        : Builder(
            builder: (anchor) => AppButton(
              label: downloadFace.label,
              icon: downloadFace.icon,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.xl,
              expand: expand,
              onPressed: () =>
                  unawaited(downloadPressed(anchor, download, request)),
            ),
          );
    final favorite = AppIconButton(
      icon: movie.isFavorite ? AppIcons.starFilled : AppIcons.star,
      tooltip: movie.isFavorite ? 'Remove from favorites' : 'Add to favorites',
      shortcut: 'F',
      selected: movie.isFavorite,
      bordered: true,
      size: layout.movieActionHeight,
      onPressed: () => unawaited(toggleFavorite()),
    );
    final cast = !ref.watch(castsToTvsProvider)
        ? null
        : AppIconButton(
            icon: AppIcons.cast,
            tooltip: 'Cast',
            bordered: true,
            size: layout.movieActionHeight,
            onPressed: () => unawaited(
              castFrom(
                context,
                item: PlayableMovie(movie),
                from: resumable ? mark.position : null,
              ),
            ),
          );
    final cheapBlur = ref.watch(formFactorProvider).isAndroidDevice;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            unawaited(toggleFavorite()),
        if (ref.watch(downloadsHereProvider))
          const SingleActivator(LogicalKeyboardKey.keyD): () =>
              unawaited(startDownloads(context, [request])),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (detailsStacked(constraints.biggest)) {
            final gap = tokens.spacing.s12;
            final downloadAction = downloadButton(expand: true);
            return SingleChildScrollView(
              child: DetailsStackedHero(
                title: movie.name,
                backdropUrl: ready?.backdropUrl,
                posterUrl: movie.posterUrl,
                cheapBlur: cheapBlur,
                overline: overline,
                meta: meta,
                below: [
                  // Play the width of the page, the favorite beside it;
                  // Resume, longer, alone, the favorite by Start over.
                  Row(
                    children: [
                      Expanded(child: playButton(expand: true)),
                      if (!resumable) ...[SizedBox(width: gap), favorite],
                      if (cast != null) ...[SizedBox(width: gap), cast],
                    ],
                  ),
                  if (resumable || downloadAction != null) ...[
                    SizedBox(height: gap),
                    Row(
                      children: [
                        if (resumable) Expanded(child: startOver(expand: true)),
                        if (resumable && downloadAction != null)
                          SizedBox(width: gap),
                        if (downloadAction != null)
                          Expanded(child: downloadAction),
                        if (resumable) ...[SizedBox(width: gap), favorite],
                      ],
                    ),
                  ],
                  if (resumable) ...[
                    SizedBox(height: gap),
                    DetailsTimeLeft(mark: mark),
                  ],
                  SizedBox(height: tokens.spacing.s24),
                  about(stacked: true),
                ],
              ),
            );
          }
          final downloadAction = downloadButton();
          return Stack(
            fit: StackFit.expand,
            children: [
              DetailsBackdrop(
                backdropUrl: ready?.backdropUrl,
                posterUrl: movie.posterUrl,
                cheapBlur: cheapBlur,
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
                        constraints: BoxConstraints(
                          maxWidth: layout.textMaxWidth,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            overline,
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
                            meta,
                            SizedBox(height: tokens.spacing.s16),
                            about(),
                            SizedBox(height: tokens.spacing.s24),
                            Wrap(
                              spacing: tokens.spacing.s12,
                              runSpacing: tokens.spacing.s12,
                              children: [
                                playButton(),
                                if (resumable) startOver(),
                                ?downloadAction,
                                favorite,
                                ?cast,
                              ],
                            ),
                            if (resumable) ...[
                              SizedBox(height: tokens.spacing.s12),
                              DetailsTimeLeft(mark: mark),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
    this.stacked = false,
  });

  final Details<Object>? details;
  final String? plot;
  final List<(String, String)> credits;
  final VoidCallback onRetry;

  /// On a page that scrolls as one column ([detailsStacked]): the plot
  /// has more lines, Retry goes under the reason.
  final bool stacked;

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
      final reason = Text(
        "Couldn't load the details. ${failureMessage(failure)}",
        style: tokens.text.body.copyWith(color: colors.textSecondary),
      );
      final retry = AppButton(
        label: 'Retry',
        icon: AppIcons.retry,
        variant: stacked ? AppButtonVariant.secondary : AppButtonVariant.ghost,
        size: stacked ? AppButtonSize.m : AppButtonSize.s,
        onPressed: onRetry,
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            reason,
            SizedBox(height: tokens.spacing.s12),
            retry,
          ],
        );
      }
      return Row(
        children: [
          Flexible(child: reason),
          SizedBox(width: tokens.spacing.s12),
          retry,
        ],
      );
    }
    final plot = this.plot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plot ?? 'No description from your provider.',
          maxLines: stacked ? 10 : 5,
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
class DetailsTimeLeft extends StatelessWidget {
  const new({required this.mark, super.key});

  final WatchMark mark;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final remaining = mark.remaining;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        // The canvas's 420, or a phone's width.
        width: math.min(tokens.details.progressWidth, constraints.maxWidth),
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

  /// The column's main action (Play, or the favorite while there is
  /// nothing to play): where ← from the seasons and the episodes goes.
  final _primary = FocusNode(debugLabel: 'series primary');
  final _rows = <String, FocusNode>{};
  final _rowKeys = <String, GlobalKey>{};

  /// The season shown: the one to continue in as the page opens, then
  /// whichever the user picks.
  int? _season;

  /// Whether the list was already placed on the episode to continue.
  bool _placed = false;

  SeriesItem get series => widget.series;

  @override
  void dispose() {
    _episodes.dispose();
    _tabs.dispose();
    _primary.dispose();
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
    final state = ref
        .watch(seriesDetailsProvider(series.sourceId, series.remoteKey))
        .value;
    final marked = ref.watch(
      seriesMarksProvider(series.sourceId, series.remoteKey),
    );
    final marks = marked.value ?? const <String, WatchMark>{};
    final details = switch (state) {
      DetailsReady(:final value) => value,
      _ => null,
    };
    final nextUp = details == null ? null : nextUpFor(details, marks);
    // Once the marks are read, the page opens on the season to continue
    // in. From then on only the user changes the season: a mark that
    // moves Continue to another one (the last episode of this season
    // marked watched) must not swap the list under whoever is in it.
    if (nextUp != null && marked.hasValue) {
      _season ??= nextUp.episode.season;
    }
    final seasons = details?.seasons ?? const <Season>[];
    final wanted = _season ?? nextUp?.episode.season;
    final shown =
        seasons.where((s) => s.number == wanted).firstOrNull ??
        seasons.firstOrNull;

    final cheapBlur = ref.watch(formFactorProvider).isAndroidDevice;
    final castable = ref.watch(castsToTvsProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            unawaited(_toggleFavorite()),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (detailsStacked(constraints.biggest)) {
            return _stacked(
              context,
              state: state,
              details: details,
              nextUp: nextUp,
              seasons: seasons,
              shown: shown,
              marks: marks,
              cheapBlur: cheapBlur,
              castable: castable,
            );
          }
          // The list opens on the episode to continue, its first Tab stop.
          if (nextUp != null && marked.hasValue) _placeOn(nextUp.episode);
          return _columns(
            context,
            state: state,
            details: details,
            nextUp: nextUp,
            seasons: seasons,
            shown: shown,
            marks: marks,
            cheapBlur: cheapBlur,
            castable: castable,
          );
        },
      ),
    );
  }

  /// The canvas's page: the column on the left, the seasons and the
  /// episodes on the right.
  Widget _columns(
    BuildContext context, {
    required Details<SeriesDetails>? state,
    required SeriesDetails? details,
    required NextUp? nextUp,
    required List<Season> seasons,
    required Season? shown,
    required Map<String, WatchMark> marks,
    required bool cheapBlur,
    required bool castable,
  }) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.details;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.bg),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width:
              layout.seriesColumnFor(MediaQuery.sizeOf(context).width) +
              tokens.spacing.s64,
          child: DetailsBackdrop(
            backdropUrl: details?.backdropUrl ?? series.backdropUrl,
            posterUrl: series.posterUrl,
            fadeRight: true,
            cheapBlur: cheapBlur,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: layout.seriesColumnFor(MediaQuery.sizeOf(context).width),
              child: Padding(
                padding: layout.seriesPadding,
                child: _SeriesColumn(
                  series: series,
                  details: details,
                  state: state,
                  nextUp: nextUp,
                  primaryFocus: _primary,
                  onPlay: _play,
                  onFavorite: () => unawaited(_toggleFavorite()),
                  onRetry: () => ref.invalidate(
                    seriesDetailsProvider(series.sourceId, series.remoteKey),
                  ),
                  castable: castable,
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
    );
  }

  /// A phone's page, and a tablet's held upright ([detailsStacked]): one
  /// column that scrolls — the backdrop, the poster beside the title, the
  /// actions the page's width, the plot, the seasons as chips, and the
  /// episodes the page's width, read as they scroll into view.
  Widget _stacked(
    BuildContext context, {
    required Details<SeriesDetails>? state,
    required SeriesDetails? details,
    required NextUp? nextUp,
    required List<Season> seasons,
    required Season? shown,
    required Map<String, WatchMark> marks,
    required bool cheapBlur,
    required bool castable,
  }) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;
    final side = CompactLayout.of(context) ? spacing.s16 : spacing.s32;
    final count = details?.seasons.length;
    final genre = (details?.genre ?? series.genre)?.split(',').first.trim();
    void retry() => ref.invalidate(
      seriesDetailsProvider(series.sourceId, series.remoteKey),
    );
    final hero = DetailsStackedHero(
      title: series.name,
      backdropUrl: details?.backdropUrl ?? series.backdropUrl,
      posterUrl: series.posterUrl,
      cheapBlur: cheapBlur,
      overline: Text(
        [
          'SERIES',
          if (genre != null && genre.isNotEmpty) genre,
        ].join('  /  ').toUpperCase(),
        style: tokens.text.overline.copyWith(color: colors.textSecondary),
      ),
      meta: DetailsMetaLine(
        year: series.year,
        runtime: switch (count) {
          null || 0 => null,
          1 => '1 season',
          final n => '$n seasons',
        },
        rating: series.rating,
      ),
      below: [
        _SeriesActions(
          series: series,
          state: state,
          nextUp: nextUp,
          primaryFocus: _primary,
          onPlay: _play,
          onFavorite: () => unawaited(_toggleFavorite()),
          castable: castable,
          expand: true,
        ),
        SizedBox(height: spacing.s24),
        _About(
          details: state,
          plot: details?.plot ?? series.plot,
          credits: const [],
          stacked: true,
          onRetry: retry,
        ),
      ],
    );
    Widget padded(Widget child) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: side),
      sliver: SliverToBoxAdapter(child: child),
    );
    final List<Widget> episodes;
    if (state == null || state is DetailsLoading) {
      episodes = [
        padded(
          Column(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.s12),
                  child: Row(
                    children: [
                      Skeleton(
                        width: _compactStill(context).width,
                        height: _compactStill(context).height,
                        borderRadius: tokens.radii.smAll,
                      ),
                      SizedBox(width: spacing.s12),
                      const Expanded(child: Skeleton()),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ];
    } else if (state case DetailsFailed(:final failure)) {
      episodes = [
        padded(
          EmptyState(
            compact: true,
            icon: AppIcons.alertCircle,
            title: "Couldn't load the episodes",
            message: failureMessage(failure),
            actionLabel: 'Retry',
            onAction: retry,
          ),
        ),
      ];
    } else if (shown == null) {
      episodes = [
        padded(
          EmptyState(
            compact: true,
            icon: AppIcons.series,
            title: 'Your provider lists no episodes for this series yet',
            actionLabel: 'Retry',
            onAction: retry,
          ),
        ),
      ];
    } else {
      episodes = [
        padded(
          _SeasonChips(
            seasons: [for (final season in seasons) season.number],
            shown: shown.number,
            episodes: shown.episodes.length,
            controller: _tabs,
            onPick: (season) => setState(() => _season = season),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: spacing.s8)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side - spacing.s8),
          sliver: SliverList.builder(
            itemCount: shown.episodes.length,
            itemBuilder: (context, index) {
              final episode = shown.episodes[index];
              return _EpisodeRow(
                key: _rowKey(episode.remoteKey),
                episode: episode,
                request: episodeDownloadRequest(series, episode),
                mark: marks[episode.remoteKey],
                focus: _rowNode(episode.remoteKey),
                onPlay: _play,
                compact: true,
              );
            },
          ),
        ),
      ];
    }
    return ColoredBox(
      color: colors.bg,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: hero),
          ...episodes,
          SliverToBoxAdapter(child: SizedBox(height: spacing.s32)),
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
        DetailsSeasonTabs(
          seasons: [for (final season in seasons) season.number],
          shown: shown.number,
          episodes: shown.episodes.length,
          controller: _tabs,
          onPick: (season) => setState(() => _season = season),
          onLeaveLeft: _primary.requestFocus,
          trailing: !ref.watch(downloadsHereProvider)
              ? null
              : _DownloadSeason(
                  onPressed: () => unawaited(
                    startDownloads(context, [
                      for (final episode in shown.episodes)
                        episodeDownloadRequest(series, episode),
                    ]),
                  ),
                ),
        ),
        SizedBox(height: tokens.spacing.s16),
        Expanded(
          child: DetailsEpisodeList(
            controller: _episodes,
            onLeaveLeft: _primary.requestFocus,
            itemCount: shown.episodes.length,
            itemBuilder: (context, index) {
              final episode = shown.episodes[index];
              return _EpisodeRow(
                key: _rowKey(episode.remoteKey),
                episode: episode,
                request: episodeDownloadRequest(series, episode),
                mark: marks[episode.remoteKey],
                focus: _rowNode(episode.remoteKey),
                onPlay: _play,
              );
            },
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
    required this.primaryFocus,
    required this.onPlay,
    required this.onFavorite,
    required this.onRetry,
    required this.castable,
  });

  /// Play's node, or the favorite's while there is nothing to play.
  final FocusNode primaryFocus;
  final SeriesItem series;
  final SeriesDetails? details;
  final Details<SeriesDetails>? state;
  final NextUp? nextUp;
  final void Function(EpisodeItem episode, {Duration? from}) onPlay;
  final VoidCallback onFavorite;
  final VoidCallback onRetry;

  /// The Cast button is drawn ([castsToTvsProvider]).
  final bool castable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.details;
    final seasons = details?.seasons.length;
    final nextUp = this.nextUp;
    // At the bottom of the column, as the canvas draws it. Where it
    // doesn't all fit (the smallest window at a larger text size, a long
    // plot) it scrolls, from its bottom: the actions stay in view and the
    // poster's top gives way. It used to overflow there.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        reverse: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                style: tokens.text.seriesTitle.copyWith(
                  color: colors.textPrimary,
                ),
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
              _SeriesActions(
                series: series,
                state: state,
                nextUp: nextUp,
                primaryFocus: primaryFocus,
                onPlay: onPlay,
                onFavorite: onFavorite,
                castable: castable,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Play, Continue or Play again, the favorite and Cast (canvas): at the
/// foot of the desktop's column, or the page's width on a stacked page
/// ([expand]).
class _SeriesActions extends StatelessWidget {
  const new({
    required this.series,
    required this.state,
    required this.nextUp,
    required this.primaryFocus,
    required this.onPlay,
    required this.onFavorite,
    required this.castable,
    this.expand = false,
  });

  final SeriesItem series;
  final Details<SeriesDetails>? state;
  final NextUp? nextUp;
  final FocusNode primaryFocus;
  final void Function(EpisodeItem episode, {Duration? from}) onPlay;
  final VoidCallback onFavorite;
  final bool castable;

  /// The primary action fills the row.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final layout = tokens.details;
    final nextUp = this.nextUp;
    final Widget? primary = nextUp == null
        ? null
        : AppButton(
            label: switch (nextUp.kind) {
              NextUpKind.again => 'Play again',
              NextUpKind.start => 'Play ${_episodeLabel(nextUp.episode)}',
              _ => 'Continue ${_episodeLabel(nextUp.episode)}',
            },
            icon: AppIcons.play,
            size: AppButtonSize.xl,
            autofocus: true,
            expand: expand,
            focusNode: primaryFocus,
            onPressed: () => onPlay(nextUp.episode, from: nextUp.from),
          );
    return Row(
      children: [
        if (primary != null) ...[
          if (expand) Expanded(child: primary) else Flexible(child: primary),
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
          // Only once the page knows there is nothing to play: the Play
          // button, arriving with the episodes, takes it then.
          autofocus: nextUp == null && state is DetailsReady,
          focusNode: nextUp == null ? primaryFocus : null,
          size: layout.movieActionHeight,
          onPressed: onFavorite,
        ),
        if (nextUp != null && castable) ...[
          SizedBox(width: tokens.spacing.s12),
          AppIconButton(
            icon: AppIcons.cast,
            tooltip: 'Cast',
            bordered: true,
            size: layout.movieActionHeight,
            onPressed: () => unawaited(
              castFrom(
                context,
                item: PlayableEpisode(series, nextUp.episode),
                from: nextUp.from,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "S2 · E4".
String _episodeLabel(EpisodeItem episode) =>
    'S${episode.season} · E${episode.episode}';

/// Season 1, Season 2… with the shown one underlined, and its episode
/// count at the right (canvas). One Tab stop; ←/→ inside, Enter shows a
/// season. A library show's page has them too.
///
/// The arrows are the tabs' own: the shell takes ← in a screen as "back
/// to the nav rail" unless the screen binds it, which would leave the
/// seasons before the first could be reached. ← on the first season
/// calls [onLeaveLeft] (the page's column is there).
class DetailsSeasonTabs extends StatefulWidget {
  const new({
    required this.seasons,
    required this.shown,
    required this.episodes,
    required this.controller,
    required this.onPick,
    this.onLeaveLeft,
    this.trailing,
    super.key,
  });

  /// After the episode count: the provider's page has Download season
  /// there (canvas).
  final Widget? trailing;

  /// The seasons' numbers, in order.
  final List<int> seasons;
  final int shown;

  /// How many episodes the shown season has.
  final int episodes;
  final FocusPaneController controller;
  final void Function(int season) onPick;
  final VoidCallback? onLeaveLeft;

  @override
  State<DetailsSeasonTabs> createState() => _DetailsSeasonTabsState();
}

class _DetailsSeasonTabsState extends State<DetailsSeasonTabs> {
  final _nodes = <int, FocusNode>{};

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _node(int season) =>
      _nodes.putIfAbsent(season, () => FocusNode(debugLabel: 'season $season'));

  void _step(int by) {
    final seasons = widget.seasons;
    final at = seasons.indexWhere((season) => _node(season).hasFocus);
    if (at < 0) return;
    final to = at + by;
    if (to < 0) {
      widget.onLeaveLeft?.call();
    } else if (to < seasons.length) {
      _node(seasons[to]).requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final episodes = widget.episodes;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: Row(
        children: [
          Flexible(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _step(-1),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _step(1),
              },
              child: FocusPane(
                debugLabel: 'seasons',
                controller: widget.controller,
                tabStop: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final season in widget.seasons)
                        Padding(
                          padding: EdgeInsets.only(right: tokens.spacing.s8),
                          child: CountTab(
                            focusNode: _node(season),
                            label: 'Season $season',
                            selected: season == widget.shown,
                            onPressed: () => widget.onPick(season),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.s12),
          Padding(
            padding: EdgeInsets.only(bottom: CountTab.underlineRoom(context)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  episodes == 1 ? '1 episode' : '$episodes episodes',
                  style: tokens.text.labelSmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                if (widget.trailing case final trailing?) ...[
                  SizedBox(width: tokens.spacing.s16),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The episodes of a details page, one Tab stop with ↑/↓ inside; ← goes
/// to the page's column ([onLeaveLeft]) rather than out to the nav rail,
/// so Play can be reached again by keys.
class DetailsEpisodeList extends StatelessWidget {
  const new({
    required this.controller,
    required this.onLeaveLeft,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final FocusPaneController controller;
  final VoidCallback onLeaveLeft;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): onLeaveLeft,
    },
    child: FocusPane(
      debugLabel: 'episodes',
      controller: controller,
      tabStop: true,
      child: ListView.builder(itemCount: itemCount, itemBuilder: itemBuilder),
    ),
  );
}

/// One episode (canvas): the still with its progress line, E4 and the
/// title, a ✓ once watched; under them the runtime and "Watched" or the
/// time left; the focused row adds the description. Enter plays it —
/// from where it was left, when it was (decision 3); its menu starts over
/// or marks it.
class _EpisodeRow extends ConsumerWidget {
  const new({
    required this.episode,
    required this.request,
    required this.mark,
    required this.focus,
    required this.onPlay,
    this.compact = false,
    super.key,
  });

  final EpisodeItem episode;

  /// What Download asks the queue for.
  final DownloadRequest request;
  final WatchMark? mark;
  final FocusNode focus;
  final void Function(EpisodeItem episode, {Duration? from}) onPlay;

  /// A stacked page's row (ADR-068): a smaller still, the title on two
  /// lines, and the description always under them — a finger has no
  /// focus to show it on.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    // A phone's still is smaller; a tablet's, the canvas's.
    final still = compact && CompactLayout.of(context)
        ? _compactStill(context)
        : tokens.details.episodeStill;
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
    final download = ref.watch(
      titleDownloadProvider(
        VodType.episode,
        episode.sourceId,
        episode.remoteKey,
      ),
    );
    final downloadFace = downloadButtonFace(download);

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
        if (!ref.watch(downloadsHereProvider))
          ...[]
        else if (download.none)
          AppMenuItem(
            label: 'Download',
            icon: AppIcons.download,
            shortcut: 'D',
            onPressed: () => unawaited(startDownloads(context, [request])),
          )
        else
          AppMenuItem(
            label: '${downloadFace.label}…',
            icon: downloadFace.icon,
            onPressed: () =>
                unawaited(downloadPressed(context, download, request)),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.s4),
      child: CallbackShortcuts(
        bindings: {
          if (ref.watch(downloadsHereProvider))
            const SingleActivator(LogicalKeyboardKey.keyD): () =>
                unawaited(startDownloads(context, [request])),
        },
        child: FocusableSurface(
          ringPlacement: RingPlacement.inside,
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
            child: _withPlot(
              context,
              Row(
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
                  SizedBox(
                    width: compact
                        ? tokens.spacing.s12
                        : tokens.spacing.s16 + 2,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: compact ? 0 : tokens.spacing.s4,
                      ),
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
                                  maxLines: compact ? 2 : 1,
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
                              SizedBox(width: tokens.spacing.s8 + 2),
                              // The mouse's: the keyboard has D and the
                              // row's menu.
                              if (ref.watch(downloadsHereProvider))
                                ExcludeFocus(
                                  child: Builder(
                                    builder: (anchor) => _EpisodeDownload(
                                      download: download,
                                      onPressed: () => unawaited(
                                        downloadPressed(
                                          anchor,
                                          download,
                                          request,
                                        ),
                                      ),
                                    ),
                                  ),
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
                          if (!compact &&
                              states.focused &&
                              episode.plot != null) ...[
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
        ),
      ),
    );
  }

  /// A compact row's description, under its still and title.
  Widget _withPlot(BuildContext context, Widget row) {
    final plot = episode.plot;
    if (!compact || plot == null || plot.trim().isEmpty) return row;
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        SizedBox(height: tokens.spacing.s8),
        Text(
          plot,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: tokens.text.label
              .withWeight(400)
              .copyWith(color: tokens.colors.textSecondary),
        ),
      ],
    );
  }
}

/// An episode's still in a stacked page's row: two thirds of the
/// canvas's.
Size _compactStill(BuildContext context) =>
    context.tokens.details.episodeStill * (2 / 3);

/// A stacked page's seasons (ADR-068): chips in a row that scrolls
/// sideways, each a finger's target, and the shown one's episode count.
/// One Tab stop; the arrows move inside it, Enter shows a season.
class _SeasonChips extends StatelessWidget {
  const new({
    required this.seasons,
    required this.shown,
    required this.episodes,
    required this.controller,
    required this.onPick,
  });

  final List<int> seasons;
  final int shown;
  final int episodes;
  final FocusPaneController controller;
  final void Function(int season) onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: math.max(context.scaled(40), CompactLayout.touchTarget),
            child: FocusPane(
              debugLabel: 'seasons',
              controller: controller,
              tabStop: true,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: seasons.length,
                separatorBuilder: (_, _) => SizedBox(width: tokens.spacing.s8),
                itemBuilder: (context, index) {
                  final season = seasons[index];
                  return TouchTarget(
                    onTap: () => onPick(season),
                    child: AppChip(
                      label: 'Season $season',
                      selected: season == shown,
                      onPressed: () => onPick(season),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.s12),
        Text(
          episodes == 1 ? '1 episode' : '$episodes episodes',
          style: tokens.text.labelSmall.copyWith(
            color: tokens.colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// "Download season" at the right of the seasons (canvas): every episode
/// of the season shown that isn't downloaded or on its way.
class _DownloadSeason extends StatelessWidget {
  const new({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      onPressed: onPressed,
      borderRadius: tokens.radii.smAll,
      semanticLabel: 'Download season',
      builder: (context, states) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.s4,
          vertical: tokens.spacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.download,
              size: 14,
              color: states.highlighted
                  ? colors.accentHover
                  : colors.accentBase,
            ),
            SizedBox(width: tokens.spacing.s4 + 2),
            Text(
              'Download season',
              style: tokens.text.caption
                  .withWeight(700)
                  .copyWith(
                    color: states.highlighted
                        ? colors.accentHover
                        : colors.accentBase,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An episode's download at the right of its title (canvas: a 32 px
/// bordered button): the arrow, its progress as it comes, the green
/// check once it is on this computer.
class _EpisodeDownload extends StatelessWidget {
  const new({required this.download, required this.onPressed});

  final TitleDownload download;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final face = downloadButtonFace(download);
    final task = download.task;
    final done = download.file != null;
    return AppTooltip(
      message: face.label,
      child: FocusableSurface(
        onPressed: onPressed,
        borderRadius: context.tokens.radii.smAll,
        semanticLabel: face.label,
        builder: (context, states) => Container(
          width: context.tokens.spacing.s32,
          height: context.tokens.spacing.s32,
          decoration: BoxDecoration(
            color: states.highlighted
                ? colors.surface2
                : colors.surface2.withValues(alpha: 0),
            borderRadius: context.tokens.radii.smAll,
            border: Border.all(color: colors.border),
          ),
          alignment: Alignment.center,
          child: task != null && task.progress != null
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: task.progress,
                    strokeWidth: 2,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation(colors.accentBase),
                  ),
                )
              : AppIcon(
                  face.icon,
                  size: 16,
                  color: done
                      ? colors.success
                      : task != null
                      ? colors.accentBase
                      : colors.textSecondary,
                ),
        ),
      ),
    );
  }
}

/// The artwork behind a page: the backdrop, or the poster blurred when
/// there is none (docs/05), under the canvas's gradients. [fadeRight] fades
/// it into the page on the right too (a series' left column).
///
/// [cheapBlur] (a TV, docs/07: no blur filters on its small GPU) decodes
/// the poster a few pixels wide and lets the scaling soften it, instead
/// of a full-screen blur.
class DetailsBackdrop extends StatelessWidget {
  const new({
    required this.backdropUrl,
    required this.posterUrl,
    this.fadeRight = false,
    this.cheapBlur = false,
    this.hero = false,
    super.key,
  });

  final String? backdropUrl;
  final String? posterUrl;
  final bool fadeRight;
  final bool cheapBlur;

  /// Across the top of a stacked page ([detailsStacked]): the picture
  /// whole, fading into the page at its foot, a little darker at its top
  /// for the ‹ Back chip.
  final bool hero;

  /// [cheapBlur]'s poster width, in logical pixels.
  static const _softWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final size = MediaQuery.sizeOf(context);
    final backdrop = artworkFor(context, backdropUrl, width: size.width);
    final poster = backdrop == null
        ? artworkFor(
            context,
            posterUrl,
            width: cheapBlur ? _softWidth : size.width / 4,
          )
        : null;
    final picture = backdrop ?? poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.surface1),
        if (picture != null)
          ImageFiltered(
            enabled: backdrop == null && !cheapBlur,
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: ArtworkImage(
              image: picture,
              fallback: const SizedBox.shrink(),
            ),
          ),
        if (hero)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.bg.withValues(alpha: 0.55),
                  colors.bg.withValues(alpha: 0),
                ],
                stops: const [0, 0.35],
              ),
            ),
          )
        else
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
              stops: [0, if (hero) 0.6 else 0.45],
            ),
          ),
        ),
      ],
    );
  }
}

/// The top of a stacked title's page ([detailsStacked], ADR-068): the
/// backdrop across the page, 16:9 (lower on a phone on its side), the
/// poster over its foot beside the [overline], the title and its [meta]
/// line; then [below] (the actions, the plot), the page's width.
class DetailsStackedHero extends StatelessWidget {
  const new({
    required this.title,
    required this.backdropUrl,
    required this.posterUrl,
    required this.meta,
    required this.below,
    this.overline,
    this.cheapBlur = false,
    super.key,
  });

  final String title;
  final String? backdropUrl;
  final String? posterUrl;
  final Widget? overline;
  final Widget meta;
  final List<Widget> below;
  final bool cheapBlur;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final window = MediaQuery.sizeOf(context);
        // A phone's poster and title; a tablet held upright has room for
        // larger ones.
        final small = CompactLayout.fits(Size(width, window.height));
        final poster = tokens.details.moviePoster * (small ? 0.4 : 2 / 3);
        final side = small ? spacing.s16 : spacing.s32;
        final heroHeight = math.min(width * 9 / 16, window.height * _heroShare);
        // The poster's top over the backdrop's foot, clear of ‹ Back.
        final posterTop = math.max(
          heroHeight - poster.height * 0.6,
          spacing.s12 * 2 + CompactLayout.touchTarget,
        );
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight,
              child: DetailsBackdrop(
                backdropUrl: backdropUrl,
                posterUrl: posterUrl,
                cheapBlur: cheapBlur,
                hero: true,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(side, posterTop, side, spacing.s32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DetailsPoster(title: title, url: posterUrl, size: poster),
                      SizedBox(width: spacing.s16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (overline case final overline?) ...[
                              overline,
                              SizedBox(height: spacing.s8),
                            ],
                            Text(
                              title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (small ? tokens.text.h1 : tokens.text.display)
                                      .copyWith(color: colors.textPrimary),
                            ),
                            SizedBox(height: spacing.s8),
                            meta,
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.s20),
                  ...below,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The backdrop's height at most, of the window's: a phone on its side
  /// still shows the title under it.
  static const _heroShare = 0.45;
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
    this.more = const [],
    this.badges = const [],
    this.watched = false,
    super.key,
  });

  final int? year;
  final double? rating;
  final String? genre;
  final String? runtime;

  /// More of the line, in order: a file's "1080p", "H.264", "AC-3 5.1".
  final List<String> more;
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
      for (final part in more) Text(part, style: style),
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

class DetailsPageLoading extends StatelessWidget {
  const new({super.key});

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

class DetailsGone extends StatelessWidget {
  const new({required this.message, super.key});

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
