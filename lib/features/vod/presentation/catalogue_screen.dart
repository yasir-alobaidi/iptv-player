import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';
import 'package:iptv_player/features/vod/presentation/title_cards.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';
import 'package:iptv_player/features/vod/presentation/vod_text.dart';

/// Movies or Series (canvas `Movies`; docs/05: Series uses the same grid):
/// the heading and its count, a filter and the sort (Recently added /
/// Name / Rating), the category chips in the user's order with More ▾ for
/// the rest, and the poster grid. Enter opens a title's page.
class CatalogueScreen extends ConsumerStatefulWidget {
  const new({required this.kind, super.key});

  /// [CatalogueKind.movie] or [CatalogueKind.series].
  final CatalogueKind kind;

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final _grid = FocusPaneController();
  final _chips = FocusPaneController();
  final _filter = TextEditingController();

  CatalogueKind get kind => widget.kind;

  @override
  void dispose() {
    _grid.dispose();
    _chips.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _clearFilter() {
    _filter.clear();
    ref.read(catalogueControllerProvider(kind).notifier).setText('');
  }

  void _open(Object item) {
    final path = switch (item) {
      final MovieItem movie => movieDetailsPath(movie),
      final SeriesItem series => seriesDetailsPath(series),
      _ => null,
    };
    if (path != null) unawaited(context.push(path));
  }

  Future<void> _toggleFavorite(Object item) async {
    switch (item) {
      case final MovieItem movie:
        await ref
            .read(movieRepositoryProvider)
            .setFavorite(movie, on: !movie.isFavorite);
      case final SeriesItem series:
        await ref
            .read(seriesRepositoryProvider)
            .setFavorite(series, on: !series.isFavorite);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final source = ref.watch(currentSourceProvider);
    if (source == null) {
      return FocusPane(
        debugLabel: 'screen-${kind.name}',
        child: EmptyState(
          icon: kind == CatalogueKind.series
              ? AppIcons.series
              : AppIcons.movies,
          title: 'No ${titlesWord(kind)} yet',
          message: 'Add your provider to see its ${titlesWord(kind)} here.',
          actionLabel: 'Add a source',
          onAction: () => context.push(addSourceRoutePath),
        ),
      );
    }
    final query = ref.watch(catalogueControllerProvider(kind));
    if (query == null) return const SizedBox.shrink();
    final count = ref.watch(titleCountProvider(kind, query));
    return FocusPane(
      debugLabel: 'screen-${kind.name}',
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.s32 - tokens.spacing.s8,
          tokens.spacing.s20,
          tokens.spacing.s32 - tokens.spacing.s8,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8),
              child: _Header(
                kind: kind,
                query: query,
                count: count.value?.count,
                filter: _filter,
              ),
            ),
            SizedBox(height: tokens.spacing.s16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8),
              child: _CategoryChips(
                kind: kind,
                query: query,
                controller: _chips,
                onDown: _grid.focusPane,
              ),
            ),
            SizedBox(height: tokens.spacing.s12),
            Expanded(child: _body(context, query, count)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    TitleQuery query,
    AsyncValue<TitleCount> count,
  ) {
    if (count.hasError) {
      return ErrorState(
        compact: true,
        title: "Couldn't load your ${titlesWord(kind)}",
        message: 'The list could not be read.',
        details: '${count.error}',
        onRetry: () => ref.invalidate(titleCountProvider(kind, query)),
      );
    }
    final counted = count.value;
    if (counted == null) return const _SkeletonGrid();
    final total = counted.count;
    if (total == 0) return _empty(query);
    final movies = ref.read(movieRepositoryProvider);
    final series = ref.read(seriesRepositoryProvider);
    final now = ref.watch(appClockProvider)();
    return TitleGrid<Object>(
      key: ValueKey(kind),
      total: total,
      controller: _grid,
      query: query,
      revision: counted.revision,
      identity: (item) => switch (item) {
        final MovieItem movie => ('movie', movie.sourceId, movie.remoteKey),
        final SeriesItem series => (
          'series',
          series.sourceId,
          series.remoteKey,
        ),
        _ => item,
      },
      load: (offset, limit) async => kind == CatalogueKind.series
          ? await series.range(query, offset, limit)
          : await movies.range(query, offset, limit),
      onFavorite: (item) => unawaited(_toggleFavorite(item)),
      card: (context, item, focus, width) => switch (item) {
        final MovieItem movie => MovieCard(
          movie: movie,
          focus: focus,
          width: width,
          now: now,
          onOpen: () => _open(movie),
          onMenu: (anchor) => unawaited(_menu(anchor, movie)),
        ),
        final SeriesItem show => SeriesCard(
          series: show,
          focus: focus,
          width: width,
          now: now,
          onOpen: () => _open(show),
          onMenu: (anchor) => unawaited(_menu(anchor, show)),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _empty(TitleQuery query) {
    final word = titlesWord(kind);
    final text = query.text.trim();
    if (text.isNotEmpty) {
      return EmptyState(
        compact: true,
        icon: AppIcons.search,
        title: 'No $word match "$text"',
        actionLabel: 'Clear filter',
        onAction: _clearFilter,
      );
    }
    final syncing = ref.watch(syncStatusProvider(query.sourceId)).value;
    if (syncing is SyncRunning) {
      return EmptyState(
        compact: true,
        icon: AppIcons.loading,
        title: 'Getting your $word…',
        message: 'They show here as soon as the sync has them.',
      );
    }
    final notifier = ref.read(catalogueControllerProvider(kind).notifier);
    return switch (query.filter) {
      FavoriteTitles() => EmptyState(
        compact: true,
        icon: AppIcons.star,
        title: kind == CatalogueKind.series
            ? 'No favorite series yet'
            : 'No favorite movies yet',
        message: 'Press F on a poster to add it here.',
      ),
      AllTitles() => EmptyState(
        compact: true,
        icon: kind == CatalogueKind.series ? AppIcons.series : AppIcons.movies,
        title: "Your provider doesn't offer $word",
        message: 'Many playlists hold live channels only.',
      ),
      _ => EmptyState(
        compact: true,
        icon: kind == CatalogueKind.series ? AppIcons.series : AppIcons.movies,
        title: 'No $word in this category.',
        actionLabel: 'Show all $word',
        onAction: () => notifier.showFilter(const AllTitles()),
      ),
    };
  }

  Future<void> _menu(BuildContext anchor, Object item) {
    final favorite = switch (item) {
      final MovieItem movie => movie.isFavorite,
      final SeriesItem series => series.isFavorite,
      _ => false,
    };
    return showAppMenu(
      anchor,
      items: [
        AppMenuItem(
          label: 'Open',
          icon: AppIcons.info,
          onPressed: () => _open(item),
        ),
        AppMenuItem(
          label: favorite ? 'Remove from favorites' : 'Add to favorites',
          icon: favorite ? AppIcons.starFilled : AppIcons.star,
          shortcut: 'F',
          onPressed: () => unawaited(_toggleFavorite(item)),
        ),
      ],
    );
  }
}

/// "All movies · 8,021 movies", the filter and the sort (canvas).
class _Header extends ConsumerWidget {
  const new({
    required this.kind,
    required this.query,
    required this.count,
    required this.filter,
  });

  final CatalogueKind kind;
  final TitleQuery query;
  final int? count;
  final TextEditingController filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final notifier = ref.read(catalogueControllerProvider(kind).notifier);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _headingFor(ref, kind, query),
          overflow: TextOverflow.ellipsis,
          style: tokens.text.h3
              .withWeight(700)
              .copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: tokens.spacing.s4 - 2),
        Text(
          count == null ? ' ' : titleCountLabel(kind, count!),
          style: tokens.text.labelSmall.copyWith(color: colors.textTertiary),
        ),
      ],
    );
    final search = SearchField(
      controller: filter,
      hint: 'Filter ${titlesWord(kind)}',
      shortcut: null,
      width: 220,
      onChanged: notifier.setText,
    );
    final sort = SegmentedControl<TitleSort>(
      options: const [
        SegmentOption(value: TitleSort.recentlyAdded, label: 'Recently added'),
        SegmentOption(value: TitleSort.name, label: 'Name'),
        SegmentOption(value: TitleSort.rating, label: 'Rating'),
      ],
      value: query.sort,
      onChanged: notifier.setSort,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow: the filter and the sort go under the heading.
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              SizedBox(height: tokens.spacing.s12),
              Row(
                children: [
                  Expanded(child: search),
                  SizedBox(width: tokens.spacing.s12),
                  sort,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            SizedBox(width: tokens.spacing.s12),
            search,
            SizedBox(width: tokens.spacing.s12),
            sort,
          ],
        );
      },
    );
  }
}

