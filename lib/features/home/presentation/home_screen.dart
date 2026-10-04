import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/home/presentation/home_rows.dart';
import 'package:iptv_player/features/home/presentation/home_state.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_menu.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';
import 'package:iptv_player/features/vod/presentation/title_cards.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';

/// Home (canvas `Home`; Phase 5 decision 5): Continue watching, Favorite
/// channels, Recently watched channels, Recently added movies and
/// Recently added series — each only when it has something — and, until
/// anything was watched, the first-run hero in front of them.
///
/// Each row is one Tab stop: ←/→ within it, ↑/↓ to the nearest card of
/// the next row. Enter plays a Continue card or a channel (full screen),
/// or opens a poster's page; F toggles a favorite; the menu key has the
/// rest.
class HomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// The canvas's rows at 1440 px: cards across and the gap between.
  static const continueAcross = 4;
  static const continueGap = 24.0;
  static const channelsAcross = 5;
  static const channelsGap = 16.0;
  static const postersAcross = 8;
  static const postersGap = 20.0;

  /// Under a card's picture: the gap, the title and the line under it.
  static const captionHeight = 56.0;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum _Row { continueWatching, favorites, recentChannels, movies, series }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<_Row, HomeRowController> _rows = {
    for (final row in _Row.values) row: HomeRowController(),
  };
  final _hero = FocusNode(debugLabel: 'home hero', skipTraversal: true);
  bool _marked = false;

  /// The rows on screen now, top to bottom, for the arrow keys.
  List<HomeRowController> _shown = const [];

  @override
  void dispose() {
    for (final row in _rows.values) {
      row.dispose();
    }
    _hero.dispose();
    super.dispose();
  }

  // ── What Enter, F and the menu do.

  void _resume(ContinueItem item) {
    final launcher = ref.read(vodLauncherProvider);
    switch (item) {
      case ContinueMovie(:final movie, :final mark):
        unawaited(launcher.playMovie(movie, from: mark.position));
      case ContinueEpisode(:final series, :final episode, :final mark):
        unawaited(launcher.playEpisode(series, episode, from: mark?.position));
      case ContinueLibraryFile(:final item, :final mark):
        unawaited(launcher.playLibraryItem(item, from: mark.position));
    }
  }

  /// A channel full screen, as Enter does in Live TV; back on Home the
  /// stream stops (Home shows no picture).
  Future<void> _watch(ChannelItem channel, ChannelQuery zapThrough) async {
    final coordinator = ref.read(playbackCoordinatorProvider);
    unawaited(coordinator.playLive(channel));
    await context.push<void>(playerRoutePath, extra: zapThrough);
    if (coordinator.current != null) unawaited(coordinator.stop());
  }

  Future<void> _toggleChannel(ChannelItem channel) => ref
      .read(channelRepositoryProvider)
      .setFavorite(channel, on: !channel.isFavorite);

  Future<void> _toggleMovie(MovieItem movie) => ref
      .read(movieRepositoryProvider)
      .setFavorite(movie, on: !movie.isFavorite);

  Future<void> _toggleSeries(SeriesItem series) => ref
      .read(seriesRepositoryProvider)
      .setFavorite(series, on: !series.isFavorite);

  Future<void> _continueMenu(BuildContext anchor, ContinueItem item) =>
      showAppMenu(
        anchor,
        items: [
          AppMenuItem(
            label: 'Remove from Continue watching',
            icon: AppIcons.close,
            onPressed: () =>
                unawaited(ref.read(watchProgressProvider).dismiss(item)),
          ),
          if (item case ContinueEpisode(:final series))
            AppMenuItem(
              label: 'Go to series',
              icon: AppIcons.series,
              onPressed: () => context.go(seriesDetailsPath(series)),
            ),
        ],
      );

  Future<void> _channelMenu(BuildContext anchor, ChannelItem channel) =>
      showChannelMenu(
        anchor,
        ref,
        channel,
        onFavorite: () => unawaited(_toggleChannel(channel)),
      );

  Future<void> _titleMenu(BuildContext anchor, Object title) {
    final (favorite, open, toggle) = switch (title) {
      final MovieItem movie => (
        movie.isFavorite,
        () => context.go(movieDetailsPath(movie)),
        () => _toggleMovie(movie),
      ),
      final SeriesItem series => (
        series.isFavorite,
        () => context.go(seriesDetailsPath(series)),
        () => _toggleSeries(series),
      ),
      _ => throw ArgumentError.value(title),
    };
    return showAppMenu(
      anchor,
      items: [
        AppMenuItem(label: 'Open', icon: AppIcons.info, onPressed: open),
        AppMenuItem(
          label: favorite ? 'Remove from favorites' : 'Add to favorites',
          icon: favorite ? AppIcons.starFilled : AppIcons.star,
          shortcut: 'F',
          onPressed: () => unawaited(toggle()),
        ),
      ],
    );
  }

  // ── See all: the screen that lists the same thing.

  /// Live TV on Favorites. Its view is made when the screen is, so the
  /// filter is set once it is up.
  void _seeFavorites() {
    context.go(AppDestination.liveTv.path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(liveTvControllerProvider.notifier)
          .showFilter(const FavoriteChannels());
    });
  }

  /// Movies or Series, all of them, Recently added first.
  void _seeRecent(CatalogueKind kind) {
    ref.read(catalogueSortProvider(kind).notifier).sort =
        TitleSort.recentlyAdded;
    context.go(
      kind == CatalogueKind.series
          ? AppDestination.series.path
          : AppDestination.movies.path,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(catalogueControllerProvider(kind).notifier)
        ..showFilter(const AllTitles())
        ..setSort(TitleSort.recentlyAdded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(currentSourceProvider);
    if (source == null) {
      return FocusPane(
        debugLabel: 'screen-home',
        child: EmptyState(
          icon: AppIcons.home,
          title: 'Nothing here yet',
          message:
              'Add your provider, and what you watch and what is new shows '
              'here.',
          actionLabel: 'Add a source',
          onAction: () => context.push(addSourceRoutePath),
        ),
      );
    }
    final id = source.id;
    final continuing = ref.watch(continueWatchingProvider);
    final favorites = ref.watch(homeFavoriteChannelsProvider(id));
    final recent = ref.watch(homeRecentChannelsProvider(id));
    final movies = ref.watch(homeRecentMoviesProvider(id));
    final series = ref.watch(homeRecentSeriesProvider(id));
    final watched = ref.watch(watchedAnythingProvider);
    final syncing = ref.watch(syncStatusProvider(id)).value is SyncRunning;
    final all = <AsyncValue<Object>>[
      continuing,
      favorites,
      recent,
      movies,
      series,
      watched,
    ];

    final Widget body;
    if (all.firstWhere((a) => a.hasError, orElse: () => continuing)
        case AsyncValue(:final error?)) {
      body = ErrorState(
        title: "Home couldn't load",
        message: 'What you were watching and what is new could not be read.',
        details: '$error',
        onRetry: () {
          ref
            ..invalidate(continueWatchingProvider)
            ..invalidate(homeFavoriteChannelsProvider(id))
            ..invalidate(homeRecentChannelsProvider(id))
            ..invalidate(homeRecentMoviesProvider(id))
            ..invalidate(homeRecentSeriesProvider(id))
            ..invalidate(watchedAnythingProvider);
        },
      );
    } else if (all.any((a) => !a.hasValue)) {
      body = const _Loading();
    } else {
      _markShown();
      body = _content(
        source,
        continuing: continuing.requireValue,
        favorites: favorites.requireValue,
        recent: recent.requireValue,
        movies: movies.requireValue,
        series: series.requireValue,
        firstRun: !watched.requireValue,
        syncing: syncing,
      );
    }
    return FocusPane(debugLabel: 'screen-home', child: body);
  }

  /// The launch's first Home with its rows: the end of a cold start.
  void _markShown() {
    if (_marked) return;
    _marked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(launchMarkProvider).homeShown();
    });
  }

  /// The hero leaves once something was watched. A screen coming back into
  /// view shows what it had until its data catches up, so the shell may
  /// just have put the focus on the hero: it goes to the first card
  /// instead of nowhere.
  void _handOffFromHero({required bool firstRun}) {
    if (firstRun || !_hero.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _shown.isNotEmpty) _shown.first.focus(0);
    });
  }

  Widget _content(
    Source source, {
    required List<ContinueItem> continuing,
    required List<ChannelItem> favorites,
    required List<ChannelItem> recent,
    required List<MovieItem> movies,
    required List<SeriesItem> series,
    required bool firstRun,
    required bool syncing,
  }) {
    final tokens = context.tokens;
    final nothingYet =
        favorites.isEmpty && recent.isEmpty && movies.isEmpty && series.isEmpty;
    final rows = <_Row>[
      if (continuing.isNotEmpty) _Row.continueWatching,
      if (favorites.isNotEmpty) _Row.favorites,
      if (recent.isNotEmpty) _Row.recentChannels,
      if (movies.isNotEmpty) _Row.movies,
      if (series.isNotEmpty) _Row.series,
    ];
    _shown = [for (final row in rows) _rows[row]!];
    _handOffFromHero(firstRun: firstRun);
    if (rows.isEmpty && !firstRun && !syncing) {
      return EmptyState(
        icon: AppIcons.home,
        title: 'Nothing here yet',
        message:
            'Favorite channels, what you watch and what your provider adds '
            'show here.',
        actionLabel: 'Open Live TV',
        onAction: () => context.go(AppDestination.liveTv.path),
      );
    }
    final inset = HomeRow.inset(tokens);
    final side = tokens.spacing.s32 - inset;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - tokens.spacing.s32 * 2;
        double across(int count, double gap) =>
            (width - gap * (count - 1)) / count;
        final continueWidth = across(
          HomeScreen.continueAcross,
          HomeScreen.continueGap,
        );
        final tileWidth = across(
          HomeScreen.channelsAcross,
          HomeScreen.channelsGap,
        );
        final posterWidth = across(
          HomeScreen.postersAcross,
          HomeScreen.postersGap,
        );
        final now = ref.watch(appClockProvider)();
        final sections = <Widget>[
          if (firstRun)
            Padding(
              key: const ValueKey('hero'),
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Focus(
                focusNode: _hero,
                canRequestFocus: false,
                child: _Hero(source: source),
              ),
            ),
          if (syncing && nothingYet)
            Padding(
              key: const ValueKey('syncing'),
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: const _GettingCatalogue(),
            ),
          // Keyed, so a row appearing above another keeps its cards, and
          // the keyboard's focus in them.
          for (final row in rows)
            KeyedSubtree(
              key: ValueKey(row),
              child: switch (row) {
                _Row.continueWatching => HomeRow(
                  title: 'Continue watching',
                  controller: _rows[row]!,
                  count: continuing.length,
                  cardWidth: continueWidth,
                  cardHeight: continueWidth * 9 / 16 + HomeScreen.captionHeight,
                  gap: HomeScreen.continueGap,
                  card: (context, i, focus) =>
                      _continueCard(continuing[i], focus, continueWidth),
                ),
                _Row.favorites => _ChannelRow(
                  title: 'Favorite channels',
                  channels: favorites,
                  controller: _rows[row]!,
                  width: tileWidth,
                  onSeeAll: _seeFavorites,
                  onWatch: (channel) => unawaited(
                    _watch(
                      channel,
                      ChannelQuery(
                        sourceId: source.id,
                        filter: const FavoriteChannels(),
                      ),
                    ),
                  ),
                  onToggle: _toggleChannel,
                  onMenu: _channelMenu,
                ),
                _Row.recentChannels => _ChannelRow(
                  title: 'Recently watched channels',
                  channels: recent,
                  controller: _rows[row]!,
                  width: tileWidth,
                  onWatch: (channel) => unawaited(
                    _watch(channel, ChannelQuery(sourceId: source.id)),
                  ),
                  onToggle: _toggleChannel,
                  onMenu: _channelMenu,
                ),
                _Row.movies => HomeRow(
                  title: 'Recently added movies',
                  controller: _rows[row]!,
                  count: movies.length,
                  cardWidth: posterWidth,
                  cardHeight: posterWidth * 3 / 2 + HomeScreen.captionHeight,
                  gap: HomeScreen.postersGap,
                  onSeeAll: () => _seeRecent(CatalogueKind.movie),
                  card: (context, i, focus) => _favoriteKey(
                    () => _toggleMovie(movies[i]),
                    MovieCard(
                      movie: movies[i],
                      focus: focus,
                      width: posterWidth,
                      now: now,
                      onOpen: () => context.go(movieDetailsPath(movies[i])),
                      onMenu: (anchor) =>
                          unawaited(_titleMenu(anchor, movies[i])),
                    ),
                  ),
                ),
                _Row.series => HomeRow(
                  title: 'Recently added series',
                  controller: _rows[row]!,
                  count: series.length,
                  cardWidth: posterWidth,
                  cardHeight: posterWidth * 3 / 2 + HomeScreen.captionHeight,
                  gap: HomeScreen.postersGap,
                  onSeeAll: () => _seeRecent(CatalogueKind.series),
                  card: (context, i, focus) => _favoriteKey(
                    () => _toggleSeries(series[i]),
                    SeriesCard(
                      series: series[i],
                      focus: focus,
                      width: posterWidth,
                      now: now,
                      onOpen: () => context.go(seriesDetailsPath(series[i])),
                      onMenu: (anchor) =>
                          unawaited(_titleMenu(anchor, series[i])),
                    ),
                  ),
                ),
              },
            ),
        ];
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) => homeArrowKey(event, _shown, above: _hero),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              side,
              tokens.spacing.s24 - inset,
              side,
              tokens.spacing.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, section) in sections.indexed) ...[
                  if (i > 0) SizedBox(height: tokens.spacing.s32 - inset * 2),
                  section,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _continueCard(ContinueItem item, FocusNode focus, double width) {
    final (title, image, line, progress, toggle) = switch (item) {
      ContinueMovie(:final movie, :final mark, :final backdropUrl) => (
        movie.name,
        backdropUrl ?? movie.posterUrl,
        [
          'Movie',
          if (mark.remaining case final left? when left > Duration.zero)
            formatTimeLeft(left),
        ].join(' · '),
        mark.fraction,
        () => _toggleMovie(movie),
      ),
      ContinueEpisode(:final series, :final episode, :final mark) => (
        series.name,
        episode.stillUrl ?? series.backdropUrl ?? series.posterUrl,
        [
          'S${episode.season} · E${episode.episode}',
          switch (mark?.remaining) {
            final left? when left > Duration.zero => formatTimeLeft(left),
            _ when mark == null => 'Up next',
            _ => null,
          },
        ].nonNulls.join(' · '),
        mark?.fraction,
        () => _toggleSeries(series),
      ),
      ContinueLibraryFile(:final item, :final mark) => (
        item.showTitle ?? item.title,
        null,
        [
          switch (item.kind) {
            LibraryKind.episode =>
              'S${item.season ?? 1} · E${item.episode ?? 1}',
            LibraryKind.movie => 'Movie',
            LibraryKind.unsorted => 'Video',
          },
          if (mark.remaining case final left? when left > Duration.zero)
            formatTimeLeft(left),
        ].join(' · '),
        mark.fraction,
        () => ref.read(libraryFavoritesProvider).toggle(item),
      ),
    };
    return _favoriteKey(
      toggle,
      Builder(
        builder: (anchor) => LandscapeCard(
          title: title,
          image: artworkFor(anchor, image, width: width),
          subtitle: line,
          progress: progress,
          width: width,
          focusNode: focus,
          onPressed: () => _resume(item),
          onMenu: () => unawaited(_continueMenu(anchor, item)),
        ),
      ),
    );
  }
}

