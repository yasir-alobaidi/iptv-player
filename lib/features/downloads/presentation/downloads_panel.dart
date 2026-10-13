import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/presentation/download_actions.dart';
import 'package:iptv_player/features/downloads/presentation/download_text.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';

/// Library → Downloads (canvas `Library · Downloads`): IN PROGRESS with
/// what each download is doing, NEEDS ATTENTION with the reason and what
/// to do, FINISHED TODAY with Play, and at the foot the space the
/// downloads take on their drive, with Change folder.
///
/// The list is one Tab stop with ↑/↓ inside. Enter does a row's main
/// thing (pause or resume, try again, play); the menu key has the rest;
/// Delete cancels or removes; Alt+↑/↓ moves a download in the queue, as
/// dragging its grip does.
class DownloadsPanel extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DownloadsPanel> createState() => _DownloadsPanelState();
}

class _DownloadsPanelState extends ConsumerState<DownloadsPanel> {
  final _list = FocusPaneController();
  final _nodes = <int, FocusNode>{};

  @override
  void dispose() {
    _list.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _node(int id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'download $id'));

  void _forgetGone(Iterable<DownloadTask> listed) {
    final ids = {for (final task in listed) task.id};
    _nodes.removeWhere((id, node) {
      if (ids.contains(id)) return false;
      // After the frame: the row that held it is being taken down.
      WidgetsBinding.instance.addPostFrameCallback((_) => node.dispose());
      return true;
    });
  }

