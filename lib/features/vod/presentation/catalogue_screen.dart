import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/favorites/presentation/favorite_hint.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/sources/presentation/sync_wait.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_grid.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';
import 'package:iptv_player/features/vod/presentation/compact_layout.dart';
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

  /// The filter field's text: what is typed, or what search asked for
  /// ("Show all in Movies"), kept in step with the query.
  final _filter = TextEditingController();

  CatalogueKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _filter.text = ref.read(catalogueControllerProvider(kind))?.text ?? '';
  }

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

  @override
  Widget build(BuildContext context) {
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
    ref.listen(catalogueControllerProvider(kind), (_, next) {
      final text = next?.text ?? '';
      if (_filter.text != text) _filter.text = text;
    });
    if (query == null) return const SizedBox.shrink();
    final count = ref.watch(titleCountProvider(kind, query));
    return FocusPane(
      debugLabel: 'screen-${kind.name}',
      child: LayoutBuilder(
        builder: (context, constraints) => _page(
          context,
          query: query,
          count: count,
          // A phone held upright (ADR-068): the edges closer, the filter
          // and the sort on one line.
          narrow: CompactLayout.narrow(constraints.maxWidth),
          short: CompactLayout.of(context),
        ),
      ),
    );
  }

  Widget _page(
    BuildContext context, {
    required TitleQuery query,
    required AsyncValue<TitleCount> count,
    required bool narrow,
    required bool short,
  }) {
    final tokens = context.tokens;
    final side = narrow
        ? tokens.spacing.s8
        : tokens.spacing.s32 - tokens.spacing.s8;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        side,
        short ? tokens.spacing.s12 : tokens.spacing.s20,
        side,
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
              narrow: narrow,
            ),
          ),
          SizedBox(height: short ? tokens.spacing.s8 : tokens.spacing.s16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8),
            child: _CategoryChips(
              kind: kind,
              query: query,
              controller: _chips,
              onDown: _grid.focusPane,
              touch: short,
            ),
          ),
          SizedBox(height: short ? tokens.spacing.s4 : tokens.spacing.s12),
          Expanded(
            child: FocusLanding(
              on: TvMode.of(context),
              child: CatalogueGrid(
                kind: kind,
                query: query,
                count: count,
                controller: _grid,
                empty: () => _empty(query),
              ),
            ),
          ),
        ],
      ),
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
    if (syncing case SyncRunning(:final progress)) {
      // They show here as soon as the sync has them; meanwhile, how far
      // it has come.
      return SyncWaitStage(
        title: 'Getting your $word…',
        progress: progress,
        waitFor: kind == CatalogueKind.series
            ? SyncWaitFor.series
            : SyncWaitFor.movies,
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
        message: favoriteHint(context, on: 'a poster'),
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
}

/// "All movies · 8,021 movies", the filter and the sort (canvas).
class _Header extends ConsumerWidget {
  const new({
    required this.kind,
    required this.query,
    required this.count,
    required this.filter,
    this.narrow = false,
  });

  final CatalogueKind kind;
  final TitleQuery query;
  final int? count;
  final TextEditingController filter;

  /// A phone held upright: the filter, which says how many there are,
  /// and the sort as a button (its menu has the three), on one line. The
  /// chosen chip says which category shows, the top bar which screen.
  final bool narrow;

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
      options: [
        for (final sort in TitleSort.values)
          SegmentOption(value: sort, label: _sortLabel(sort)),
      ],
      value: query.sort,
      onChanged: notifier.setSort,
    );
    if (narrow) {
      final touch = CompactLayout.touchTarget;
      return Row(
        children: [
          Expanded(
            child: SearchField(
              controller: filter,
              hint: count == null
                  ? 'Filter ${titlesWord(kind)}'
                  : 'Filter ${titleCountLabel(kind, count!)}',
              shortcut: null,
              height: touch,
              onChanged: notifier.setText,
            ),
          ),
          SizedBox(width: tokens.spacing.s8),
          Builder(
            builder: (anchor) => AppIconButton(
              icon: AppIcons.filter,
              tooltip: 'Sort: ${_sortLabel(query.sort)}',
              bordered: true,
              size: touch,
              onPressed: () => unawaited(
                showAppMenu(
                  anchor,
                  items: [
                    for (final sort in TitleSort.values)
                      AppMenuItem(
                        label: _sortLabel(sort),
                        checked: query.sort == sort,
                        onPressed: () => notifier.setSort(sort),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
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

String _sortLabel(TitleSort sort) => switch (sort) {
  TitleSort.recentlyAdded => 'Recently added',
  TitleSort.name => 'Name',
  TitleSort.rating => 'Rating',
};

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
    this.touch = false,
  });

  final CatalogueKind kind;
  final TitleQuery query;
  final FocusPaneController controller;
  final VoidCallback onDown;

  /// A phone's: each chip a finger's target tall, a tap beside it its
  /// own (ADR-068).
  final bool touch;

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
        // The chips' own height and the room their focus ring needs; on a
        // phone, a finger's.
        height: touch
            ? math.max(context.scaled(40), CompactLayout.touchTarget)
            : context.scaled(40),
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
                    final chip = AppChip(
                      label: label,
                      selected: query.filter == filter,
                      onPressed: () => notifier.showFilter(filter),
                    );
                    return touch
                        ? TouchTarget(
                            onTap: () => notifier.showFilter(filter),
                            child: chip,
                          )
                        : chip;
                  },
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.s8),
            Builder(
              builder: (anchor) {
                void more() => unawaited(
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
                );
                final chip = AppChip(
                  label: 'More',
                  icon: AppIcons.chevronDown,
                  onPressed: more,
                );
                return touch ? TouchTarget(onTap: more, child: chip) : chip;
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The canvas's skeleton cards, while the count is read.
