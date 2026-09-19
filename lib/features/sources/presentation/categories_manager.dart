import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';

/// Settings → Categories (the approved sketch: the Pick-categories layout
/// with per-row controls). Per source and kind: show or hide each
/// category, rename it, and put it in the user's order. Everything is
/// kept across re-syncs (docs/02).
class CategoriesManager extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CategoriesManager> createState() => _CategoriesManagerState();
}

class _CategoriesManagerState extends ConsumerState<CategoriesManager> {
  CatalogueKind _kind = CatalogueKind.live;
  var _filter = '';
  var _showHidden = true;

  /// Switches flipped and names changed but not yet back from the
  /// database, so each shows at once (docs/05: optimistic updates).
  final _hidden = <int, bool>{};
  final _names = <int, String>{};

  /// The order the user just made, by kind, until the database agrees.
  final _order = <CatalogueKind, List<int>>{};
  String? _error;

  /// Runs [write]; [settle] then drops the optimistic value, given
  /// whether the write worked.
  Future<void> _write(
    Future<Result<void>> Function(CategoryRepository repo) write, {
    required void Function({required bool ok}) settle,
  }) async {
    setState(() => _error = null);
    final result = await write(ref.read(categoryRepositoryProvider));
    if (!mounted) return;
    setState(() {
      settle(ok: result.isOk);
      if (result case Err(:final failure)) {
        _error = "Couldn't save that change. ${failureMessage(failure)}";
      }
    });
  }

  void _setHidden(Iterable<CategoryChoice> categories, {required bool hidden}) {
    final ids = [for (final c in categories) c.id];
    if (ids.isEmpty) return;
    setState(() {
      for (final id in ids) {
        _hidden[id] = hidden;
      }
    });
    unawaited(
      _write(
        (repo) => ids.length == 1
            ? repo.setHidden(ids.single, hidden: hidden)
            : repo.setHiddenMany(ids, hidden: hidden),
        settle: ({required ok}) {
          for (final id in ids) {
            if (_hidden[id] == hidden) _hidden.remove(id);
          }
        },
      ),
    );
  }

  /// Moves the category at [from] in [shown] past its neighbour there,
  /// in the full list's order ([all]), so a filtered list reorders
  /// sensibly.
  void _move(
    List<CategoryChoice> all,
    List<CategoryChoice> shown,
    int from,
    int to,
  ) {
    if (from == to || to < 0 || to >= shown.length) return;
    final ids = [for (final c in all) c.id];
    final moved = shown[from].id;
    final anchor = shown[to].id;
    ids.remove(moved);
    final at = ids.indexOf(anchor);
    ids.insert(to > from ? at + 1 : at, moved);
    final kind = _kind;
    setState(() => _order[kind] = ids);
    // The new order stays on screen until the database reports it
    // (see [_apply]); dropping it when the write returns could show the
    // old order for a frame.
    unawaited(
      _write(
        (repo) => repo.reorder(ids),
        settle: ({required ok}) {
          if (!ok) _order.remove(kind);
        },
      ),
    );
  }

  void _resetOrder(String sourceId) {
    final kind = _kind;
    setState(() => _order.remove(kind));
    unawaited(
      _write(
        (repo) => repo.resetOrder(sourceId, kind),
        settle: ({required ok}) {},
      ),
    );
  }

  Future<void> _rename(CategoryChoice category) async {
    final result = await showAppDialog<_RenameResult>(
      context,
      builder: (context) => _RenameDialog(category: category),
    );
    if (result == null || !mounted) return;
    final name = result.name?.trim();
    final value = name == null || name.isEmpty ? null : name;
    setState(
      () =>
          _names[category.id] = value ?? category.providerName ?? category.name,
    );
    unawaited(
      _write(
        (repo) => repo.rename(category.id, value),
        settle: ({required ok}) => _names.remove(category.id),
      ),
    );
  }

  CategoryList _apply(CategoryList list, CatalogueKind kind) {
    var categories = list.categories;
    if (_hidden.isNotEmpty || _names.isNotEmpty) {
      categories = [
        for (final c in categories)
          c.copyWith(
            isHidden: _hidden[c.id] ?? c.isHidden,
            name: _names[c.id] ?? c.name,
          ),
      ];
    }
    if (_order[kind] case final order?) {
      final byId = {for (final c in categories) c.id: c};
      if (order.length != categories.length || !order.every(byId.containsKey)) {
        _order.remove(kind);
      } else if (categories.indexed.every((e) => e.$2.id == order[e.$1])) {
        // The database has caught up.
        _order.remove(kind);
      } else {
        categories = [for (final id in order) byId[id]!];
      }
    }
    return list.copyWith(categories: categories);
  }

