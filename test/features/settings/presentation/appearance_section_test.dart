import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/text_scale.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/settings/domain/appearance_store.dart';
import 'package:iptv_player/features/settings/presentation/appearance_section.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../../app/app_harness.dart';
import '../../../design/design_harness.dart';
import '../../casting/support/cast_ui_harness.dart' show focusedLabelOf;
import '../../onboarding/onboarding_fakes.dart';
import '../appearance_fakes.dart';

void main() {
  /// 8:05 in the evening wherever the test runs (CI is UTC).
  final now = DateTime(2026, 9, 14, 20, 5);

  /// Settings, with Appearance chosen in its list.
  Future<void> open(
    WidgetTester tester, {
    AppearanceStore? store,
    SystemAppearance desktop = const SystemAppearance(),
    Size size = const Size(1440, 900),
  }) async {
    final fakes = OnboardingFakes()
      ..sources.seed()
      ..now = now;
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      size: size,
      withAppearance: true,
      overrides: [
        ...fakes.overrides,
        ...sourceShellOverrides,
        ...appearanceOverrides(store: store, desktop: desktop),
      ],
    );
    await tester.tap(find.text('Appearance').first);
    await settleApp(tester);
  }

  BuildContext page(WidgetTester tester) =>
      tester.element(find.byType(AppearanceSection));

  /// Tab until the control labelled [label] has the focus.
  Future<void> tabTo(WidgetTester tester, String label) async {
    for (var i = 0; i < 40; i++) {
      if (focusedLabelOf(tester) == label) return;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    fail('Tab never reached "$label" (on ${focusedLabelOf(tester)})');
  }

  testWidgets('every control is a Tab stop with a focus ring, in the order '
      'the page reads', (tester) async {
    await open(tester);
    Focus.of(tester.element(find.text('Appearance').first)).requestFocus();
    await tester.pump();

    // Out of Settings' list and into the page.
    await tabTo(tester, 'Blue');

    final walked = <String>[];
    for (var i = 0; i < 17; i++) {
      if (i > 0) await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      // One frame for the focus to land, one for its ring to be drawn.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final focused = FocusManager.instance.primaryFocus!.context!;
      final surface = focused.widget is FocusableSurface
          ? focused.widget
          : focused.findAncestorWidgetOfExactType<FocusableSurface>()!;
      walked.add(focusedLabelOf(tester)!);
      expect(
        hasFocusRing(tester, of: find.byWidget(surface)),
        isTrue,
        reason: 'no ring on ${walked.last}',
      );
    }

    expect(walked, [
      'Blue', 'Violet', 'Teal', 'Amber', 'Rose', //
      'System', '100 %', '115 %', '130 %', //
      'Comfortable', 'Compact', //
      'System', 'On', 'Off', //
      'System', '12-hour', '24-hour',
    ]);
  });

  testWidgets('an accent chosen with Enter shows at once and is saved', (
    tester,
  ) async {
    final store = ScriptedAppearanceStore();
    await open(tester, store: store);
    expect(page(tester).tokens.colors.accent, AppAccent.blue);

    await tabTo(tester, 'Teal');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(page(tester).tokens.colors.accent, AppAccent.teal);
    expect(store.saved.single.accent, AppAccent.teal);
    // The focus stays where it was: the next key is the user's.
    expect(focusedLabelOf(tester), 'Teal');
  });

  testWidgets('a text size, the density and reduce motion each show at once', (
    tester,
  ) async {
    final store = ScriptedAppearanceStore();
    await open(tester, store: store);
    expect(page(tester).textScale, 1);

    await tabTo(tester, '130 %');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(page(tester).textScale, 1.3);

    await tabTo(tester, 'Compact');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(page(tester).tokens.density, AppDensity.compact);

    await tabTo(tester, 'On');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(page(tester).tokens.motion.reduceMotion, isTrue);

    expect(
      store.saved.last,
      const AppearanceSettings(
        textSize: TextSizeChoice.s130,
        density: AppDensity.compact,
        reduceMotion: SystemSwitch.on,
      ),
    );
    await settleApp(tester);
  });

  testWidgets('the clock says the time as it will be written', (tester) async {
    await open(tester);
    expect(
      find.text('It is 8:05 PM, as your desktop writes it.'),
      findsOneWidget,
    );

    await tabTo(tester, '24-hour');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('It is 20:05.'), findsOneWidget);
    expect(page(tester).tokens.timeStyle, TimeStyle.h24);
  });

  testWidgets('System says what the desktop answers, and the cap', (
    tester,
  ) async {
    await open(
      tester,
      desktop: const SystemAppearance(
        textScale: 1.5,
        reduceMotion: true,
        use24Hour: true,
      ),
    );

    expect(page(tester).textScale, 1.3);
    expect(
      find.textContaining('Your desktop is at 150 %, so this is 130 %.'),
      findsOneWidget,
    );
    expect(page(tester).tokens.motion.reduceMotion, isTrue);
    expect(
      find.textContaining('Your desktop has animations off, so this is on.'),
      findsOneWidget,
    );
    expect(
      find.text('It is 20:05, as your desktop writes it.'),
      findsOneWidget,
    );
  });

  testWidgets('the first frame already has the stored look', (tester) async {
    final fakes = OnboardingFakes()..sources.seed();
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      withAppearance: true,
      settle: false,
      overrides: [
        ...fakes.overrides,
        ...sourceShellOverrides,
        ...appearanceOverrides(
          settings: const AppearanceSettings(
            accent: AppAccent.rose,
            textSize: TextSizeChoice.s115,
            density: AppDensity.compact,
            reduceMotion: SystemSwitch.on,
            clock: ClockChoice.h24,
          ),
        ),
      ],
    );

    final context = tester.element(find.byType(SettingsScreen));
    expect(context.tokens.colors.accent, AppAccent.rose);
    expect(context.tokens.density, AppDensity.compact);
    expect(context.tokens.motion.reduceMotion, isTrue);
    expect(context.tokens.timeStyle, TimeStyle.h24);
    expect(context.textScale, 1.15);
    await settleApp(tester);
  });

  testWidgets("settings that couldn't be read: the usual ones, a line that "
      'says so, and Try again', (tester) async {
    final store = ScriptedAppearanceStore(
      const AppearanceSettings(accent: AppAccent.amber),
    )..readFailure = StorageFailure('locked');
    await open(tester, store: store);

    expect(find.textContaining("Couldn't read your settings"), findsOneWidget);
    expect(page(tester).tokens.colors.accent, AppAccent.blue);

    store.readFailure = null;
    await tabTo(tester, 'Try again');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);

    expect(find.textContaining("Couldn't read your settings"), findsNothing);
    expect(page(tester).tokens.colors.accent, AppAccent.amber);
  });

  testWidgets("a change that can't be saved shows anyway, and says it lasts "
      'until the app closes', (tester) async {
    final store = ScriptedAppearanceStore()
      ..saveFailure = StorageFailure('disk full');
    await open(tester, store: store);

    await tabTo(tester, 'Violet');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);

    expect(page(tester).tokens.colors.accent, AppAccent.violet);
    expect(find.textContaining("Couldn't save that change"), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
  });

  testWidgets('at 130 % in the smallest window nothing overflows: a control '
      'that no longer fits beside its words goes under them', (tester) async {
    await open(
      tester,
      size: const Size(1024, 640),
      store: InMemoryAppearanceStore(
        const AppearanceSettings(textSize: TextSizeChoice.s130),
      ),
    );

    expect(tester.takeException(), isNull);
    // The accents no longer fit beside "Accent": they sit under it.
    final words = tester.getBottomLeft(
      find.text('The colour of what is chosen, focused or playing.'),
    );
    final control = tester.getTopLeft(find.text('Blue'));
    expect(control.dy, greaterThan(words.dy));

    // And every control is still reached, the last one scrolled into view.
    Focus.of(tester.element(find.text('Appearance').first)).requestFocus();
    await tester.pump();
    await tabTo(tester, '24-hour');
    await settleApp(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.text('24-hour')).bottom, lessThanOrEqualTo(640));
  });

  test('the notes under Text size', () {
    String note(
      double desktop, [
      TextSizeChoice choice = TextSizeChoice.system,
    ]) => textSizeNote(choice, SystemAppearance(textScale: desktop));

    expect(
      note(1),
      "System follows your desktop's text size, up to 130 %. "
      'Your desktop is at 100 %.',
    );
    expect(note(1.25), endsWith('Your desktop is at 125 %.'));
    expect(note(0.9), endsWith('Your desktop is at 90 %, so this is 100 %.'));
    expect(
      note(1.5, TextSizeChoice.s115),
      "System follows your desktop's text size, up to 130 %.",
    );
    expect(
      note(double.nan),
      "System follows your desktop's text size, up to 130 %.",
    );
  });
}
