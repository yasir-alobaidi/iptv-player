import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/favorites/data/favorites_providers.dart';
import 'package:iptv_player/features/favorites/domain/favorites.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/presentation/categories_manager.dart';

/// The canvas's categories pane (248 px): Favorites pinned, All channels,
/// then the visible categories with their counts, and "N categories
/// hidden · Manage" at the foot. One Tab stop; ↑↓ move, Enter shows.
class CategoriesPane extends ConsumerWidget {
  const new({
    required this.controller,
    this.onEnterList,
    this.onChosen,
    super.key,
  });

  final FocusPaneController controller;

  /// → moves on to the channel list, where it was.
  final VoidCallback? onEnterList;

  /// A category was chosen: the list takes the focus once it has loaded.
  final VoidCallback? onChosen;

  static const width = 248.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final view = ref.watch(liveTvControllerProvider);
    if (view == null) return const SizedBox.shrink();
    final sourceId = view.query.sourceId;
    final current = view.query.filter;
    final list = ref.watch(categoryListProvider(sourceId, CatalogueKind.live));
    final favorites = ref
        .watch(
          channelCountProvider(
            ChannelQuery(sourceId: sourceId, filter: const FavoriteChannels()),
          ),
        )
        .value;
    final all = ref
        .watch(channelCountProvider(ChannelQuery(sourceId: sourceId)))
        .value;
    final groups =
        ref.watch(favoriteGroupsProvider(sourceId)).value ??
        const <FavoriteGroup>[];
    final hiddenChannels =
        ref
            .watch(
              channelCountProvider(
                ChannelQuery(
                  sourceId: sourceId,
                  filter: const HiddenChannels(),
                ),
              ),
            )
            .value ??
        0;
    final notifier = ref.read(liveTvControllerProvider.notifier);

    void show(ChannelFilter filter) {
      notifier.showFilter(filter);
      onChosen?.call();
    }

    final repository = ref.read(categoryRepositoryProvider);
    final notices = ref.read(appNoticesProvider);

    /// Moves the category at [from] of the shown ones past its neighbour
    /// at [to], in the order of all of them (hidden ones included), as
    /// the Categories manager does.
    void move(
      List<CategoryChoice> all,
      List<CategoryChoice> shown,
      int from,
      int to,
    ) {
      if (to < 0 || to >= shown.length || from == to) return;
      final ids = [for (final c in all) c.id];
      final moved = shown[from].id;
      final anchor = shown[to].id;
      ids.remove(moved);
      final at = ids.indexOf(anchor);
      ids.insert(to > from ? at + 1 : at, moved);
      unawaited(repository.reorder(ids));
    }

    Future<void> categoryMenu(
      BuildContext anchor,
      List<CategoryChoice> all,
      List<CategoryChoice> shown,
      int index,
    ) {
      final category = shown[index];
      return showAppMenu(
        anchor,
        items: [
          AppMenuItem(
            label: 'Hide category',
            icon: AppIcons.eye,
            onPressed: () => unawaited(() async {
              if (current case CategoryChannels(:final categoryId)
                  when categoryId == category.id) {
                notifier.showFilter(const AllChannels());
              }
              await repository.setHidden(category.id, hidden: true);
              notices.show(
                AppNotice(
                  'Category hidden',
                  actionLabel: 'Undo',
                  onAction: () => unawaited(
                    repository.setHidden(category.id, hidden: false),
                  ),
                ),
              );
            }()),
          ),
          AppMenuItem(
            label: 'Rename…',
            icon: AppIcons.edit,
            onPressed: () => unawaited(() async {
              final named = await askCategoryName(anchor, category);
              if (named != null) {
                await repository.rename(category.id, named.name);
              }
            }()),
          ),
          AppMenuItem(
            label: 'Move up',
            icon: AppIcons.arrowUp,
            shortcut: 'Alt ↑',
            onPressed: () => move(all, shown, index, index - 1),
          ),
          AppMenuItem(
            label: 'Move down',
            icon: AppIcons.arrowDown,
            shortcut: 'Alt ↓',
            onPressed: () => move(all, shown, index, index + 1),
          ),
        ],
      );
    }

