import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/shell/bottom_bar.dart';
import 'package:iptv_player/app/shell/nav_rail.dart';
import 'package:iptv_player/app/shell/top_bar.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../features/onboarding/onboarding_fakes.dart';
import '../features/settings/appearance_fakes.dart';
import 'app_harness.dart';

/// ADR-068: on a phone, a tablet or a Chromebook the app is a touch app:
/// a phone held upright has the bottom bar and a compact top bar; wider,
/// the rail. Nothing of the desktop's it can't do (Cast, downloads, the
/// Library, keycaps), nothing of the TV's remote (its canvas, its keys).
void main() {
  Future<AppUnderTest> open(
    WidgetTester tester, {
    FormFactor formFactor = FormFactor.mobile,
    Size size = const Size(390, 844),
    String location = '/',
    bool offline = false,
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
        formFactorProvider.overrideWithValue(formFactor),
        if (offline) appOfflineProvider.overrideWith((_) => Stream.value(true)),
      ],
    );
  }

  Finder bottomItem(String label) => find.descendant(
    of: find.byType(ShellBottomBar),
    matching: findByLabel(label),
  );

  testWidgets('a phone held upright: the bottom bar with Home, Live TV, '
      'Movies, Series and Favorites; Search and Settings in the top bar; '
      'no rail, Cast, Library, keycaps or TV canvas', (tester) async {
    await open(tester);

    expect(find.byType(NavRail), findsNothing);
    expect(find.byType(ShellBottomBar), findsOneWidget);
    for (final label in ['Home', 'Live TV', 'Movies', 'Series', 'Favorites']) {
      expect(bottomItem(label), findsOneWidget, reason: label);
    }
    expect(bottomItem('Library'), findsNothing);
    expect(bottomItem('Settings'), findsNothing);
    expect(
      tester.widget<ShellTopBar>(find.byType(ShellTopBar)).compact,
      isTrue,
    );
    expect(findByLabel('Search'), findsOneWidget);
    expect(findByLabel('Settings'), findsOneWidget);
    expect(findByLabel('Cast'), findsNothing);
    expect(find.byType(Kbd), findsNothing);
    expect(find.byType(TvCanvas), findsNothing);
    expect(find.byType(TvSelectKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bottom bar opens its destination; Settings is without '
      'Casting, Downloads or the keyboard page', (tester) async {
    final app = await open(tester);

    await tester.tap(bottomItem('Movies'));
    await settleApp(tester);
    expect(app.location, '/movies');

    // The sections, at a tablet's width (a phone's Settings is its own
    // layout, test/features/settings).
    await open(tester, size: const Size(1024, 768), location: '/settings');
    for (final gone in [
      'Casting',
      'Downloads & library',
      'Keyboard shortcuts',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.text('Playback'), findsWidgets);
  });

  testWidgets("the compact bar's title is never cut for the source's "
      'chip', (tester) async {
    await open(tester, size: const Size(360, 780), location: '/settings');
    final title = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(ShellTopBar),
        matching: find.text('Settings'),
      ),
    );
    expect(title.didExceedMaxLines, isFalse);
  });

  testWidgets('wider (a tablet, a phone on its side): the rail and the top '
      'bar, still without Cast or the Library', (tester) async {
    await open(tester, size: const Size(1024, 768));

    expect(find.byType(NavRail), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
    expect(
      tester.widget<ShellTopBar>(find.byType(ShellTopBar)).compact,
      isFalse,
    );
    expect(findByLabel('Cast'), findsNothing);
    expect(findByLabel('Library'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline on a phone or a TV: no downloads or files to '
      'offer, and no Library to open; the desktop keeps both', (tester) async {
    await open(tester, offline: true);
    expect(find.textContaining('downloads and local files'), findsNothing);
    expect(
      find.text(
        "You're offline — check this device's connection to the internet.",
      ),
      findsOneWidget,
    );
    expect(find.text('Open Library'), findsNothing);

    await open(
      tester,
      formFactor: FormFactor.tv,
      size: const Size(960, 540),
      offline: true,
    );
    expect(find.textContaining('downloads and local files'), findsNothing);
    expect(find.text('Open Library'), findsNothing);

    await open(
      tester,
      formFactor: FormFactor.desktop,
      size: const Size(1440, 900),
      offline: true,
    );
    expect(find.textContaining('downloads and local files'), findsOneWidget);
    expect(find.text('Open Library'), findsOneWidget);
  });
}
