import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogue_state.g.dart';

/// The sort a Movies or Series grid was left on, for the session: coming
/// back to a grid finds it as it was (docs/05).
@Riverpod(keepAlive: true)
class CatalogueSort extends _$CatalogueSort {
  @override
  TitleSort build(CatalogueKind kind) => TitleSort.recentlyAdded;

  TitleSort get sort => state;

  set sort(TitleSort value) => state = value;
}

/// What a Movies or Series grid shows: the browsed source's titles, one
/// category or all, a filter and the sort. Starts over when the source
/// changes; the sort stays.
@riverpod
class CatalogueController extends _$CatalogueController {
  @override
  TitleQuery? build(CatalogueKind kind) {
    final source = ref.watch(currentSourceProvider);
    if (source == null) return null;
    return TitleQuery(
      sourceId: source.id,
      sort: ref.read(catalogueSortProvider(kind)),
    );
  }

  /// Shows [filter]'s titles; the filter text resets.
  void showFilter(TitleFilter filter) {
    final query = state;
    if (query == null || query.filter == filter) return;
    state = query.copyWith(filter: filter, text: '');
  }

  void setText(String text) {
    final query = state;
    if (query == null || query.text == text) return;
    state = query.copyWith(text: text);
  }

  void setSort(TitleSort sort) {
    final query = state;
    if (query == null) return;
    ref.read(catalogueSortProvider(kind).notifier).sort = sort;
    state = query.copyWith(sort: sort);
  }
}

/// How many titles a query matches, live, and a revision that moves on
/// every change: a favorite or a watch mark changes what a card shows and
/// not the count, and the grid must read its window again for it.
@immutable
final class TitleCount {
  const new(this.count, this.revision);

  final int count;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is TitleCount && other.count == count && other.revision == revision;

  @override
  int get hashCode => Object.hash(count, revision);
}

@riverpod
Stream<TitleCount> titleCount(Ref ref, CatalogueKind kind, TitleQuery query) {
  var revision = 0;
  final counts = kind == CatalogueKind.series
      ? ref.watch(seriesRepositoryProvider).watchCount(query)
      : ref.watch(movieRepositoryProvider).watchCount(query);
  return counts.map((count) => TitleCount(count, revision++));
}