    final categories = list.value?.categories ?? const <CategoryChoice>[];
    final visible = [
      for (final c in categories)
        if (!c.isHidden) c,
    ];
    final hidden = categories.length - visible.length;
    final uncategorized = list.value?.uncategorized ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.all(tokens.spacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.s8 + 2,
              tokens.spacing.s8,
              tokens.spacing.s8 + 2,
              tokens.spacing.s8 + 2,
            ),
            child: Text(
              'CATEGORIES',
              style: tokens.text.overline.copyWith(color: colors.textTertiary),
            ),
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowRight):
                    ?onEnterList,
              },
              child: FocusPane(
                debugLabel: 'live-categories',
                controller: controller,
                tabStop: true,
                child: list.hasError
                    ? const EmptyState(
                        compact: true,
                        icon: AppIcons.alertCircle,
                        title: "Couldn't load the categories",
                      )
                    : ListView(
                        children: [
                          _CategoryItem(
                            label: 'Favorites',
                            icon: AppIcons.star,
                            count: favorites,
                            selected: current is FavoriteChannels,
                            onPressed: () => show(const FavoriteChannels()),
                          ),
                          // Each group is a list of its own to zap
                          // through, in the user's order (decision 7).
                          for (final group in groups)
                            _CategoryItem(
                              label: group.name,
                              count: group.count,
                              nested: true,
                              selected:
                                  current is FavoriteGroupChannels &&
                                  current.groupId == group.id,
                              onPressed: () =>
                                  show(FavoriteGroupChannels(group.id)),
                            ),
                          _CategoryItem(
                            label: 'All channels',
                            count: all,
                            selected: current is AllChannels,
                            onPressed: () => show(const AllChannels()),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: tokens.spacing.s8,
                              horizontal: tokens.spacing.s4 + 2,
                            ),
                            child: Divider(height: 1, color: colors.surface3),
                          ),
                          if (list.isLoading && !list.hasValue)
                            for (var i = 0; i < 6; i++)
                              Padding(
                                padding: EdgeInsets.all(tokens.spacing.s8),
                                child: const Skeleton(height: 20),
                              ),
                          for (final (i, category) in visible.indexed)
                            _CategoryItem(
                              // Keyed, so the focus moves with a moved one.
                              key: ValueKey('category-${category.id}'),
                              label: category.name,
                              count: category.itemCount,
                              selected:
                                  current is CategoryChannels &&
                                  current.categoryId == category.id,
                              onPressed: () =>
                                  show(CategoryChannels(category.id)),
                              onMove: (by) =>
                                  move(categories, visible, i, i + by),
                              onMenu: (anchor) => unawaited(
                                categoryMenu(anchor, categories, visible, i),
                              ),
                            ),
                          if (uncategorized > 0)
                            _CategoryItem(
                              label: 'Uncategorized',
                              count: uncategorized,
                              selected: current is UncategorizedChannels,
                              onPressed: () =>
                                  show(const UncategorizedChannels()),
                            ),
                        ],
                      ),
              ),
            ),
          ),
          if (hidden > 0 || hiddenChannels > 0)
            Container(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.s8 + 2,
                tokens.spacing.s4,
                tokens.spacing.s4,
                0,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.surface3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hiddenLine(categories: hidden, channels: hiddenChannels),
                      style: tokens.text.labelSmall.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  AppButton(
                    label: 'Manage',
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.s,
                    onPressed: () {
                      final location = ref.read(
                        settingsLocationProvider.notifier,
                      );
                      // Only channels hidden: straight to where they
                      // come back.
                      if (hidden == 0) {
                        openHiddenChannels(
                          GoRouter.of(context),
                          location,
                          ref.read(hiddenChannelsRequestProvider.notifier),
                          sourceId: sourceId,
                        );
                        return;
                      }
                      location.showCategories(sourceId);
                      context.go(AppDestination.settings.path);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.count,
    this.icon,
    this.nested = false,
    this.onMove,
    this.onMenu,
    super.key,
  });

  final String label;
  final int? count;
  final AppIcons? icon;
  final bool selected;
  final VoidCallback onPressed;

  /// A group of favorites: under Favorites, set in by the star's width.
  final bool nested;

  /// Alt+↑ (-1) and Alt+↓ (+1): a category moves in the user's order.
  final void Function(int by)? onMove;

  /// The menu key: a category's menu.
  final void Function(BuildContext anchor)? onMenu;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final move = onMove;
    final menu = onMenu;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (move == null ||
            event is KeyUpEvent ||
            !HardwareKeyboard.instance.isAltPressed) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp) {
          move(-1);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          move(1);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Builder(
        builder: (anchor) => FocusableSurface(
          onPressed: onPressed,
          onMenu: menu == null ? null : () => menu(anchor),
          background: selected ? colors.surface3 : null,
          hoverBackground: colors.surface2,
          borderRadius: tokens.radii.controlAll,
          semanticLabel: count == null ? label : '$label, $count',
          builder: (context, states) => SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (selected)
                  Positioned(
                    left: 0,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: colors.accentBase,
                        borderRadius: tokens.radii.smAll,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.s8 + 2,
                  ),
                  child: Row(
                    children: [
                      if (icon case final icon?) ...[
                        AppIcon(icon, size: 16, color: colors.textSecondary),
                        SizedBox(width: tokens.spacing.s8 + 2),
                      ] else if (nested)
                        SizedBox(width: 16 + tokens.spacing.s8 + 2),
                      Expanded(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.text.label
                              .withWeight(selected ? 700 : 600)
                              .copyWith(
                                color: selected
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                              ),
                        ),
                      ),
                      if (count case final count?)
                        Text(
                          formatCount(count),
                          style: tokens.text.labelSmall.copyWith(
                            color: selected
                                ? colors.textSecondary
                                : colors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The categories pane's foot (sketch A): "3 categories · 2 channels
/// hidden", or one of the two.
String hiddenLine({required int categories, required int channels}) {
  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final parts = [
    if (categories > 0) count(categories, 'category', 'categories'),
    if (channels > 0) count(channels, 'channel', 'channels'),
  ];
  return '${parts.join(' · ')} hidden';
}
