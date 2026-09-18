import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_frame.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/category_groups.dart';

/// Onboarding step 4 (canvas `Onboarding · Pick categories`): turn off
/// the categories the user doesn't watch. Categories are clustered by
/// their country tag; each switch is saved as it is flipped, so Finish
/// only leaves.
class PickCategoriesScreen extends ConsumerStatefulWidget {
  const new({required this.sourceId, super.key});

  final String sourceId;

  @override
  ConsumerState<PickCategoriesScreen> createState() =>
      _PickCategoriesScreenState();
}

class _PickCategoriesScreenState extends ConsumerState<PickCategoriesScreen> {
  CatalogueKind _kind = CatalogueKind.live;
  var _filter = '';

  /// Groups the user opened or closed, by kind and label. Absent means
  /// the default: the first group open, the rest closed.
  final _expanded = <(CatalogueKind, String), bool>{};

  /// Switches flipped but not yet back from the database, so a tap shows
  /// at once (docs/05: optimistic updates for hide).
  final _pending = <int, bool>{};
  String? _writeError;

  CategoryList _apply(CategoryList list) {
    if (_pending.isEmpty) return list;
    return list.copyWith(
      categories: [
        for (final c in list.categories)
          if (_pending[c.id] case final hidden?)
            c.copyWith(isHidden: hidden)
          else
            c,
      ],
    );
  }

  Future<void> _write(
    Map<int, bool> changes,
    Future<Result<void>> Function(CategoryRepository repo) write,
  ) async {
    setState(() {
      _pending.addAll(changes);
      _writeError = null;
    });
    final result = await write(ref.read(categoryRepositoryProvider));
    if (!mounted) return;
    setState(() {
      for (final id in changes.keys) {
        if (_pending[id] == changes[id]) _pending.remove(id);
      }
      if (result case Err(:final failure)) {
        _writeError = "Couldn't save that change. ${failureMessage(failure)}";
      }
    });
  }

  void _toggle(CategoryChoice category) {
    final hidden = !category.isHidden;
    unawaited(
      _write({
        category.id: hidden,
      }, (repo) => repo.setHidden(category.id, hidden: hidden)),
    );
  }

  void _setMany(Iterable<CategoryChoice> categories, {required bool hidden}) {
    final ids = [for (final c in categories) c.id];
    if (ids.isEmpty) return;
    unawaited(
      _write({
        for (final id in ids) id: hidden,
      }, (repo) => repo.setHiddenMany(ids, hidden: hidden)),
    );
  }

