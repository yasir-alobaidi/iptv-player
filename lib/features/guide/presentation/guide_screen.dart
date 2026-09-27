import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_timeline.dart';
import 'package:iptv_player/features/guide/presentation/guide_grid.dart';
import 'package:iptv_player/features/guide/presentation/guide_text.dart';
import 'package:iptv_player/features/guide/presentation/guide_view_state.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';

/// Guide (canvas `Guide`, docs/05 §5): the day pills, Jump to now and
/// the category filter over the grid of the current source's channels.
///
/// The canvas draws those controls in the screen's header; here the
/// shell's top bar is shared by every screen (it holds the source
/// switcher and search), so they sit in a toolbar under it.
///
/// Every state (hard rule 4): no source; skeletons while the guide's
/// coverage is read; no guide yet, or one importing; a guide with nothing
/// from now on or nothing today; the grid; an import running over the
/// guide in use (a thin line on the card, the old guide still drawn); a
/// refresh that failed, offline or not (a line in the toolbar, the guide
/// in use still drawn).
class GuideScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSourceProvider);
    return FocusPane(
      debugLabel: 'screen-guide',
      child: source == null
          ? EmptyState(
              icon: AppIcons.guide,
              title: 'No guide yet',
              message: "Add your provider to see what's on its channels.",
              actionLabel: 'Add a source',
              onAction: () => context.push(addSourceRoutePath),
            )
          // Keyed by source: the grid's place and its cache belong to one.
          : _GuideView(key: ValueKey(source.id), source: source),
    );
  }
}

class _GuideView extends ConsumerStatefulWidget {
  const new({required this.source, super.key});

  final Source source;

  @override
  ConsumerState<_GuideView> createState() => _GuideViewState();
}

class _GuideViewState extends ConsumerState<_GuideView> {
  final _grid = GuideGridController();
  String? _error;
  GoRouter? _router;

  /// The path the router last showed, so a return to the Guide can be
  /// told from a notification that changed nothing (a sheet closing).
  String? _path;

