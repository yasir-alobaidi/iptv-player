import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/nav_rail.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/app/shell/top_bar.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// The desktop shell (docs/05): nav rail, top bar, the current
/// destination and the casting bar. Toasts show over every route
/// (`AppToasts`).
///
/// It owns no domain state. Everything it shows comes from the providers
/// in `shell_state.dart`, which later phases fill in.
class DesktopShell extends ConsumerStatefulWidget {
  const new({
    required this.navigationShell,
    this.onOpenSearch,
    this.immersive = false,
    super.key,
  });

  /// The router's branch container; switching branches keeps each
  /// destination's state.
  final StatefulNavigationShell navigationShell;

  /// A page that draws edge to edge under no top bar: a title's details
  /// (the canvas draws none there).
  final bool immersive;

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
  bool _hadOverlay = false;

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepFocusOnTv);
    _railPane.dispose();
    _topBarPane.dispose();
    _contentPane.dispose();
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
    // A remote has no pointer to start from: on a TV the first screen
    // opens with its first control focused, as every screen after it
    // does (docs/07). A desktop starts with nothing focused.
    if (ref.read(formFactorProvider) == FormFactor.tv) {
      _focusFirstOnTv();
      FocusManager.instance.addListener(_keepFocusOnTv);
    }
  }

  bool _refocusing = false;

  /// A remote has no pointer to put the focus back: on a TV something in
  /// the shell always has it. Back from a page above (the sign-in, a
  /// title) or a closed dialog can leave it on no control; then the
  /// screen's remembered item, or its first, takes it.
  void _keepFocusOnTv() {
    final focused = FocusManager.instance.primaryFocus;
    if (_refocusing || (focused != null && focused is! FocusScopeNode)) {
      return;
    }
    _refocusing = true;
    // After the frame that closed what had it; a lost focus asks for no
    // frame of its own, so one is asked for.
    WidgetsBinding.instance
      ..addPostFrameCallback(
        (_) => scheduleMicrotask(() {
          _refocusing = false;
          // After the screen's own autofocus (a title's Play), a microtask
          // queued while it was built.
          if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
          final now = FocusManager.instance.primaryFocus;
          if (now != null && now is! FocusScopeNode) return;
          // The pane may remember the route's own scope, which shows
          // nothing focused: its first control then.
          final last = _contentPane.lastFocused;
          if (last != null && last is! FocusScopeNode && last.canRequestFocus) {
            last.requestFocus();
          } else if (!_contentPane.focusFirst()) {
            _railPane.focusPane();
          }
        }),
      )
      ..scheduleFrame();
  }

  /// The first screen's controls come with its data (Home's rows), and
  /// the route's own scope takes the focus once after the first frame:
  /// checks every 100 ms for 2 s until a control has it, and stops at
  /// anything focused, the user's own first press included.
  void _focusFirstOnTv([int tries = 20]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tries == 0) return;
      final focused = FocusManager.instance.primaryFocus;
      if (focused != null && focused is! FocusScopeNode) return;
      _contentPane.focusFirst();
      Timer(
        const Duration(milliseconds: 100),
        () => _focusFirstOnTv(tries - 1),
      );
    });
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
      // A screen that asked for its own focus (autofocus: the details
      // pages' Play) keeps it. Autofocus lands in the focus manager's
      // next update, a microtask queued while the screen was built, so
      // this looks after it.
      scheduleMicrotask(() {
        if (!mounted) return;
        final focused = FocusManager.instance.primaryFocus;
        if (_contentPane.hasFocus && focused is! FocusScopeNode) return;
        // The first control of the screen that opened, not the pane's
        // remembered item: the controller is shared by every branch, so
        // what it remembers may belong to the destination just left.
        _contentPane.focusFirst();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    final wantsExpanded = ref.watch(railExpandedProvider);
    final source = ref.watch(shellSourceProvider);
    final sourceChoices = ref.watch(shellSourceChoicesProvider);
    final syncStatus = ref.watch(shellSyncStatusProvider);
    final notice = ref.watch(shellNoticeProvider);
    final offline = ref.watch(appOfflineProvider).value ?? false;
    final downloads = ref.watch(shellDownloadsProvider);
    final cast = ref.watch(shellCastSessionProvider);
    final castButton = ref.watch(shellCastButtonProvider);
    final overlay = ref.watch(shellContentOverlayProvider);
    if (overlay == null && _hadOverlay) {
      // The screen is back from under the overlay: the keyboard with it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _contentPane.focusPane();
      });
    }
    _hadOverlay = overlay != null;

    final onTv = ref.watch(formFactorProvider) == FormFactor.tv;
    final shell = LayoutBuilder(
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
                      showToggle: !onTv,
                      destinations: AppDestination.primaryOn(
                        ref.watch(formFactorProvider),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          if (!widget.immersive)
                            ShellTopBar(
                              title: _current.label,
                              source: source,
                              sourceChoices: sourceChoices,
                              syncStatus: syncStatus,
                              downloads: downloads,
                              onOpenSearch: widget.onOpenSearch ?? () {},
                              onOpenSource: () => _go(AppDestination.settings),
                              onOpenDownloads: () {
                                ref.read(shellShowDownloadsProvider)?.call();
                                _go(AppDestination.library);
                              },
                              onCast: castButton == null
                                  ? null
                                  : () => castButton.onPressed(context),
                              castConnected: castButton?.connected ?? false,
                              showCast: ref.watch(castsToTvsProvider),
                              paneController: _topBarPane,
                              onLeaveDown: onTv ? _contentPane.focusPane : null,
                            ),
                          if (notice != null && !widget.immersive)
                            _NoticeBar(notice: notice),
                          if (offline && !widget.immersive)
                            _OfflineBar(
                              // Already there: nothing to open.
                              onOpenLibrary: _current == AppDestination.library
                                  ? null
                                  : () => _go(AppDestination.library),
                            ),
                          Expanded(
                            child: _ContentPane(
                              controller: _contentPane,
                              onLeaveLeft: _railPane.focusPane,
                              // A remote reaches the top bar (search, the
                              // source) only so; a keyboard also by Tab.
                              onLeaveUp: onTv && !widget.immersive
                                  ? _topBarPane.focusPane
                                  : null,
                              textFieldsKeepArrows: !onTv,
                              child: overlay == null
                                  ? widget.navigationShell
                                  : Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Kept, as it was, under the
                                        // overlay: back to it on Esc.
                                        Offstage(
                                          child: ExcludeFocus(
                                            child: TickerMode(
                                              enabled: false,
                                              child: widget.navigationShell,
                                            ),
                                          ),
                                        ),
                                        overlay,
                                      ],
                                    ),
                            ),
                          ),
                          if (cast != null)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                tokens.spacing.s16,
                                0,
                                tokens.spacing.s16,
                                tokens.spacing.s16,
                              ),
                              child: CastingBar(
                                title: cast.title,
                                deviceName: cast.deviceName,
                                imageName: cast.imageName,
                                image: artworkFor(
                                  context,
                                  cast.imageUrl,
                                  width: tokens.cast.barLogo,
                                ),
                                quality: cast.quality,
                                status: cast.status,
                                isPlaying: cast.isPlaying,
                                reconnecting: cast.reconnecting,
                                onOpen: cast.onOpen,
                                onPlayPause: cast.onPlayPause,
                                onStop: cast.onStop,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    // A TV's Back at a section's root goes Home; on Home it leaves the
    // app. A desktop has no system back.
    return ref.watch(formFactorProvider) == FormFactor.tv
        ? BackButtonListener(onBackButtonPressed: _backOnTv, child: shell)
        : shell;
  }

  /// Android leaves an app on Back from any section's root: a remote's
  /// Back from Settings closed Bijou. A page above the section (a film's,
  /// a dialog) is popped as before.
  Future<bool> _backOnTv() async {
    if (GoRouter.of(context).canPop()) return false;
    if (_current == AppDestination.home) return false;
    _go(AppDestination.home);
    return true;
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

/// "You're offline", under the top bar of every screen while the app's
/// network status says so (Phase 8 decision 11; on every screen since
/// Phase 9 step 7): what is on this computer still plays, and the Library
/// is where it is.
class _OfflineBar extends StatelessWidget {
  const new({required this.onOpenLibrary});

  /// Null on the Library itself.
  final VoidCallback? onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final spacing = context.tokens.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.s24, spacing.s12, spacing.s24, 0),
      child: Semantics(
        liveRegion: true,
        child: AppBanner(
          message: "You're offline — downloads and local files still play.",
          tone: BannerTone.warning,
          actionLabel: onOpenLibrary == null ? null : 'Open Library',
          onAction: onOpenLibrary,
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

/// The destination's pane. Left at its edge hands focus back to the rail,
/// and on a TV Up at its top to the top bar: an arrow moves within the
/// screen first, so Left in a row of tabs or buttons walks the row (the
/// user, on the Bedroom TV: Left in Favorites' tabs jumped to the rail).
/// A screen with its own horizontal movement (a rail of posters) binds
/// Left first and this never fires.
class _ContentPane extends StatelessWidget {
  const new({
    required this.controller,
    required this.onLeaveLeft,
    required this.child,
    this.onLeaveUp,
    this.textFieldsKeepArrows = true,
  });

  final FocusPaneController controller;
  final bool Function() onLeaveLeft;

  /// Null: Up stays in the screen.
  final bool Function()? onLeaveUp;

  /// A keyboard's arrows move the caret in a text field (the desktop).
  final bool textFieldsKeepArrows;
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft):
          const _LeaveContentIntent(TraversalDirection.left),
      if (onLeaveUp != null)
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const _LeaveContentIntent(TraversalDirection.up),
    },
    child: Actions(
      actions: {
        _LeaveContentIntent: _LeaveContentAction(
          onLeave: (direction) => switch (direction) {
            TraversalDirection.up => onLeaveUp?.call(),
            _ => onLeaveLeft(),
          },
          textFieldsKeepArrows: textFieldsKeepArrows,
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
  const new(this.direction);

  final TraversalDirection direction;
}

class _LeaveContentAction extends Action<_LeaveContentIntent> {
  new({required this.onLeave, required this.textFieldsKeepArrows});

  final void Function(TraversalDirection direction) onLeave;
  final bool textFieldsKeepArrows;

  @override
  bool isEnabled(_LeaveContentIntent intent, [BuildContext? context]) =>
      !textFieldsKeepArrows ||
      FocusManager.instance.primaryFocus?.context?.widget is! EditableText;

  @override
  Object? invoke(_LeaveContentIntent intent) {
    final focused = FocusManager.instance.primaryFocus;
    // Within the screen first; only at its edge to the chrome.
    if (focused != null &&
        focused is! FocusScopeNode &&
        focused.focusInDirection(intent.direction)) {
      return null;
    }
    onLeave(intent.direction);
    return null;
  }
}