  void _addSource() {
    ref.read(pendingSourceDraftProvider.notifier).draft = null;
    ref.read(onboardingReturnPathProvider.notifier).path = GoRouterState.of(
      context,
    ).uri.path;
    unawaited(context.push<void>(addSourceRoutePath));
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesProvider).value;
    final wanted = ref.watch(settingsLocationProvider).categoriesSourceId;
    final current = ref.watch(currentSourceProvider);
    final source = sources?.where((s) => s.id == wanted).firstOrNull ?? current;

    if (sources == null) {
      return const SettingsPanel(title: 'Categories', body: _Loading());
    }
    if (source == null) {
      return SettingsPanel(
        title: 'Categories',
        body: EmptyState(
          icon: AppIcons.filter,
          title: 'No categories yet',
          message: 'Add a source first; its categories appear here.',
          actionLabel: 'Add a source',
          onAction: _addSource,
        ),
      );
    }

    final lists = {
      for (final kind in CatalogueKind.values)
        kind: ref.watch(categoryListProvider(source.id, kind)),
    };
    final loading = lists.values.any((l) => !l.hasValue && !l.hasError);
    final error = lists.values
        .map((l) => l.error)
        .whereType<Object>()
        .firstOrNull;
    final kinds = [
      for (final kind in CatalogueKind.values)
        if (lists[kind]!.value case final list?
            when list.categories.isNotEmpty || list.uncategorized > 0)
          kind,
    ];
    final kind = kinds.isEmpty || kinds.contains(_kind) ? _kind : kinds.first;
    final list = switch (lists[kind]!.value) {
      final value? => _apply(value, kind),
      null => null,
    };

    final Widget body;
    if (error != null) {
      body = ErrorState(
        title: "Couldn't load the categories",
        message: failureMessage(
          error is AppFailure ? error : AppFailure.fromError(error),
        ),
        onRetry: () {
          for (final kind in CatalogueKind.values) {
            ref.invalidate(categoryListProvider(source.id, kind));
          }
        },
      );
    } else if (loading || list == null) {
      body = const _Loading();
    } else if (kinds.isEmpty) {
      body = EmptyState(
        icon: AppIcons.filter,
        title: 'No categories from ${source.name}',
        message: source.lastSyncedAt == null
            ? "It hasn't synced yet. Categories appear after its first sync."
            : 'Your provider sends no categories, so everything is shown.',
      );
    } else {
      body = _Manager(
        list: list,
        kind: kind,
        filter: _filter,
        showHidden: _showHidden,
        onToggle: (c) => _setHidden([c], hidden: !c.isHidden),
        onSetMany: _setHidden,
        onMove: _move,
        onRename: (c) => unawaited(_rename(c)),
      );
    }

    final many = (sources.length) > 1;
    return SettingsPanel(
      title: 'Categories',
      subtitle: many
          ? 'Per source: what shows, what it is called, and in what order.'
          : '${source.name}: what shows, what it is called, and in what '
                'order.',
      actions: [
        if (many)
          Builder(
            builder: (anchor) => AppButton(
              label: source.name,
              trailingIcon: AppIcons.chevronDown,
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(
                showAppMenu(
                  anchor,
                  width: 260,
                  items: [
                    for (final s in sources)
                      AppMenuItem(
                        label: s.name,
                        checked: s.id == source.id,
                        onPressed: () => ref
                            .read(settingsLocationProvider.notifier)
                            .showCategories(s.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kinds.isNotEmpty && list != null && error == null) ...[
            _Toolbar(
              kinds: kinds,
              kind: kind,
              counts: {
                for (final k in kinds)
                  k: lists[k]!.value?.categories.length ?? 0,
              },
              showHidden: _showHidden,
              customOrder: list.customOrder || _order.containsKey(kind),
              onKind: (k) => setState(() {
                _kind = k;
                _filter = '';
              }),
              onFilter: (text) => setState(() => _filter = text),
              onShowHidden: () => setState(() => _showHidden = !_showHidden),
              onResetOrder: () => _resetOrder(source.id),
            ),
            SizedBox(height: context.tokens.spacing.s12),
          ],
          if (_error != null) ...[
            AppBanner(
              message: _error!,
              tone: BannerTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
            SizedBox(height: context.tokens.spacing.s12),
          ],
          Expanded(child: body),
        ],
      ),
      footer: kinds.isEmpty || list == null
          ? null
          : _Footer(kind: kind, list: list),
    );
  }
}

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final spacing = context.tokens.spacing;
    return Semantics(
      label: 'Loading categories',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 420, height: 36),
          SizedBox(height: spacing.s16),
          for (var i = 0; i < 6; i++) ...[
            const Skeleton(height: 48),
            SizedBox(height: spacing.s8),
          ],
        ],
      ),
    );
  }
}

