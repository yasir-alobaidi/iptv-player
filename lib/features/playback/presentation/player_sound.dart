import 'dart:async';

import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player_sound.g.dart';

/// How loud the player is (ADR-017): one engine, so one volume for the
/// full-screen player and the preview alike, kept across restarts. The
/// engine is told the stored level when this is first read (`bootstrap()`
/// reads it), then every change.
///
/// On a TV the remote's volume and mute keys work the TV itself, and the
/// player has no volume control (ADR-025): it always plays at full volume,
/// unmuted, whatever a desktop-era level or a stray M stored.
@Riverpod(keepAlive: true)
class PlayerSoundController extends _$PlayerSoundController {
  /// What a key or a notch of the wheel changes the volume by.
  static const step = 5.0;

  /// Where Unmute goes when the level was dragged to nothing.
  static const _audible = 50.0;

  bool _saving = false;
  bool _unsaved = false;

  @override
  PlayerSound build() {
    if (_onTv) return const PlayerSound();
    final stored = ref.read(uiPreferencesProvider).playerSound;
    // A new engine plays at full volume, unmuted.
    unawaited(_tell(const PlayerSound(), stored));
    return stored;
  }

  /// [volume] 0–100. Turning it up from nothing, or at all while muted,
  /// is also Unmute.
  void setVolume(double volume) {
    final level = volume.clamp(0, 100).toDouble();
    _set(PlayerSound(volume: level, muted: state.muted && level <= 0));
  }

  /// A key or the wheel: one [step] up (+1) or down (-1). Up while muted
  /// is Unmute, a step above where the level was left.
  void nudge(int steps) {
    if (state.muted && steps < 0) return;
    setVolume(((state.volume + steps * step) / step).round() * step);
  }

  void toggleMute() {
    if (state.silent) {
      _set(PlayerSound(volume: state.volume <= 0 ? _audible : state.volume));
    } else {
      _set(state.copyWith(muted: true));
    }
  }

  /// A TV's remote and a phone's keys turn the system's volume: the app's
  /// stays full (ADR-068).
  bool get _onTv => ref.read(formFactorProvider).isAndroidDevice;

  void _set(PlayerSound next) {
    final before = state;
    if (next == before || _onTv) return;
    state = next;
    unawaited(_tell(before, next));
    unawaited(_save());
  }

  /// A drag changes the level many times a second: one write at a time,
  /// and the last level always written. A failed write only costs the
  /// level at the next launch.
  Future<void> _save() async {
    _unsaved = true;
    if (_saving) return;
    _saving = true;
    final preferences = ref.read(uiPreferencesProvider);
    while (_unsaved && ref.mounted) {
      _unsaved = false;
      await preferences.setPlayerSound(state);
    }
    _saving = false;
  }

  Future<void> _tell(PlayerSound before, PlayerSound next) async {
    final engine = ref.read(playerEngineProvider);
    if (next.volume != before.volume) await engine.setVolume(next.volume);
    if (next.muted != before.muted) await engine.setMuted(muted: next.muted);
  }
}
