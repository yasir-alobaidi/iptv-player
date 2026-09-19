import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'window_controls.g.dart';

/// What the player needs from the desktop window. `window_manager` in the
/// app (lib/app/window_setup.dart); nothing happens in tests.
abstract interface class WindowControls {
  Future<bool> isFullScreen();

  Future<void> setFullScreen({required bool on});
}

final class NoWindowControls implements WindowControls {
  const new();

  @override
  Future<bool> isFullScreen() async => false;

  @override
  Future<void> setFullScreen({required bool on}) async {}
}

@Riverpod(keepAlive: true)
WindowControls windowControls(Ref ref) => const NoWindowControls();
