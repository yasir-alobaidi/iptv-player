import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/shell/nav_rail.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/app/shell/toast_host.dart';
import 'package:iptv_player/app/shell/top_bar.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// The desktop shell (docs/05): nav rail, top bar, the current
/// destination, the casting bar and the toast area.
///
/// It owns no domain state. Everything it shows comes from the providers
/// in `shell_state.dart`, which later phases fill in.
class DesktopShell extends ConsumerStatefulWidget {
  const new({required this.navigationShell, this.onOpenSearch, super.key});

  /// The router's branch container; switching branches keeps each
  /// destination's state.
  final StatefulNavigationShell navigationShell;

  /// Ctrl+K and `/` go through the global shortcuts; the top bar's search
  /// field calls this.
  final VoidCallback? onOpenSearch;

  @override
  ConsumerState<DesktopShell> createState() => DesktopShellState();
}

class DesktopShellState extends ConsumerState<DesktopShell> {
  final _railPane = FocusPaneController();
  final _topBarPane = FocusPaneController();
  final _contentPane = FocusPaneController();
  final _toasts = ToastHostController();

  @override
  void dispose() {
    _railPane.dispose();
    _topBarPane.dispose();
    _contentPane.dispose();
    _toasts.dispose();
    super.dispose();
  }

  /// The branch the shell last drew, so a change can be told from a
  /// rebuild for any other reason (a toast, a resize, a source arriving).
  ///
  /// Read in [initState], not with `late`: a `late` initializer runs on
  /// first *read*, which is inside [didUpdateWidget], by which time the
  /// index has already moved and every change looks like none.
  int _branch = 0;

  @override
  void initState() {
    super.initState();
    _branch = widget.navigationShell.currentIndex;
  }

  GoRouter get _router => GoRouter.of(context);

  AppDestination get _current =>
      AppDestination.values[widget.navigationShell.currentIndex];

  void _go(AppDestination destination) => widget.navigationShell.goBranch(
    destination.index,
    // Tapping the destination you are already on goes back to its root,
    // which is go_router's own convention for a shell branch.
    initialLocation: destination.index == widget.navigationShell.currentIndex,
  );

  @override
  void didUpdateWidget(DesktopShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final branch = widget.navigationShell.currentIndex;
    if (branch == _branch) return;
    _branch = branch;
    _followTheJump();
  }

  /// Focus follows a destination jump into the new screen.
  ///
  /// Switching a branch pulls the keyboard focus into the new route's own
  /// scope, where nothing is focusable and no ring is drawn, so focus has
  /// to be placed deliberately either way:
  ///
  /// * Ctrl+1 … Ctrl+7 and Ctrl+, mean "take me there", so focus lands on
  ///   the first control of the screen that opened. Leaving it behind
  ///   costs a keyboard user a Tab walk back into the content every time.
  /// * Arrowing to a rail item and pressing Enter is the opposite
  ///   gesture: the user is working *in* the rail and wants to keep
  ///   browsing it, so the item they pressed gets its focus back.
  void _followTheJump() {
    // Read before the frame ends, while the old focus is still in place.
    final railItem = _railPane.hasFocus
        ? FocusManager.instance.primaryFocus
        : null;

    // The new branch is built in this frame and is only traversable once
    // it has been laid out, so the move waits for the frame to end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (railItem != null) {
        if (railItem.context != null) {
          railItem.requestFocus();
        } else {
          _railPane.focusPane();
        }
        return;
      }
      // The first control of the screen that opened, not the pane's
      // remembered item: the controller is shared by every branch, so
      // what it remembers may belong to the destination just left.
      _contentPane.focusFirst();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    ref.listen(nonFatalErrorsProvider, (previous, next) {
      final failure = next.value;
      if (failure == null) return;
      _toasts.show(
        ShellToast(message: failureWithAnswer(failure), tone: ToastTone.error),
      );
    });

