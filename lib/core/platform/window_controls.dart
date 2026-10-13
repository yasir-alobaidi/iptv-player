import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'window_controls.g.dart';

/// What the player and the reminders need from the desktop window.
/// `window_manager` in the app (lib/app/window_setup.dart); nothing
/// happens in tests.
abstract interface class WindowControls {
  Future<bool> isFullScreen();

  Future<void> setFullScreen({required bool on});

  /// True when the window is in front and has the keyboard: a reminder
  /// is then said inside the app, not by the desktop (Phase 9 decision
  /// 10).
  Future<bool> isFocused();

  /// Shows the window (out of the taskbar if it was minimized) and asks
  /// the desktop to put it in front. [activationToken] is what the
  /// desktop handed out with the user's click on a notification: Wayland
  /// refuses a window that raises itself without one, and then says "…
  /// is ready" instead.
  Future<void> bringToFront({String? activationToken});
}

final class NoWindowControls implements WindowControls {
  const new();

  @override
  Future<bool> isFullScreen() async => false;

  @override
  Future<void> setFullScreen({required bool on}) async {}

  @override
  Future<bool> isFocused() async => true;

  @override
  Future<void> bringToFront({String? activationToken}) async {}
}

@Riverpod(keepAlive: true)
WindowControls windowControls(Ref ref) => const NoWindowControls();