  void _finish() {
    ref.read(pendingSourceDraftProvider.notifier).draft = null;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final lists = {
      for (final kind in CatalogueKind.values)
        kind: ref.watch(categoryListProvider(widget.sourceId, kind)),
    };
    final loading = lists.values.any((l) => !l.hasValue && !l.hasError);
    final error = lists.values
        .map((l) => l.error)
        .whereType<Object>()
        .firstOrNull;

    // Tabs for the kinds this source has at all.
    final kinds = [
      for (final kind in CatalogueKind.values)
        if (lists[kind]!.value case final list?
            when list.categories.isNotEmpty || list.uncategorized > 0)
          kind,
    ];
    if (!loading && kinds.isNotEmpty && !kinds.contains(_kind)) {
      _kind = kinds.first;
    }
    final current = lists[_kind]!.value;
    final list = current == null ? null : _apply(current);

    final Widget body;
    if (error != null) {
      body = ErrorState(
        title: "Couldn't load your categories",
        message: failureMessage(
          error is AppFailure ? error : AppFailure.fromError(error),
        ),
        onRetry: () {
          for (final kind in CatalogueKind.values) {
            ref.invalidate(categoryListProvider(widget.sourceId, kind));
          }
        },
      );
    } else if (loading || list == null) {
      body = const _Loading();
    } else if (kinds.isEmpty) {
      body = const EmptyState(
        icon: AppIcons.liveTv,
        title: 'Nothing to pick',
        message:
            'Your provider sent no categories, so everything it has will '
            'be shown. You can go straight on.',
      );
    } else {
      body = _Picker(
        kind: _kind,
        kinds: kinds,
        lists: {for (final kind in kinds) kind: _apply(lists[kind]!.value!)},
        filter: _filter,
        expanded: _expanded,
        writeError: _writeError,
        onKind: (kind) => setState(() => _kind = kind),
        onFilter: (text) => setState(() => _filter = text),
        onExpand: (group, {required open}) =>
            setState(() => _expanded[(_kind, group.label)] = open),
        onToggle: _toggle,
        onSetMany: _setMany,
      );
    }

    return OnboardingFrame(
      step: 3,
      title: 'Pick what you watch',
      subtitle:
          "Turn off what you don't need. Hidden categories can be shown "
          'again in Settings.',
      trailing: list == null || error != null || kinds.isEmpty
          ? null
          : _Summary(kind: _kind, list: list),
      body: body,
      footer: OnboardingFooter(
        leading: AppButton(
          label: 'Back',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.l,
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) router.pop();
          },
        ),
        note: switch (list?.uncategorized ?? 0) {
          0 => null,
          final n =>
            '${formatCount(n)} ${_noun(_kind, n)} without a category are '
                'always shown.',
        },
        actions: [
          AppButton(
            label: 'Finish',
            trailingIcon: AppIcons.arrowRight,
            size: AppButtonSize.l,
            onPressed: _finish,
          ),
        ],
      ),
    );
  }
}

String _noun(CatalogueKind kind, int count) => switch (kind) {
  CatalogueKind.live => count == 1 ? 'channel' : 'channels',
  CatalogueKind.movie => count == 1 ? 'movie' : 'movies',
  CatalogueKind.series => 'series',
};

String _kindLabel(CatalogueKind kind) => switch (kind) {
  CatalogueKind.live => 'Live TV',
  CatalogueKind.movie => 'Movies',
  CatalogueKind.series => 'Series',
};

class _Summary extends StatelessWidget {
  const new({required this.kind, required this.list});