String _headingFor(WidgetRef ref, CatalogueKind kind, TitleQuery query) =>
    switch (query.filter) {
      AllTitles() => allTitlesHeading(kind),
      FavoriteTitles() => 'Favorites',
      UncategorizedTitles() => 'Uncategorized',
      CategoryTitles(:final categoryId) =>
        ref
                .watch(categoryListProvider(query.sourceId, kind))
                .value
                ?.categories
                .where((c) => c.id == categoryId)
                .firstOrNull
                ?.name ??
            allTitlesHeading(kind),
    };

/// All, Favorites, the visible categories in the user's order and
/// Uncategorized, in one row that scrolls sideways; More ▾ lists them all.
/// One Tab stop; ←/→ inside, ↓ into the grid.
class _CategoryChips extends ConsumerWidget {
  const new({
    required this.kind,
    required this.query,
    required this.controller,
    required this.onDown,
  });

  final CatalogueKind kind;
  final TitleQuery query;
  final FocusPaneController controller;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final notifier = ref.read(catalogueControllerProvider(kind).notifier);
    final list = ref.watch(categoryListProvider(query.sourceId, kind)).value;
    final choices = <(String, TitleFilter)>[
      ('All', const AllTitles()),
      ('Favorites', const FavoriteTitles()),
      for (final category in list?.categories ?? const <CategoryChoice>[])
        if (!category.isHidden) (category.name, CategoryTitles(category.id)),
      if ((list?.uncategorized ?? 0) > 0)
        ('Uncategorized', const UncategorizedTitles()),
    ];
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.arrowDown): onDown},
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: FocusPane(
                debugLabel: '${kind.name} categories',
                controller: controller,
                tabStop: true,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.all(tokens.spacing.s4 - 1),
                  itemCount: choices.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: tokens.spacing.s8),
                  itemBuilder: (context, index) {
                    final (label, filter) = choices[index];
                    return AppChip(
                      label: label,
                      selected: query.filter == filter,
                      onPressed: () => notifier.showFilter(filter),
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.s8),
            Builder(
              builder: (anchor) => AppChip(
                label: 'More',
                icon: AppIcons.chevronDown,
                onPressed: () => unawaited(
                  showAppMenu(
                    anchor,
                    items: [
                      for (final (label, filter) in choices)
                        AppMenuItem(
                          label: label,
                          checked: query.filter == filter,
                          onPressed: () => notifier.showFilter(filter),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The canvas's skeleton cards, while the count is read.
class _SkeletonGrid extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + TitleGrid.columnGap) /
                    (TitleGrid.minCardWidth + TitleGrid.columnGap))
                .floor()
                .clamp(1, 12);
        final width =
            (constraints.maxWidth -
                tokens.spacing.s8 * 2 -
                TitleGrid.columnGap * (columns - 1)) /
            columns;
        return Padding(
          padding: EdgeInsets.all(tokens.spacing.s8),
          child: Wrap(
            spacing: TitleGrid.columnGap,
            runSpacing: TitleGrid.rowGap,
            clipBehavior: Clip.hardEdge,
            children: [
              for (var i = 0; i < columns * 2; i++)
                SkeletonPoster(width: width),
            ],
          ),
        );
      },
    );
  }
}
