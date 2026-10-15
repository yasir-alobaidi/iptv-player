import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/still_watching.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import '../features/playback/support/playback_fakes.dart';

/// ADR-025: on a TV, long playback with no key from the remote asks, and
/// stops with no answer, so a TV switched off without the Google TV
/// knowing doesn't hold a one-connection source all night.
void main() {
  const after = Duration(minutes: 3);
  late Rig rig;
  late GoRouter router;
  var second = 0;

  Future<void> pumpPlaying(WidgetTester tester) async {
    rig = Rig();
    second = 0;
    router = GoRouter(
      initialLocation: '/play',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Home')),
        GoRoute(path: '/play', builder: (_, _) => const Text('Playing')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
          routerProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: router,
          builder: (context, child) =>
              StillWatching(after: after, child: child!),
        ),
      ),
    );
    await tester.runAsync(() => rig.coordinator.playLive(channel(1)));
    rig.engine.firstFrame();
    await tester.pump();
  }

  /// The stream going on, a second at a time, as mpv reports it.
  Future<void> play(WidgetTester tester, Duration length) async {
    for (var s = 0; s < length.inSeconds; s++) {
      rig.engine.progress(Duration(seconds: ++second));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('no key for the while asks; no answer stops and goes Home', (
    tester,
  ) async {
    await pumpPlaying(tester);
    await play(tester, after);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Still watching?'), findsOneWidget);
    expect(rig.state, isA<PlaybackPlaying>());

    await play(tester, StillWatching.answerWithin);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Still watching?'), findsNothing);
    expect(rig.state, isA<PlaybackIdle>());
    expect(rig.engine.calls, contains('stop'));
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a key on the remote starts the count again', (tester) async {
    await pumpPlaying(tester);
    await play(tester, after - const Duration(minutes: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await play(tester, const Duration(minutes: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Still watching?'), findsNothing);
    await rig.coordinator.stop();
  });

  testWidgets('Keep watching goes on playing, and asks again only after '
      'another while', (tester) async {
    await pumpPlaying(tester);
    await play(tester, after);
    await tester.pump(const Duration(milliseconds: 300));
    // Keep watching has the focus, as a remote meets it.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Still watching?'), findsNothing);
    expect(rig.state, isA<PlaybackPlaying>());

    await play(tester, StillWatching.answerWithin);
    expect(rig.state, isA<PlaybackPlaying>());
    expect(find.text('Still watching?'), findsNothing);
    await rig.coordinator.stop();
  });
}
