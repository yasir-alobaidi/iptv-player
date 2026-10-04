import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/favorites/data/favorites_providers.dart';
import 'package:iptv_player/features/favorites/domain/favorite_layout.dart';
import 'package:iptv_player/features/favorites/domain/favorites.dart';
import 'package:iptv_player/features/favorites/presentation/group_name_dialog.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_menu.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_grid.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';

enum _Tab { channels, movies, series }

/// Favorites (canvas `Favorites`, Phase 6 step 6): the browsed source's
/// favorite channels in the user's order and groups, and their favorite
/// movies and series.
///
/// Channels: one Tab stop, ↑/↓ inside it; Enter plays full screen; F
/// removes, with Undo; Alt+↑/↓ moves a channel, past a group's edge into
/// the next; on a group's header Enter, ← and → fold and unfold it; the
/// menu key has the channel's or the group's menu. The mouse drags a
/// channel by its grip.
class FavoritesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  _Tab _tab = _Tab.channels;
  final _list = FocusPaneController();
  final _grid = FocusPaneController();

  @override
  void dispose() {
    _list.dispose();
    _grid.dispose();
    super.dispose();
  }

  Future<void> _newGroup(String sourceId) async {
    final favorites = ref.read(favoritesRepositoryProvider);
    final name = await showGroupNameDialog(
      context,
      title: 'New group',
      action: 'Create',
    );
    if (name != null) await favorites.createGroup(sourceId, name);
  }

  static TitleQuery _titles(String sourceId) =>
      TitleQuery(sourceId: sourceId, filter: const FavoriteTitles());

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final source = ref.watch(currentSourceProvider);
    if (source == null) {
      return FocusPane(
        debugLabel: 'screen-favorites',
        child: EmptyState(
          icon: AppIcons.star,
          title: 'No favorites yet',
          message:
              'Add your provider, then press F on any channel, movie '
              'or series to keep it here.',
          actionLabel: 'Add a source',
          onAction: () => context.push(addSourceRoutePath),
        ),
      );
    }
    final id = source.id;
    final channelCount = ref
        .watch(
          channelCountProvider(
            ChannelQuery(sourceId: id, filter: const FavoriteChannels()),
          ),
        )
        .value;
    final movies = ref.watch(
      titleCountProvider(CatalogueKind.movie, _titles(id)),
    );
    final series = ref.watch(
      titleCountProvider(CatalogueKind.series, _titles(id)),
    );
    final spacing = tokens.spacing;

    return FocusPane(
      debugLabel: 'screen-favorites',
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.s32,
          spacing.s12,
          spacing.s32,
          spacing.s20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.surface3)),
              ),
              child: Row(
                children: [
                  for (final (tab, label, count) in [
                    (_Tab.channels, 'Channels', channelCount),
                    (_Tab.movies, 'Movies', movies.value?.count),
                    (_Tab.series, 'Series', series.value?.count),
                  ]) ...[
                    CountTab(
                      label: label,
                      count: count,
                      selected: _tab == tab,
                      onPressed: () => setState(() => _tab = tab),
                    ),
                    SizedBox(width: spacing.s16),
                  ],
                  const Spacer(),
                  if (_tab == _Tab.channels) ...[
                    Text(
                      'Drag to reorder',
                      style: tokens.text.caption
                          .withWeight(600)
                          .copyWith(color: colors.textTertiary),
                    ),
                    SizedBox(width: spacing.s16),
                    AppButton(
                      label: 'New group',
                      icon: AppIcons.plus,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.s,
                      onPressed: () => unawaited(_newGroup(id)),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: spacing.s16),
            Expanded(
              child: switch (_tab) {
                _Tab.channels => _ChannelsPanel(
                  key: ValueKey('favorite-channels-$id'),
                  sourceId: id,
                  controller: _list,
                ),
                _Tab.movies => _titleGrid(CatalogueKind.movie, id, movies),
                _Tab.series => _titleGrid(CatalogueKind.series, id, series),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleGrid(
    CatalogueKind kind,
    String sourceId,
    AsyncValue<TitleCount> count,
  ) {
    final movies = kind == CatalogueKind.movie;
    return CatalogueGrid(
      key: ValueKey(kind),
      kind: kind,
      query: _titles(sourceId),
      count: count,
      controller: _grid,
      // In its own branch, as Home opens one: Esc there goes to its grid.
      onOpen: (path) => context.go(path),
      empty: () => EmptyState(
        compact: true,
        icon: AppIcons.star,
        title: movies ? 'No favorite movies yet' : 'No favorite series yet',
        message: 'Press F on a poster to add it here.',
        actionLabel: movies ? 'Open Movies' : 'Open Series',
        onAction: () => context.go(
          movies ? AppDestination.movies.path : AppDestination.series.path,
        ),
      ),
    );
  }
}

/// The Channels tab: the list in its panel, and the hint at its foot.
class _ChannelsPanel extends ConsumerStatefulWidget {
  const new({required this.sourceId, required this.controller, super.key});

  final String sourceId;
  final FocusPaneController controller;

  @override
  ConsumerState<_ChannelsPanel> createState() => _ChannelsPanelState();
}

class _ChannelsPanelState extends ConsumerState<_ChannelsPanel> {
  List<ChannelItem>? _channels;
  AppFailure? _error;

  /// Each entry's node, by its key, so a move or a remove can put the
  /// keyboard back where it belongs.
  final _nodes = <String, FocusNode>{};

  /// The entry to focus once the list has read itself again.
  String? _focusAfterLoad;
  int? _focusIndexAfterLoad;

  ChannelQuery get _query =>
      ChannelQuery(sourceId: widget.sourceId, filter: const FavoriteChannels());

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final result = await ref
        .read(channelRepositoryProvider)
        .range(_query, 0, 5000);
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Ok(:final value):
          _channels = value;
          _error = null;
        case Err(:final failure):
          _error = failure;
      }
    });
    if (result.valueOrNull case final channels? when channels.isNotEmpty) {
      unawaited(ref.read(guideServiceProvider).warm(channels));
    }
  }

  static String _keyOf(FavoriteEntry entry) => switch (entry) {
    FavoriteHeader(:final groupId) => 'g$groupId',
    FavoriteChannel(:final channel) => 'c${channel.remoteKey}',
  };

  FocusNode _nodeFor(String key) =>
      _nodes.putIfAbsent(key, () => FocusNode(debugLabel: 'favorite $key'));

  /// The key of the entry with the keyboard, if one has it.
  String? get _focusedKey {
    for (final MapEntry(:key, :value) in _nodes.entries) {
      if (value.hasFocus) return key;
    }
    return null;
  }

  void _placeFocus(List<FavoriteEntry> entries) {
    final key = _focusAfterLoad;
    final index = _focusIndexAfterLoad;
    if (key == null && index == null) return;
    _focusAfterLoad = null;
    _focusIndexAfterLoad = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || entries.isEmpty) return;
      final target = key != null && _nodes.containsKey(key)
          ? key
          : _keyOf(entries[(index ?? 0).clamp(0, entries.length - 1)]);
      _nodes[target]?.requestFocus();
    });
  }

  // What the keys and the menus do.

  Future<void> _watch(ChannelItem channel) async {
    final coordinator = ref.read(playbackCoordinatorProvider);
    unawaited(coordinator.playLive(channel));
    await context.push<void>(playerRoutePath, extra: _query);
    // Favorites shows no picture: back here, the stream stops.
    if (coordinator.current != null) unawaited(coordinator.stop());
  }

  /// F: out of the favorites at once, with Undo putting it back where it
  /// was (docs/05: optimistic updates).
  Future<void> _remove(ChannelItem channel, List<FavoriteEntry> entries) async {
    final channels = ref.read(channelRepositoryProvider);
    final favorites = ref.read(favoritesRepositoryProvider);
    final notices = ref.read(appNoticesProvider);
    final place = (
      groupId: channel.favoriteGroupId,
      index: [
        for (final c in _channels ?? const <ChannelItem>[])
          if (c.favoriteGroupId == channel.favoriteGroupId) c.id,
      ].indexOf(channel.id),
    );
    _focusIndexAfterLoad = entries.indexWhere(
      (e) => e is FavoriteChannel && e.channel.id == channel.id,
    );
    await channels.setFavorite(channel, on: false);
    notices.show(
      AppNotice.undoable(
        'Removed ${channel.name} from favorites',
        onUndo: () => unawaited(
          favorites.moveChannel(
            channel,
            groupId: place.groupId,
            index: place.index < 0 ? 1 << 30 : place.index,
          ),
        ),
      ),
    );
  }

  Future<void> _move(ChannelItem channel, FavoritePlace place) async {
    final favorites = ref.read(favoritesRepositoryProvider);
    _focusAfterLoad = 'c${channel.remoteKey}';
    final groups = ref.read(favoriteGroupsProvider(widget.sourceId)).value;
    final target = groups?.where((g) => g.id == place.groupId).firstOrNull;
    if (target != null && target.collapsed) {
      await favorites.setCollapsed(target.id, collapsed: false);
    }
    await favorites.moveChannel(
      channel,
      groupId: place.groupId,
      index: place.index,
    );
  }

  Future<void> _moveGroup(FavoriteGroup group, int by) async {
    final groups =
        ref.read(favoriteGroupsProvider(widget.sourceId)).value ?? const [];
    final at = groups.indexWhere((g) => g.id == group.id);
    if (at < 0) return;
    _focusAfterLoad = 'g${group.id}';
    await ref
        .read(favoritesRepositoryProvider)
        .moveGroup(group.id, (at + by).clamp(0, groups.length - 1));
  }

  Future<void> _renameGroup(FavoriteGroup group) async {
    final favorites = ref.read(favoritesRepositoryProvider);
    final name = await showGroupNameDialog(
      context,
      title: 'Rename group',
      initial: group.name,
    );
    if (name != null) await favorites.renameGroup(group.id, name);
  }

  Future<void> _channelMenu(
    BuildContext anchor,
    ChannelItem channel,
    List<FavoriteEntry> entries,
  ) => showChannelMenu(
    anchor,
    ref,
    channel,
    onWatch: () => unawaited(_watch(channel)),
    onFavorite: () => unawaited(_remove(channel, entries)),
  );

  Future<void> _headerMenu(BuildContext anchor, FavoriteGroup group) {
    final favorites = ref.read(favoritesRepositoryProvider);
    return showAppMenu(
      anchor,
      items: [
        AppMenuItem(
          label: 'Rename…',
          icon: AppIcons.edit,
          onPressed: () => unawaited(_renameGroup(group)),
        ),
        AppMenuItem(
          label: 'Move up',
          icon: AppIcons.arrowUp,
          shortcut: 'Alt ↑',
          onPressed: () => unawaited(_moveGroup(group, -1)),
        ),
        AppMenuItem(
          label: 'Move down',
          icon: AppIcons.arrowDown,
          shortcut: 'Alt ↓',
          onPressed: () => unawaited(_moveGroup(group, 1)),
        ),
        const AppMenuItem.separator(),
        AppMenuItem(
          label: 'Delete group',
          icon: AppIcons.trash,
          destructive: true,
          onPressed: () => unawaited(favorites.deleteGroup(group.id)),
        ),
      ],
    );
  }

  /// The keys the list answers beyond ↑/↓ and Enter.
  KeyEventResult _onKey(
    KeyEvent event,
    List<FavoriteEntry> entries,
    List<FavoriteGroup> groups,
  ) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final focused = _focusedKey;
    final entry = entries.where((e) => _keyOf(e) == focused).firstOrNull;
    if (entry == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final vertical =
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
    switch (entry) {
      case FavoriteChannel(:final channel):
        if (alt && vertical) {
          final place = keyboardMove(
            groups,
            _channels ?? const [],
            channel,
            down: key == LogicalKeyboardKey.arrowDown,
          );
          if (place != null) unawaited(_move(channel, place));
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyF && !alt) {
          unawaited(_remove(channel, entries));
          return KeyEventResult.handled;
        }
      case FavoriteHeader(:final group?):
        if (alt && vertical) {
          unawaited(
            _moveGroup(group, key == LogicalKeyboardKey.arrowDown ? 1 : -1),
          );
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight) {
          final fold = key == LogicalKeyboardKey.arrowLeft;
          if (group.collapsed != fold) {
            unawaited(
              ref
                  .read(favoritesRepositoryProvider)
                  .setCollapsed(group.id, collapsed: fold),
            );
          }
          return KeyEventResult.handled;
        }
      case FavoriteHeader():
        break;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    ref.listen(channelRevisionProvider(_query), (_, _) => unawaited(_load()));
    final groupsValue = ref.watch(favoriteGroupsProvider(widget.sourceId));
    ref.watch(guideRevisionProvider);
    final channels = _channels;
    final groups = groupsValue.value;

    final Widget body;
    if ((_error != null && channels == null) || groupsValue.hasError) {
      body = ErrorState(
        compact: true,
        title: "Couldn't load your favorites",
        message: 'The list could not be read.',
        details: '${_error ?? groupsValue.error}',
        onRetry: () {
          ref.invalidate(favoriteGroupsProvider(widget.sourceId));
          unawaited(_load());
        },
      );
    } else if (channels == null || groups == null) {
      body = Column(
        children: [
          for (var i = 0; i < 6; i++)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.s4),
              child: const SkeletonRow(height: 60),
            ),
        ],
      );
    } else if (channels.isEmpty && groups.isEmpty) {
      body = EmptyState(
        compact: true,
        icon: AppIcons.star,
        title: 'No favorite channels yet',
        message: 'Press F on a channel in Live TV to add it here.',
        actionLabel: 'Open Live TV',
        onAction: () => context.go(AppDestination.liveTv.path),
      );
    } else {
      final entries = favoriteEntries(groups, channels);
      _placeFocus(entries);
      body = _list(context, entries, groups);
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.s12,
        tokens.spacing.s8,
        tokens.spacing.s12,
        tokens.spacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: body),
          Container(
            padding: EdgeInsets.only(top: tokens.spacing.s8 + 2),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.surface3)),
            ),
            child: Row(
              children: [
                SizedBox(width: tokens.spacing.s8 + 2),
                Text('Press', style: _hint(tokens)),
                SizedBox(width: tokens.spacing.s8),
                const Kbd('F'),
                SizedBox(width: tokens.spacing.s8),
                Expanded(
                  child: Text(
                    'on any channel, movie, or series to add it here or '
                    'remove it.',
                    style: _hint(tokens),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _hint(AppTokens tokens) =>
      tokens.text.caption.copyWith(color: tokens.colors.textTertiary);

  Widget _list(
    BuildContext context,
    List<FavoriteEntry> entries,
    List<FavoriteGroup> groups,
  ) {
    final guide = ref.read(guideServiceProvider);
    final now = ref.watch(appClockProvider)();
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _onKey(event, entries, groups),
      child: FocusPane(
        debugLabel: 'favorites-channels',
        controller: widget.controller,
        tabStop: true,
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: entries.length,
          proxyDecorator: (child, index, animation) => Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.tokens.colors.surface3,
                borderRadius: context.tokens.radii.controlAll,
                boxShadow: context.tokens.elevation.overlay,
              ),
              child: child,
            ),
          ),
          onReorderItem: (from, to) {
            final entry = entries[from];
            if (entry is! FavoriteChannel) return;
            unawaited(_move(entry.channel, dropPlace(entries, from, to)));
          },
          itemBuilder: (context, index) {
            final entry = entries[index];
            final key = _keyOf(entry);
            return switch (entry) {
              FavoriteHeader(:final group) => _Header(
                key: ValueKey(key),
                group: group,
                focusNode: group == null ? null : _nodeFor(key),
                count:
                    group?.count ??
                    entries
                        .whereType<FavoriteChannel>()
                        .where(
                          (c) =>
                              c.groupId == null ||
                              !groups.any((g) => g.id == c.groupId),
                        )
                        .length,
                onToggle: group == null
                    ? null
                    : () => unawaited(
                        ref
                            .read(favoritesRepositoryProvider)
                            .setCollapsed(
                              group.id,
                              collapsed: !group.collapsed,
                            ),
                      ),
                onRename: group == null
                    ? null
                    : () => unawaited(_renameGroup(group)),
                onMenu: group == null
                    ? null
                    : (anchor) => unawaited(_headerMenu(anchor, group)),
              ),
              FavoriteChannel(:final channel) => Padding(
                key: ValueKey(key),
                padding: EdgeInsets.only(bottom: context.tokens.spacing.s4 - 2),
                child: _row(
                  context,
                  index,
                  channel,
                  entries,
                  groups,
                  guide,
                  now,
                ),
              ),
            };
          },
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    int index,
    ChannelItem channel,
    List<FavoriteEntry> entries,
    List<FavoriteGroup> groups,
    GuideService guide,
    DateTime now,
  ) {
    final programme = guide.cached(channel)?.now;
    final on =
        programme != null &&
        !programme.start.isAfter(now) &&
        programme.end.isAfter(now);
    final colors = context.tokens.colors;
    return ChannelRow(
      name: channel.name,
      quality: channel.quality?.label,
      number: channel.number,
      image: artworkFor(context, channel.logoUrl, width: 40),
      nowTitle: on ? programme.title : null,
      progress: on ? programme.progressAt(now) : null,
      timeLeft: on ? formatTimeLeft(programme.end.difference(now)) : null,
      isFavorite: true,
      focusNode: _nodeFor('c${channel.remoteKey}'),
      leading: ReorderableDragStartListener(
        index: index,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: AppIcon(
            AppIcons.dragHandle,
            size: 18,
            color: colors.textTertiary,
          ),
        ),
      ),
      onPressed: () => unawaited(_watch(channel)),
      onToggleFavorite: () => unawaited(_remove(channel, entries)),
      onMenu: () {
        final anchor = _nodeFor('c${channel.remoteKey}').context;
        if (anchor != null) {
          unawaited(_channelMenu(anchor, channel, entries));
        }
      },
    );
  }
}

