import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/shell/nav_rail.dart';
import 'package:iptv_player/app/shell/top_bar.dart';
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
    // The time is the bar's last thing, a TV having no clock of its own
    // in an app (ADR-065).
    expect(
      find.descendant(
        of: find.byType(ShellTopBar),
        matching: find.byType(ShellClock),
      ),
      findsOneWidget,
    );
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

  testWidgets('Settings → Data on a TV: no Export or Import (a TV has no '
      'files), and nothing said of "this computer"', (tester) async {
    await open(tester, formFactor: FormFactor.tv);
    await tester.tap(find.text('Data'));
    await settleApp(tester);

    expect(find.text('Pictures'), findsOneWidget);
    expect(find.text('Export…'), findsNothing);
    expect(find.text('Import…'), findsNothing);
    expect(find.textContaining('this computer'), findsNothing);
  });

  testWidgets("a TV's screen is laid out 1280 wide (a 1080p TV is 960 "
      'across to Android), scaled to fill it; the desktop as it is', (
    tester,
  ) async {
    await open(tester, formFactor: FormFactor.tv);
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(NavRail))).width,
      TvCanvas.width,
    );
    expect(tester.getRect(find.byType(NavRail)).bottom, 540);

    await open(tester, formFactor: FormFactor.desktop);
    expect(MediaQuery.sizeOf(tester.element(find.byType(NavRail))).width, 1440);
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

  group('a remote finds its way (the user, on the Bedroom TV)', () {
    String? focused() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return null;
      return (context.widget is FocusableSurface
              ? context.widget as FocusableSurface
              : context.findAncestorWidgetOfExactType<FocusableSurface>())
          ?.semanticLabel;
    }

    bool inTopBar() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<ShellTopBar>() !=
        null;

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await settleApp(tester);
    }

    testWidgets('Up at the top of the screen reaches the top bar (the '
        'search, the source), and Down comes back', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      await tester.pump(const Duration(milliseconds: 500));
      expect(inTopBar(), isFalse);

      for (var i = 0; i < 6 && !inTopBar(); i++) {
        await press(tester, LogicalKeyboardKey.arrowUp);
      }
      expect(inTopBar(), isTrue);

      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(inTopBar(), isFalse);
      expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
    });

    testWidgets('Left walks a row of buttons, and only at the edge of the '
        'screen goes to the rail', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      Focus.of(tester.element(find.text('Edit').first)).requestFocus();
      await settleApp(tester);
      expect(focused(), 'Edit');

      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(focused(), 'Sync now');

      bool inRail() =>
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<NavRail>() !=
          null;
      final walked = <String?>[];
      for (var i = 0; i < 6 && !inRail(); i++) {
        await press(tester, LogicalKeyboardKey.arrowLeft);
        walked.add(focused());
      }
      expect(inRail(), isTrue);
      // Through Settings' own list on the way.
      expect(walked.length, greaterThan(1));
      // Onto the screen's own item.
      expect(walked.last, 'Settings', reason: '$walked');
    });

    testWidgets('Left from the top of a screen lands on its own rail item, '
        "not the rail's first", (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      // The first section of Settings' list, level with Home.
      Focus.of(tester.element(find.text('Sources').first)).requestFocus();
      await settleApp(tester);
      expect(focused(), isNot('Settings'));

      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(focused(), 'Settings');
    });

    testWidgets('the rail has no expand toggle on a TV (it is too narrow '
        'to expand); the desktop keeps it', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      expect(railItem('Expand menu'), findsNothing);

      await open(tester, formFactor: FormFactor.desktop);
      expect(railItem('Expand menu'), findsOneWidget);
    });

    testWidgets('something always has the focus: when it is lost (a page '
        'or a dialog closed) the screen takes it back', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      await tester.pump(const Duration(milliseconds: 500));
      FocusManager.instance.primaryFocus?.unfocus();
      await settleApp(tester);
      expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
    });
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
