import 'package:iptv_player/core/platform/sleep_inhibitor.dart';

/// One hold on the system's sleep for several reasons — a cast, the
/// downloads (Phase 8 step 3) — so neither lets the computer sleep while
/// the other needs it awake. Each reason holds through its own [view].
final class SharedSleep {
  new(this._system);

  final SleepInhibitor _system;
  final _holding = <String, String>{};
  bool _held = false;

  /// The system is being asked to hold: a release meanwhile is left to
  /// the answer.
  bool _asking = false;

  /// What [name] uses as its [SleepInhibitor].
  SleepInhibitor view(String name) => _View(this, name);

  /// Whether the system hold is on.
  bool get held => _held;

  Future<bool> _hold(String name, String why) async {
    _holding[name] = why;
    if (_held) return true;
    _held = true;
    _asking = true;
    final took = await _system.hold(why);
    _asking = false;
    // Let go meanwhile: nothing to keep.
    if (_holding.isEmpty) {
      _held = false;
      await _system.release();
      return false;
    }
    return took;
  }

  Future<void> _release(String name) async {
    if (_holding.remove(name) == null ||
        _holding.isNotEmpty ||
        !_held ||
        _asking) {
      return;
    }
    _held = false;
    await _system.release();
  }
}

final class _View implements SleepInhibitor {
  new(this._shared, this._name);

  final SharedSleep _shared;
  final String _name;

  @override
  Future<bool> hold(String why) => _shared._hold(_name, why);

  @override
  Future<void> release() => _shared._release(_name);
}
