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

    /// The provider's own name, which a rename hides; null when the
    /// category isn't renamed.
    String? providerName,
  }) = _CategoryChoice;

  const new _();

  bool get isRenamed => providerName != null;
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

    /// True when the user reordered this list; false while it follows the
    /// provider's order.
    @Default(false) bool customOrder,
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

  /// The user's name for a category; null or blank restores the
  /// provider's. Kept across re-syncs.
  Future<Result<void>> rename(int id, String? name);

  /// Stores [idsInOrder] — every category of one kind of one source — as
  /// the user's order. Kept across re-syncs; a category the provider adds
  /// later goes after them.
  Future<Result<void>> reorder(List<int> idsInOrder);

  /// Back to the provider's order.
  Future<Result<void>> resetOrder(String sourceId, CatalogueKind kind);
}
