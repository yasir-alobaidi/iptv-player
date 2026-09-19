import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/sources/presentation/source_text.dart';

/// Settings → Sources (the approved Phase 2 sketch): every source as a
/// card with its account, what it holds and how its last sync went, and
/// Refresh / Edit / more. Reordered by dragging the handle or with
/// Alt+↑ / Alt+↓; the order is the switcher's order.
class SourcesSettings extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SourcesSettings> createState() => _SourcesSettingsState();
}

class _SourcesSettingsState extends ConsumerState<SourcesSettings> {
  /// The order the user just made, shown until the database says the
  /// same; without it a dragged card would jump back for a frame.
  List<String>? _order;
  String? _error;

  void _add() {
    ref.read(pendingSourceDraftProvider.notifier).draft = null;
    ref.read(onboardingReturnPathProvider.notifier).path = GoRouterState.of(
      context,
    ).uri.path;
    unawaited(context.push<void>(addSourceRoutePath));
  }

  Future<void> _reorder(List<Source> sources, int from, int to) async {
    if (from == to || to < 0 || to >= sources.length) return;
    final ids = [for (final s in sources) s.id];
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    setState(() {
      _order = ids;
      _error = null;
    });
    final result = await ref.read(sourceRepositoryProvider).reorder(ids);
    if (!mounted) return;
    if (result case Err(:final failure)) {
      setState(() {
        _order = null;
        _error = "Couldn't save the new order. ${failureMessage(failure)}";
      });
    }
  }

