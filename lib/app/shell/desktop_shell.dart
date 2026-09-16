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

  AppDestination get _current =>
      AppDestination.values[widget.navigationShell.currentIndex];

  void _go(AppDestination destination) => widget.navigationShell.goBranch(
    destination.index,
    // Tapping the destination you are already on goes back to its root,
    // which is go_router's own convention for a shell branch.
    initialLocation: destination.index == widget.navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    ref.listen(nonFatalErrorsProvider, (previous, next) {
      final failure = next.value;
      if (failure == null) return;
      _toasts.show(
        ShellToast(message: failureMessage(failure), tone: ToastTone.error),
      );
    });

    final wantsExpanded = ref.watch(railExpandedProvider);
    final source = ref.watch(shellSourceProvider);
    final syncStatus = ref.watch(shellSyncStatusProvider);
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
          body: Stack(
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
                          syncStatus: syncStatus,
                          downloads: downloads,
                          onOpenSearch: widget.onOpenSearch ?? () {},
                          onOpenSource: () => _go(AppDestination.settings),
                          onOpenDownloads: () => _go(AppDestination.library),
                          paneController: _topBarPane,
                        ),
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
        );
      },
    );
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