String _kindLabel(CatalogueKind kind) => switch (kind) {
  CatalogueKind.live => 'Live TV',
  CatalogueKind.movie => 'Movies',
  CatalogueKind.series => 'Series',
};

String _noun(CatalogueKind kind, int count) => switch (kind) {
  CatalogueKind.live => count == 1 ? 'channel' : 'channels',
  CatalogueKind.movie => count == 1 ? 'movie' : 'movies',
  CatalogueKind.series => 'series',
};

class _Toolbar extends StatelessWidget {
  const new({
    required this.kinds,
    required this.kind,
    required this.counts,
    required this.showHidden,
    required this.customOrder,
    required this.onKind,
    required this.onFilter,
    required this.onShowHidden,
    required this.onResetOrder,
  });

  final List<CatalogueKind> kinds;
  final CatalogueKind kind;
  final Map<CatalogueKind, int> counts;
  final bool showHidden;
  final bool customOrder;
  final ValueChanged<CatalogueKind> onKind;
  final ValueChanged<String> onFilter;
  final VoidCallback onShowHidden;
  final VoidCallback onResetOrder;

  @override
  Widget build(BuildContext context) {
    final spacing = context.tokens.spacing;
    return Wrap(
      spacing: spacing.s12,
      runSpacing: spacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (kinds.length > 1)
          SegmentedControl<CatalogueKind>(
            options: [
              for (final k in kinds)
                SegmentOption(
                  value: k,
                  label: _kindLabel(k),
                  count: formatCount(counts[k] ?? 0),
                ),
            ],
            value: kind,
            onChanged: onKind,
          ),
        SearchField(
          key: ValueKey('manager-filter-$kind'),
          hint: 'Filter categories',
          shortcut: null,
          width: 260,
          onChanged: onFilter,
        ),
        AppChip(
          label: 'Show hidden',
          icon: AppIcons.eye,
          selected: showHidden,
          onPressed: onShowHidden,
        ),
        if (customOrder)
          AppButton(
            label: "Provider's order",
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.s,
            onPressed: onResetOrder,
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const new({required this.kind, required this.list});

  final CatalogueKind kind;
  final CategoryList list;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final shown = formatCount(list.visibleCount);
    final total = formatCount(list.categories.length);
    final loose =
        '${formatCount(list.uncategorized)} '
        '${_noun(kind, list.uncategorized)}';
    final parts = [
      '$shown of $total shown',
      if (list.uncategorized > 0) '$loose without a category are always shown',
      'Hidden categories stay hidden after a re-sync',
    ];
    return Semantics(
      liveRegion: true,
      child: Text(
        '${parts.join(' · ')}.',
        style: tokens.text.caption.copyWith(color: tokens.colors.textTertiary),
      ),
    );
  }
}

class _Manager extends StatelessWidget {
  const new({
    required this.list,
    required this.kind,
    required this.filter,
    required this.showHidden,
    required this.onToggle,
    required this.onSetMany,
    required this.onMove,
    required this.onRename,
  });

  final CategoryList list;
  final CatalogueKind kind;
  final String filter;
  final bool showHidden;
  final ValueChanged<CategoryChoice> onToggle;
  final void Function(Iterable<CategoryChoice>, {required bool hidden})
  onSetMany;
  final void Function(
    List<CategoryChoice> all,
    List<CategoryChoice> shown,
    int from,
    int to,
  )
  onMove;
  final ValueChanged<CategoryChoice> onRename;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final query = filter.trim().toLowerCase();
    final shown = [
      for (final c in list.categories)
        if ((showHidden || !c.isHidden) &&
            (query.isEmpty ||
                c.name.toLowerCase().contains(query) ||
                (c.providerName?.toLowerCase().contains(query) ?? false)))
          c,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                query.isEmpty
                    ? '${formatCount(shown.length)} '
                          '${shown.length == 1 ? 'category' : 'categories'}'
                    : '${formatCount(shown.length)} match "$filter"',
                style: tokens.text.labelSmall.copyWith(
                  color: tokens.colors.textTertiary,
                ),
              ),
            ),
            AppButton(
              label: 'Select all',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.s,
              onPressed: shown.isEmpty
                  ? null
                  : () => onSetMany(shown, hidden: false),
            ),
            AppButton(
              label: 'Select none',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.s,
              onPressed: shown.isEmpty
                  ? null
                  : () => onSetMany(shown, hidden: true),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.s8),
        Expanded(
          child: shown.isEmpty
              ? EmptyState(
                  compact: true,
                  icon: AppIcons.search,
                  title: query.isNotEmpty
                      ? 'No categories match "$filter"'
                      : 'Every category is hidden',
                  message: query.isNotEmpty
                      ? null
                      : 'Turn on Show hidden to see them.',
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: shown.length,
                  onReorderItem: (from, to) =>
                      onMove(list.categories, shown, from, to),
                  proxyDecorator: (child, index, animation) =>
                      Material(type: MaterialType.transparency, child: child),
                  itemBuilder: (context, index) {
                    final category = shown[index];
                    return Padding(
                      key: ValueKey(category.id),
                      padding: EdgeInsets.only(bottom: tokens.spacing.s4),
                      child: _CategoryRow(
                        category: category,
                        index: index,
                        unit: _noun(kind, category.itemCount),
                        onToggle: () => onToggle(category),
                        onRename: () => onRename(category),
                        onMove: (by) =>
                            onMove(list.categories, shown, index, index + by),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// One category (sketch): drag handle, the switch with its name, the
/// count, and Rename. Alt+↑ / Alt+↓ move it.
class _CategoryRow extends StatelessWidget {
  const new({
    required this.category,
    required this.index,
    required this.unit,
    required this.onToggle,
    required this.onRename,
    required this.onMove,
  });

  final CategoryChoice category;
  final int index;
  final String unit;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final on = !category.isHidden;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
            onMove(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () =>
            onMove(1),
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: tokens.radii.controlAll,
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8),
                  child: AppIcon(
                    AppIcons.dragHandle,
                    size: 16,
                    color: colors.textTertiary,
                    semanticLabel: 'Drag to reorder',
                  ),
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                toggled: on,
                child: FocusableSurface(
                  onPressed: onToggle,
                  borderRadius: tokens.radii.smAll,
                  hoverBackground: colors.surface3,
                  semanticLabel:
                      '${category.name}, '
                      '${formatCount(category.itemCount)} $unit',
                  builder: (context, states) => Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.s8,
                    ),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          AppCheckbox(
                            state: on ? CheckState.on : CheckState.off,
                            emphasized: states.highlighted,
                          ),
                          SizedBox(width: tokens.spacing.s12),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    category.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tokens.text.label
                                        .withWeight(states.focused ? 700 : 600)
                                        .copyWith(
                                          color: on || states.highlighted
                                              ? colors.textPrimary
                                              : colors.textSecondary,
                                        ),
                                  ),
                                ),
                                if (category.providerName
                                    case final original?) ...[
                                  SizedBox(width: tokens.spacing.s8),
                                  Flexible(
                                    child: Text(
                                      'was $original',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tokens.text.labelSmall.copyWith(
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(width: tokens.spacing.s12),
                          Text(
                            '${formatCount(category.itemCount)} $unit',
                            style: tokens.text.labelSmall
                                .withWeight(500)
                                .copyWith(color: colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.s4),
            AppIconButton(
              icon: AppIcons.edit,
              tooltip: 'Rename ${category.name}',
              size: 36,
              iconSize: 16,
              onPressed: onRename,
            ),
            SizedBox(width: tokens.spacing.s4),
          ],
        ),
      ),
    );
  }
}

final class _RenameResult {
  const new(this.name);

  /// Null or blank: the provider's name.
  final String? name;
}

class _RenameDialog extends StatefulWidget {
  const new({required this.category});

  final CategoryChoice category;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.category.name)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.category.name.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_RenameResult(_controller.text));

  @override
  Widget build(BuildContext context) {
    final original = widget.category.providerName;
    return AppDialog(
      title: 'Rename category',
      focusButtons: false,
      subtitle: original == null
          ? 'Only this app sees the new name.'
          : 'Your provider calls it "$original".',
      primaryLabel: 'Save',
      onPrimary: _save,
      secondaryLabel: original == null ? 'Cancel' : "Use provider's name",
      onSecondary: () =>
          Navigator.of(context)
              .pop(original == null ? null : const _RenameResult(null)),
      child: AppTextField(
        controller: _controller,
        label: 'Name',
        autofocus: true,
        onSubmitted: (_) => _save(),
      ),
    );
  }
}
