import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
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
    this.formFactor,
  });

  final Size size;

  /// A phone's or a tablet's look ([FormFactor.mobile], ADR-068): the app
  /// pumped as one, with a status bar above and a gesture bar below
  /// ([insets]). Null: the scene's own (the desktop, unless it says).
  final FormFactor? formFactor;

  /// The system's bars a phone draws over the app, in logical pixels.
  EdgeInsets get insets => formFactor == FormFactor.mobile
      ? EdgeInsets.only(
          top: size.width < size.height ? 32 : 0,
          bottom: 24,
          left: size.width < size.height ? 0 : 32,
        )
      : EdgeInsets.zero;
  final TextSizeChoice text;
  final bool reduceMotion;

  /// Whether the keyboard is walked in this look: at 100 % and at 130 %
  /// in the smallest window, where a wrapped row of controls is likeliest
  /// to lose one.
  final bool keyboard;

  String get name =>
      '${formFactor == FormFactor.mobile ? 'phone ' : ''}'
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
/// the keyboard walked twice, reduce motion once (what it changes is
/// what moves, not where things are), and, at the canvas's text size,
/// the windows between and beyond those two that people have: a 720p
/// screen, the commonest laptop, a larger laptop, a QHD monitor, and an
/// ultrawide one (where a pane that only stretches gives itself away).
const auditLooks = [
  AuditLook(auditSmall, TextSizeChoice.s100, keyboard: true),
  AuditLook(auditSmall, TextSizeChoice.s115),
  AuditLook(auditSmall, TextSizeChoice.s130, keyboard: true),
  AuditLook(auditLarge, TextSizeChoice.s100),
  AuditLook(auditLarge, TextSizeChoice.s115),
  AuditLook(auditLarge, TextSizeChoice.s130),
  AuditLook(auditSmall, TextSizeChoice.s100, reduceMotion: true),
  AuditLook(Size(1280, 720), TextSizeChoice.s100),
  AuditLook(Size(1366, 768), TextSizeChoice.s100),
  AuditLook(Size(1600, 900), TextSizeChoice.s100),
  AuditLook(Size(2560, 1440), TextSizeChoice.s100),
  AuditLook(Size(3440, 1440), TextSizeChoice.s100),
  // Android phones and tablets (ADR-068): the smallest phone people
  // have, held upright, with the keyboard walked; a large one at 130 %;
  // a phone on its side; a tablet held upright.
  AuditLook(
    Size(360, 780),
    TextSizeChoice.s100,
    keyboard: true,
    formFactor: FormFactor.mobile,
  ),
  AuditLook(Size(412, 915), TextSizeChoice.s130, formFactor: FormFactor.mobile),
  AuditLook(Size(780, 360), TextSizeChoice.s100, formFactor: FormFactor.mobile),
  AuditLook(
    Size(800, 1280),
    TextSizeChoice.s100,
    formFactor: FormFactor.mobile,
  ),
];

/// The looks this run draws: with `AUDIT_LOOKS=phone` only the phone's
/// and tablet's, `AUDIT_LOOKS=all` every one of [auditLooks], otherwise
/// the desktop's. The phone's join the default once every screen has its
/// phone layout (ADR-068, in progress).
List<AuditLook> get auditLooksToRun =>
    switch (Platform.environment['AUDIT_LOOKS']) {
      'phone' => [
        for (final look in auditLooks)
          if (look.formFactor == FormFactor.mobile) look,
      ],
      'all' => auditLooks,
      _ => [
        for (final look in auditLooks)
          if (look.formFactor != FormFactor.mobile) look,
      ],
    };

/// The look the audit is drawing in right now; null in every other test.
///
/// `pumpApp` and `appearanceOverrides` read it, so a scene is pumped the
/// way its own test pumps it — the same fixtures, the same steps — only
/// in another window and at another text size. That is what lets every
/// golden double as an audit scene.
AuditLook? currentAuditLook;
