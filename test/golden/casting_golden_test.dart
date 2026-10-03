// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/features/casting/domain/cast_coordinator.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/casting/support/cast_fakes.dart';
import '../features/casting/support/cast_ui_harness.dart';
import '../features/playback/support/playback_fakes.dart';
import 'golden_harness.dart';

const _bedroom = CastDevice(
  id: 'bedroom',
  name: 'Bedroom',
  host: '192.168.1.60',
  model: 'Chromecast',
  manual: true,
);

const _kitchen = CastDevice(
  id: 'kitchen',
  name: 'Kitchen Speaker Display',
  host: '192.168.1.70',
  model: 'Chromecast built-in',
  status: 'Spotify',
);

void main() {
  late CastUi ui;
  late ChannelItem arena;

  Future<void> pump(WidgetTester tester, Size size) async {
    hideDebugBanner();
    ui = CastUi();
    ui.live.fakes.now = goldenNow();
    addTearDown(() => tester.runAsync(ui.live.db.close));
    addTearDown(ui.dispose);
    await tester.runAsync(ui.live.seed);
    arena = (await tester.runAsync(() => ui.channel('201')))!;
    final now = ui.live.fakes.now;
    ui.live.guide.byKey['201'] = NowNext(
      now: Programme(
        title: 'Continental Cup · Semi-final',
        start: now.subtract(const Duration(minutes: 74)),
        end: now.add(const Duration(minutes: 46)),
      ),
    );
    ui.cast.devices.devices['bedroom'] = const KnownCastDevice(
      id: 'bedroom',
      name: 'Bedroom',
      host: '192.168.1.60',
      port: 8009,
      manual: true,
      model: 'Chromecast',
      hevc: HevcSupport.no,
      learned: CastLearned(maxHeight: 1080),
    );
    await pumpApp(
      tester,
      size: size,
      initialLocation: AppDestination.liveTv.path,
      overrides: [...ui.overrides, ...sourceShellOverrides],
    );
    await settleCast(tester);
  }

  Future<void> castTo(WidgetTester tester, Playable item) async {
    unawaited(ui.cast.coordinator.connect(tvDevice));
    await settleCast(tester);
    final playback = ui.live.rig.coordinator;
    unawaited(switch (item) {
      PlayableChannel(:final channel) => playback.playLive(channel),
      _ => playback.playVod(item),
    });
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(castingViewOpenProvider.notifier)
        .open();
    await settleCast(tester);
    ui.cast.relay.sessions.lastOrNull?.emit(const CastRelayFetched());
    ui.cast.tv.playing();
    await settleCast(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> end(WidgetTester tester) async {
    unawaited(ui.cast.coordinator.disconnect());
    await settleCast(tester);
    await ui.live.rig.coordinator.stop();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('casting', () {
    for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('view $name', (tester) async {
        await pump(tester, size);
        await castTo(tester, PlayableChannel(arena));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/casting_view_$name.png'),
        );
        await end(tester);
      });

      testWidgets('picker $name', (tester) async {
        await pump(tester, size);
        ui.devices = [tvDevice, _bedroom, _kitchen];
        unawaited(ui.live.rig.coordinator.playLive(arena));
        await settleCast(tester);
        ui.live.rig.engine.firstFrame();
        await settleCast(tester);
        await tester.tap(findByLabel('Cast'));
        await settleCast(tester);
        await tester.pump(const Duration(milliseconds: 300));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/casting_picker_$name.png'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await end(tester);
      });
    }

    testWidgets('a movie (sketch A)', (tester) async {
      await pump(tester, const Size(1280, 800));
      ui.cast.probe.next = const StreamProbed(mkvFacts);
      await castTo(tester, PlayableMovie(movie(7, runtime: mkvFacts.duration)));
      ui.cast.tv.playing(position: const Duration(minutes: 42, seconds: 10));
      await settleCast(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/casting_view_movie.png'),
      );
      await end(tester);
    });

    testWidgets("it failed: the TV couldn't reach this computer (sketch D)", (
      tester,
    ) async {
      await pump(tester, const Size(1280, 800));
      unawaited(ui.cast.coordinator.connect(tvDevice));
      await settleCast(tester);
      unawaited(ui.live.rig.coordinator.playLive(arena));
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(castingViewOpenProvider.notifier)
          .open();
      await settleCast(tester);
      // The TV never asks for the stream.
      await tester.pump(const CastTimings().reach);
      await settleCast(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text("Living Room TV couldn't reach this computer"),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/casting_view_failed.png'),
      );
      await end(tester);
    });
  }, skip: goldenSkipReason);
}