  final CatalogueKind kind;
  final CategoryList list;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final kindWord = switch (kind) {
      CatalogueKind.live => 'live',
      CatalogueKind.movie => 'movie',
      CatalogueKind.series => 'series',
    };
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text.rich(
            TextSpan(
              text: formatCount(list.visibleCount),
              style: tokens.text.stat.copyWith(color: colors.textPrimary),
              children: [
                TextSpan(
                  text:
                      ' of ${formatCount(list.categories.length)} $kindWord '
                      'categories on',
                  style: tokens.text.label.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.s4),
          Text(
            '${formatCount(list.visibleItemCount)} of '
            '${formatCount(list.itemCount)} ${_noun(kind, list.itemCount)}',
            style: tokens.text.caption.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
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
          const Skeleton(width: 320, height: 40),
          SizedBox(height: spacing.s16),
          for (var i = 0; i < 5; i++) ...[
            const Skeleton(height: 56),
            SizedBox(height: spacing.s8),
          ],
        ],
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const new({
    required this.kind,
    required this.kinds,
    required this.lists,
    required this.filter,
    required this.expanded,
    required this.writeError,
    required this.onKind,
    required this.onFilter,
    required this.onExpand,
    required this.onToggle,
    required this.onSetMany,
  });

  final CatalogueKind kind;
  final List<CatalogueKind> kinds;
  final Map<CatalogueKind, CategoryList> lists;
  final String filter;
  final Map<(CatalogueKind, String), bool> expanded;
  final String? writeError;
  final ValueChanged<CatalogueKind> onKind;
  final ValueChanged<String> onFilter;
  final void Function(CategoryGroup group, {required bool open}) onExpand;
  final ValueChanged<CategoryChoice> onToggle;
  final void Function(Iterable<CategoryChoice>, {required bool hidden})
  onSetMany;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spacing = tokens.spacing;
    final list = lists[kind]!;
    final query = filter.trim().toLowerCase();
    final shown = query.isEmpty
        ? list.categories
        : [
            for (final c in list.categories)
              if (c.name.toLowerCase().contains(query)) c,
          ];
    // Clustered over the whole list, then filtered, so a match keeps its
    // group even when it is the only one left in it.
    final all = groupCategories(list.categories);
    // One cluster needs no header: a plain grid reads better.
    final flat = all.length == 1;
    final groups = query.isEmpty
        ? all
        : [
            for (final group in all)
              if (group.entries
                      .where(
                        (e) => e.category.name.toLowerCase().contains(query),
                      )
                      .toList()
                  case final entries when entries.isNotEmpty)
                CategoryGroup(
                  code: group.code,
                  label: group.label,
                  entries: entries,
                ),
          ];

    final slivers = <Widget>[];
    if (shown.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: EmptyState(
            compact: true,
            icon: AppIcons.search,
            title: list.categories.isEmpty
                ? 'No ${_kindLabel(kind).toLowerCase()} categories'
                : 'No categories match "$filter"',
            message: list.categories.isEmpty
                ? 'Everything here is shown without a category.'
                : null,
          ),
        ),
      );
    }
    for (final (index, group) in groups.indexed) {
      final open =
          flat ||
          query.isNotEmpty ||
          (expanded[(kind, group.label)] ?? index == 0);
      if (index > 0) {
        slivers.add(SliverToBoxAdapter(child: SizedBox(height: spacing.s8)));
      }
      slivers.add(
        DecoratedSliver(
          decoration: BoxDecoration(
            color: tokens.colors.surface1,
            borderRadius: tokens.radii.lgAll,
            border: Border.all(color: tokens.colors.surface3),
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (!flat)
                SliverToBoxAdapter(
                  child: _GroupHeader(
                    group: group,
                    open: open,
                    unit: _noun(kind, 2),
                    onExpand: query.isEmpty
                        ? () => onExpand(group, open: !open)
                        : null,
                    onCheck: () => onSetMany([
                      for (final e in group.entries) e.category,
                    ], hidden: group.visibleCount == group.entries.length),
                  ),
                ),
              if (open)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.s16 + 2,
                    flat ? spacing.s16 + 2 : 0,
                    spacing.s16 + 2,
                    spacing.s16 + 2,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      mainAxisExtent: 44,
                      crossAxisSpacing: spacing.s8,
                      mainAxisSpacing: spacing.s8,
                    ),
                    itemCount: group.entries.length,
                    itemBuilder: (context, i) => _CategoryTile(
                      entry: group.entries[i],
                      onPressed: () => onToggle(group.entries[i].category),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (kinds.length > 1) ...[
              SegmentedControl<CatalogueKind>(
                options: [
                  for (final k in kinds)
                    SegmentOption(
                      value: k,
                      label: _kindLabel(k),
                      count: formatCount(lists[k]!.categories.length),
                    ),
                ],
                value: kind,
                onChanged: onKind,
              ),
              SizedBox(width: spacing.s12),
            ],
            SearchField(
              key: ValueKey('filter-$kind'),
              hint: 'Filter categories',
              shortcut: null,
              width: 300,
              onChanged: onFilter,
            ),
            const Spacer(),
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
        if (writeError != null) ...[
          SizedBox(height: spacing.s12),
          AppBanner(message: writeError!, tone: BannerTone.error),
        ],
        SizedBox(height: spacing.s16),
        Expanded(
          child: FocusTraversalGroup(child: CustomScrollView(slivers: slivers)),
        ),
      ],
    );
  }
}

/// A country cluster's header row (canvas): its checkbox, name, tag,
/// counts and the chevron that opens it. The checkbox and the rest are
/// separate targets: Space on the checkbox flips the whole group, Enter
/// on the row opens or closes it.
class _GroupHeader extends StatelessWidget {
  const new({
    required this.group,
    required this.open,
    required this.unit,
    required this.onExpand,
    required this.onCheck,
  });

  final CategoryGroup group;
  final bool open;

  /// `channels`, `movies`, `series`.
  final String unit;

  /// Null while filtering: every matching group is open.
  final VoidCallback? onExpand;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final on = group.visibleCount;
    final all = group.entries.length;
    final state = on == all
        ? CheckState.on
        : on == 0
        ? CheckState.off
        : CheckState.mixed;
    final counts = on == all
        ? '$on of $all on · ${formatCount(group.itemCount)} $unit'
        : '$on of $all on · ${formatCount(group.visibleItemCount)} of '
              '${formatCount(group.itemCount)} $unit';

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: tokens.spacing.s8),
            child: FocusableSurface(
              onPressed: onCheck,
              borderRadius: tokens.radii.smAll,
              semanticLabel: state == CheckState.on
                  ? 'Hide every ${group.label} category'
                  : 'Show every ${group.label} category',
              builder: (context, states) => Padding(
                padding: EdgeInsets.all(tokens.spacing.s8 + 2),
                child: AppCheckbox(state: state, emphasized: states.focused),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              expanded: open,
              child: FocusableSurface(
                onPressed: onExpand,
                enabled: onExpand != null,
                borderRadius: tokens.radii.smAll,
                semanticLabel: '${group.label}, $counts',
                builder: (context, states) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.s8,
                    vertical: tokens.spacing.s8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tokens.text.titleSmall
                                    .withWeight(on == 0 ? 700 : 800)
                                    .copyWith(
                                      color: on == 0
                                          ? colors.textEmphasis
                                          : colors.textPrimary,
                                    ),
                              ),
                            ),
                            if (group.code case final code?
                                when code != group.label) ...[
                              SizedBox(width: tokens.spacing.s12),
                              AppBadge(code),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: tokens.spacing.s16),
                      Text(
                        counts,
                        style: tokens.text.caption.copyWith(
                          color: on == 0
                              ? colors.textTertiary
                              : colors.textSecondary,
                        ),
                      ),
                      if (onExpand != null) ...[
                        SizedBox(width: tokens.spacing.s12),
                        AppIcon(
                          open ? AppIcons.chevronUp : AppIcons.chevronDown,
                          size: 18,
                          color: states.highlighted
                              ? colors.textPrimary
                              : colors.textTertiary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.s8),
        ],
      ),
    );
  }
}

/// One category (canvas): checkbox, name without its tag, item count.
/// The whole tile is the switch.
class _CategoryTile extends StatelessWidget {
  const new({required this.entry, required this.onPressed});

  final CategoryEntry entry;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final on = !entry.category.isHidden;
    return Semantics(
      toggled: on,
      child: FocusableSurface(
        onPressed: onPressed,
        background: colors.surface2,
        hoverBackground: colors.surface3,
        semanticLabel:
            '${entry.category.name}, ${formatCount(entry.category.itemCount)}',
        builder: (context, states) => Container(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
          decoration: BoxDecoration(
            color: states.focused ? colors.surface3 : null,
            borderRadius: tokens.radii.controlAll,
          ),
          child: Row(
            children: [
              AppCheckbox(
                state: on ? CheckState.on : CheckState.off,
                emphasized: states.highlighted,
              ),
              SizedBox(width: tokens.spacing.s8 + 2),
              Expanded(
                child: Text(
                  entry.shortName,
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
              SizedBox(width: tokens.spacing.s8),
              Text(
                formatCount(entry.category.itemCount),
                style: tokens.text.labelSmall
                    .withWeight(500)
                    .copyWith(
                      color: states.focused
                          ? colors.textSecondary
                          : colors.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
