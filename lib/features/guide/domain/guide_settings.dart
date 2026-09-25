import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';

/// Settings → Guide's global choices (ADR-011 decision 4). The time
/// offset is per source and lives on the source
/// (`Source.epgOffsetMinutes`).
@immutable
final class GuideSettings {
  const new({this.keepDays = defaultKeepDays});

  /// Tolerant: anything missing, damaged or out of range reads as the
  /// default (hard rule 1 applies to our own stored values too).
  factory fromJson(Object? json) {
    if (json is! Map) return const GuideSettings();
    final days = switch (json['keep_days']) {
      final int v => v,
      final num v when v.isFinite && v == v.roundToDouble() => v.toInt(),
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    if (days == null || days < minKeepDays || days > maxKeepDays) {
      return const GuideSettings();
    }
    return GuideSettings(keepDays: days);
  }

  static const defaultKeepDays = 7;
  static const minKeepDays = 1;
  static const maxKeepDays = 14;

  /// What the Keep menu offers.
  static const keepDaysOptions = [1, 2, 3, 5, 7, 10, 14];

  /// Days of programmes kept ahead of now. A day behind is always kept
  /// as well (the importer's `keepBehind`).
  final int keepDays;

  Duration get keepAhead => Duration(days: keepDays);

  Map<String, Object?> toJson() => {'keep_days': keepDays};

  GuideSettings copyWith({int? keepDays}) =>
      GuideSettings(keepDays: keepDays ?? this.keepDays);

  @override
  bool operator ==(Object other) =>
      other is GuideSettings && other.keepDays == keepDays;

  @override
  int get hashCode => keepDays.hashCode;

  @override
  String toString() => 'GuideSettings(keepDays: $keepDays)';
}

/// Where [GuideSettings] are kept.
abstract interface class GuideSettingsStore {
  Future<Result<GuideSettings>> load();

  Future<Result<void>> save(GuideSettings settings);
}

/// The time offsets Settings → Guide steps through, in minutes: half
/// hours from −12 h to +12 h.
const guideOffsetStepMinutes = 30;
const int guideOffsetLimitMinutes = 12 * 60;
