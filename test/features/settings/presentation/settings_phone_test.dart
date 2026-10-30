import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/shell/bottom_bar.dart';
import 'package:iptv_player/app/shell/top_bar.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../../app/app_harness.dart';
import '../../onboarding/onboarding_fakes.dart';
import '../appearance_fakes.dart';

/// ADR-068: Settings on a phone held upright is one pane at a time — the
/// list of sections, then a section under "‹ Settings" — and a section's
/// rows put their control under their words. A tablet keeps two panes.
void main() {
  Future<AppUnderTest> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    String location = '/settings',
  }) {
    final fakes = OnboardingFakes()..sources.seed();
    return pumpApp(
      tester,
      initialLocation: location,
      size: size,
      withAppearance: true,
      overrides: [
        ...fakes.overrides,
        ...sourceShellOverrides,
        ...appearanceOverrides(),
        formFactorProvider.overrideWithValue(FormFactor.mobile),
      ],
    );
  }

  Finder backChip() => findByLabel('Back to Settings');
  Finder row(String label) => findByLabel(label);

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await settleApp(tester);
  }

  String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

  testWidgets("the compact top bar's Settings opens Settings, its list of "
      'sections, without an overflow', (tester) async {
    final app = await open(tester, location: '/');

    await tester.tap(
      find.descendant(
        of: find.byType(ShellTopBar),
        matching: findByLabel('Settings'),
      ),
    );
    await settleApp(tester);

    expect(app.location, '/settings');
    expect(tester.takeException(), isNull);
    for (final section in [
      'Sources',
      'Playback',
      'Guide',
      'Categories',
      'Appearance',
      'Data',
      'About & diagnostics',
    ]) {
      expect(row(section), findsOneWidget, reason: section);
    }
    expect(find.text('Casting'), findsNothing);
    expect(backChip(), findsNothing);
  });

  testWidgets('a section opens in place of the list; "‹ Settings", Esc '
      "and the system's Back each return to it, on the section's row", (
    tester,
  ) async {
    final app = await open(tester);

    Future<void> openAppearance() async {
      await tester.tap(row('Appearance'));
      await settleApp(tester);
      expect(backChip(), findsOneWidget);
      expect(find.text('Changes show at once.'), findsOneWidget);
      expect(row('Playback'), findsNothing);
      expect(focused(), 'Back to Settings');
    }

    void expectList() {
      expect(backChip(), findsNothing);
      expect(row('Playback'), findsOneWidget);
      expect(focused(), 'Settings: Appearance');
    }

    await openAppearance();
    await tester.tap(backChip());
    await settleApp(tester);
    expectList();

    await openAppearance();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleApp(tester);
    expectList();

    await openAppearance();
    await systemBack(tester);
    expectList();
    expect(app.location, '/settings');

    // From the list, Back is the shell's: Home.
    await systemBack(tester);
    expect(app.location, '/');
    expect(tester.takeException(), isNull);
  });

  testWidgets("a section's rows put the control under the words, a "
      'segmented control across the row', (tester) async {
    await open(tester);
    await tester.tap(row('Appearance'));
    await settleApp(tester);

    final title = tester.getRect(find.text('Accent'));
    final control = tester.getRect(
      find.byWidgetPredicate((w) => w is SegmentedControl).first,
    );
    final screen = tester.getRect(find.byType(Scaffold).first);
    expect(control.top, greaterThan(title.bottom));
    expect(control.width, greaterThan(screen.width - 40));
    for (final element in find.byType(FocusableSurface).evaluate()) {
      final box = element.renderObject! as RenderBox;
      if (!box.hasSize || box.size.isEmpty) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      expect(rect.right, lessThanOrEqualTo(390.5), reason: '$element');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the place is kept: back in Settings, the section left open '
      'is open', (tester) async {
    final app = await open(tester);
    await tester.tap(row('Sources'));
    await settleApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(ShellBottomBar),
        matching: findByLabel('Home'),
      ),
    );
    await settleApp(tester);
    expect(app.location, '/');
    await tester.tap(
      find.descendant(
        of: find.byType(ShellTopBar),
        matching: findByLabel('Settings'),
      ),
    );
    await settleApp(tester);

    expect(backChip(), findsOneWidget);
    expect(find.text('Add source'), findsOneWidget);
  });

  testWidgets("the top bar's Settings, in Settings, returns to the list", (
    tester,
  ) async {
    await open(tester);
    await tester.tap(row('Appearance'));
    await settleApp(tester);
    expect(backChip(), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ShellTopBar),
        matching: findByLabel('Settings'),
      ),
    );
    await settleApp(tester);

    expect(backChip(), findsNothing);
    expect(row('Sources'), findsOneWidget);
    expect(row('About & diagnostics'), findsOneWidget);
  });

  testWidgets("the source's chip opens Sources, whichever section was "
      'open last', (tester) async {
    final app = await open(tester);
    await tester.tap(row('Appearance'));
    await settleApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(ShellBottomBar),
        matching: findByLabel('Home'),
      ),
    );
    await settleApp(tester);

    await tester.tap(findByLabel('Source: Northwind TV'));
    await settleApp(tester);

    expect(app.location, '/settings');
    expect(backChip(), findsOneWidget);
    expect(find.text('Add source'), findsOneWidget);
  });

  testWidgets("a tablet keeps the two panes, with a finger's buttons", (
    tester,
  ) async {
    await open(tester, size: const Size(1024, 768));

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(backChip(), findsNothing);
    expect(find.text('Add source'), findsOneWidget);
    final buttons = find.byType(AppButton);
    expect(buttons, findsWidgets);
    for (final button in buttons.evaluate()) {
      final size = (button.renderObject! as RenderBox).size;
      expect(
        size.height,
        greaterThanOrEqualTo(touchTargetSize),
        reason: (button.widget as AppButton).label,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
