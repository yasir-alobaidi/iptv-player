import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';

/// Which titles a Movies or Series grid shows (docs/05: the category
/// chips).
sealed class TitleFilter {
  const new();
}

/// Every title in a category the user didn't hide, and those in none.
@immutable
final class AllTitles extends TitleFilter {
  const new();

  @override
  bool operator ==(Object other) => other is AllTitles;

  @override
  int get hashCode => 1;
}

/// The favorites, whatever their category.
@immutable
final class FavoriteTitles extends TitleFilter {
  const new();

  @override
  bool operator ==(Object other) => other is FavoriteTitles;

  @override
  int get hashCode => 2;
}

@immutable
final class CategoryTitles extends TitleFilter {
  const new(this.categoryId);

  final int categoryId;

  @override
  bool operator ==(Object other) =>
      other is CategoryTitles && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(3, categoryId);
}

/// Titles with no category, or one the provider no longer lists.
@immutable
final class UncategorizedTitles extends TitleFilter {
  const new();

  @override
  bool operator ==(Object other) => other is UncategorizedTitles;

  @override
  int get hashCode => 4;
}

/// The grid's sort (docs/05: Recently added / Name / Rating).
enum TitleSort {
  /// The provider's date, then the order the app first saw a title: an M3U
  /// list has no dates. For series, `last_modified`, which a panel moves
  /// when episodes arrive.
  recentlyAdded,
  name,

  /// Best first; unrated last.
  rating,
}

@immutable
final class TitleQuery {
  const new({
    required this.sourceId,
    this.filter = const AllTitles(),
    this.text = '',
    this.sort = TitleSort.recentlyAdded,
  });

  final String sourceId;
  final TitleFilter filter;

  /// Matches anywhere in the name, ignoring case.
  final String text;
  final TitleSort sort;

  TitleQuery copyWith({TitleFilter? filter, String? text, TitleSort? sort}) =>
      TitleQuery(
        sourceId: sourceId,
        filter: filter ?? this.filter,
        text: text ?? this.text,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) =>
      other is TitleQuery &&
      other.sourceId == sourceId &&
      other.filter == filter &&
      other.text == text &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(sourceId, filter, text, sort);
}

/// A details page's data, as it arrives (Phase 5 decision 2): what the
/// database has at once, or a first fetch, or why that failed.
sealed class Details<T> {
  const new();
}

/// Nothing cached yet, and the fetch is running.
final class DetailsLoading<T> extends Details<T> {
  const new();
}

/// [value] from the database or a fresh fetch. [refreshing] while a stale
/// cache is being fetched again behind it; nothing on screen says so.
final class DetailsReady<T> extends Details<T> {
  const new(this.value, {this.refreshing = false});

  final T value;
  final bool refreshing;
}

/// The first fetch failed and nothing was cached: the page shows what the
/// list row knows, the reason and Retry.
final class DetailsFailed<T> extends Details<T> {
  const new(this.failure);

  final AppFailure failure;
}
