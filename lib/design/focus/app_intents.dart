import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the item menu (Menu key or Shift+F10, and right-click).
class AppMenuIntent extends Intent {
  const new();
}

/// Shortcuts every focusable element understands. Directional movement is
/// Flutter's [DirectionalFocusIntent]; it is listed here so the shell and
/// the Google TV build (Phase 11) can reuse one map.
abstract final class AppShortcuts {
  /// Enter/Space activate, as required by hard rule 5.
  static const activation = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  /// Menu key and Shift+F10 open the item menu.
  static const menu = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.contextMenu): AppMenuIntent(),
    SingleActivator(LogicalKeyboardKey.f10, shift: true): AppMenuIntent(),
  };

  /// Arrow keys move focus. Flutter's default shortcuts already include
  /// these; the map is here for scopes that replace the defaults.
  static const directional = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
      TraversalDirection.up,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
      TraversalDirection.down,
    ),
    SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
      TraversalDirection.left,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
      TraversalDirection.right,
    ),
  };

  /// Everything a focusable surface binds.
  static const surface = <ShortcutActivator, Intent>{...activation, ...menu};
}
