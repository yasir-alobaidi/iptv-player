/// The Favorites screen's channel list as one flat list of group headers
/// and channels (Phase 6 plan, risks: Flutter's reorderable list has no
/// groups), and where a move lands in it. Pure: Alt+↑/↓ and a drag's drop
/// go through the same rules.
library;

import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/favorites/domain/favorites.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// A line of the list.
sealed class FavoriteEntry {
  const new();
}

/// A group's header; [group] null is "Ungrouped", shown once a group
/// exists and some favorites are in none.
@immutable
final class FavoriteHeader extends FavoriteEntry {
  const new(this.group);

  final FavoriteGroup? group;

  int? get groupId => group?.id;

  @override
  bool operator ==(Object other) =>
      other is FavoriteHeader && other.group == group;

  @override
  int get hashCode => group.hashCode;
}

@immutable
final class FavoriteChannel extends FavoriteEntry {
  const new(this.channel);

  final ChannelItem channel;

  int? get groupId => channel.favoriteGroupId;

  @override
  bool operator ==(Object other) =>
      other is FavoriteChannel && other.channel == channel;

  @override
  int get hashCode => channel.hashCode;
}

/// Where a channel goes: into `groupId` (null: no group) at `index` of
/// that group's channels.
typedef FavoritePlace = ({int? groupId, int index});

/// The list the screen draws: each group's header and, unless it is
/// collapsed, its channels in their order; then the favorites in no
/// group, under "Ungrouped" once any group exists. [channels] come in the
/// favorites' order (groups in order, then the rest).
List<FavoriteEntry> favoriteEntries(
  List<FavoriteGroup> groups,
  List<ChannelItem> channels,
) {
  final known = {for (final group in groups) group.id};
  List<ChannelItem> inGroup(int? id) => [
    for (final channel in channels)
      if (id == null
          ? !known.contains(channel.favoriteGroupId)
          : channel.favoriteGroupId == id)
        channel,
  ];
  final ungrouped = inGroup(null);
  return [
    for (final group in groups) ...[
      FavoriteHeader(group),
      if (!group.collapsed)
        for (final channel in inGroup(group.id)) FavoriteChannel(channel),
    ],
    if (groups.isNotEmpty && ungrouped.isNotEmpty) const FavoriteHeader(null),
    for (final channel in ungrouped) FavoriteChannel(channel),
  ];
}

/// Alt+↓ ([down]) or Alt+↑ on [channel]: one place along its group, and
/// past the group's edge into the next group's first place (or the one
/// before's last), the favorites in no group coming after every group.
/// Null at either end of the list.
FavoritePlace? keyboardMove(
  List<FavoriteGroup> groups,
  List<ChannelItem> channels,
  ChannelItem channel, {
  required bool down,
}) {
  final known = {for (final group in groups) group.id};
  int? sectionOf(ChannelItem c) =>
      known.contains(c.favoriteGroupId) ? c.favoriteGroupId : null;
  final sections = <int?>[for (final group in groups) group.id, null];
  List<ChannelItem> members(int? id) => [
    for (final c in channels)
      if (sectionOf(c) == id) c,
  ];
  final section = sectionOf(channel);
  final list = members(section);
  final at = list.indexWhere((c) => c.id == channel.id);
  if (at < 0) return null;
  if (down && at < list.length - 1) return (groupId: section, index: at + 1);
  if (!down && at > 0) return (groupId: section, index: at - 1);
  final next = sections.indexOf(section) + (down ? 1 : -1);
  if (next < 0 || next >= sections.length) return null;
  final target = sections[next];
  return (groupId: target, index: down ? 0 : members(target).length);
}

/// A drag of `entries[from]` dropped at [to], its place in the list
/// without it (`ReorderableListView.onReorderItem`'s index): the channel
/// takes the group of the nearest header above where it lands — none
/// above, the first group, or no group when there are none — at its
/// place among that group's channels.
FavoritePlace dropPlace(List<FavoriteEntry> entries, int from, int to) {
  final rest = [...entries]..removeAt(from);
  final at = to.clamp(0, rest.length);
  var header = -1;
  for (var i = at - 1; i >= 0; i--) {
    if (rest[i] is FavoriteHeader) {
      header = i;
      break;
    }
  }
  final int? groupId;
  if (header >= 0) {
    groupId = (rest[header] as FavoriteHeader).groupId;
  } else {
    final first = rest.whereType<FavoriteHeader>().firstOrNull;
    groupId = first?.groupId;
    header = first == null ? -1 : rest.indexOf(first);
  }
  var index = 0;
  for (var i = header + 1; i < at; i++) {
    if (rest[i] is FavoriteChannel) index++;
  }
  return (groupId: groupId, index: index);
}
