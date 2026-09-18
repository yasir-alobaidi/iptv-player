import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/core/result.dart';

export 'package:iptv_player/core/catalogue_kind.dart';

part 'categories.freezed.dart';

/// One category as the pickers show it.
@freezed
abstract class CategoryChoice with _$CategoryChoice {
  const factory({
    required int id,

    /// The user's rename, or the provider's name.
    required String name,
    required bool isHidden,

    /// Channels, movies or series filed under it.
    required int itemCount,
  }) = _CategoryChoice;
}

/// A source's categories of one kind, in display order, and the items
/// filed under none of them.
@freezed
abstract class CategoryList with _$CategoryList {
  const factory({
    required List<CategoryChoice> categories,

    /// Items with no category, or one the provider no longer lists. They
    /// are always shown: there is no category to hide them with.
    @Default(0) int uncategorized,
  }) = _CategoryList;

  const new _();

  int get visibleCount => categories.where((c) => !c.isHidden).length;

  int get itemCount =>
      categories.fold(uncategorized, (sum, c) => sum + c.itemCount);

  int get visibleItemCount => categories
      .where((c) => !c.isHidden)
      .fold(uncategorized, (sum, c) => sum + c.itemCount);
}

/// The categories a source's picker lists, and the switches it flips.
/// Hiding is kept across re-syncs (docs/02). Nothing throws across this
/// boundary; a stream's error is an `AppFailure`.
abstract interface class CategoryRepository {
  Stream<CategoryList> watch(String sourceId, CatalogueKind kind);

  Future<Result<void>> setHidden(int id, {required bool hidden});

  Future<Result<void>> setHiddenMany(Iterable<int> ids, {required bool hidden});

  /// "Select all" and "Select none".
  Future<Result<void>> setAllHidden(
    String sourceId,
    CatalogueKind kind, {
    required bool hidden,
  });
}