  /// Moves [task] to where [target] is in the queue; the keyboard stays
  /// on it.
  void _moveTo(DownloadTask task, DownloadTask target, List<DownloadTask> all) {
    final index = all.indexWhere((each) => each.id == target.id);
    if (index < 0) return;
    unawaited(ref.read(downloadServiceProvider).move(task.id, index));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[task.id]?.requestFocus();
    });
  }

  /// The keyboard goes to the row that takes a removed one's place.
  void _focusAfter(DownloadTask gone, List<DownloadTask> rows) {
    if (_nodes[gone.id]?.hasFocus != true) return;
    final at = rows.indexWhere((each) => each.id == gone.id);
    final next = at < 0
        ? null
        : at + 1 < rows.length
        ? rows[at + 1]
        : at > 0
        ? rows[at - 1]
        : null;
    if (next != null) _nodes[next.id]?.requestFocus();
  }

  Future<void> _cancel(DownloadTask task, List<DownloadTask> rows) async {
    final service = ref.read(downloadServiceProvider);
    if (task.downloadedBytes > 0) {
      final confirmed = await showAppDialog<bool>(
        context,
        builder: (context) => AppDialog(
          title: 'Cancel this download?',
          primaryLabel: 'Cancel download',
          destructive: true,
          onPrimary: () => Navigator.of(context).pop(true),
          secondaryLabel: 'Keep downloading',
          onSecondary: () => Navigator.of(context).pop(false),
          child: Text(
            'The ${librarySize(task.downloadedBytes)} of '
            '${downloadName(task)} downloaded so far is deleted.',
            style: context.tokens.text.body.copyWith(
              color: context.tokens.colors.textSecondary,
            ),
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _focusAfter(task, rows);
    await service.cancel(task.id);
  }

  void _remove(DownloadTask task, List<DownloadTask> rows) {
    _focusAfter(task, rows);
    unawaited(ref.read(downloadServiceProvider).remove(task.id));
  }

  Future<void> _play(DownloadTask task) async {
    final notices = ref.read(appNoticesProvider);
    final launcher = ref.read(vodLauncherProvider);
    final progress = ref.read(watchProgressProvider);
    final id = task.libraryItemId;
    final item = id == null
        ? null
        : await ref.read(libraryRepositoryProvider).item(id);
    if (item == null) {
      notices.show(
        AppNotice(
          '${downloadName(task)} is no longer in your library.',
          tone: NoticeTone.error,
        ),
      );
      return;
    }
    final mark = await progress.watch(libraryVodRef(item)).first;
    await launcher.playLibraryItem(
      item,
      from: mark != null && mark.resumable ? mark.position : null,
    );
  }

  Future<void> _showInFolder(DownloadTask task) async {
    final notices = ref.read(appNoticesProvider);
    if (!await ref.read(fileRevealProvider).showInFolder(task.targetPath)) {
      notices.show(
        AppNotice("Couldn't open the folder.", tone: NoticeTone.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tasks = ref.watch(downloadTasksProvider);
    final now = ref.watch(appClockProvider)();

    final Widget body;
    switch (tasks) {
      case AsyncError(:final error):
        body = ErrorState(
          compact: true,
          title: "Couldn't load your downloads",
          message: 'The list could not be read.',
          details: '$error',
          onRetry: () => ref.invalidate(downloadTasksProvider),
        );
      case AsyncData(:final value):
        final sections = downloadSections(value, now);
        final listed = [
          ...sections.inProgress,
          ...sections.needsAttention,
          ...sections.finished,
        ];
        _forgetGone(listed);
        body = listed.isEmpty
            ? const EmptyState(
                compact: true,
                icon: AppIcons.download,
                title: downloadsEmptyTitle,
                message: downloadsEmptyMessage,
              )
            : _sections(sections, all: value, listed: listed);
      default:
        body = Column(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.s8 + 2),
                child: SkeletonRow(height: tokens.library.downloadRowHeight),
              ),
          ],
        );
    }

    // Sketch G: the queue stopped for want of room on the drive.
    final noSpace = (tasks.value ?? const <DownloadTask>[]).any(
      (task) =>
          task.state == DownloadTaskState.paused &&
          task.problem == DownloadProblem.noSpace,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (noSpace) ...[
          AppBanner(
            message: downloadSpaceBanner(
              ref.watch(downloadSpaceNeededProvider),
            ),
            tone: BannerTone.warning,
            actionLabel: 'Change folder',
            onAction: () => unawaited(
              pickDownloadFolder(ProviderScope.containerOf(context)),
            ),
          ),
          SizedBox(height: tokens.spacing.s12),
        ],
        Expanded(child: body),
        SizedBox(height: tokens.spacing.s12),
        _Storage(
          onChangeFolder: () =>
              unawaited(pickDownloadFolder(ProviderScope.containerOf(context))),
        ),
      ],
    );
  }

  Widget _sections(
    DownloadSections sections, {
    required List<DownloadTask> all,
    required List<DownloadTask> listed,
  }) {
    final tokens = context.tokens;
    final service = ref.read(downloadServiceProvider);
    final gap = SizedBox(height: tokens.spacing.s8 + 2);
    final running = sections.inProgress;

    Widget inProgress(int index) {
      final task = running[index];
      // What a queued download waits for: the one ahead of it.
      final before = index > 0 ? running[index - 1] : null;
      return _InProgressRow(
        key: ValueKey(task.id),
        task: task,
        before: before,
        index: index,
        focus: _node(task.id),
        onToggle: () => unawaited(
          task.state == DownloadTaskState.paused
              ? service.resume(task.id)
              : service.pause(task.id),
        ),
        onCancel: () => unawaited(_cancel(task, listed)),
        onMove: (by) {
          final to = index + by;
          if (to >= 0 && to < running.length) _moveTo(task, running[to], all);
        },
      );
    }

    return FocusPane(
      debugLabel: 'downloads',
      controller: _list,
      tabStop: true,
      child: ListView(
        children: [
          if (running.isNotEmpty) ...[
            _SectionHeader(label: 'IN PROGRESS', count: running.length),
            gap,
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: running.length,
              onReorderItem: (from, to) =>
                  _moveTo(running[from], running[to], all),
              proxyDecorator: (child, index, animation) =>
                  Material(type: MaterialType.transparency, child: child),
              itemBuilder: (context, index) => Padding(
                key: ValueKey(running[index].id),
                padding: EdgeInsets.only(bottom: tokens.spacing.s8 + 2),
                child: inProgress(index),
              ),
            ),
          ],
          if (sections.needsAttention.isNotEmpty) ...[
            if (running.isNotEmpty) SizedBox(height: tokens.spacing.s12),
            _SectionHeader(
              label: 'NEEDS ATTENTION',
              count: sections.needsAttention.length,
            ),
            gap,
            for (final task in sections.needsAttention) ...[
              _AttentionRow(
                key: ValueKey(task.id),
                task: task,
                focus: _node(task.id),
                onRetry: () => unawaited(service.retry(task.id)),
                onRemove: () => _remove(task, listed),
                onEditSource: () =>
                    unawaited(context.push(editSourcePath(task.sourceId))),
              ),
              gap,
            ],
          ],
          if (sections.finished.isNotEmpty) ...[
            if (running.isNotEmpty || sections.needsAttention.isNotEmpty)
              SizedBox(height: tokens.spacing.s12),
            _SectionHeader(
              label: 'FINISHED TODAY',
              count: sections.finished.length,
              action: 'Clear list',
              onAction: () => unawaited(service.clearFinished()),
            ),
            SizedBox(height: tokens.spacing.s4),
            for (final task in sections.finished)
              _FinishedRow(
                key: ValueKey(task.id),
                task: task,
                focus: _node(task.id),
                onPlay: () => unawaited(_play(task)),
                onShowInFolder: () => unawaited(_showInFolder(task)),
                onRemove: () => _remove(task, listed),
                onClear: () => unawaited(service.clearFinished()),
              ),
          ],
        ],
      ),
    );
  }
}

/// "IN PROGRESS 2", and at the right an action of the section's (Clear
/// list), which is the mouse's: the rows' menus have it for the keyboard.
class _SectionHeader extends StatelessWidget {
  const new({
    required this.label,
    required this.count,
    this.action,
    this.onAction,
  });

  final String label;
  final int count;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s4),
      child: Row(
        children: [
          Text(
            label,
            style: tokens.text.overline.copyWith(color: colors.textTertiary),
          ),
          SizedBox(width: tokens.spacing.s8),
          Text(
            '$count',
            style: tokens.text.labelSmall.copyWith(color: colors.textTertiary),
          ),
          const Spacer(),
          if (action case final action?)
            ExcludeFocus(
              child: FocusableSurface(
                onPressed: onAction,
                borderRadius: tokens.radii.smAll,
                semanticLabel: action,
                builder: (context, states) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.s4,
                    vertical: tokens.spacing.s4 / 2,
                  ),
                  child: Text(
                    action,
                    style: tokens.text.labelSmall
                        .withWeight(700)
                        .copyWith(
                          color: states.highlighted
                              ? colors.textPrimary
                              : colors.textTertiary,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row's picture in its 96 px box: a movie's poster upright, an
/// episode's still across.
class _Art extends StatelessWidget {
  const new({required this.task, required this.height, this.faded = false});

  final DownloadTask task;

  /// The row's height: the poster is as tall as it allows.
  final double height;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final layout = tokens.library;
    final movie = task.type == VodType.movie;
    final pictureHeight = movie
        ? (height - tokens.spacing.s12).clamp(0.0, layout.rowPosterHeight)
        : layout.rowStillHeight;
    final pictureWidth = movie
        ? pictureHeight * layout.rowPosterWidth / layout.rowPosterHeight
        : layout.rowArtBox;
    return SizedBox(
      width: layout.rowArtBox,
      child: Center(
        child: Opacity(
          opacity: faded ? 0.6 : 1,
          child: ClipRRect(
            borderRadius: tokens.radii.smAll,
            child: SizedBox(
              width: pictureWidth,
              height: pictureHeight,
              child: PosterArtwork(
                title: downloadTitle(task),
                showTitle: false,
                image: artworkFor(
                  context,
                  task.artworkUrl,
                  width: pictureWidth,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Copper Hollow  Movie · 2025".
class _TitleLine extends StatelessWidget {
  const new({required this.task, required this.strong});

  final DownloadTask task;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final subtitle = downloadSubtitle(task);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            downloadTitle(task),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.bodyStrong
                .withWeight(strong ? 800 : 700)
                .copyWith(color: colors.textPrimary),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(width: tokens.spacing.s8 + 2),
          Flexible(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.text.caption.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

/// The frame every row shares: the grip's place, the picture, what the
/// row says, and its buttons — which are the mouse's, the row itself
/// being what the keyboard is on.
class _RowFrame extends StatelessWidget {
  const new({
    required this.task,
    required this.height,
    required this.focus,
    required this.label,
    required this.onPressed,
    required this.onMenu,
    required this.body,
    required this.actions,
    this.grip,
    this.panel = true,
    this.faded = false,
  });

  final DownloadTask task;
  final double height;
  final FocusNode focus;
  final String label;
  final VoidCallback onPressed;
  final void Function(BuildContext anchor) onMenu;
  final Widget Function(SurfaceStates states) body;
  final List<Widget> Function(SurfaceStates states) actions;
  final Widget? grip;

  /// Drawn as a panel (in progress, needs attention); finished rows sit
  /// on the page.
  final bool panel;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Builder(
      builder: (anchor) => FocusableSurface(
        focusNode: focus,
        borderRadius: tokens.radii.mdAll,
        semanticLabel: label,
        onPressed: onPressed,
        onMenu: () => onMenu(anchor),
        builder: (context, states) => Container(
          height: height,
          padding: EdgeInsets.only(
            left: tokens.spacing.s8 + 2,
            right: tokens.spacing.s16,
          ),
          decoration: BoxDecoration(
            color: states.highlighted
                ? colors.surface3
                : panel
                ? colors.surface1
                : colors.surface1.withValues(alpha: 0),
            borderRadius: tokens.radii.mdAll,
            border: Border.all(
              color: states.highlighted
                  ? colors.border
                  : panel
                  ? colors.borderSubtle
                  : colors.borderSubtle.withValues(alpha: 0),
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: tokens.spacing.s16, child: grip),
              SizedBox(width: tokens.spacing.s16),
              _Art(task: task, height: height, faded: faded),
              SizedBox(width: tokens.spacing.s16),
              Expanded(child: body(states)),
              SizedBox(width: tokens.spacing.s16),
              ExcludeFocus(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, action) in actions(states).indexed) ...[
                      if (i > 0) SizedBox(width: tokens.spacing.s8),
                      action,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A download that is running, waiting or paused (canvas, 92 px): the
/// bar, "49%  1.0 GB of 2.1 GB · 8.4 MB/s · about 2 min left", Pause or
/// Resume, and Cancel.
class _InProgressRow extends StatelessWidget {
  const new({
    required this.task,
    required this.before,
    required this.index,
    required this.focus,
    required this.onToggle,
    required this.onCancel,
    required this.onMove,
    super.key,
  });

  final DownloadTask task;
  final DownloadTask? before;
  final int index;
  final FocusNode focus;
  final VoidCallback onToggle;
  final VoidCallback onCancel;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.library;
    final paused = task.state == DownloadTaskState.paused;
    final word = downloadStateWord(task);
    final details = downloadStateDetails(task, before: before);
    final caption = tokens.text.caption.copyWith(color: colors.textSecondary);

    void menu(BuildContext anchor) => unawaited(
      showAppMenu(
        anchor,
        items: [
          AppMenuItem(
            label: paused ? 'Resume' : 'Pause',
            icon: paused ? AppIcons.play : AppIcons.pause,
            shortcut: 'Enter',
            onPressed: onToggle,
          ),
          AppMenuItem(
            label: 'Move up',
            shortcut: 'Alt ↑',
            onPressed: () => onMove(-1),
          ),
          AppMenuItem(
            label: 'Move down',
            shortcut: 'Alt ↓',
            onPressed: () => onMove(1),
          ),
          AppMenuItem(
            label: 'Cancel download',
            icon: AppIcons.close,
            shortcut: 'Del',
            destructive: true,
            onPressed: onCancel,
          ),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
            onMove(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () =>
            onMove(1),
        const SingleActivator(LogicalKeyboardKey.delete): onCancel,
      },
      child: _RowFrame(
        task: task,
        height: layout.downloadRowHeight,
        focus: focus,
        label: '${downloadName(task)}, $word',
        onPressed: onToggle,
        onMenu: menu,
        grip: ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: AppIcon(
              AppIcons.dragHandle,
              size: 16,
              color: colors.textTertiary,
              semanticLabel: 'Drag to reorder',
            ),
          ),
        ),
        body: (states) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleLine(task: task, strong: states.focused),
            SizedBox(height: tokens.spacing.s8),
            ProgressBar(
              value: task.progress ?? 0,
              height: layout.rowBarHeight,
              color: paused ? colors.textTertiary : null,
              semanticLabel: 'Downloaded',
            ),
            SizedBox(height: tokens.spacing.s8),
            Row(
              children: [
                Text(
                  word,
                  style: caption
                      .withWeight(
                        task.state == DownloadTaskState.downloading ? 800 : 700,
                      )
                      .copyWith(
                        color: task.state == DownloadTaskState.downloading
                            ? colors.textPrimary
                            : colors.textEmphasis,
                      ),
                ),
                for (final (i, detail) in details.indexed) ...[
                  SizedBox(width: tokens.spacing.s8),
                  // "49%  1.0 GB of 2.1 GB" has no dot between them.
                  if (i > 0 || task.state != DownloadTaskState.downloading) ...[
                    Text(
                      '·',
                      style: caption.copyWith(color: colors.borderStrong),
                    ),
                    SizedBox(width: tokens.spacing.s8),
                  ],
                  Flexible(
                    child: Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: (states) => [
          // A queued download has nothing to pause yet (canvas).
          if (task.state != DownloadTaskState.queued)
            AppIconButton(
              icon: paused ? AppIcons.play : AppIcons.pause,
              tooltip: paused ? 'Resume' : 'Pause',
              bordered: true,
              onPressed: onToggle,
            ),
          AppIconButton(
            icon: AppIcons.close,
            tooltip: 'Cancel download',
            bordered: true,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// A download that stopped (canvas, 80 px): the reason in red, Retry and
/// Remove; an account the provider refused has Edit source first.
class _AttentionRow extends StatelessWidget {
  const new({
    required this.task,
    required this.focus,
    required this.onRetry,
    required this.onRemove,
    required this.onEditSource,
    super.key,
  });

  final DownloadTask task;
  final FocusNode focus;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final VoidCallback onEditSource;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final account = task.problem == DownloadProblem.auth;
    final reason = downloadProblemText(task);

    void menu(BuildContext anchor) => unawaited(
      showAppMenu(
        anchor,
        items: [
          if (account)
            AppMenuItem(
              label: 'Edit source',
              icon: AppIcons.edit,
              shortcut: 'Enter',
              onPressed: onEditSource,
            ),
          AppMenuItem(
            label: 'Retry',
            icon: AppIcons.retry,
            shortcut: account ? null : 'Enter',
            onPressed: onRetry,
          ),
          AppMenuItem(
            label: 'Remove',
            icon: AppIcons.close,
            shortcut: 'Del',
            destructive: true,
            onPressed: onRemove,
          ),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.delete): onRemove},
      child: _RowFrame(
        task: task,
        height: tokens.library.attentionRowHeight,
        focus: focus,
        label: '${downloadName(task)}, $reason',
        onPressed: account ? onEditSource : onRetry,
        onMenu: menu,
        faded: true,
        body: (states) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleLine(task: task, strong: false),
            SizedBox(height: tokens.spacing.s4 + 2),
            Row(
              children: [
                AppIcon(AppIcons.alertCircle, size: 14, color: colors.danger),
                SizedBox(width: tokens.spacing.s8),
                Flexible(
                  child: Text(
                    reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.caption
                        .withWeight(700)
                        .copyWith(color: colors.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: (states) => [
          if (account)
            AppButton(
              label: 'Edit source',
              icon: AppIcons.edit,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.s,
              onPressed: onEditSource,
            ),
          AppButton(
            label: 'Retry',
            icon: AppIcons.retry,
            variant: account
                ? AppButtonVariant.ghost
                : AppButtonVariant.secondary,
            size: AppButtonSize.s,
            onPressed: onRetry,
          ),
          if (!account)
            AppButton(
              label: 'Remove',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.s,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// A download finished today (canvas, 72 px): its size and when it
/// finished, Play and Show in folder.
class _FinishedRow extends StatelessWidget {
  const new({
    required this.task,
    required this.focus,
    required this.onPlay,
    required this.onShowInFolder,
    required this.onRemove,
    required this.onClear,
    super.key,
  });

  final DownloadTask task;
  final FocusNode focus;
  final VoidCallback onPlay;
  final VoidCallback onShowInFolder;
  final VoidCallback onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final line = downloadFinishedLine(task, tokens.timeStyle);

    void menu(BuildContext anchor) => unawaited(
      showAppMenu(
        anchor,
        items: [
          AppMenuItem(
            label: 'Play',
            icon: AppIcons.play,
            shortcut: 'Enter',
            onPressed: onPlay,
          ),
          AppMenuItem(
            label: 'Show in folder',
            icon: AppIcons.folder,
            onPressed: onShowInFolder,
          ),
          AppMenuItem(
            label: 'Remove from this list',
            icon: AppIcons.close,
            shortcut: 'Del',
            onPressed: onRemove,
          ),
          AppMenuItem(label: 'Clear list', onPressed: onClear),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.delete): onRemove},
      child: _RowFrame(
        task: task,
        height: tokens.library.finishedRowHeight,
        focus: focus,
        label: '${downloadName(task)}, $line',
        onPressed: onPlay,
        onMenu: menu,
        panel: false,
        body: (states) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleLine(task: task, strong: false),
            SizedBox(height: tokens.spacing.s4 + 1),
            Row(
              children: [
                AppIcon(AppIcons.check, size: 14, color: colors.success),
                SizedBox(width: tokens.spacing.s4 + 2),
                Flexible(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: (states) => [
          AppButton(
            label: 'Play',
            icon: AppIcons.play,
            // The row the keyboard or the mouse is on has the lit one
            // (canvas).
            variant: states.highlighted
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            size: AppButtonSize.s,
            onPressed: onPlay,
          ),
          AppIconButton(
            icon: AppIcons.folder,
            tooltip: 'Show in folder',
            bordered: true,
            size: AppButtonSize.s.height,
            iconSize: 18,
            onPressed: onShowInFolder,
          ),
        ],
      ),
    );
  }
}

/// The foot of the tab (canvas): "Downloads 42.3 GB · 118 GB free of 512
/// GB", the folder, the drive's bar — the downloads' share lit, the rest
/// of what is used dimmer — and Change folder.
class _Storage extends ConsumerWidget {
  const new({required this.onChangeFolder});

  final VoidCallback onChangeFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final folder = ref.watch(downloadFolderProvider).value;
    final disk = ref.watch(downloadDiskSpaceProvider).value;
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final totals = ref.watch(libraryFolderTotalsProvider).value ?? const {};
    final used = [
      for (final each in folders)
        if (each.isDownloadFolder) totals[each.id]?.bytes ?? 0,
    ].fold(0, (sum, bytes) => sum + bytes);
    final total = disk?.total ?? 0;
    final mine = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final others = total > 0
        ? ((total - disk!.free - used) / total).clamp(0.0, 1.0 - mine)
        : 0.0;
    // Under 5 GB or 5 %: the meter says so before a download has to stop.
    final low =
        disk != null &&
        (disk.free < 5 * 1024 * 1024 * 1024 || disk.free < total * 0.05);
    final free = downloadsFreeLabel(disk);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s16 + 2,
        vertical: tokens.spacing.s12 + 2,
      ),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.mdAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.storage, color: colors.textSecondary),
          SizedBox(width: tokens.spacing.s16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      downloadsUsedLabel(used),
                      style: tokens.text.caption
                          .withWeight(700)
                          .copyWith(color: colors.textPrimary),
                    ),
                    if (free.isNotEmpty) ...[
                      SizedBox(width: tokens.spacing.s8),
                      Text(
                        '·',
                        style: tokens.text.caption.copyWith(
                          color: colors.borderStrong,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.s8),
                      Text(
                        free,
                        style: tokens.text.caption.copyWith(
                          color: low ? colors.warning : colors.textSecondary,
                        ),
                      ),
                    ],
                    SizedBox(width: tokens.spacing.s16),
                    Expanded(
                      child: Text(
                        folder == null
                            ? ''
                            : displayFolderPath(
                                folder,
                                ref.watch(homeFolderProvider),
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: tokens.text.mono.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.s8),
                ClipRRect(
                  borderRadius: tokens.radii.pillAll,
                  child: SizedBox(
                    height: tokens.library.meterHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (mine > 0)
                          Expanded(
                            flex: (mine * 10000).round().clamp(1, 10000),
                            child: ColoredBox(
                              color: low ? colors.warning : colors.accentBase,
                            ),
                          ),
                        if (others > 0)
                          Expanded(
                            flex: (others * 10000).round().clamp(1, 10000),
                            child: ColoredBox(color: colors.borderStrong),
                          ),
                        Expanded(
                          flex: ((1 - mine - others) * 10000).round().clamp(
                            1,
                            10000,
                          ),
                          child: ColoredBox(color: colors.surface3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.s16),
          AppButton(
            label: 'Change folder',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.s,
            onPressed: onChangeFolder,
          ),
        ],
      ),
    );
  }
}
