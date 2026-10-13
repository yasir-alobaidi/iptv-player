import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/tokens.dart';

/// Settings → Appearance → Text size (Phase 9 decision 2). [system]
/// follows the desktop's text size.
enum TextSizeChoice {
  system('System', null),
  s100('100 %', 1),
  s115('115 %', 1.15),
  s130('130 %', 1.3);

  new(this.label, this.scale);

  final String label;

  /// The scale it asks for; null follows the desktop.
  final double? scale;
}

/// A choice that can follow the desktop: reduce motion.
enum SystemSwitch {
  system('System'),
  on('On'),
  off('Off');

  new(this.label);

  final String label;
}

/// Settings → Appearance → Clock.
enum ClockChoice {
  system('System'),
  h12('12-hour'),
  h24('24-hour');

  new(this.label);

  final String label;
}

/// What the desktop says about text and motion, as Flutter's embedder
/// passes it on (GNOME's text scaling factor, clock format and
/// animations switch on Linux).
@immutable
final class SystemAppearance {
  const new({
    this.textScale = 1,
    this.reduceMotion = false,
    this.use24Hour = false,
  });

  final double textScale;
  final bool reduceMotion;
  final bool use24Hour;

  @override
  bool operator ==(Object other) =>
      other is SystemAppearance &&
      other.textScale == textScale &&
      other.reduceMotion == reduceMotion &&
      other.use24Hour == use24Hour;

  @override
  int get hashCode => Object.hash(textScale, reduceMotion, use24Hour);

  @override
  String toString() =>
      'SystemAppearance(text $textScale, reduce motion $reduceMotion, '
      '24-hour $use24Hour)';
}

/// What Settings → Appearance holds. The defaults follow the desktop, so
/// a desktop already set to large text or a 24-hour clock needn't be set
/// again here (Phase 9 decision 2).
@immutable
final class AppearanceSettings {
  const new({
    this.accent = AppAccent.blue,
    this.textSize = TextSizeChoice.system,
    this.density = AppDensity.comfortable,
    this.reduceMotion = SystemSwitch.system,
    this.clock = ClockChoice.system,
  });

  /// Tolerant: anything unknown or damaged reads as the default.
  factory fromJson(Object? json) {
    if (json is! Map) return const AppearanceSettings();
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return AppearanceSettings(
      accent: pick(AppAccent.values, json['accent'], AppAccent.blue),
      textSize: pick(
        TextSizeChoice.values,
        json['text_size'],
        TextSizeChoice.system,
      ),
      density: pick(AppDensity.values, json['density'], AppDensity.comfortable),
      reduceMotion: pick(
        SystemSwitch.values,
        json['reduce_motion'],
        SystemSwitch.system,
      ),
      clock: pick(ClockChoice.values, json['clock'], ClockChoice.system),
    );
  }

  final AppAccent accent;
  final TextSizeChoice textSize;
  final AppDensity density;
  final SystemSwitch reduceMotion;
  final ClockChoice clock;

  /// The largest text the app lays out for (docs/05 "Accessibility"): a
  /// desktop set larger gets this, which is bigger than 100 % and laid
  /// out right, rather than its own size with rows that overflow.
  static const maxTextScale = 1.3;

  /// The smallest: the canvas's own sizes.
  static const minTextScale = 1.0;

  AppearanceSettings copyWith({
    AppAccent? accent,
    TextSizeChoice? textSize,
    AppDensity? density,
    SystemSwitch? reduceMotion,
    ClockChoice? clock,
  }) => AppearanceSettings(
    accent: accent ?? this.accent,
    textSize: textSize ?? this.textSize,
    density: density ?? this.density,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    clock: clock ?? this.clock,
  );

  /// As stored in the `settings` table.
  Map<String, Object?> toJson() => {
    'accent': accent.name,
    'text_size': textSize.name,
    'density': density.name,
    'reduce_motion': reduceMotion.name,
    'clock': clock.name,
  };

  /// What the app draws with on a desktop that says [system].
  Appearance resolve(SystemAppearance system) {
    final asked = textSize.scale ?? system.textScale;
    // A desktop can report anything, a NaN included: the canvas's size
    // then.
    final scale = asked.isFinite
        ? asked.clamp(minTextScale, maxTextScale)
        : minTextScale;
    return Appearance(
      accent: accent,
      density: density,
      textScale: scale,
      reduceMotion: switch (reduceMotion) {
        SystemSwitch.system => system.reduceMotion,
        SystemSwitch.on => true,
        SystemSwitch.off => false,
      },
      timeStyle: switch (clock) {
        ClockChoice.system => system.use24Hour ? TimeStyle.h24 : TimeStyle.h12,
        ClockChoice.h12 => TimeStyle.h12,
        ClockChoice.h24 => TimeStyle.h24,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      other.accent == accent &&
      other.textSize == textSize &&
      other.density == density &&
      other.reduceMotion == reduceMotion &&
      other.clock == clock;

  @override
  int get hashCode =>
      Object.hash(accent, textSize, density, reduceMotion, clock);

  @override
  String toString() => 'AppearanceSettings(${toJson()})';
}

/// The look the app is drawn with: [AppearanceSettings] with every
/// "System" answered.
@immutable
final class Appearance {
  const new({
    this.accent = AppAccent.blue,
    this.density = AppDensity.comfortable,
    this.textScale = 1,
    this.reduceMotion = false,
    this.timeStyle = TimeStyle.h12,
  });

  final AppAccent accent;
  final AppDensity density;

  /// 1.0 to [AppearanceSettings.maxTextScale].
  final double textScale;
  final bool reduceMotion;
  final TimeStyle timeStyle;

  @override
  bool operator ==(Object other) =>
      other is Appearance &&
      other.accent == accent &&
      other.density == density &&
      other.textScale == textScale &&
      other.reduceMotion == reduceMotion &&
      other.timeStyle == timeStyle;

  @override
  int get hashCode =>
      Object.hash(accent, density, textScale, reduceMotion, timeStyle);

  @override
  String toString() =>
      'Appearance(${accent.name}, ${density.name}, text $textScale, '
      'reduce motion $reduceMotion, ${timeStyle.name})';
}
