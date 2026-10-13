import 'package:flutter/widgets.dart';
import 'package:iptv_player/design/appearance.dart';

/// The smallest window the app allows, and a large one.
const auditSmall = Size(1024, 640);
const auditLarge = Size(1920, 1080);

/// How the audit draws a scene (Phase 9 decision 14): the window, the
/// text size, reduce motion.
@immutable
final class AuditLook {
  const new(
    this.size,
    this.text, {
    this.reduceMotion = false,
    this.keyboard = false,
  });

  final Size size;
  final TextSizeChoice text;
  final bool reduceMotion;

  /// Whether the keyboard is walked in this look: at 100 % and at 130 %
  /// in the smallest window, where a wrapped row of controls is likeliest
  /// to lose one.
  final bool keyboard;

  String get name =>
      '${size.width.toInt()}×${size.height.toInt()} at ${text.label}'
      '${reduceMotion ? ', reduce motion' : ''}';

  /// Settings → Appearance as [settings] has it, with this look's text
  /// size and motion.
  AppearanceSettings applyTo(AppearanceSettings settings) => settings.copyWith(
    textSize: text,
    reduceMotion: reduceMotion ? SystemSwitch.on : SystemSwitch.off,
  );
}

/// Every look a scene is drawn in: the three text sizes in both windows,
/// the keyboard walked twice, and reduce motion once (what it changes is
/// what moves, not where things are).
const auditLooks = [
  AuditLook(auditSmall, TextSizeChoice.s100, keyboard: true),
  AuditLook(auditSmall, TextSizeChoice.s115),
  AuditLook(auditSmall, TextSizeChoice.s130, keyboard: true),
  AuditLook(auditLarge, TextSizeChoice.s100),
  AuditLook(auditLarge, TextSizeChoice.s115),
  AuditLook(auditLarge, TextSizeChoice.s130),
  AuditLook(auditSmall, TextSizeChoice.s100, reduceMotion: true),
];

/// The look the audit is drawing in right now; null in every other test.
///
/// `pumpApp` and `appearanceOverrides` read it, so a scene is pumped the
/// way its own test pumps it — the same fixtures, the same steps — only
/// in another window and at another text size. That is what lets every
/// golden double as an audit scene.
AuditLook? currentAuditLook;
