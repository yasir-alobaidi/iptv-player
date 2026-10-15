// The coordinator's futures run on the test's clock; pumps drive them.
// ignore_for_file: unawaited_futures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_surface.dart';

import '../../design/design_harness.dart';
import 'support/playback_fakes.dart';

void main() {
  final picture = find.byKey(const ValueKey('fake-video'));
  final spinner = find.byType(CircularProgressIndicator);

  Future<void> pumpSurface(WidgetTester tester, Rig rig) => pumpDesign(
    tester,
    ProviderScope(
      overrides: [
        playerEngineProvider.overrideWithValue(rig.engine),
        playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
      ],
      child: const SizedBox(
        width: 640,
        height: 360,
        child: PlayerSurface(compact: true),
      ),
    ),
  );

  // The Bedroom TV (ADR-027): a film resumed after a channel showed the
  // channel's last picture under "Reconnecting" for about 30 s.
  testWidgets('a film reconnecting before its own picture shows none, never '
      "the channel's last one; after its own, that one", (tester) async {
    final rig = Rig();
    await pumpSurface(tester, rig);
    rig.coordinator.playLive(channel(1));
    await tester.pump();
    rig.engine.firstFrame();
    await tester.pump();
    expect(picture, findsOneWidget);

    rig.coordinator.playVod(
      PlayableMovie(movie(1)),
      from: const Duration(minutes: 3),
    );
    await tester.pump();
    expect(rig.state, isA<PlaybackOpening>());
    expect(picture, findsNothing);
    expect(spinner, findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(rig.state, isA<PlaybackReconnecting>());
    expect(picture, findsNothing);
    expect(find.byType(ReconnectingPill), findsOneWidget);

    // The next attempt shows the film; a stall then keeps its picture.
    await tester.pump(const Duration(seconds: 1));
    rig.engine.firstFrame();
    await tester.pump();
    expect(picture, findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    expect(rig.state, isA<PlaybackReconnecting>());
    expect(picture, findsOneWidget);
    expect(find.byType(ReconnectingPill), findsOneWidget);

    rig.coordinator.stop();
    await tester.pump();
  });
}
