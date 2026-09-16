import 'package:flutter/material.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// The shell's 64 px top bar (canvas; docs/05 said 56 px and the canvas
/// wins — ADR-008): screen title, source chip, search field, sync status,
/// download indicator and the cast button.
class ShellTopBar extends StatelessWidget {
  const new({
    required this.title,
    required this.onOpenSearch,
    this.source,
    this.syncStatus,
    this.downloads,
    this.onOpenSource,
    this.onOpenDownloads,
    this.onCast,
    this.paneController,
    super.key,
  });

  static const height = 64.0;
  static const searchWidth = 380.0;

  final String title;
  final VoidCallback onOpenSearch;
  final ShellSource? source;
  final ShellSyncStatus? syncStatus;
  final ShellDownloads? downloads;
  final VoidCallback? onOpenSource;
  final VoidCallback? onOpenDownloads;

  /// Null until Phase 7, which is why the cast button starts disabled.
  final VoidCallback? onCast;
  final FocusPaneController? paneController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: FocusPane(
        controller: paneController,
        debugLabel: 'top-bar',
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.h2.copyWith(color: colors.textPrimary),
              ),
            ),
            SizedBox(width: tokens.spacing.s16),
            _SourceChip(source: source, onPressed: onOpenSource),
            const Spacer(),
            SizedBox(width: tokens.spacing.s16),
            SearchField(width: searchWidth, onTap: onOpenSearch),
            if (syncStatus != null) ...[
              SizedBox(width: tokens.spacing.s16),
              _SyncStatus(status: syncStatus!),
            ],
            if (downloads != null) ...[
              SizedBox(width: tokens.spacing.s16),
              _DownloadIndicator(
                downloads: downloads!,
                onPressed: onOpenDownloads,
              ),
            ],
            SizedBox(width: tokens.spacing.s16),
            AppIconButton(
              icon: AppIcons.cast,
              tooltip: onCast == null ? 'Casting comes in Phase 7' : 'Cast',
              shortcut: 'C',
              bordered: true,
              onPressed: onCast,
            ),
          ],
        ),
      ),
    );
  }
}

/// The source switcher (canvas: a 32 px pill with a status dot and a
/// chevron). With no provider configured it reads "No source" and opens
/// Settings → Sources.
class _SourceChip extends StatelessWidget {
  const new({required this.source, required this.onPressed});

  final ShellSource? source;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final label = source?.name ?? 'No source';
    final dot = switch (source) {
      null => colors.textTertiary,
      ShellSource(connected: true) => colors.success,
      _ => colors.warning,
    };

    return AppTooltip(
      message: source == null ? 'Add a source' : 'Switch source',
      child: FocusableSurface(
        onPressed: onPressed,
        borderRadius: tokens.radii.pillAll,
        background: colors.surface2,
        hoverBackground: colors.surface3,
        semanticLabel: 'Source: $label',
        builder: (context, states) => Container(
          height: 32,
          padding: EdgeInsets.only(
            left: tokens.spacing.s8,
            right: tokens.spacing.s12,
          ),
          decoration: BoxDecoration(
            borderRadius: tokens.radii.pillAll,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              SizedBox(width: tokens.spacing.s8),
              Text(
                label,
                style: tokens.text.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(width: tokens.spacing.s8),
              AppIcon(
                AppIcons.chevronDown,
                size: 14,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Syncing channels · 12,340" or "Guide updated 12 min ago" (docs/05).
class _SyncStatus extends StatelessWidget {
  const new({required this.status});

  final ShellSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status.busy) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.accentBase,
            ),
          ),
          SizedBox(width: tokens.spacing.s8),
        ],
        Text(
          status.message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tokens.text.caption.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

/// "↓ 2 · 34 %" while downloads run; opens Library → Downloads (docs/09).
class _DownloadIndicator extends StatelessWidget {
  const new({required this.downloads, required this.onPressed});

  final ShellDownloads downloads;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final percent = (downloads.progress.clamp(0.0, 1.0) * 100).round();
    final label = '${downloads.active} · $percent %';

    return AppTooltip(
      message: 'Downloads',
      child: FocusableSurface(
        onPressed: onPressed,
        borderRadius: tokens.radii.controlAll,
        hoverBackground: colors.surface3,
        semanticLabel: '${downloads.active} downloads, $percent per cent',
        builder: (context, states) => Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.downloadActive,
                size: 16,
                color: colors.accentBase,
              ),
              SizedBox(width: tokens.spacing.s8 - 2),
              Text(
                label,
                style: tokens.text.caption.copyWith(color: colors.textEmphasis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
