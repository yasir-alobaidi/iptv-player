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
import 'package:iptv_player/features/guide/data/guide_providers.dart';

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
    HardwareKeyboard.instance.removeHandler(_userPressed);
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
      _launching = true;
      HardwareKeyboard.instance.addHandler(_userPressed);
      _focusFirstOnTv();
      FocusManager.instance.addListener(_keepFocusOnTv);
    }
  }

  /// From launch until the user's first press: until then the focus is
  /// the launch's to place ([_focusFirstOnTv]).
  bool _launching = false;

  /// The user's first press ends the launch's say over the focus.
  bool _userPressed(KeyEvent event) {
    if (event is KeyDownEvent) {
      _launching = false;
      HardwareKeyboard.instance.removeHandler(_userPressed);
    }
    return false;
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
            // At launch, only until the screen has a control.
            _focusFirstOnTv();
          }
        }),
      )
      ..scheduleFrame();
  }

  /// Whether [_focusFirstOnTv] waits for a frame.
  bool _awaitingFirst = false;

  /// The first screen's controls come with its data: Home's rows, seconds
  /// after the first frames from a provider's large catalogue. After each
  /// frame, until a control of the screen has the focus, its first takes
  /// it, from nothing or from the rail's item that held it meanwhile
  /// ([_keepFocusOnTv]). Not after the user's first press: the focus is
  /// never moved from where they put it. (The Bedroom TV, build 217: this
  /// stopped at anything focused, the rail's Home too, and checked for
  /// 2 s; the rows came later, and the focus stayed in the rail.)
  void _focusFirstOnTv() {
    if (!_launching || _awaitingFirst) return;
    _awaitingFirst = true;
    WidgetsBinding.instance.addPostFrameCallback(
      // After the screen's own autofocus (a title's Play), a microtask
      // queued while it was built: before it, the page's first control
      // (‹ Movies) took Play's place.
      (_) => scheduleMicrotask(() {
        _awaitingFirst = false;
        if (!mounted || !_launching) return;
        final focused = FocusManager.instance.primaryFocus;
        if (_contentPane.hasFocus && focused is! FocusScopeNode) return;
        // Not from under a page or a dialog above the shell.
        if ((ModalRoute.of(context)?.isCurrent ?? true) &&
            _contentPane.focusFirst()) {
          return;
        }
        _focusFirstOnTv();
      }),
    );
  }

  /// Up from the top of the screen, on a TV: onto the top bar's item
  /// above the control it leaves, as an arrow picks one inside the
  /// screen, not onto the item the bar remembers (the Bedroom TV: Up from
  /// Movies' sort reached the source switcher, not the search over it).
  /// Down comes back to the control, the screen's remembered item.
  bool _upToTopBar() {
    final from = FocusManager.instance.primaryFocus;
    if (from != null &&
        from is! FocusScopeNode &&
        _topBarPane.focusAbove(from.rect)) {
      return true;
    }
    return _topBarPane.focusPane();
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
  ///
  /// On a TV the focus in the rail goes to the item of the screen shown:
  /// the one pressed or rested on, or Home's after Back. A rest opens the
  /// item the focus is on ([NavRail.onRest]), so left on the item Back
  /// went from, it would open that screen again.
  void _followTheJump() {
    // Read before the frame ends, while the old focus is still in place.
    final railItem = _railPane.hasFocus
        ? FocusManager.instance.primaryFocus
        : null;
    final onTv = ref.read(formFactorProvider) == FormFactor.tv;

    // The new branch is built in this frame and is only traversable once
    // it has been laid out, so the move waits for the frame to end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (railItem != null) {
        // The rail's landing is the item of the screen shown.
        if (onTv && _railPane.focusFirst()) return;
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

    // The Guide switched off (or found off at launch) while its page
    // shows: Home, as the router sends any later visit (ADR-031).
    ref.listen(guideSwitchedOffProvider, (_, off) {
      if (off && _current == AppDestination.guide) _go(AppDestination.home);
    });

    final onTv = ref.watch(formFactorProvider) == FormFactor.tv;
    final shell = LayoutBuilder(
      builder: (context, constraints) {
        // Below 1280 px the rail collapses whatever the user chose
        // (docs/05); their choice comes back when the window grows.
        // A TV's rail stays collapsed: its canvas is just 1280 wide, and
        // it has no toggle (ADR-026).
        final expanded =
            wantsExpanded &&
            !onTv &&
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
                      // A remote opens a destination by resting on it, as
                      // OK does, but never back to the root of the one
                      // shown (the rail skips that one too).
                      onRest: onTv
                          ? (destination) => widget.navigationShell.goBranch(
                              destination.index,
                            )
                          : null,
                      showToggle: !onTv,
                      destinations: AppDestination.primaryOn(
                        ref.watch(formFactorProvider),
                        guide: ref.watch(guideEnabledProvider),
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
                              // A remote's Left lands on the screen's own
                              // item, as a TV's menus do, not on the item
                              // last focused there (the Bedroom TV:
                              // Settings, from Home). A keyboard's
                              // returns where it left the rail.
                              onLeaveLeft: onTv
                                  ? _railPane.focusFirst
                                  : _railPane.focusPane,
                              // A remote reaches the top bar (search, the
                              // source) only so; a keyboard also by Tab.
                              onLeaveUp: onTv && !widget.immersive
                                  ? _upToTopBar
                                  : null,
                              textFieldsKeepArrows: !onTv,
                              // A title's page on a TV: Left from Play
                              // went up to ‹ Back, far above its row,
                              // before the menu (the Bedroom TV).
                              leftStaysInRow: onTv && widget.immersive,
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
    this.leftStaysInRow = false,
  });

  final FocusPaneController controller;
  final bool Function() onLeaveLeft;

  /// Null: Up stays in the screen.
  final bool Function()? onLeaveUp;

  /// A keyboard's arrows move the caret in a text field (the desktop).
  final bool textFieldsKeepArrows;

  /// Left moves within the screen only to a control beside the focused
  /// one (its height overlapping), and otherwise to the rail: on a page
  /// whose controls left of a row sit far above it (a title's ‹ Back).
  final bool leftStaysInRow;
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
          leftStaysInRow: leftStaysInRow,
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
  new({
    required this.onLeave,
    required this.textFieldsKeepArrows,
    required this.leftStaysInRow,
  });

  final void Function(TraversalDirection direction) onLeave;
  final bool textFieldsKeepArrows;
  final bool leftStaysInRow;

  @override
  bool isEnabled(_LeaveContentIntent intent, [BuildContext? context]) =>
      !textFieldsKeepArrows ||
      // A text field's focus is a Focus inside its EditableText.
      FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>() ==
          null;

  @override
  Object? invoke(_LeaveContentIntent intent) {
    final focused = FocusManager.instance.primaryFocus;
    // Within the screen first; only at its edge to the chrome.
    final rowOnly =
        leftStaysInRow && intent.direction == TraversalDirection.left;
    if (focused != null &&
        focused is! FocusScopeNode &&
        (!rowOnly || _besideOnLeft(focused)) &&
        focused.focusInDirection(intent.direction)) {
      return null;
    }
    onLeave(intent.direction);
    return null;
  }

  /// A control left of [focused] in its row: one whose height overlaps
  /// its own. Only laid-out controls count.
  static bool _besideOnLeft(FocusNode focused) {
    final scope = focused.nearestScope;
    if (scope == null) return false;
    final from = focused.rect;
    for (final node in scope.traversalDescendants) {
      if (identical(node, focused) || node is FocusScopeNode) continue;
      final box = node.context?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = node.rect;
      if (rect.right <= from.left + 1 &&
          rect.bottom > from.top &&
          rect.top < from.bottom) {
        return true;
      }
    }
    return false;
  }
}