/// F on a card toggles its favorite.
Widget _favoriteKey(Future<void> Function() toggle, Widget card) =>
    CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            unawaited(toggle()),
      },
      child: card,
    );

/// A row of channel tiles, each with what is on now: warmed from the
/// guide in one lookup, and moved on every minute.
class _ChannelRow extends ConsumerStatefulWidget {
  const new({
    required this.title,
    required this.channels,
    required this.controller,
    required this.width,
    required this.onWatch,
    required this.onToggle,
    required this.onMenu,
    this.onSeeAll,
  });

  final String title;
  final List<ChannelItem> channels;
  final HomeRowController controller;
  final double width;
  final void Function(ChannelItem channel) onWatch;
  final Future<void> Function(ChannelItem channel) onToggle;
  final Future<void> Function(BuildContext anchor, ChannelItem channel) onMenu;
  final VoidCallback? onSeeAll;

  @override
  ConsumerState<_ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends ConsumerState<_ChannelRow> {
  @override
  void initState() {
    super.initState();
    _warm();
  }

  @override
  void didUpdateWidget(_ChannelRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channels != widget.channels) _warm();
  }

  void _warm() =>
      unawaited(ref.read(guideServiceProvider).warm(widget.channels));

  @override
  Widget build(BuildContext context) => MinuteTicker(
    builder: (context) => HomeRow(
      title: widget.title,
      controller: widget.controller,
      count: widget.channels.length,
      cardWidth: widget.width,
      cardHeight: ChannelTile.height,
      gap: HomeScreen.channelsGap,
      onSeeAll: widget.onSeeAll,
      card: (context, i, focus) {
        final channel = widget.channels[i];
        return _favoriteKey(
          () => widget.onToggle(channel),
          _Tile(
            channel: channel,
            focus: focus,
            width: widget.width,
            onWatch: () => widget.onWatch(channel),
            onMenu: (anchor) => unawaited(widget.onMenu(anchor, channel)),
          ),
        );
      },
    ),
  );
}

