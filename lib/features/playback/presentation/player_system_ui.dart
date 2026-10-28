import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player_system_ui.g.dart';

/// What the full-screen player asks of a phone's or a tablet's screen
/// (ADR-068): the picture on the whole of it, and a phone turned on its
/// side. A desktop has a window instead (`WindowControls`), and a TV is
/// always both.
abstract interface class PlayerSystemUi {
  /// The player opens: the system's bars hide (a swipe from an edge shows
  /// them for a moment), and with [landscape] (a phone) the picture turns
  /// on its side, either way round as the phone is held.
  Future<void> enter({required bool landscape});

  /// The player is left: every orientation the device allows (its own
  /// rotation lock again), and the system's bars back over the app.
  Future<void> leave();
}

/// [PlayerSystemUi] on Android's own calls (`SystemChrome`).
final class SystemChromePlayerUi implements PlayerSystemUi {
  const new();

  @override
  Future<void> enter({required bool landscape}) => _quietly(() async {
    if (landscape) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  });

  @override
  Future<void> leave() => _quietly(() async {
    // None named: the app's own default, which follows the rotation lock
    // (all four would turn the screen against it).
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  });

  /// A screen that can't turn or hide its bars still plays.
  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on PlatformException {
      // Nothing to do: the picture plays as the screen is.
    } on MissingPluginException {
      // A platform with no such call (a test's): the same.
    }
  }
}

@Riverpod(keepAlive: true)
PlayerSystemUi playerSystemUi(Ref ref) => const SystemChromePlayerUi();
