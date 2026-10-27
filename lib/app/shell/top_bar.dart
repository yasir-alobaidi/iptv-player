import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/presentation/time_corner.dart';

/// The shell's 64 px top bar (canvas; docs/05 said 56 px and the canvas
/// wins — ADR-008): screen title, source chip, search field, sync status,
/// download indicator, the cast button, and the clock.
class ShellTopBar extends StatelessWidget {
  const new({
    required this.title,
    required this.onOpenSearch,
    this.source,
    this.sourceChoices,
    this.syncStatus,
    this.downloads,
    this.onOpenSource,
    this.onOpenDownloads,
    this.onCast,
    this.castConnected = false,
    this.showCast = true,
    this.paneController,
    this.onLeaveDown,
    this.clock,
    super.key,
  });

  static const height = 64.0;
  static const searchWidth = 380.0;

  /// The bar's width inside its padding, at the canvas's text size, from
  /// which the clock is drawn: it gives way first when the bar is
  /// cramped (a 1024 px window at 115 % text while a sync is said), where
  /// the window isn't full screen and the desktop's own clock shows.
  static const clockFrom = 850.0;

  final String title;
  final VoidCallback onOpenSearch;
  final ShellSource? source;

  /// Two or more sources turn the chip into a switcher menu.
  final ShellSourceChoices? sourceChoices;
  final ShellSyncStatus? syncStatus;
  final ShellDownloads? downloads;

  /// "Manage sources…", and the chip itself with fewer than two sources.
  final VoidCallback? onOpenSource;
  final VoidCallback? onOpenDownloads;

  /// The device picker; null disables the button (a build that can't
  /// cast, the component gallery).
  final VoidCallback? onCast;

  /// A cast is on: the connected icon, as the canvas draws it.
  final bool castConnected;

  /// False on a TV, which is the player itself (docs/07): no Cast button.
  final bool showCast;
  final FocusPaneController? paneController;

  /// Down from the bar, to the screen under it (a TV's remote); null:
  /// the arrows move as everywhere.
  final bool Function()? onLeaveDown;

  /// The time, for the clock at the bar's right end ([ShellClock]); null
  /// draws none (the component gallery).
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Container(
      height: context.scaled(height),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: FocusPane(
        controller: paneController,
        debugLabel: 'top-bar',
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): ?onLeaveDown,
          },
          child: LayoutBuilder(
            builder: (context, constraints) => _row(
              context,
              clock: constraints.maxWidth >= context.scaled(clockFrom)
                  ? clock
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, {required DateTime Function()? clock}) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Row(
      children: [
        // The title and the chip take the room the right end
        // doesn't, so the right end sits at the bar's edge (canvas).
        // A Spacer beside the Flexible title split the room with
        // it, and the search field stood off in the middle.
        Expanded(
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
              _SourceChip(
                source: source,
                choices: sourceChoices,
                onManage: onOpenSource,
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.spacing.s16),
        SearchField(width: searchWidth, onTap: onOpenSearch),
        if (syncStatus != null) ...[
          SizedBox(width: tokens.spacing.s16),
          _SyncStatus(status: syncStatus!),
        ],
        if (downloads != null) ...[
          SizedBox(width: tokens.spacing.s16),
          _DownloadIndicator(downloads: downloads!, onPressed: onOpenDownloads),
        ],
        if (showCast) ...[
          SizedBox(width: tokens.spacing.s16),
          AppIconButton(
            icon: castConnected ? AppIcons.castConnected : AppIcons.cast,
            tooltip: castConnected ? 'Casting' : 'Cast',
            shortcut: 'C',
            bordered: true,
            selected: castConnected,
            onPressed: onCast,
          ),
        ],
        if (clock case final clock?) ...[
          SizedBox(width: tokens.spacing.s16),
          ShellClock(clock: clock),
        ],
      ],
    );
  }
}

/// The source switcher (canvas: a 32 px pill with a status dot and a
/// chevron). With two or more sources it opens a menu of them and
/// "Manage sources…"; otherwise it opens Settings → Sources. With no
/// provider configured it reads "No source".
class _SourceChip extends StatelessWidget {
  const new({
    required this.source,
    required this.choices,
    required this.onManage,
  });

  final ShellSource? source;
  final ShellSourceChoices? choices;
  final VoidCallback? onManage;

  void _open(BuildContext context) {
    final choices = this.choices;
    if (choices == null || choices.sources.length < 2) {
      onManage?.call();
      return;
    }
    unawaited(
      showAppMenu(
        context,
        width: 260,
        items: [
          for (final choice in choices.sources)
            AppMenuItem(
              label: choice.name,
              checked: choice.id == source?.id,
              onPressed: () => choices.onSelect(choice.id),
            ),
          const AppMenuItem.separator(),
          AppMenuItem(
            label: 'Manage sources…',
            icon: AppIcons.settings,
            onPressed: onManage,
          ),
        ],
      ),
    );
  }

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

    final switcher = (choices?.sources.length ?? 0) >= 2;
    return AppTooltip(
      message: source == null
          ? 'Add a source'
          : switcher
          ? 'Switch source'
          : 'Manage sources',
      child: FocusableSurface(
        onPressed: onManage == null ? null : () => _open(context),
        borderRadius: tokens.radii.pillAll,
        background: colors.surface2,
        hoverBackground: colors.surface3,
        semanticLabel: 'Source: $label',
        builder: (context, states) => Container(
          height: context.scaled(32),
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
          // Still with reduce motion on, as every spinner.
          const AppSpinner(size: 14),
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
          height: context.scaled(32),
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

/// The time while browsing, at the top bar's right end (ADR-065): a full
/// screen window hides the desktop's own clock, and a TV shows none in an
/// app. A clock to glance at, as the player's corner is (ADR-053): quiet,
/// without AM/PM ("2:15"; "14:15" with a 24-hour clock in Appearance),
/// never a stop for the keys or the mouse. It turns with the minute on
/// its own.
class ShellClock extends StatefulWidget {
  const new({required this.clock, super.key});

  final DateTime Function() clock;

  @override
  State<ShellClock> createState() => _ShellClockState();
}

class _ShellClockState extends State<ShellClock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _schedule() {
    _tick = Timer(timeCornerWait(widget.clock()), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final now = widget.clock();
    return Text(
      formatClockShort(now, tokens.timeStyle),
      maxLines: 1,
      semanticsLabel: 'The time: ${formatClock(now, tokens.timeStyle)}',
      style: tokens.text.bodyStrong.copyWith(
        color: tokens.colors.textSecondary,
      ),
    );
  }
}
