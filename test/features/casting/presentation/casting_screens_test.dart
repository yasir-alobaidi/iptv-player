import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/casting_view.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import '../../../app/app_harness.dart';
import '../support/cast_fakes.dart';
import '../support/cast_ui_harness.dart';

/// The screens while casting (Phase 7 decision 2): Live TV's preview
/// (sketch B), a click that only chooses, Enter that plays on the TV, and
/// the player handing over to the casting view.
void main() {
  late CastUi ui;
  late ChannelItem arena;

  late AppUnderTest app;

  Future<void> pump(WidgetTester tester) async {
    ui = CastUi();
    addTearDown(() => tester.runAsync(ui.live.db.close));
    addTearDown(ui.dispose);
    await tester.runAsync(ui.live.seed);
    arena = (await tester.runAsync(() => ui.channel('201')))!;
    app = await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: ui.overrides,
    );
    await settleCast(tester);
  }

  void castTest(String description, Future<void> Function(WidgetTester) body) =>
      testWidgets(description, (tester) async {
        try {
          await body(tester);
        } finally {
          unawaited(ui.cast.coordinator.disconnect());
          await settleCast(tester);
          await ui.live.rig.coordinator.stop();
        }
      });

  Future<void> castArena(WidgetTester tester) async {
    unawaited(ui.cast.coordinator.connect(tvDevice));
    await settleCast(tester);
    unawaited(ui.live.rig.coordinator.playLive(arena));
    await settleCast(tester);
    ui.cast.relay.last.emit(const CastRelayFetched());
    ui.cast.tv.playing();
    await settleCast(tester);
  }

  castTest("Live TV's preview while casting: what is on the TV, and the "
      'way back to it', (tester) async {
    await pump(tester);
    await castArena(tester);

    expect(find.text('Playing on Living Room TV'), findsOneWidget);
    expect(find.text('201 · Arena Sports 1'), findsWidgets);
    expect(find.text('Enter on a channel plays it on the TV.'), findsOneWidget);
    await tester.tap(find.text('Arena Sports 2'));
    await settleCast(tester);
    expect(find.text('Play on Living Room TV'), findsOneWidget);
    expect(ui.live.rig.engine.opened, isEmpty, reason: 'no stream here');

    await tester.tap(find.text('Open casting view'));
    await settleCast(tester);
    expect(find.byType(CastingView), findsOneWidget);
  });

  castTest('a click chooses a channel, and changes nothing on the TV; Enter '
      'plays it there', (tester) async {
    await pump(tester);
    await castArena(tester);

    await tester.tap(find.text('Arena Sports 2'));
    await settleCast(tester);
    await tester.pump(const Duration(seconds: 1));
    await settleCast(tester);
    expect(ui.cast.tv.loads, hasLength(1));
    expect(ui.live.rig.engine.opened, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleCast(tester, rounds: 8);
    expect(ui.cast.tv.loads, hasLength(2));
    expect(
      (ui.cast.coordinator.state.item! as PlayableChannel).channel.remoteKey,
      '202',
    );
    expect(find.byType(CastingView), findsOneWidget);
    expect(ui.live.rig.engine.opened, isEmpty);
  });

  castTest('the player hands over to the casting view while casting', (
    tester,
  ) async {
    await pump(tester);
    await castArena(tester);
    final router = app.router;
    unawaited(router.push<void>(playerRoutePath));
    await settleCast(tester);
    expect(router.state.uri.path, isNot(playerRoutePath));
    expect(find.byType(CastingView), findsOneWidget);
    expect(ui.live.rig.state, isA<PlaybackCasting>());
    expect(ui.cast.coordinator.state.phase, CastPhase.playing);
  });
}
