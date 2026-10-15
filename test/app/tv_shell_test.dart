import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../features/onboarding/onboarding_fakes.dart';
import '../features/settings/appearance_fakes.dart';
import 'app_harness.dart';

/// docs/07 and ADR-025: on a TV the app is the TV's, with nothing of the
/// desktop's that a remote can't use or a TV hasn't got: no Cast (the TV
/// is the player), no keycaps, no library, no keyboard page. The desktop
/// keeps all of it.
void main() {
  Future<AppUnderTest> open(
    WidgetTester tester, {
    required FormFactor formFactor,
    String location = '/settings',
  }) {
    final fakes = OnboardingFakes()..sources.seed();
    return pumpApp(
      tester,
      initialLocation: location,
      // A 1080p TV is 960 × 540 logical pixels.
      size: formFactor == FormFactor.tv
          ? const Size(960, 540)
          : const Size(1440, 900),
      withAppearance: true,
      overrides: [
        ...fakes.overrides,
        ...sourceShellOverrides,
        ...appearanceOverrides(),
        formFactorProvider.overrideWithValue(formFactor),
      ],
    );
  }

  Finder railItem(String label) => find.byWidgetPredicate(
    (widget) => widget is FocusableSurface && widget.semanticLabel == label,
  );

  testWidgets('on a TV: no Cast button, no keycaps, no Library, and '
      'Settings without Casting, Downloads or Keyboard shortcuts', (
    tester,
  ) async {
    await open(tester, formFactor: FormFactor.tv);

    expect(findByLabel('Cast'), findsNothing);
    expect(find.byType(Kbd), findsNothing);
    expect(railItem('Library'), findsNothing);
    expect(railItem('Live TV'), findsOneWidget);
    for (final gone in [
      'Casting',
      'Downloads & library',
      'Keyboard shortcuts',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.text('Playback'), findsOneWidget);
    expect(find.byType(TvSelectKey), findsOneWidget);
  });

  testWidgets('on the desktop, all of it is there', (tester) async {
    await open(tester, formFactor: FormFactor.desktop);

    expect(find.byType(Kbd), findsWidgets);
    expect(findByLabel('Cast'), findsOneWidget);
    expect(railItem('Library'), findsOneWidget);
    for (final kept in [
      'Casting',
      'Downloads & library',
      'Keyboard shortcuts',
    ]) {
      expect(find.text(kept), findsOneWidget, reason: kept);
    }
    expect(find.byType(TvSelectKey), findsNothing);
  });

  testWidgets('a remote has no pointer to start from: on a TV the first '
      'screen opens with a control focused; a desktop with none', (
    tester,
  ) async {
    await open(tester, formFactor: FormFactor.tv, location: '/');
    await tester.pump(const Duration(milliseconds: 500));
    expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));

    await open(tester, formFactor: FormFactor.desktop, location: '/');
    await tester.pump(const Duration(milliseconds: 500));
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
  });

  group("a remote's Back (the system's back)", () {
    late bool leftTheApp;
    setUp(() => leftTheApp = false);

    void watchTheExit(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') leftTheApp = true;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('on a TV, Back at a section goes Home, and only Back on '
        'Home leaves the app', (tester) async {
      watchTheExit(tester);
      final app = await open(tester, formFactor: FormFactor.tv);

      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, '/');
      expect(leftTheApp, isFalse);

      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(leftTheApp, isTrue);
    });

    testWidgets('on the desktop, nothing of it', (tester) async {
      watchTheExit(tester);
      final app = await open(tester, formFactor: FormFactor.desktop);

      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, '/settings');
      expect(leftTheApp, isTrue);
    });
  });
}
