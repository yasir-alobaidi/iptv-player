// A probe, by hand: is the player's picture drawn when its widget is put
// on screen after playback has started (as the app does: the picture is
// mounted once playback is Playing), and with the test window's size
// overridden (as every whole-app walk does)?
//
//     PROBE_LATE=1 PROBE_SIZE=1 flutter test \
//       integration_test/manual/picture_probe.dart -d linux
//
// Prints the picture's size as the engine reports it and mpv's dropped
// frames, a second at a time.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';

import '../support/fake_panel.dart';
import '../support/keyboard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final late = Platform.environment['PROBE_LATE'] == '1';
  final sized = Platform.environment['PROBE_SIZE'] == '1';

  testWidgets('the picture, mounted ${late ? 'after' : 'before'} play', (
    tester,
  ) async {
    HttpOverrides.global = null;
    if (sized) {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    final panel = (await tester.runAsync(
      () => FakePanel.start(streams: true),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    final secrets = SecretRegistry();
    final log = AppLog(output: SilentOutput(), secrets: secrets);
    final engine = (await tester.runAsync(
      () => MediaKitPlayerEngine.create(log: log, secrets: secrets),
    ))!;
    addTearDown(() => tester.runAsync(engine.dispose));
    final show = ValueNotifier(!late);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (context, shown, _) => shown
              ? engine.videoView(background: const Color(0xFF000000))
              : const ColoredBox(color: Color(0xFF202020)),
        ),
      ),
    );
    var first = false;
    final events = engine.events.listen((event) {
      if (event is PlayerFirstFrame) first = true;
    });
    addTearDown(events.cancel);
    await tester.runAsync(
      () => engine.open(PlayRequest(url: '${panel.url}/live/test/test/1.ts')),
    );
    Future<void> wait(int ms) =>
        tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    for (var i = 0; i < 100 && !first; i++) {
      await wait(100);
    }
    expect(first, isTrue, reason: 'the first frame');
    Future<void> say(String when) async {
      final info = await tester.runAsync(engine.streamInfo);
      final texture = find.byType(Texture);
      final size = texture.evaluate().isEmpty
          ? 'not mounted'
          : '${tester.getSize(texture.first)}';
      // The probe's output.
      // ignore: avoid_print
      print('PROBE $when: picture $size, dropped ${info?.droppedFrames}');
    }

    await say('at the first frame');
    await wait(2000);
    await say('2 s later');
    show.value = true;
    await tester.pump();
    for (var second = 1; second <= 6; second++) {
      await wait(1000);
      await tester.pump();
      await say('${late ? 'mounted' : 'playing'} for $second s');
    }
  });
}