  /// Builds again when the day changes (the pills' "Today") or the guide
  /// runs out, whichever comes first; nothing else would.
  Timer? _wake;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onLocation);
      _router = router?..routerDelegate.addListener(_onLocation);
      _path = router?.state.uri.path;
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onLocation);
    _wake?.cancel();
    _grid.dispose();
    super.dispose();
  }

  /// Back on the Guide from the player: the Guide shows no picture, so
  /// the stream stops (Live TV does the same when it is left).
  void _onLocation() {
    // The top route's path: a push (the player) leaves the delegate's
    // own configuration on the page under it.
    final path = _router?.state.uri.path;
    final previous = _path;
    _path = path;
    if (path != AppDestination.guide.path || previous == path) return;
    if (!ref.exists(playbackCoordinatorProvider)) return;
    final coordinator = ref.read(playbackCoordinatorProvider);
    if (coordinator.current != null) unawaited(coordinator.stop());
  }

  /// Watch channel: the player, full screen, zapping through the Guide's
  /// own list.
  void _watch(ChannelItem channel, ChannelQuery query) {
    unawaited(ref.read(playbackCoordinatorProvider).playLive(channel));
    unawaited(context.push(playerRoutePath, extra: query));
  }

  void _openSettings() {
    ref.read(settingsLocationProvider.notifier).showGuide(widget.source.id);
    context.go(AppDestination.settings.path);
  }

  void _refresh() => unawaited(
    ref.read(guideImportServiceProvider).importGuide(widget.source.id),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final sourceId = widget.source.id;
    final coverage = ref.watch(guideCoverageProvider(sourceId));
    final query = ref.watch(guideChannelsProvider);
    final now = ref.watch(appClockProvider)();
    final progress = ref.watch(guideImportProgressProvider(sourceId)).value;

    final value = coverage.value;
    _wakeFor(now, value?.lastEnd);
    if (coverage.hasError && value == null) {
      return ErrorState(
        title: "Couldn't read the guide",
        message: 'It could not be read from this computer.',
        details: '${coverage.error}',
        onRetry: () => ref.invalidate(guideCoverageProvider(sourceId)),
      );
    }
    if (value == null || query == null) return const _LoadingCard();
    if (!value.hasGuide) return _noGuide(value, progress);
    if (_nothingAhead(value, now) case final state?) return state;

    final timeline = GuideTimeline.forGuide(
      now: now,
      hourWidth: tokens.guide.hourWidth,
      firstStart: value.firstStart,
      lastEnd: value.lastEnd,
    );
    final failed =
        value.lastImport?.outcome == GuideImportOutcome.failed &&
        !value.isImporting;
    final spacing = tokens.spacing;
    // Built bottom-up so the grid comes first in the tree: a jump to the
    // Guide (Ctrl+3, G) focuses the first control, which should be the
    // grid. Tab still goes by position: the toolbar, then the grid.
    return Column(
      verticalDirection: VerticalDirection.up,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.s24,
              spacing.s12,
              spacing.s24,
              spacing.s16,
            ),
            child: GuideGrid(
              query: query,
              timeline: timeline,
              controller: _grid,
              onWatch: (channel) => _watch(channel, query),
              onError: (message) => setState(() => _error = message),
              importing: value.isImporting,
              importFraction: progress?.fraction,
            ),
          ),
        ),
        if (_error case final error?)
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.s24,
              spacing.s12,
              spacing.s24,
              0,
            ),
            child: AppBanner(
              message: error,
              tone: BannerTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.s24,
            spacing.s16,
            spacing.s24,
            0,
          ),
          child: _Toolbar(
            grid: _grid,
            timeline: timeline,
            now: now,
            query: query,
            status: value.isImporting
                ? _Status(line: importProgressLine(progress))
                : failed
                ? _Status(line: guideStaleLine(value, now), warning: true)
                : null,
          ),
        ),
      ],
    );
  }

  void _wakeFor(DateTime now, DateTime? lastEnd) {
    var at = nextDay(now);
    if (lastEnd != null && lastEnd.isAfter(now) && lastEnd.isBefore(at)) {
      at = lastEnd;
    }
    _wake?.cancel();
    _wake = Timer(at.difference(now), () {
      if (mounted) setState(() {});
    });
  }

  Widget _noGuide(GuideCoverage coverage, EpgImportProgress? progress) {
    if (coverage.isImporting) {
      return EmptyState(
        icon: AppIcons.loading,
        title: 'Importing the guide…',
        message:
            '${importProgressLine(progress)}. It shows here as soon as '
            "it's in.",
      );
    }
    final last = coverage.lastImport;
    if (last != null && last.outcome == GuideImportOutcome.failed) {
      return ErrorState(
        title: "Couldn't import the guide",
        message: importFailureMessage(last),
        onRetry: _refresh,
        retryLabel: 'Try again',
      );
    }
    return EmptyState(
      icon: AppIcons.guide,
      title: 'No guide yet',
      message: 'Import one from Settings → Guide.',
      actionLabel: 'Open Settings → Guide',
      onAction: _openSettings,
    );
  }

  /// A guide that has run out, or starts after today: nothing to draw
  /// around now.
  Widget? _nothingAhead(GuideCoverage coverage, DateTime now) {
    final lastEnd = coverage.lastEnd;
    final firstStart = coverage.firstStart;
    if (lastEnd == null || !lastEnd.isAfter(now)) {
      return EmptyState(
        icon: AppIcons.guide,
        title: 'Your guide has run out',
        message: lastEnd == null
            ? "It has no programmes. Refresh it to see what's on."
            : 'It ends ${dayInSentence(lastEnd, now)} at '
                  "${formatClock(lastEnd)}. Refresh it to see what's on.",
        actionLabel: coverage.isImporting ? null : 'Refresh guide',
        onAction: _refresh,
      );
    }
    if (firstStart != null && !firstStart.isBefore(nextDay(now))) {
      return EmptyState(
        icon: AppIcons.guide,
        title: 'Nothing in the guide for today',
        message:
            'It starts ${dayInSentence(firstStart, now)} '
            'at ${formatClock(firstStart)}. If its times look shifted, set a '
            'time offset in Settings → Guide.',
        actionLabel: 'Open Settings → Guide',
        onAction: _openSettings,
      );
    }
    return null;
  }
}

/// Day pills, Jump to now, the running import or a failed refresh, and
/// the category filter.
class _Toolbar extends ConsumerWidget {
  const new({
    required this.grid,
    required this.timeline,
    required this.now,
    required this.query,
    this.status,
  });