/// A group's header (canvas): its chevron, NAME, count, and Rename; for
/// the favorites in no group, "UNGROUPED" and its count only.
class _Header extends StatelessWidget {
  const new({
    required this.group,
    required this.count,
    this.focusNode,
    this.onToggle,
    this.onRename,
    this.onMenu,
    super.key,
  });

  final FavoriteGroup? group;
  final int count;
  final FocusNode? focusNode;
  final VoidCallback? onToggle;
  final VoidCallback? onRename;
  final void Function(BuildContext anchor)? onMenu;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final group = this.group;
    final style = tokens.text.labelSmall.copyWith(color: colors.textTertiary);
    final content = Row(
      children: [
        if (group != null) ...[
          AppIcon(
            group.collapsed ? AppIcons.chevronRight : AppIcons.chevronDown,
            size: 16,
            color: colors.textTertiary,
          ),
          SizedBox(width: tokens.spacing.s8),
        ],
        Text(
          (group?.name ?? 'Ungrouped').toUpperCase(),
          style: tokens.text.overline.copyWith(color: colors.textTertiary),
        ),
        SizedBox(width: tokens.spacing.s8),
        Text(formatCount(count), style: style),
        const Spacer(),
        if (onRename != null)
          ExcludeFocus(
            child: AppButton(
              label: 'Rename',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.s,
              onPressed: onRename,
            ),
          ),
      ],
    );
    final padded = SizedBox(
      height: 40,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8 + 2),
        child: content,
      ),
    );
    if (group == null) return padded;
    return Builder(
      builder: (anchor) => FocusableSurface(
        focusNode: focusNode,
        onPressed: onToggle,
        onMenu: onMenu == null ? null : () => onMenu!(anchor),
        borderRadius: tokens.radii.controlAll,
        semanticLabel:
            '${group.name}, $count, ${group.collapsed ? 'folded' : 'open'}',
        builder: (context, states) => padded,
      ),
    );
  }
}
