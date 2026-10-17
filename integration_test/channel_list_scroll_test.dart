// Phase 9 step 8's measurement for Live TV's channel list (docs/06: 50,000
// rows, no frame over 16 ms): the fake panel's `large` catalogue synced,
// Live TV open on All channels, and the list scrolled every way a user
// scrolls it — flings and the wheel, ↓ held down, PageDown (the list has
// no End or Home: a first run pressed them and measured nothing).
// Frame build times and the UI isolate's longest pause are reported per
// kind of scroll, meaningful in profile mode only:
//
//     flutter drive --profile -d linux \
//       --driver=test_driver/integration_test.dart \
//       --target=integration_test/channel_list_scroll_test.dart
//
// on the real display (under xvfb the software rasterizer competes with
// the app for the CPU), which writes them to
// build/integration_response_data.json as well.
//
// The keys move the selection, and the preview follows it: the player is
// one that "plays" at once with no picture, so what is measured is the
// list, the guide lines under its rows and the preview's words, not
// libmpv opening streams the `large` profile doesn't have.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart' hide ChannelRow;
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_list_pane.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import 'support/fake_panel.dart';
import 'support/frames.dart';
import 'support/guide_on.dart';
import 'support/keyboard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    "Live TV's channel list scrolls 50,000 channels",
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;

      final panel = (await tester.runAsync(
        () => FakePanel.start(profile: 'large'),
      ))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('iptv_channel_scroll'),
      ))!;
      final db = AppDatabase(
        (await tester.runAsync(() => openAppDatabase(directory)))!,
      );
      final log = AppLog(output: SilentOutput(), secrets: SecretRegistry());
      // A player that has its first frame as soon as it is asked (once
      // the opening has been heard by everyone: the engine's events don't
      // nest).
      final engine = FakePlayerEngine();
      final opening = engine.events.listen((event) {
        if (event is PlayerOpening) scheduleMicrotask(engine.firstFrame);
      });
      final container = ProviderContainer(
        overrides: [
          appLogProvider.overrideWithValue(log),
          secretRegistryProvider.overrideWithValue(SecretRegistry()),
          errorReporterProvider.overrideWithValue(ErrorReporter(log)),
          appDatabaseProvider.overrideWithValue(db),
          credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
          startLocationProvider.overrideWithValue(AppDestination.liveTv.path),
          playerEngineProvider.overrideWithValue(engine),
          ...sourceShellOverrides,
          // The guide lines under the rows, as before the switch (ADR-031).
          guideSwitchedOn(),
        ],
      );
      addTearDown(
        () => tester.runAsync(() async {
          await container.read(playbackCoordinatorProvider).stop();
          await opening.cancel();
          container.dispose();
          await db.close();
          await directory.delete(recursive: true);
        }),
      );

      final prepared = await tester.runAsync(() async {
        final added = await container
            .read(sourceRepositoryProvider)
            .add(
              SourceDraft(
                type: SourceType.xtream,
                name: 'Large',
                url: panel.url,
                username: 'test',
                password: 'test',
              ),
            );
        final synced = await container
            .read(syncServiceProvider)
            .sync(added.valueOrNull!.id);
        return synced.isOk ? 'ready' : 'sync: ${synced.failureOrNull}';
      });
      expect(prepared, 'ready');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      final k = Keys(tester)..resume();
      await tester.pump();
      final list = find.descendant(
        of: find.byType(ChannelListPane),
        matching: find.byType(ListView),
      );
      await k.waitFor(list, seconds: 30);
      final firstRow = find
          .descendant(of: list, matching: find.byType(ChannelRow))
          .first;
      await k.waitFor(firstRow, seconds: 30);
      final center = tester.getCenter(list);

      Future<void> wait(int ms) => waitReal(tester, ms);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      Future<void> wheel(Offset delta) async {
        await tester.sendEventToBinding(pointer.hover(center));
        await tester.sendEventToBinding(pointer.scroll(delta));
      }

      Future<void> key(LogicalKeyboardKey logical, PhysicalKeyboardKey key) =>
          tester.sendKeyEvent(logical, physicalKey: key);

      Future<FrameStats> measure(Future<void> Function() scroll) =>
          measureFrames(tester, binding, scroll);

      // The mouse first (it moves no selection), then the keys, which
      // need the focus on a row.
      final results = <String, FrameStats>{
        'fling': await measure(() async {
          for (var i = 0; i < 12; i++) {
            await tester.fling(list, const Offset(0, -1400), 4000);
            await wait(450);
          }
        }),
        'wheel': await measure(() async {
          for (var i = 0; i < 120; i++) {
            await wheel(const Offset(0, 120));
            await wait(16);
          }
        }),
      };

      // The keys go from wherever the mouse left the list: the first row
      // on screen takes the focus.
      await wait(1200);
      Focus.of(
        tester.element(
          find.descendant(of: list, matching: find.byType(ChannelRow)).first,
        ),
      ).requestFocus();
      await wait(600);

      results.addAll({
        // ↓ held: a row a key, thirty a second.
        'arrow_down': await measure(() async {
          for (var i = 0; i < 150; i++) {
            await key(
              LogicalKeyboardKey.arrowDown,
              PhysicalKeyboardKey.arrowDown,
            );
            await wait(33);
          }
        }),
        'page_down': await measure(() async {
          for (var i = 0; i < 20; i++) {
            await key(
              LogicalKeyboardKey.pageDown,
              PhysicalKeyboardKey.pageDown,
            );
            await wait(80);
          }
        }),
      });

      binding.reportData = {
        'channel_list_scroll': {
          for (final MapEntry(:key, :value) in results.entries)
            key: value.toJson(),
        },
      };
      for (final MapEntry(:key, :value) in results.entries) {
        // The measurement is this test's output, read by whoever runs it.
        // ignore: avoid_print
        print(
          'channel list scroll $key '
          '(${kProfileMode ? 'profile' : 'debug'} mode): $value',
        );
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 8)),
    // As the app runs without a screen reader: flutter_test builds the
    // semantics tree on every frame unless told not to.
    semanticsEnabled: false,
  );
}