class _Tile extends ConsumerWidget {
  const new({
    required this.channel,
    required this.focus,
    required this.width,
    required this.onWatch,
    required this.onMenu,
  });

  final ChannelItem channel;
  final FocusNode focus;
  final double width;
  final VoidCallback onWatch;
  final void Function(BuildContext anchor) onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowNextProvider(channel)).value?.now;
    final at = ref.watch(appClockProvider)();
    return ChannelTile(
      name: channel.name,
      image: artworkFor(context, channel.logoUrl, width: ChannelTile.logoSize),
      programme: now?.title,
      progress: now?.progressAt(at),
      width: width,
      focusNode: focus,
      onPressed: onWatch,
      onMenu: () => onMenu(context),
    );
  }
}

/// The first-run hero (the approved sketch): what the source holds, and
/// the way into it. Open Live TV has the focus.
class _Hero extends ConsumerWidget {
  const new({required this.source});

  final Source source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    int? count(CatalogueKind kind) =>
        ref.watch(homeCountProvider(source.id, kind)).value;
    final channels = count(CatalogueKind.live);
    final movies = count(CatalogueKind.movie);
    final series = count(CatalogueKind.series);
    final line = heroLine(
      channels: channels,
      movies: movies,
      series: series,
      source: source.name,
    );
    final browse = switch ((movies ?? 0, series ?? 0)) {
      (> 0, _) => ('Browse movies', AppDestination.movies.path),
      (_, > 0) => ('Browse series', AppDestination.series.path),
      _ => null,
    };
    return ClipRRect(
      borderRadius: tokens.radii.lgAll,
      child: DecoratedBox(
        // Over the backdrop, which fills the card.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: tokens.radii.lgAll,
        ),
        child: AppBackdrop(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.s40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME',
                  style: tokens.text.overline.copyWith(
                    color: colors.accentBase,
                  ),
                ),
                SizedBox(height: tokens.spacing.s8),
                Text(
                  'Start watching',
                  style: tokens.text.hero.copyWith(color: colors.textPrimary),
                ),
                if (line != null) ...[
                  SizedBox(height: tokens.spacing.s8),
                  Text(
                    line,
                    style: tokens.text.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.s24),
                Wrap(
                  spacing: tokens.spacing.s12,
                  runSpacing: tokens.spacing.s12,
                  children: [
                    AppButton(
                      label: 'Open Live TV',
                      icon: AppIcons.play,
                      size: AppButtonSize.l,
                      onPressed: () => context.go(AppDestination.liveTv.path),
                    ),
                    if (browse case (final label, final path))
                      AppButton(
                        label: label,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.l,
                        onPressed: () => context.go(path),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "12,340 channels, 8,021 movies and 1,204 series from Home provider.";
/// a count of zero is left out, and nothing is said until one is known.
String? heroLine({
  required int? channels,
  required int? movies,
  required int? series,
  required String source,
}) {
  String? part(int? n, String one, String many) => switch (n) {
    null || 0 => null,
    1 => '1 $one',
    final n => '${formatCount(n)} $many',
  };
  final parts = [
    part(channels, 'channel', 'channels'),
    part(movies, 'movie', 'movies'),
    part(series, 'series', 'series'),
  ].nonNulls.toList();
  if (parts.isEmpty) return null;
  final joined = parts.length == 1
      ? parts.single
      : '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';
  return '$joined from $source.';
}

/// A first sync still under way: what has arrived shows below.
class _GettingCatalogue extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const EmptyState(
    compact: true,
    icon: AppIcons.loading,
    title: 'Getting your catalogue…',
    message: 'Channels, movies and series show here as they arrive.',
  );
}

/// Skeleton rows while Home's data is read (hard rule 4).
class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - tokens.spacing.s32 * 2;
        final poster =
            (width - HomeScreen.postersGap * (HomeScreen.postersAcross - 1)) /
            HomeScreen.postersAcross;
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.s32,
            vertical: tokens.spacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var row = 0; row < 3; row++) ...[
                if (row > 0) SizedBox(height: tokens.spacing.s32),
                const Skeleton(width: 220, height: 24),
                SizedBox(height: tokens.spacing.s16),
                Row(
                  children: [
                    for (var i = 0; i < HomeScreen.postersAcross; i++) ...[
                      if (i > 0) const SizedBox(width: HomeScreen.postersGap),
                      SkeletonPoster(width: poster),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
