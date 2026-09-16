import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';

/// Jump to a destination (Ctrl+1 … Ctrl+7, Ctrl+,).
class GoToDestinationIntent extends Intent {
  const new(this.destination);

  final AppDestination destination;
}

/// Open the search overlay (Ctrl+K, and `/` outside a text field).
class OpenSearchIntent extends Intent {
  const new({this.printableKey = false});

  /// True for `/`, which has to reach a text field instead of opening
  /// search when the user is typing.
  final bool printableKey;
}

/// Esc: close what is on top (docs/05: back / exit fullscreen / close
/// dialog). The player's own Esc handling arrives in Phase 3.
class CloseTopIntent extends Intent {
  const new();
}

/// The shortcuts that work anywhere in the app. They wrap the router's
/// navigator, so they fire on every screen, including the search overlay.
///
/// Player keys (Space, F, arrows, digits) belong to the player and come
/// in Phase 3; putting them here would swallow them on every other
/// screen.
class AppGlobalShortcuts extends ConsumerWidget {
  const new({required this.child, super.key});

  static Map<ShortcutActivator, Intent> get shortcuts => {
    for (var number = 1; number <= 7; number++)
      SingleActivator(_numberKeys[number - 1], control: true):
          GoToDestinationIntent(AppDestination.forNumberKey(number)!),
    const SingleActivator(LogicalKeyboardKey.comma, control: true):
        const GoToDestinationIntent(AppDestination.settings),
    const SingleActivator(LogicalKeyboardKey.keyK, control: true):
        const OpenSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.slash): const OpenSearchIntent(
      printableKey: true,
    ),
    const SingleActivator(LogicalKeyboardKey.escape): const CloseTopIntent(),
  };

  static const List<LogicalKeyboardKey> _numberKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
  ];

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          GoToDestinationIntent: CallbackAction<GoToDestinationIntent>(
            onInvoke: (intent) {
              // Leave the overlay first, so Ctrl+2 from search lands on
              // Live TV rather than behind the scrim.
              if (isSearchOpen(router) && router.canPop()) router.pop();
              router.go(intent.destination.path);
              return null;
            },
          ),
          OpenSearchIntent: _OpenSearchAction(router),
          CloseTopIntent: _CloseTopAction(router),
        },
        child: child,
      ),
    );
  }
}

/// `/` types a slash when the user is in a text field, so the action
/// disables itself there and the key reaches the field. Ctrl+K always
/// works, which is why it is the documented shortcut.
///
/// A disabled action makes [Shortcuts] ignore the key instead of eating
/// it, which is what lets the slash through.
class _OpenSearchAction extends Action<OpenSearchIntent> {
  new(this._router);

  final GoRouter _router;

  @override
  bool isEnabled(OpenSearchIntent intent, [BuildContext? context]) {
    if (isSearchOpen(_router)) return false;
    return !(intent.printableKey && textInputHasFocus());
  }

  @override
  Object? invoke(OpenSearchIntent intent) {
    unawaited(_router.push<void>(searchRoutePath));
    return null;
  }
}

/// Esc only when there is something to close; otherwise the key goes on
/// to whatever has focus.
class _CloseTopAction extends Action<CloseTopIntent> {
  new(this._router);

  final GoRouter _router;

  @override
  bool isEnabled(CloseTopIntent intent, [BuildContext? context]) =>
      _router.canPop();

  @override
  Object? invoke(CloseTopIntent intent) {
    _router.pop();
    return null;
  }
}

/// True when the keyboard focus is inside a text field, where printable
/// shortcuts must not fire.
bool textInputHasFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}
