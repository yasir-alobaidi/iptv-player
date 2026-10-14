// A probe, by hand: in the whole app, is the player's picture drawn again
// after playback stopped and started (PROBE=stop), after the player was
// left and opened again (PROBE=leave), and after a cast to the fake TV and
// Stop casting (PROBE=cast)? The window keeps its own size (see
// picture_probe.dart for why).
//
//     PROBE=cast flutter test integration_test/manual/picture_probe_app.dart -d linux
//
// Prints the picture's size and mpv's dropped frames after each step.

import 'dart:async';
import 'dart:io';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';

import '../support/cast_tv.dart';
import '../support/fake_panel.dart';
import '../support/keyboard.dart';
import '../support/panel_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final what = Platform.environment['PROBE'] ?? 'stop';
  final binaries = castBinaries();

  testWidgets('the picture again, after: $what', (tester) async {
    HttpOverrides.global = null;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    final folder = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('iptv_probe'),
    ))!;
    addTearDown(() => tester.runAsync(() => folder.delete(recursive: true)));
    final panel = (await tester.runAsync(
      () => FakePanel.start(streams: true),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    final app = (await tester.runAsync(
      () => PanelApp.open(
        panel,
        video: true,
        maxConnections: 1,
        overrides: castOverrides(binaries!, folder),
      ),
    ))!;
    addTearDown(() => tester.runAsync(app.close));
    final container = app.container;
    final channel = (await tester.runAsync(
      () => container
          .read(channelRepositoryProvider)
          .byRemoteKey(app.sourceId, '1'),
    ))!.valueOrNull!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const IptvPlayerApp(),
      ),
    );
    SystemChannels.lifecycle.setMessageHandler((message) async => null);
    tester.binding.platformDispatcher.onViewFocusChange = (_) {};
    Keys(tester).resume();
    await tester.pump();

    final coordinator = container.read(playbackCoordinatorProvider);
    final cast = container.read(castCoordinatorProvider);
    final router = container.read(routerProvider);
    Future<void> wait(int ms) async {
      final until = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(until)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    Future<void> say(String when) async {
      final info = await tester.runAsync(coordinator.engine.streamInfo);
      final textures = find.byType(Texture).evaluate().toList();
      final sizes = [for (final texture in textures) '${texture.size}']
          .join(', ');
      // The probe's output.
      // ignore: avoid_print
      print(
        'PROBE $when: ${coordinator.state.runtimeType} on ${app.location}, '
        'picture ${textures.isEmpty ? 'not mounted' : sizes}, dropped '
        '${info?.droppedFrames}',
      );
    }

    Future<void> play(String when) async {
      await tester.runAsync(() => coordinator.playLive(channel));
      unawaited(router.push<void>(playerRoutePath));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        // The probe's output.
        // ignore: avoid_print
        print(
          'PROBE   $when +${(i + 1) * 50} ms: on ${app.location}, the '
          'player ${find.byType(PlayerScreen).evaluate().isEmpty ? 'not ' : ''}'
          'in the tree, ${coordinator.state.runtimeType}, casting '
          '${coordinator.casting}, the casting view '
          '${container.read(castingViewOpenProvider) ? 'open' : 'closed'}, '
          'the cast ${cast.state.phase.name}',
        );
      }
      for (var i = 0; i < 100 && coordinator.state is! PlaybackPlaying; i++) {
        await wait(100);
      }
      await wait(3000);
      await say(when);
      await wait(2000);
      await say('$when, 2 s on');
    }

    await wait(1500);
    await play('first play');
    switch (what) {
      case 'stop':
        await tester.runAsync(coordinator.stop);
        await wait(1500);
        await say('stopped, the player still open');
      case 'leave':
        await tester.runAsync(coordinator.stop);
        router.go(AppDestination.movies.path);
        await wait(2500);
        await say('stopped, on Movies');
      case 'cast':
        final tv = (await tester.runAsync(
          () => FakeReceiver.start(
            playback: FakePlayback(ffprobe: binaries!.ffprobe),
          ),
        ))!;
        addTearDown(() => tester.runAsync(tv.close));
        await tester.runAsync(
          () => cast.connect(
            CastDevice(
              id: 'probe-fake-tv',
              name: tv.device.name,
              host: tv.host,
              port: tv.port,
              model: 'Chromecast',
              manual: true,
            ),
          ),
        );
        for (
          var i = 0;
          i < 600 &&
              !(cast.state.phase == CastPhase.playing &&
                  tv.playerState == 'PLAYING');
          i++
        ) {
          await wait(100);
        }
        await say('on the TV (${cast.state.phase.name}, ${tv.playerState})');
        await tester.runAsync(cast.disconnect);
        await wait(2000);
        await say('after Stop casting');
    }
    await play('second play');
  });
}