  final GuideGridController grid;
  final GuideTimeline timeline;
  final DateTime now;
  final ChannelQuery query;
  final Widget? status;

  /// Room a day pill takes, and what the toolbar keeps for the rest.
  static const _pillWidth = 84.0;
  static const _reserved = 440.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final spacing = tokens.spacing;
    final days = timeline.days(now);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room =
            constraints.maxWidth - _reserved - (status == null ? 0 : 220);
        final fit = (room / _pillWidth).floor().clamp(2, 99);
        final shown = days.take(fit).toList();
        return SizedBox(
          height: AppButtonSize.s.height,
          child: Row(
            children: [
              ListenableBuilder(
                listenable: grid,
                builder: (context, _) => SegmentedControl<DateTime?>(
                  options: [
                    for (final day in shown)
                      SegmentOption(
                        value: day,
                        label: switch (day) {
                          _ when day == startOfDay(now) => 'Today',
                          _ when day == nextDay(startOfDay(now)) => 'Tomorrow',
                          _ => formatDayPill(day),
                        },
                      ),
                  ],
                  value: shown.contains(grid.day) ? grid.day : null,
                  onChanged: (day) {
                    if (day != null) grid.showDay(day);
                  },
                ),
              ),
              SizedBox(width: spacing.s12),
              AppButton(
                label: 'Jump to now',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.s,
                onPressed: grid.jumpToNow,
              ),
              const Spacer(),
              if (status != null) ...[
                Flexible(child: status!),
                SizedBox(width: spacing.s12),
              ],
              _CategoryFilter(query: query),
            ],
          ),
        );
      },
    );
  }
}

/// A line in the toolbar: the import running, or a refresh that failed.
class _Status extends StatelessWidget {
  const new({required this.line, this.warning = false});

  final String line;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final color = warning ? colors.warning : colors.textTertiary;
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            warning ? AppIcons.alertTriangle : AppIcons.loading,
            size: 14,
            color: color,
          ),
          SizedBox(width: tokens.spacing.s8),
          Flexible(
            child: Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.text.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which channels the grid lists: all, favorites, a category.
class _CategoryFilter extends ConsumerWidget {
  const new({required this.query});

  final ChannelQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref
        .watch(categoryListProvider(query.sourceId, CatalogueKind.live))
        .value;
    final categories = [
      for (final category in list?.categories ?? const <CategoryChoice>[])
        if (!category.isHidden) category,
    ];
    final notifier = ref.read(guideChannelsProvider.notifier);
    final label = switch (query.filter) {
      AllChannels() => 'All channels',
      FavoriteChannels() => 'Favorites',
      UncategorizedChannels() => 'Uncategorized',
      CategoryChannels(:final categoryId) =>
        categories.where((c) => c.id == categoryId).firstOrNull?.name ??
            'Channels',
    };
    AppMenuItem item(String label, ChannelFilter filter) => AppMenuItem(
      label: label,
      checked: query.filter == filter,
      onPressed: () => notifier.showFilter(filter),
    );
    return Builder(
      builder: (anchor) => AppButton(
        label: label,
        trailingIcon: AppIcons.chevronDown,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.s,
        onPressed: () => unawaited(
          showAppMenu(
            anchor,
            width: 260,
            items: [
              item('All channels', const AllChannels()),
              item('Favorites', const FavoriteChannels()),
              if (categories.isNotEmpty) const AppMenuItem.separator(),
              for (final category in categories)
                item(category.name, CategoryChannels(category.id)),
              if ((list?.uncategorized ?? 0) > 0)
                item('Uncategorized', const UncategorizedChannels()),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grid's card with skeleton rows, while the guide's coverage is
/// read.
class _LoadingCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spacing = tokens.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.s24,
        spacing.s16 + AppButtonSize.s.height + spacing.s12,
        spacing.s24,
        spacing.s16,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.surface1,
          borderRadius: tokens.radii.lgAll,
          border: Border.all(color: tokens.colors.borderSubtle),
        ),
        child: ClipRRect(
          borderRadius: tokens.radii.lgAll,
          child: Padding(
            padding: EdgeInsets.only(top: tokens.guide.rulerHeight),
            child: const GuideSkeletonRows(),
          ),
        ),
      ),
    );
  }
}
