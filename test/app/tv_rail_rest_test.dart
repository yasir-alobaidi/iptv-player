import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/nav_rail.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/presentation/preview_pane.dart';

import '../features/home/home_fakes.dart';
import '../features/vod/vod_fakes.dart';
import 'app_harness.dart';

/// On a TV a rest on a rail item opens it (the user: "when I move it will
/// take me to the page and that's it"); moving on before
/// [NavRail.openAfter] opens nothing, and the screen shown is never taken
/// back to its root. The desktop opens with Enter or a click only.
void main() {
  late HomeFakes home;
  late AppUnderTest app;

  /// Every path the router showed after the app opened, in order.
  late List<String> visited;

  Future<void> open(
    WidgetTester tester, {
    FormFactor formFactor = FormFactor.tv,
    String location = '/',
  }) async {
    home = HomeFakes();
    addTearDown(() => tester.runAsync(home.db.close));
    await tester.runAsync(home.seed);
    app = await pumpApp(
      tester,
      initialLocation: location,
      // A 1080p TV is 960 × 540 logical pixels.
      size: formFactor == FormFactor.tv
          ? const Size(960, 540)
          : const Size(1440, 900),
      overrides: [
        ...home.overrides,
        formFactorProvider.overrideWithValue(formFactor),
      ],
    );
    await settle(tester);
    visited = [];
    void record() {
      if (visited.lastOrNull != app.location) visited.add(app.location);
    }

    app.router.routerDelegate.addListener(record);
    addTearDown(() => app.router.routerDelegate.removeListener(record));
  }

  String? focused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    return (context.widget is FocusableSurface
            ? context.widget as FocusableSurface
            : context.findAncestorWidgetOfExactType<FocusableSurface>())
        ?.semanticLabel;
  }

  bool inRail() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<NavRail>() !=
      null;

  /// One press, and the frame that moves the focus; no time passes.
  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  /// From the screen into the rail, onto the item of the screen shown.
  Future<void> intoTheRail(WidgetTester tester) async {
    for (var i = 0; i < 6 && !inRail(); i++) {
      await press(tester, LogicalKeyboardKey.arrowLeft);
    }
    expect(inRail(), isTrue);
  }

  /// Lets the focus rest: past the wait, and the frames of what opened.
  Future<void> rest(WidgetTester tester) async {
    await tester.pump(NavRail.openAfter);
    await settleApp(tester);
  }

  const justUnder = Duration(milliseconds: 250);

  testWidgets('a rest on a rail item opens its page, as OK does, the focus '
      'staying on the item; Right goes into the page', (tester) async {
    await open(tester);
    await intoTheRail(tester);
    expect(focused(), AppDestination.home.label);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), AppDestination.liveTv.label);
    await tester.pump(justUnder);
    expect(app.location, AppDestination.home.path, reason: 'not yet');
    await rest(tester);
    expect(app.location, AppDestination.liveTv.path);
    expect(focused(), AppDestination.liveTv.label);

    await press(tester, LogicalKeyboardKey.arrowDown);
    await rest(tester);
    expect(app.location, AppDestination.movies.path);
    expect(focused(), AppDestination.movies.label);
    expect(visited, [AppDestination.liveTv.path, AppDestination.movies.path]);

    await press(tester, LogicalKeyboardKey.arrowRight);
    await settleApp(tester);
    expect(inRail(), isFalse);
    expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
    expect(app.location, AppDestination.movies.path);
  });

  testWidgets('quick presses open nothing on the way, only where the focus '
      'stops', (tester) async {
    await open(tester);
    await intoTheRail(tester);

    for (var i = 0; i < 3; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
      await tester.pump(justUnder);
    }
    expect(focused(), AppDestination.series.label);
    expect(visited, isEmpty, reason: 'nothing opened on the way');

    await rest(tester);
    expect(visited, [AppDestination.series.path]);
    expect(focused(), AppDestination.series.label);
    // Live TV, passed over, took no stream.
    expect(home.rig.engine.opened, isEmpty);
  });

  testWidgets('a held arrow (key repeats) opens only where it stops; '
      'Settings at the bottom opens on a rest too', (tester) async {
    await open(tester);
    await intoTheRail(tester);

    // Android repeats a held key 20 times a second: Home to Favorites.
    const repeat = Duration(milliseconds: 50);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(repeat);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(repeat);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), AppDestination.favorites.label);
    expect(visited, isEmpty, reason: 'nothing opened while it was held');

    await rest(tester);
    expect(visited, [AppDestination.favorites.path]);
    expect(focused(), AppDestination.favorites.label);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), AppDestination.settings.label);
    await rest(tester);
    expect(app.location, AppDestination.settings.path);
    expect(focused(), AppDestination.settings.label);
  });

  testWidgets("a rest on the screen shown keeps its page (a film's under "
      'Movies), and coming back by a rest finds it there', (tester) async {
    const film = '/movies/src-1/501';
    await open(tester, location: film);
    await intoTheRail(tester);
    expect(focused(), AppDestination.movies.label);

    await rest(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(app.location, film, reason: 'not Movies at its root');

    // Down to Series and back up to Movies, under the wait.
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump(justUnder);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await rest(tester);
    expect(app.location, film);
    expect(visited, isEmpty);

    // Up to Live TV, then back to Movies: the film's page again.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await rest(tester);
    expect(app.location, AppDestination.liveTv.path);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await rest(tester);
    expect(app.location, film);
    expect(focused(), AppDestination.movies.label);
  });

  testWidgets("Back on a TV goes Home from the rail too, and the rail's "
      'focus goes with it: on the item left, a rest would open it again', (
    tester,
  ) async {
    // Launched on Live TV: Home is built by the Back, which takes the
    // focus into its route and gives it back to the rail.
    await open(tester, location: AppDestination.liveTv.path);
    await intoTheRail(tester);
    expect(focused(), AppDestination.liveTv.label);

    await tester.binding.handlePopRoute();
    await settleApp(tester);
    await tester.pump(const Duration(seconds: 1));
    await settleApp(tester);
    expect(app.location, AppDestination.home.path);
    expect(focused(), AppDestination.home.label);
  });

  testWidgets('Live TV opened by a rest takes no stream (the provider allows '
      'one) until the focus reaches a channel', (tester) async {
    await open(tester);
    await intoTheRail(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await rest(tester);
    expect(app.location, AppDestination.liveTv.path);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(home.rig.engine.opened, isEmpty);

    // Into the page: the categories first, then the channels.
    await press(tester, LogicalKeyboardKey.arrowRight);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(inRail(), isFalse);
    expect(home.rig.engine.opened, isEmpty);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(PreviewPane.debounce);
    await settle(tester);
    expect(focused(), 'Arena Sports 1');
    expect(home.rig.engine.opened, hasLength(1));
    expect(home.rig.engine.opened.single.url, contains('201'));

    await home.rig.coordinator.stop();
    await settle(tester);
  });

  testWidgets('the desktop opens nothing on focus: Enter opens it', (
    tester,
  ) async {
    await open(tester, formFactor: FormFactor.desktop);
    tester
        .widget<FocusableActionDetector>(
          find
              .descendant(
                of: findByLabel(AppDestination.movies.label),
                matching: find.byType(FocusableActionDetector),
              )
              .first,
        )
        .focusNode!
        .requestFocus();
    await tester.pump();
    expect(focused(), AppDestination.movies.label);

    await tester.pump(const Duration(seconds: 1));
    await settleApp(tester);
    expect(app.location, AppDestination.home.path);

    await press(tester, LogicalKeyboardKey.enter);
    await settleApp(tester);
    expect(app.location, AppDestination.movies.path);
  });
}
