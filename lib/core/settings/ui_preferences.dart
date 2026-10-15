import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';

/// Small UI choices that survive a restart.
///
/// The shell sees only this interface; the settings-table implementation
/// lives in `lib/data` (hard rule 6). [railExpanded] is a plain getter
/// rather than a future because the first frame needs it — `bootstrap()`
/// reads the stored value before `runApp`.
abstract interface class UiPreferences {
  bool get railExpanded;

  Future<Result<void>> setRailExpanded({required bool expanded});

  /// The source the top bar's switcher last picked; null until the user
  /// picks one, which means the first source in their order.
  String? get currentSourceId;

  Future<Result<void>> setCurrentSourceId(String? id);

  /// The player's volume and whether it is muted, as the user left them:
  /// the engine gets them before the first thing plays.
  PlayerSound get playerSound;

  Future<Result<void>> setPlayerSound(PlayerSound sound);

  /// The language Bijou's keyboard for the remote last had ("en", "ar");
  /// null until one was chosen (ADR-027).
  String? get keyboardLanguage;

  Future<Result<void>> setKeyboardLanguage(String code);
}

/// How loud the player is: [volume] 0–100, and [muted] over it (the
/// level is kept, so Unmute goes back to it).
@immutable
final class PlayerSound {
  const new({this.volume = 100, this.muted = false});

  /// Tolerant: anything unknown or damaged reads as the default.
  factory fromJson(Object? json) {
    if (json is! Map) return const PlayerSound();
    final volume = json['volume'];
    return PlayerSound(
      volume: volume is num && volume.isFinite
          ? volume.toDouble().clamp(0, 100).toDouble()
          : 100,
      muted: json['muted'] == true,
    );
  }

  final double volume;
  final bool muted;

  /// Nothing to hear: muted, or turned all the way down.
  bool get silent => muted || volume <= 0;

  PlayerSound copyWith({double? volume, bool? muted}) =>
      PlayerSound(volume: volume ?? this.volume, muted: muted ?? this.muted);

  Map<String, Object?> toJson() => {'volume': volume, 'muted': muted};

  @override
  bool operator ==(Object other) =>
      other is PlayerSound && other.volume == volume && other.muted == muted;

  @override
  int get hashCode => Object.hash(volume, muted);

  @override
  String toString() =>
      'PlayerSound(${volume.round()}${muted ? ', muted' : ''})';
}

/// Keeps choices for the lifetime of the process only. Used by tests and
/// as the default until `bootstrap()` overrides the provider.
final class InMemoryUiPreferences implements UiPreferences {
  bool _railExpanded = false;
  String? _currentSourceId;

  @override
  bool get railExpanded => _railExpanded;

  @override
  Future<Result<void>> setRailExpanded({required bool expanded}) async {
    _railExpanded = expanded;
    return const Ok(null);
  }

  @override
  String? get currentSourceId => _currentSourceId;

  @override
  Future<Result<void>> setCurrentSourceId(String? id) async {
    _currentSourceId = id;
    return const Ok(null);
  }

  @override
  PlayerSound playerSound = const PlayerSound();

  @override
  Future<Result<void>> setPlayerSound(PlayerSound sound) async {
    playerSound = sound;
    return const Ok(null);
  }

  @override
  String? keyboardLanguage;

  @override
  Future<Result<void>> setKeyboardLanguage(String code) async {
    keyboardLanguage = code;
    return const Ok(null);
  }
}
