import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';

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
    final notifier = ref.read(liveTvControllerProvider.notifier);

    void show(ChannelFilter filter) {
      notifier.showFilter(filter);
      onChosen?.call();
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
                          for (final category in visible)
                            _CategoryItem(
                              label: category.name,
                              count: category.itemCount,
                              selected:
                                  current is CategoryChannels &&
                                  current.categoryId == category.id,
                              onPressed: () =>
                                  show(CategoryChannels(category.id)),
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
          if (hidden > 0)
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
                      '$hidden ${hidden == 1 ? 'category' : 'categories'} '
                      'hidden',
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
                      ref
                          .read(settingsLocationProvider.notifier)
                          .showCategories(sourceId);
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
  });

  final String label;
  final int? count;
  final AppIcons? icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      onPressed: onPressed,
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
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8 + 2),
              child: Row(
                children: [
                  if (icon case final icon?) ...[
                    AppIcon(icon, size: 16, color: colors.textSecondary),
                    SizedBox(width: tokens.spacing.s8 + 2),
                  ],
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
    );
  }
}
