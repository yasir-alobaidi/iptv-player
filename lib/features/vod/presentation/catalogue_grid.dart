import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';
import 'package:iptv_player/features/vod/presentation/title_cards.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';
import 'package:iptv_player/features/vod/presentation/vod_text.dart';

/// The poster grid of a [TitleQuery], with its loading, error and empty
/// states: Movies' and Series' body, and Favorites' Movies and Series
/// tabs. Enter opens a title's page, F toggles its favorite, the menu key
/// has Open and the favorite.
class CatalogueGrid extends ConsumerWidget {
  const new({
    required this.kind,
    required this.query,
    required this.count,
    required this.controller,
    required this.empty,
    this.onOpen,
    super.key,
  });

  final CatalogueKind kind;
  final TitleQuery query;

  /// The query's count ([titleCountProvider]), which the owner shows too.
  final AsyncValue<TitleCount> count;
  final FocusPaneController controller;

  /// What shows when the query has nothing.
  final Widget Function() empty;

  /// Opens a title's page at the path given; by default pushed in the
  /// current branch.
  final void Function(String path)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    if (total == 0) return empty();
    final movies = ref.read(movieRepositoryProvider);
    final series = ref.read(seriesRepositoryProvider);
    final now = ref.watch(appClockProvider)();
    return TitleGrid<Object>(
      key: ValueKey(kind),
      total: total,
      controller: controller,
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
      onFavorite: (item) => unawaited(_toggleFavorite(ref, item)),
      card: (context, item, focus, width) => switch (item) {
        final MovieItem movie => MovieCard(
          movie: movie,
          focus: focus,
          width: width,
          now: now,
          onOpen: () => _open(context, movie),
          onMenu: (anchor) => unawaited(_menu(context, ref, anchor, movie)),
        ),
        final SeriesItem show => SeriesCard(
          series: show,
          focus: focus,
          width: width,
          now: now,
          onOpen: () => _open(context, show),
          onMenu: (anchor) => unawaited(_menu(context, ref, anchor, show)),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  void _open(BuildContext context, Object item) {
    final path = switch (item) {
      final MovieItem movie => movieDetailsPath(movie),
      final SeriesItem series => seriesDetailsPath(series),
      _ => null,
    };
    if (path == null) return;
    final open = onOpen;
    if (open != null) {
      open(path);
    } else {
      unawaited(context.push(path));
    }
  }

  Future<void> _toggleFavorite(WidgetRef ref, Object item) async {
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

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    BuildContext anchor,
    Object item,
  ) {
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
          onPressed: () => _open(context, item),
        ),
        AppMenuItem(
          label: favorite ? 'Remove from favorites' : 'Add to favorites',
          icon: favorite ? AppIcons.starFilled : AppIcons.star,
          shortcut: 'F',
          onPressed: () => unawaited(_toggleFavorite(ref, item)),
        ),
      ],
    );
  }
}

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