    final wantsExpanded = ref.watch(railExpandedProvider);
    final source = ref.watch(shellSourceProvider);
    final sourceChoices = ref.watch(shellSourceChoicesProvider);
    final syncStatus = ref.watch(shellSyncStatusProvider);
    final notice = ref.watch(shellNoticeProvider);
    final downloads = ref.watch(shellDownloadsProvider);
    final cast = ref.watch(shellCastSessionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Below 1280 px the rail collapses whatever the user chose
        // (docs/05); their choice comes back when the window grows.
        final expanded =
            wantsExpanded &&
            constraints.maxWidth >= WindowSizes.railCollapseWidth;

        return Scaffold(
          backgroundColor: colors.bg,
          body: Actions(
            actions: {CloseTopIntent: _LeaveChromeAction(this)},
            child: Stack(
              children: [
                Row(
                  children: [
                    NavRail(
                      current: _current,
                      expanded: expanded,
                      onSelect: _go,
                      onToggleExpanded: () =>
                          ref.read(railExpandedProvider.notifier).toggle(),
                      paneController: _railPane,
                      // Left/Right between panes return to the item the user
                      // left from, or the pane's first (docs/05).
                      onLeaveRight: _contentPane.focusPane,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          ShellTopBar(
                            title: _current.label,
                            source: source,
                            sourceChoices: sourceChoices,
                            syncStatus: syncStatus,
                            downloads: downloads,
                            onOpenSearch: widget.onOpenSearch ?? () {},
                            onOpenSource: () => _go(AppDestination.settings),
                            onOpenDownloads: () => _go(AppDestination.library),
                            paneController: _topBarPane,
                          ),
                          if (notice != null) _NoticeBar(notice: notice),
                          Expanded(
                            child: _ContentPane(
                              controller: _contentPane,
                              onLeaveLeft: _railPane.focusPane,
                              child: widget.navigationShell,
                            ),
                          ),
                          if (cast != null)
                            CastingBar(
                              title: cast.title,
                              deviceName: cast.deviceName,
                              subtitle: cast.subtitle,
                              isPlaying: cast.isPlaying,
                              progress: cast.progress,
                              reconnecting: cast.reconnecting,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                ToastHost(controller: _toasts),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The shell's notice (expiry, refused sign-in), as a banner between the
/// top bar and the screen.
class _NoticeBar extends StatelessWidget {
  const new({required this.notice});

  final ShellNotice notice;

  @override
  Widget build(BuildContext context) {
    final spacing = context.tokens.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.s24, spacing.s12, spacing.s24, 0),
      child: Semantics(
        liveRegion: true,
        child: AppBanner(
          message: notice.message,
          tone: switch (notice.tone) {
            ShellNoticeTone.info => BannerTone.info,
            ShellNoticeTone.warning => BannerTone.warning,
            ShellNoticeTone.error => BannerTone.error,
          },
          actionLabel: notice.actionLabel,
          onAction: notice.onAction,
          onDismiss: notice.onDismiss,
        ),
      ),
    );
  }
}

/// Esc, while focus is in the shell's chrome: step back out into the
/// screen (docs/05).
///
/// Esc has one meaning everywhere — leave what you stepped into — and the
/// order matters: anything open (the search overlay, a dialog) closes
/// first, then focus in the rail or the top bar returns to the content,
/// and Esc with focus already in the content does nothing rather than
/// navigating somewhere the user did not ask for.
///
/// This shadows the global [CloseTopIntent] action while focus is inside
/// the shell — [Actions] resolves from the focused node outwards and does
/// not fall through to an outer action — so it has to pop as well.
class _LeaveChromeAction extends Action<CloseTopIntent> {
  new(this._shell);

  final DesktopShellState _shell;

  bool get _chromeHasFocus =>
      _shell._railPane.hasFocus || _shell._topBarPane.hasFocus;

  @override
  bool isEnabled(CloseTopIntent intent, [BuildContext? context]) =>
      _shell._router.canPop() || _chromeHasFocus;

  @override
  Object? invoke(CloseTopIntent intent) {
    if (_shell._router.canPop()) {
      _shell._router.pop();
      return null;
    }
    // Back to where the user was in the screen, not to its first control:
    // Esc is a step back, so it should return them, not relocate them.
    _shell._contentPane.focusPane();
    return null;
  }
}

/// The destination's pane. Left at its edge hands focus back to the rail;
/// a screen with its own horizontal movement (a rail of posters) binds
/// Left first and this never fires.
class _ContentPane extends StatelessWidget {
  const new({
    required this.controller,
    required this.onLeaveLeft,
    required this.child,
  });

  final FocusPaneController controller;
  final bool Function() onLeaveLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.arrowLeft): _LeaveContentIntent(),
    },
    child: Actions(
      actions: {
        _LeaveContentIntent: CallbackAction<_LeaveContentIntent>(
          onInvoke: (_) {
            onLeaveLeft();
            return null;
          },
        ),
      },
      child: FocusPane(
        controller: controller,
        debugLabel: 'content',
        child: child,
      ),
    ),
  );
}

class _LeaveContentIntent extends Intent {
  const new();
}
