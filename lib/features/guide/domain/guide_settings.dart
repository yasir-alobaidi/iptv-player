import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/result.dart';

/// Settings → Guide's global choices (ADR-011 decision 4): whether there
/// is a guide at all (ADR-031), and the days kept. The time offset is per
/// source and lives on the source (`Source.epgOffsetMinutes`).
@immutable
final class GuideSettings {
  const new({this.enabled = false, this.keepDays = defaultKeepDays});

  /// The choices a device starts with: the Guide off, and a week ahead on
  /// a desktop; on a TV, with its 2 GB, three days (docs/07), and on a
  /// phone, whose storage and memory are its apps' to share (ADR-068).
  factory defaultsOn(FormFactor formFactor) => switch (formFactor) {
    FormFactor.desktop => const GuideSettings(),
    FormFactor.tv ||
    FormFactor.mobile => const GuideSettings(keepDays: defaultKeepDaysOnTv),
  };

  /// Tolerant: anything missing, damaged or out of range reads as
  /// [defaults]' (hard rule 1 applies to our own stored values too), each
  /// choice on its own.
  factory fromJson(
    Object? json, {
    GuideSettings defaults = const GuideSettings(),
  }) {
    if (json is! Map) return defaults;
    final days = switch (json['keep_days']) {
      final int v => v,
      final num v when v.isFinite && v == v.roundToDouble() => v.toInt(),
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    return GuideSettings(
      // On only when it says so: the guide costs space and an import.
      enabled: json['enabled'] == true,
      keepDays: days == null || days < minKeepDays || days > maxKeepDays
          ? defaults.keepDays
          : days,
    );
  }

  static const defaultKeepDays = 7;
  static const defaultKeepDaysOnTv = 3;
  static const minKeepDays = 1;
  static const maxKeepDays = 14;

  /// What the Keep menu offers.
  static const keepDaysOptions = [1, 2, 3, 5, 7, 10, 14];

  /// What is kept behind now, whatever the days ahead: yesterday on a
  /// desktop; the last two hours on a TV (docs/07).
  static Duration keepBehindOn(FormFactor formFactor) => switch (formFactor) {
    FormFactor.desktop => const Duration(days: 1),
    FormFactor.tv || FormFactor.mobile => const Duration(hours: 2),
  };

  /// Whether the guide is imported and the Guide shown (ADR-031). Off,
  /// nothing is downloaded and the stored guide is cleared; channels
  /// show what's on from the provider's short EPG.
  final bool enabled;

  /// Days of programmes kept ahead of now. What is kept behind is the
  /// importer's `keepBehind` ([keepBehindOn]).
  final int keepDays;

  Duration get keepAhead => Duration(days: keepDays);

  Map<String, Object?> toJson() => {'enabled': enabled, 'keep_days': keepDays};

  GuideSettings copyWith({bool? enabled, int? keepDays}) => GuideSettings(
    enabled: enabled ?? this.enabled,
    keepDays: keepDays ?? this.keepDays,
  );

  @override
  bool operator ==(Object other) =>
      other is GuideSettings &&
      other.enabled == enabled &&
      other.keepDays == keepDays;

  @override
  int get hashCode => Object.hash(enabled, keepDays);

  @override
  String toString() => 'GuideSettings(enabled: $enabled, keepDays: $keepDays)';
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
