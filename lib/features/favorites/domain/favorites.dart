import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// A group of favorite channels the user made (Phase 6 decision 6), per
/// source.
@immutable
final class FavoriteGroup {
  const new({
    required this.id,
    required this.sourceId,
    required this.name,
    this.collapsed = false,
    this.count = 0,
  });

  final int id;
  final String sourceId;
  final String name;

  /// Folded away on the Favorites screen.
  final bool collapsed;

  /// Its channels that show: not hidden by the user (decision 8).
  final int count;

  @override
  bool operator ==(Object other) =>
      other is FavoriteGroup &&
      other.id == id &&
      other.sourceId == sourceId &&
      other.name == name &&
      other.collapsed == collapsed &&
      other.count == count;

  @override
  int get hashCode => Object.hash(id, sourceId, name, collapsed, count);

  @override
  String toString() => 'FavoriteGroup($id, $name, $count)';
}

/// The order and the groups of the user's favorite channels. The
/// channels themselves are listed by `ChannelRepository` with
/// `FavoriteChannels` (every favorite, groups in their order, then the
/// ones in no group) or `FavoriteGroupChannels`. Nothing throws across
/// this boundary.
abstract interface class FavoritesRepository {
  /// A source's groups in their order, again after every change to them,
  /// the favorites or the channels.
  Stream<List<FavoriteGroup>> watchGroups(String sourceId);

  /// An empty group at the end. Returns its id.
  Future<Result<int>> createGroup(String sourceId, String name);

  Future<Result<void>> renameGroup(int groupId, String name);

  /// Puts the group at [index] of its source's groups.
  Future<Result<void>> moveGroup(int groupId, int index);

  /// Its channels stay favorites, at the end of the ones in no group.
  Future<Result<void>> deleteGroup(int groupId);

  Future<Result<void>> setCollapsed(int groupId, {required bool collapsed});

  /// Puts [channel] in group [groupId] (null: no group) at [index] of
  /// its channels, making it a favorite first when it isn't one.
  Future<Result<void>> moveChannel(
    ChannelItem channel, {
    required int? groupId,
    required int index,
  });
}
