/// Keeps the computer from sleeping while it serves a cast (Phase 7
/// decision 7): a suspend would cut the TV's stream. The screen may still
/// blank. Phase 8's downloads hold it too.
abstract interface class SleepInhibitor {
  /// Holds the computer awake, saying [why] where the system shows it.
  /// Holding again while held changes nothing. Never throws: false when
  /// the system has no way to, or refused.
  Future<bool> hold(String why);

  /// Lets the computer sleep again. Nothing happens when nothing is held.
  Future<void> release();
}

/// Nothing to hold: tests, and systems without a way.
final class NoSleepInhibitor implements SleepInhibitor {
  const new();

  @override
  Future<bool> hold(String why) async => false;

  @override
  Future<void> release() async {}
}
