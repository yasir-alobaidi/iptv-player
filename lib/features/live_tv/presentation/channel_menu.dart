import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/casting/presentation/cast_actions.dart';
import 'package:iptv_player/features/favorites/data/favorites_providers.dart';
import 'package:iptv_player/features/favorites/domain/favorites.dart';
import 'package:iptv_player/features/favorites/presentation/group_name_dialog.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_rename_dialog.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';

/// The one channel menu (Phase 6 step 7), wherever a channel's row or
/// tile is — Live TV, the Guide's channel column, Home, Favorites and
/// Search: Watch, the favorite, Add to group…, Rename…, Hide channel.
///
/// [onWatch] leaves Watch out when null. [onFavorite] replaces the plain
/// toggle (Favorites' remove has Undo). [after] follows the rest, under a
/// separator. [onChanged] hears that the channel changed, for a list that
/// doesn't refresh by itself (search's results).
Future<void> showChannelMenu(
  BuildContext anchor,
  WidgetRef ref,
  ChannelItem channel, {
  VoidCallback? onWatch,
  VoidCallback? onFavorite,
  VoidCallback? onChanged,
  List<AppMenuItem> after = const [],
}) {
  final channels = ref.read(channelRepositoryProvider);
  final notices = ref.read(appNoticesProvider);
  final favorites = ref.read(favoritesRepositoryProvider);
  Future<void> changed(Future<void> action) async {
    await action;
    onChanged?.call();
  }

  return showAppMenu(
    anchor,
    items: [
      if (onWatch != null)
        AppMenuItem(label: 'Watch', icon: AppIcons.play, onPressed: onWatch),
      AppMenuItem(
        label: 'Cast…',
        icon: AppIcons.cast,
        onPressed: () =>
            unawaited(castFrom(anchor, item: PlayableChannel(channel))),
      ),
      AppMenuItem(
        label: channel.isFavorite
            ? 'Remove from favorites'
            : 'Add to favorites',
        icon: channel.isFavorite ? AppIcons.starFilled : AppIcons.star,
        shortcut: 'F',
        onPressed:
            onFavorite ??
            () => unawaited(
              changed(channels.setFavorite(channel, on: !channel.isFavorite)),
            ),
      ),
      AppMenuItem(
        label: channel.favoriteGroupId == null
            ? 'Add to group…'
            : 'Move to group…',
        icon: AppIcons.plus,
        onPressed: () => unawaited(() async {
          // Read now, straight from the store: the menu may open where
          // nothing watches the groups.
          final groups = await favorites.watchGroups(channel.sourceId).first;
          if (!anchor.mounted) return;
          await showGroupMenu(
            anchor,
            favorites,
            channel,
            groups,
            onChanged: onChanged,
          );
        }()),
      ),
      AppMenuItem(
        label: 'Rename…',
        icon: AppIcons.edit,
        onPressed: () =>
            unawaited(changed(renameChannel(anchor, channels, channel))),
      ),
      const AppMenuItem.separator(),
      AppMenuItem(
        label: channel.isHidden ? 'Show channel' : 'Hide channel',
        icon: AppIcons.eye,
        onPressed: () => unawaited(
          changed(
            channel.isHidden
                ? channels.setHidden(channel.id, hidden: false)
                : hideChannel(channels, notices, channel, onUndo: onChanged),
          ),
        ),
      ),
      ...after,
    ],
  );
}

/// Hides [channel] at once, and says so with Undo (docs/05: optimistic
/// updates for favorite and hide).
Future<void> hideChannel(
  ChannelRepository channels,
  AppNotices notices,
  ChannelItem channel, {
  VoidCallback? onUndo,
}) async {
  await channels.setHidden(channel.id, hidden: true);
  notices.show(
    AppNotice.undoable(
      'Channel hidden',
      onUndo: () => unawaited(() async {
        await channels.setHidden(channel.id, hidden: false);
        onUndo?.call();
      }()),
    ),
  );
}

/// "Add to group…": the source's groups (the channel's own ticked), No
/// group for one in a group, and New group…. A channel not yet a
/// favorite becomes one; it goes at the end of the group.
Future<void> showGroupMenu(
  BuildContext anchor,
  FavoritesRepository favorites,
  ChannelItem channel,
  List<FavoriteGroup> groups, {
  VoidCallback? onChanged,
}) {
  Future<void> into(int? groupId) async {
    await favorites.moveChannel(channel, groupId: groupId, index: 1 << 30);
    onChanged?.call();
  }

  return showAppMenu(
    anchor,
    items: [
      for (final group in groups)
        AppMenuItem(
          label: group.name,
          checked: channel.favoriteGroupId == group.id,
          onPressed: () => unawaited(into(group.id)),
        ),
      if (channel.favoriteGroupId != null)
        AppMenuItem(label: 'No group', onPressed: () => unawaited(into(null))),
      if (groups.isNotEmpty) const AppMenuItem.separator(),
      AppMenuItem(
        label: 'New group…',
        icon: AppIcons.plus,
        onPressed: () => unawaited(() async {
          final name = await showGroupNameDialog(
            anchor,
            title: 'New group',
            action: 'Create',
          );
          if (name == null) return;
          final created = await favorites.createGroup(channel.sourceId, name);
          if (created.valueOrNull case final id?) await into(id);
        }()),
      ),
    ],
  );
}