  Future<void> _remove(Source source) async {
    final confirmed = await showAppDialog<bool>(
      context,
      builder: (context) => AppDialog(
        title: 'Remove ${source.name}?',
        destructive: true,
        primaryLabel: 'Remove',
        onPrimary: () => Navigator.of(context).pop(true),
        secondaryLabel: 'Keep',
        onSecondary: () => Navigator.of(context).pop(false),
        child: Text(
          'Its channels, movies, series and your category choices are '
          "removed from this computer. Your subscription isn't affected, "
          'and you can add the source again later.',
          style: context.tokens.text.body.copyWith(
            color: context.tokens.colors.textSecondary,
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final router = GoRouter.of(context);
    final removed = await ref.read(syncServiceProvider).removeSource(source.id);
    if (!mounted) return;
    switch (removed) {
      case Ok():
        ref.read(chosenSourceIdProvider.notifier).forget(source.id);
        final left = await ref.read(sourceRepositoryProvider).all();
        // The last source gone: back to the start, as on a first launch.
        if (left.valueOrNull?.isEmpty ?? false) router.go(welcomeRoutePath);
      case Err(:final failure):
        setState(
          () => _error =
              "Couldn't remove ${source.name}. ${failureMessage(failure)}",
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final sources = ref.watch(sourcesProvider);
    final current = ref.watch(currentSourceProvider);

    final list = sources.value;
    var ordered = list;
    if (list != null && _order != null) {
      final byId = {for (final s in list) s.id: s};
      if (_order!.length == list.length && _order!.every(byId.containsKey)) {
        ordered = [for (final id in _order!) byId[id]!];
        if (list.indexed.every((e) => e.$2.id == _order![e.$1])) {
          _order = null;
        }
      } else {
        _order = null;
      }
    }

    final Widget body;
    if (sources.hasError && list == null) {
      final error = sources.error!;
      body = ErrorState(
        title: "Couldn't load your sources",
        message: failureMessage(
          error is AppFailure ? error : AppFailure.fromError(error),
        ),
        onRetry: () => ref.invalidate(sourcesProvider),
      );
    } else if (ordered == null) {
      body = const _Loading();
    } else if (ordered.isEmpty) {
      body = EmptyState(
        icon: AppIcons.liveTv,
        title: 'No sources yet',
        message:
            'Add the Xtream account or playlist you already pay for, and '
            'its channels, movies and series appear here.',
        actionLabel: 'Add a source',
        onAction: _add,
      );
    } else {
      final shown = ordered;
      body = ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: shown.length,
        onReorderItem: (from, to) => unawaited(_reorder(shown, from, to)),
        proxyDecorator: (child, index, animation) =>
            Material(type: MaterialType.transparency, child: child),
        itemBuilder: (context, index) {
          final source = shown[index];
          return Padding(
            key: ValueKey(source.id),
            padding: EdgeInsets.only(bottom: tokens.spacing.s8),
            child: SourceCard(
              source: source,
              index: index,
              count: shown.length,
              isCurrent: shown.length > 1 && source.id == current?.id,
              onMove: (by) => unawaited(_reorder(shown, index, index + by)),
              onRemove: () => unawaited(_remove(source)),
            ),
          );
        },
      );
    }

    return SettingsPanel(
      title: 'Sources',
      subtitle: 'Where your channels, movies and series come from.',
      actions: [
        AppButton(
          label: 'Add source',
          icon: AppIcons.plus,
          variant: AppButtonVariant.secondary,
          onPressed: _add,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppBanner(
              message: _error!,
              tone: BannerTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
            SizedBox(height: tokens.spacing.s12),
          ],
          Expanded(child: body),
        ],
      ),
      footer: (ordered?.length ?? 0) < 2
          ? null
          : Text(
              'Drag a handle, or press Alt+↑ / Alt+↓, to reorder. The '
              'switcher in the top bar picks which source you browse.',
              style: tokens.text.caption.copyWith(
                color: tokens.colors.textTertiary,
              ),
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
      label: 'Loading sources',
      child: Column(
        children: [
          for (var i = 0; i < 2; i++) ...[
            const Skeleton(height: 112),
            SizedBox(height: spacing.s8),
          ],
        ],
      ),
    );
  }
}

/// One source (sketch): dot, name, type and account on the first line;
/// what it holds and when it synced on the second, or the live progress,
/// or why the last attempt failed; then its actions.
class SourceCard extends ConsumerWidget {
  const new({
    required this.source,
    required this.index,
    required this.count,
    required this.isCurrent,
    required this.onMove,
    required this.onRemove,
    super.key,
  });

  final Source source;
  final int index;
  final int count;

  /// Marked "Browsing" when there is more than one source.
  final bool isCurrent;

  /// Moves the card by -1 or +1.
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final overview = ref.watch(sourceOverviewProvider(source.id));
    final status =
        ref.watch(syncStatusProvider(source.id)).value ?? const SyncIdle();
    final now = ref.watch(appClockProvider)();
    final info = overview.value;
    final sync = ref.read(syncServiceProvider);
    final running = status is SyncRunning;
    final lastFailed =
        !running && info?.lastSync?.outcome == LastSyncOutcome.failed;
    final account = info?.account;

    final dot = switch ((running, lastFailed, account)) {
      (true, _, _) => colors.accentBase,
      (_, true, _) => colors.danger,
      (_, _, final a?)
          when !accountIsActive(a) || (daysToExpiry(a, now) ?? 0) < 0 =>
        colors.danger,
      (_, _, final a?)
          when (daysToExpiry(a, now) ?? expiryWarningDays) <
              expiryWarningDays =>
        colors.warning,
      _ when info?.lastSync == null => colors.textTertiary,
      _ => colors.success,
    };

    final headline = [
      sourceTypeLabel(source.type),
      if (account != null) accountSummary(account, now),
      if (source.lastSyncedAt == null && !running) 'never synced',
    ].join(' · ');

    final Widget detail;
    if (status case SyncRunning(:final progress)) {
      detail = Row(
        children: [
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.accentBase,
            ),
          ),
          SizedBox(width: tokens.spacing.s8),
          Flexible(
            child: _Line(
              syncProgressLine(progress),
              color: colors.textSecondary,
            ),
          ),
        ],
      );
    } else if (overview.hasError && info == null) {
      detail = _Line(
        "Couldn't read this source's details.",
        color: colors.danger,
      );
    } else if (info == null) {
      detail = const Skeleton.text(width: 260, height: 14);
    } else {
      final synced = source.lastSyncedAt;
      final parts = [
        if (!info.counts.isEmpty || synced != null) countsSummary(info.counts),
        if (synced != null) 'synced ${formatAgo(synced, now)}',
      ];
      detail = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parts.isNotEmpty)
            _Line(parts.join(' · '), color: colors.textTertiary),
          if (lastFailed) ...[
            if (parts.isNotEmpty) SizedBox(height: tokens.spacing.s4),
            _Line(
              'Last attempt failed: ${_failure(info.lastSync!)}',
              color: colors.danger,
            ),
          ] else if (parts.isEmpty)
            _Line('Nothing synced yet', color: colors.textTertiary),
        ],
      );
    }

    final never = info?.lastSync == null || source.lastSyncedAt == null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
            onMove(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () =>
            onMove(1),
      },
      child: Semantics(
        container: true,
        label: source.name,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.s4,
            tokens.spacing.s12 + 2,
            tokens.spacing.s16,
            tokens.spacing.s12 + 2,
          ),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: tokens.radii.controlAll,
            border: Border.all(
              color: isCurrent ? colors.accentSoftBorder : colors.surface2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (count > 1)
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spacing.s4),
                      child: AppIcon(
                        AppIcons.dragHandle,
                        size: 18,
                        color: colors.textTertiary,
                        semanticLabel: 'Drag to reorder',
                      ),
                    ),
                  ),
                )
              else
                SizedBox(width: tokens.spacing.s12),
              SizedBox(width: tokens.spacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: tokens.spacing.s8 + 2),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  source.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens.text.bodyStrong.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isCurrent) ...[
                                SizedBox(width: tokens.spacing.s8),
                                const AppBadge(
                                  'Browsing',
                                  tone: AppBadgeTone.accent,
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: tokens.spacing.s12),
                        // Inflexible, so it sits at the right edge; the
                        // name gives way first.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Text(
                            headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: tokens.text.caption.copyWith(
                              color: account == null
                                  ? colors.textSecondary
                                  : dot == colors.danger
                                  ? colors.danger
                                  : dot == colors.warning
                                  ? colors.warning
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.s4 + 2),
                    Padding(
                      padding: EdgeInsets.only(left: tokens.spacing.s16 + 2),
                      child: detail,
                    ),
                    SizedBox(height: tokens.spacing.s12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (running)
                          AppButton(
                            label: 'Cancel sync',
                            size: AppButtonSize.s,
                            variant: AppButtonVariant.ghost,
                            onPressed: () => unawaited(sync.cancel(source.id)),
                          )
                        else
                          AppButton(
                            label: lastFailed
                                ? 'Retry'
                                : never
                                ? 'Sync now'
                                : 'Refresh',
                            icon: AppIcons.retry,
                            size: AppButtonSize.s,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => unawaited(sync.sync(source.id)),
                          ),
                        SizedBox(width: tokens.spacing.s8),
                        AppButton(
                          label: 'Edit',
                          icon: AppIcons.edit,
                          size: AppButtonSize.s,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => unawaited(
                            context.push<void>(editSourcePath(source.id)),
                          ),
                        ),
                        SizedBox(width: tokens.spacing.s8),
                        Builder(
                          builder: (anchor) => AppIconButton(
                            icon: AppIcons.more,
                            tooltip: 'More for ${source.name}',
                            size: 36,
                            iconSize: 18,
                            bordered: true,
                            onPressed: () =>
                                unawaited(_more(anchor, ref, running: running)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _more(
    BuildContext anchor,
    WidgetRef ref, {
    required bool running,
  }) {
    final location = ref.read(settingsLocationProvider.notifier);
    final chosen = ref.read(chosenSourceIdProvider.notifier);
    return showAppMenu(
      anchor,
      width: 220,
      items: [
        if (count > 1)
          AppMenuItem(
            label: 'Browse this source',
            icon: AppIcons.eye,
            checked: isCurrent,
            onPressed: isCurrent ? null : () => chosen.choose(source.id),
          ),
        AppMenuItem(
          label: 'Categories…',
          icon: AppIcons.filter,
          onPressed: () => location.showCategories(source.id),
        ),
        AppMenuItem(
          label: 'Account details…',
          icon: AppIcons.info,
          onPressed: () => unawaited(
            showAppDialog<void>(
              anchor,
              builder: (context) => SourceDetailsDialog(source: source),
            ),
          ),
        ),
        if (count > 1) ...[
          const AppMenuItem.separator(),
          AppMenuItem(
            label: 'Move up',
            icon: AppIcons.arrowUp,
            shortcut: 'Alt ↑',
            onPressed: index == 0 ? null : () => onMove(-1),
          ),
          AppMenuItem(
            label: 'Move down',
            icon: AppIcons.arrowDown,
            shortcut: 'Alt ↓',
            onPressed: index == count - 1 ? null : () => onMove(1),
          ),
        ],
        const AppMenuItem.separator(),
        AppMenuItem(
          label: 'Remove…',
          icon: AppIcons.trash,
          destructive: true,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

String _failure(LastSync run) =>
    syncFailureMessage(run.failureCode, status: run.failureStatus);

class _Line extends StatelessWidget {
  const new(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: context.tokens.text.caption.copyWith(color: color),
  );
}

/// "Account details…": everything the app knows about a source, none of
/// it secret.
class SourceDetailsDialog extends ConsumerWidget {
  const new({required this.source, super.key});

  final Source source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final info = ref.watch(sourceOverviewProvider(source.id)).value;
    final now = ref.watch(appClockProvider)();
    final account = info?.account;
    final last = info?.lastSync;

    final rows = <(String, String)>[
      ('Type', sourceTypeLabel(source.type)),
      (
        switch (source.type) {
          SourceType.xtream => 'Server',
          SourceType.m3uUrl => 'Playlist',
          SourceType.m3uFile => 'File',
        },
        source.displayUrl,
      ),
      if (source.username case final user?) ('Username', user),
      if (account != null) ...[
        ('Status', account.status ?? 'Not reported'),
        (
          'Expires',
          switch (account.expiresAt) {
            null => 'Never',
            final at => switch (daysToExpiry(account, now)!) {
              < 0 => 'Expired ${formatDate(at)}',
              0 => '${formatDate(at)} · today',
              1 => '${formatDate(at)} · tomorrow',
              final days => '${formatDate(at)} · in $days days',
            },
          },
        ),
        if (account.isTrial) ('Trial', 'Yes'),
        if (account.maxConnections case final max?)
          (
            'Connections',
            account.activeConnections == null
                ? '$max allowed'
                : '${account.activeConnections} of $max in use',
          ),
        if (account.allowedFormats.isNotEmpty)
          (
            'Formats',
            account.allowedFormats.map((f) => f.toUpperCase()).join(', '),
          ),
        if (account.serverTimezone case final zone?) ('Time zone', zone),
      ],
      ('Live format', source.liveFormat == LiveFormat.ts ? 'TS' : 'HLS'),
      if (info != null) ('Holds', countsSummary(info.counts)),
      (
        'Last sync',
        switch (last) {
          null => 'Never',
          LastSync(outcome: LastSyncOutcome.running) => 'Running now',
          LastSync(
            outcome: LastSyncOutcome.failed,
            :final failureCode,
            :final failureStatus,
          ) =>
            'Failed ${formatAgo(last.finishedAt ?? last.startedAt, now)}: '
                '${syncFailureMessage(failureCode, status: failureStatus)}',
          LastSync(outcome: LastSyncOutcome.cancelled) =>
            'Cancelled ${formatAgo(last.finishedAt ?? last.startedAt, now)}',
          LastSync(:final finishedAt) =>
            'Finished ${formatAgo(finishedAt ?? last.startedAt, now)}',
        },
      ),
      ('Refreshes', 'every ${source.refreshHours} h, when the app opens'),
      ('Added', formatDate(source.createdAt)),
    ];

    return AppDialog(
      title: source.name,
      subtitle: 'Nothing here is secret: the password stays in your keyring.',
      primaryLabel: 'Done',
      onPrimary: () => Navigator.of(context).pop(),
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final (label, value) in rows)
              Container(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.s8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.surface3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(
                        label,
                        style: tokens.text.caption.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: tokens.text.caption.copyWith(
                          color: colors.textPrimary,
                        ),
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
