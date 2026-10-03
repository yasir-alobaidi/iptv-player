import 'dart:async';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:window_manager/window_manager.dart';

/// Sets the desktop window up and remembers where the user left it.
///
/// On Wayland an application cannot position its own window, so only the
/// size is restored there (ADR-008); the position is still saved, because
/// the same profile may next start on X11.
class AppWindow with WindowListener {
  new({required this.store, required this.log});

  static const _saveDebounce = Duration(milliseconds: 500);
  static const _logTag = 'window';

  /// The most closing waits for [beforeClose].
  static const closeWithin = Duration(seconds: 4);

  /// Runs when the user closes the window, before it goes: the TV's media
  /// and the relay stop, every FFmpeg ends (hard rule 8). The window
  /// closes after it, or after [closeWithin], whatever happens.
  Future<void> Function()? beforeClose;
  var _closing = false;

  final WindowBoundsStore store;
  final AppLog log;
  Timer? _saveTimer;
  bool _listening = false;

  /// Applies the minimum size, the title and the remembered bounds, then
  /// shows the window. Never throws: a window that can't be restored
  /// still opens at its default size.
  Future<void> setUp() async {
    await windowManager.ensureInitialized();

    final saved = (await store.load()).valueOrNull;
    final bounds = resolveStartupBounds(
      saved,
      canRestorePosition: !isWaylandSession(),
    );

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: bounds.size,
        minimumSize: WindowSizes.minimum,
        center: bounds.position == null,
        title: 'IPTV Player',
      ),
      () async {
        final position = bounds.position;
        if (position != null) await windowManager.setPosition(position);
        if (bounds.maximized) await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
      },
    );

    windowManager.addListener(this);
    _listening = true;
    // Closing comes to [onWindowClose] first.
    await windowManager.setPreventClose(true);
  }

  @override
  Future<void> onWindowClose() async {
    if (_closing) return;
    _closing = true;
    final clock = Stopwatch()..start();
    try {
      await beforeClose?.call().timeout(closeWithin);
      log.info(_logTag, 'Closing after ${clock.elapsedMilliseconds} ms');
    } on Object catch (error) {
      log.warning(_logTag, 'Closing without finishing up: $error');
    } finally {
      await dispose();
      // Written out before the process goes.
      try {
        await log.close();
      } on Object catch (_) {}
      await windowManager.destroy();
    }
  }

  /// Stops listening and writes whatever is still pending. Called when
  /// the app shuts down.
  Future<void> dispose() async {
    _saveTimer?.cancel();
    if (_listening) {
      windowManager.removeListener(this);
      _listening = false;
    }
  }

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  /// A drag fires dozens of events a second; only the last one is worth
  /// writing.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () => unawaited(_save()));
  }

  Future<void> _save() async {
    try {
      final maximized = await windowManager.isMaximized();
      // A maximized window's own size is the screen's; keep the size it
      // will go back to.
      if (maximized) {
        final saved = (await store.load()).valueOrNull;
        if (saved != null) {
          await store.save(
            WindowBounds(
              size: saved.size,
              position: saved.position,
              maximized: true,
            ),
          );
          return;
        }
      }
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final result = await store.save(
        WindowBounds(size: size, position: position, maximized: maximized),
      );
      final failure = result.failureOrNull;
      if (failure != null) {
        log.warning(_logTag, 'Could not save the window bounds: $failure');
      }
    } on Object catch (error, stackTrace) {
      log.warning(
        _logTag,
        'Could not read the window bounds',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// [WindowControls] on window_manager.
final class WindowManagerControls implements WindowControls {
  const new();

  @override
  Future<bool> isFullScreen() => windowManager.isFullScreen();

  @override
  Future<void> setFullScreen({required bool on}) =>
      windowManager.setFullScreen(on);
}
