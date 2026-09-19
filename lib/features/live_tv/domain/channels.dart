import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';

/// One live channel as the Live TV screen and the player show it.
@immutable
final class ChannelItem {
  const new({
    required this.id,
    required this.sourceId,
    required this.remoteKey,
    required this.name,
    this.providerName,
    this.number,
    this.logoUrl,
    this.categoryId,
    this.epgKey,
    this.archiveDays = 0,
    this.isFavorite = false,
    this.isHidden = false,
  });

  /// The database row id: stable within a sync, not across them. User
  /// data is keyed by [sourceId] + [remoteKey].
  final int id;
  final String sourceId;
  final String remoteKey;

  /// The user's rename, or the provider's name.
  final String name;

  /// The provider's own name when the user renamed the channel.
  final String? providerName;
  final int? number;
  final String? logoUrl;
  final int? categoryId;
  final String? epgKey;

  /// Catch-up days the provider keeps (0 = none).
  final int archiveDays;
  final bool isFavorite;
  final bool isHidden;

  @override
  bool operator ==(Object other) =>
      other is ChannelItem &&
      other.id == id &&
      other.sourceId == sourceId &&
      other.remoteKey == remoteKey &&
      other.name == name &&
      other.providerName == providerName &&
      other.number == number &&
      other.logoUrl == logoUrl &&
      other.categoryId == categoryId &&
      other.epgKey == epgKey &&
      other.archiveDays == archiveDays &&
      other.isFavorite == isFavorite &&
      other.isHidden == isHidden;

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    remoteKey,
    name,
    providerName,
    number,
    logoUrl,
    categoryId,
    epgKey,
    archiveDays,
    isFavorite,
    isHidden,
  );

  @override
  String toString() => 'ChannelItem($id, $number $name)';
}

/// Which channels a list shows (docs/05: Favorites pinned, All channels,
/// then the visible categories).
sealed class ChannelFilter {
  const new();
}

/// Every channel not hidden, in a category the user didn't hide.
@immutable
final class AllChannels extends ChannelFilter {
  const new();

  @override
  bool operator ==(Object other) => other is AllChannels;

  @override
  int get hashCode => 1;
}

/// The favorites, whatever their category.
@immutable
final class FavoriteChannels extends ChannelFilter {
  const new();

  @override
  bool operator ==(Object other) => other is FavoriteChannels;

  @override
  int get hashCode => 2;
}

@immutable
final class CategoryChannels extends ChannelFilter {
  const new(this.categoryId);

  final int categoryId;

  @override
  bool operator ==(Object other) =>
      other is CategoryChannels && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(3, categoryId);
}

/// Channels with no category, or one the provider no longer lists.
@immutable
final class UncategorizedChannels extends ChannelFilter {
  const new();

  @override
  bool operator ==(Object other) => other is UncategorizedChannels;

  @override
  int get hashCode => 4;
}

enum ChannelSort {
  /// The provider's numbers, then its order.
  number,
  name,
}

@immutable
final class ChannelQuery {
  const new({
    required this.sourceId,
    this.filter = const AllChannels(),
    this.text = '',
    this.sort = ChannelSort.number,
    this.showHidden = false,
  });

  final String sourceId;
  final ChannelFilter filter;

  /// Matches anywhere in the name, ignoring case.
  final String text;
  final ChannelSort sort;

  /// Include channels the user hid (the empty state's "Show hidden").
  final bool showHidden;

  ChannelQuery copyWith({
    ChannelFilter? filter,
    String? text,
    ChannelSort? sort,
    bool? showHidden,
  }) => ChannelQuery(
    sourceId: sourceId,
    filter: filter ?? this.filter,
    text: text ?? this.text,
    sort: sort ?? this.sort,
    showHidden: showHidden ?? this.showHidden,
  );

  @override
  bool operator ==(Object other) =>
      other is ChannelQuery &&
      other.sourceId == sourceId &&
      other.filter == filter &&
      other.text == text &&
      other.sort == sort &&
      other.showHidden == showHidden;

  @override
  int get hashCode => Object.hash(sourceId, filter, text, sort, showHidden);
}

/// The live channels of a source, for a list that can hold 50,000 rows:
/// the screen asks for a count and then the window it shows (hard rule 2).
/// Nothing throws across this boundary.
abstract interface class ChannelRepository {
  /// How many channels [query] matches, again after every change to the
  /// channels, their categories or the favorites.
  Stream<int> watchCount(ChannelQuery query);

  /// [limit] channels from [offset], in [query]'s order.
  Future<Result<List<ChannelItem>>> range(
    ChannelQuery query,
    int offset,
    int limit,
  );

  /// Where channel [id] sits in [query]'s order; null when not in it.
  Future<Result<int?>> indexOf(ChannelQuery query, int id);

  /// The channel with provider number [number] (number entry).
  Future<Result<ChannelItem?>> byNumber(String sourceId, int number);

  Future<Result<ChannelItem?>> byRemoteKey(String sourceId, String remoteKey);

  Future<Result<void>> setFavorite(ChannelItem channel, {required bool on});

  Future<Result<void>> setHidden(int id, {required bool hidden});

  /// Null or blank restores the provider's name. Kept across re-syncs.
  Future<Result<void>> rename(int id, String? name);
}
