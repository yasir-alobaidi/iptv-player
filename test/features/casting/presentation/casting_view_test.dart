import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/casting_view.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';

import '../../../app/app_harness.dart';
import '../../playback/support/playback_fakes.dart';
import '../support/cast_fakes.dart';
import '../support/cast_ui_harness.dart';

/// The casting view (canvas `Casting`, sketches A and D) and the bar
/// under it, on a real cast coordinator over fakes.
void main() {
  late CastUi ui;
  late ChannelItem arena;

  Future<void> pump(WidgetTester tester) async {
    ui = CastUi();
    addTearDown(() => tester.runAsync(ui.live.db.close));
    addTearDown(ui.dispose);
    await tester.runAsync(ui.live.seed);
    arena = (await tester.runAsync(() => ui.channel('201')))!;
    final now = ui.live.fakes.now;
    ui.live.guide.byKey['201'] = NowNext(
      now: Programme(
        title: 'Continental Cup · Semi-final',
        start: now.subtract(const Duration(minutes: 30)),
        end: now.add(const Duration(minutes: 90)),
      ),
    );
    await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: ui.overrides,
    );
    await settleCast(tester);
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  /// A session on the TV, [item] playing there, the view open.
  Future<void> cast(WidgetTester tester, Playable item) async {
    unawaited(ui.cast.coordinator.connect(tvDevice));
    await settleCast(tester);
    final playback = ui.live.rig.coordinator;
    unawaited(switch (item) {
      PlayableChannel(:final channel) => playback.playLive(channel),
      _ => playback.playVod(item),
    });
    container(tester).read(castingViewOpenProvider.notifier).open();
    await settleCast(tester);
    ui.cast.relay.sessions.lastOrNull?.emit(const CastRelayFetched());
    ui.cast.tv.playing();
    await settleCast(tester);
  }

  Future<void> stopCasting(WidgetTester tester) async {
    unawaited(ui.cast.coordinator.disconnect());
    await settleCast(tester);
  }

  /// A test that always ends its session while it can still pump: a
  /// session left on keeps timers going, and teardown would wait for good.
  void castTest(String description, Future<void> Function(WidgetTester) body) =>
      testWidgets(description, (tester) async {
        try {
          await body(tester);
        } finally {
          await stopCasting(tester);
          await ui.live.rig.coordinator.stop();
        }
      });

  castTest('live: what plays on the TV, the badge and its words, the bar', (
    tester,
  ) async {
    await pump(tester);
    await cast(tester, PlayableChannel(arena));

    expect(find.byType(CastingView), findsOneWidget);
    expect(find.text('PLAYING ON LIVING ROOM TV'), findsOneWidget);
    expect(find.text('201 · Arena Sports 1'), findsOneWidget);
    expect(find.text('Continental Cup · Semi-final'), findsWidgets);
    expect(find.text('ORIGINAL QUALITY'), findsOneWidget);
    expect(find.text('1080p · 50 fps · H.264 · AAC 2.0'), findsOneWidget);
    expect(
      find.text(
        'Video and audio go to your TV untouched. Nothing is '
        're-encoded.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Casting to Living Room TV · Original quality'),
      findsOneWidget,
    );
    expect(findByLabel('Previous channel'), findsOneWidget);
    expect(findByLabel('Pause'), findsNothing, reason: 'no pause for live');
    await stopCasting(tester);
  });

  castTest('↓ changes channel on the TV, after the keys rest', (tester) async {
    await pump(tester);
    await cast(tester, PlayableChannel(arena));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settleCast(tester, rounds: 3);
    expect(
      find.textContaining('Arena Sports 2'),
      findsWidgets,
      reason: 'the channel the key reached, shown before it plays',
    );
    // The next channel is looked up in the database first.
    await settleCast(tester, rounds: 3);
    expect(ui.cast.tv.loads, hasLength(1), reason: 'not yet');
    for (var i = 0; i < 3; i++) {
      await tester.pump(CastingView.zapDebounce);
      await settleCast(tester);
    }
    expect(ui.cast.tv.loads, hasLength(2));
    expect(
      (ui.cast.coordinator.state.item! as PlayableChannel).channel.remoteKey,
      '202',
    );
    await stopCasting(tester);
  });

  castTest('connecting says so; the TV launching does not hold the '
      'relay', (tester) async {
    await pump(tester);
    final launching = ui.cast.receivers.launching = Completer<void>();
    unawaited(ui.cast.coordinator.connect(tvDevice));
    unawaited(ui.live.rig.coordinator.playLive(arena));
    container(tester).read(castingViewOpenProvider.notifier).open();
    await settleCast(tester);
    expect(find.text('Connecting to Living Room TV…'), findsOneWidget);
    expect(find.text('CONNECTING TO LIVING ROOM TV'), findsOneWidget);
    expect(ui.cast.relay.sessions, hasLength(1));
    launching.complete();
    await settleCast(tester);
    expect(find.text('Connecting to Living Room TV…'), findsNothing);
    await stopCasting(tester);
  });

  castTest('reconnecting: the pill, and the bar says so', (tester) async {
    await pump(tester);
    await cast(tester, PlayableChannel(arena));
    ui.cast.tv.emit(ui.cast.tv.state.copyWith(link: CastLink.reconnecting));
    await settleCast(tester);
    expect(find.text('Reconnecting to Living Room TV…'), findsNWidgets(2));
    await stopCasting(tester);
  });

  castTest("failed: why in docs/03's words, Details, Try again, Play here", (
    tester,
  ) async {
    await pump(tester);
    await cast(tester, PlayableChannel(arena));
    ui.cast.relay.last.fail(
      const CastRelayFailure(
        CastRelayFailureKind.providerRefused,
        status: 401,
        detail: 'HTTP error 401 Unauthorized',
      ),
    );
    await settleCast(tester);
    expect(find.text('Your provider refused this account'), findsOneWidget);
    await tester.tap(find.text('Details'));
    await settleCast(tester);
    expect(find.textContaining('HTTP error 401 Unauthorized'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await settleCast(tester);
    expect(ui.cast.relay.sessions, hasLength(2));
    ui.cast.relay.last.fail(
      const CastRelayFailure(CastRelayFailureKind.providerUnreachable),
    );
    await settleCast(tester);

    await tester.tap(find.text('Play here'));
    await settleCast(tester);
    expect(ui.cast.coordinator.state.phase, CastPhase.off);
    expect(ui.live.rig.engine.opened.single.url, contains('201'));
    expect(find.byType(CastingView), findsNothing);
    await ui.live.rig.coordinator.stop();
  });

  castTest('a file: its place and length, ←/→ seek, Space pauses', (
    tester,
  ) async {
    await pump(tester);
    ui.cast.probe.next = const StreamProbed(mkvFacts);
    await cast(tester, PlayableMovie(movie(7)));
    ui.cast.tv.playing(position: const Duration(minutes: 1));
    await settleCast(tester);
    expect(find.text('Movie 7'), findsWidgets);
    expect(find.text('1:40:00'), findsOneWidget);
    expect(findByLabel('Previous channel'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settleCast(tester);
    await tester.pump(CastingView.seekDebounce);
    await settleCast(tester);
    final seek = ui.cast.relay.last.renews.single.startAt!;
    expect(seek, greaterThanOrEqualTo(const Duration(minutes: 1, seconds: 20)));
    expect(seek, lessThan(const Duration(minutes: 1, seconds: 30)));

    ui.cast.tv.playing();
    await settleCast(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settleCast(tester);
    expect(ui.cast.tv.calls, contains('pause'));
    // The bar has its own.
    await tester.tap(
      find.descendant(
        of: find.byType(CastingBar),
        matching: findByLabel('Pause'),
      ),
    );
    await settleCast(tester);
    expect(ui.cast.tv.calls.where((c) => c == 'pause'), hasLength(2));
    await stopCasting(tester);
  });

  castTest('Esc goes back while the cast goes on; the bar opens the view '
      'again', (tester) async {
    await pump(tester);
    await cast(tester, PlayableChannel(arena));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleCast(tester);
    expect(find.byType(CastingView), findsNothing);
    expect(ui.cast.coordinator.state.phase, CastPhase.playing);
    expect(
      find.text('Playing on Living Room TV'),
      findsOneWidget,
      reason: "Live TV's preview while casting (sketch B)",
    );

    await tester.tap(find.text('Casting to Living Room TV · Original quality'));
    await settleCast(tester);
    expect(find.byType(CastingView), findsOneWidget);
    await stopCasting(tester);
  });

  castTest('Stop casting ends it: the view and the bar go', (tester) async {
    await pump(tester);
    await cast(tester, PlayableChannel(arena));
    await tester.tap(
      find.descendant(
        of: find.byType(CastingView),
        matching: find.text('Stop casting'),
      ),
    );
    await settleCast(tester);
    expect(ui.cast.coordinator.state.phase, CastPhase.off);
    expect(find.byType(CastingView), findsNothing);
    expect(find.textContaining('Casting to Living Room TV'), findsNothing);
    expect(ui.cast.tv.calls, contains('stop'));
  });

  castTest('M mutes the TV', (tester) async {
    await pump(tester);
    await cast(tester, PlayableChannel(arena));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await settleCast(tester);
    expect(ui.cast.tv.calls, contains('muted:true'));
    await stopCasting(tester);
  });
}
