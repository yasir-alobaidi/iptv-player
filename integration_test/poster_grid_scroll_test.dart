// Phase 5's exit measurement for the poster grid (plan step 8): the fake
// panel's `large` catalogue synced — 30,000 movies, each with a poster
// the panel serves from its own host, through the app's picture cache as
// the app runs it — then Movies scrolled every way a user scrolls it:
// flings, the wheel, ↓, PageDown, End and Home. docs/06 has no row for a
// grid, so the channel list's budget applies: no frame over 16 ms.
//
// Then the grid top to bottom by flings (in profile mode only), and what
// the decoded pictures hold in memory after it (docs/06: ≤ 150 MB).
// Meaningful in profile mode, on the real display:
//
//     flutter drive --profile -d linux \
//       --driver=test_driver/integration_test.dart \
//       --target=integration_test/poster_grid_scroll_test.dart
//
// which writes the numbers to build/integration_response_data.json too.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/images/artwork_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';
import 'package:iptv_player/data/images/cached_artwork.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';

import 'support/fake_panel.dart';
import 'support/frames.dart';
import 'support/keyboard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the poster grid scrolls 30,000 movies with their posters',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final images = PaintingBinding.instance.imageCache;
      capDecodedImages(images);

      final panel = (await tester.runAsync(
        () => FakePanel.start(profile: 'large'),
      ))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('iptv_grid_scroll'),
      ))!;
      final db = AppDatabase(
        (await tester.runAsync(() => openAppDatabase(directory)))!,
      );
      final artwork = ArtworkCache(
        directory: Directory('${directory.path}/artwork'),
      );
      final log = AppLog(output: SilentOutput(), secrets: SecretRegistry());
      final container = ProviderContainer(
        overrides: [
          appLogProvider.overrideWithValue(log),
          secretRegistryProvider.overrideWithValue(SecretRegistry()),
          errorReporterProvider.overrideWithValue(ErrorReporter(log)),
          appDatabaseProvider.overrideWithValue(db),
          credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
          startLocationProvider.overrideWithValue(AppDestination.movies.path),
          artworkImagesProvider.overrideWithValue(CachedArtworkImages(artwork)),
          ...sourceShellOverrides,
        ],
      );
      addTearDown(
        () => tester.runAsync(() async {
          container.dispose();
          await db.close();
          await directory.delete(recursive: true);
        }),
      );

      final synced = await tester.runAsync(() async {
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
        final result = await container
            .read(syncServiceProvider)
            .sync(added.valueOrNull!.id);
        return result.isOk ? 'synced' : '${result.failureOrNull}';
      });
      expect(synced, 'synced');
      final rssBefore = ProcessInfo.currentRss;

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
      final grid = find.byWidgetPredicate((w) => w is TitleGrid);
      await k.waitFor(find.text('30,000 movies'), seconds: 30);
      await k.waitFor(grid);
      await k.tabTo(grid);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: grid, matching: find.byType(Scrollable)).first,
      );
      final center = tester.getCenter(grid);
      // The first screen's posters, before anything is measured.
      await waitReal(tester, 2000);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      Future<void> wheel(Offset delta) async {
        await tester.sendEventToBinding(pointer.hover(center));
        await tester.sendEventToBinding(pointer.scroll(delta));
      }

      Future<void> key(LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
          tester.sendKeyEvent(key, physicalKey: physical);

      // How far each kind of scroll took the grid, and where the focus
      // ended: a key that did nothing would still count its frames.
      final moved = <String, String>{};
      Future<FrameStats> measure(
        String name,
        Future<void> Function() scroll,
      ) async {
        final from = scrollable.position.pixels;
        final stats = await measureFrames(tester, binding, scroll);
        moved[name] =
            '${(scrollable.position.pixels - from).round()} px, focus on '
            '${k.focusedLabel() ?? FocusManager.instance.primaryFocus}';
        return stats;
      }

      final results = <String, FrameStats>{
        'fling': await measure('fling', () async {
          for (var i = 0; i < 12; i++) {
            await tester.fling(grid, const Offset(0, -1400), 4000);
            await waitReal(tester, 450);
          }
        }),
        'wheel_down': await measure('wheel_down', () async {
          for (var i = 0; i < 120; i++) {
            await wheel(const Offset(0, 120));
            await waitReal(tester, 16);
          }
        }),
        'arrow_down': await measure('arrow_down', () async {
          for (var i = 0; i < 30; i++) {
            await key(
              LogicalKeyboardKey.arrowDown,
              PhysicalKeyboardKey.arrowDown,
            );
            await waitReal(tester, 120);
          }
        }),
        'page_down': await measure('page_down', () async {
          for (var i = 0; i < 20; i++) {
            await key(
              LogicalKeyboardKey.pageDown,
              PhysicalKeyboardKey.pageDown,
            );
            await waitReal(tester, 150);
          }
        }),
        'end': await measure('end', () async {
          await key(LogicalKeyboardKey.end, PhysicalKeyboardKey.end);
          await waitReal(tester, 800);
        }),
        'home': await measure('home', () async {
          await key(LogicalKeyboardKey.home, PhysicalKeyboardKey.home);
          await waitReal(tester, 800);
        }),
        // Top to bottom: fast flings until the last row is on screen. In
        // the measuring run only (profile mode): in debug, under CI's
        // xvfb, it would take minutes.
        if (kProfileMode)
          'end_to_end': await measure('end_to_end', () async {
            final deadline = DateTime.now().add(const Duration(minutes: 4));
            while (scrollable.position.extentAfter > 0 &&
                DateTime.now().isBefore(deadline)) {
              await tester.fling(grid, const Offset(0, -3000), 12000);
              await waitReal(tester, 250);
            }
          }),
      };
      if (kProfileMode) {
        expect(scrollable.position.extentAfter, 0, reason: 'the end reached');
      }
      // What was on its way lands, and the cache settles.
      await waitReal(tester, 3000);

      final memory = {
        'decoded_cache_mb': images.currentSizeBytes / (1 << 20),
        'decoded_cache_images': images.currentSize,
        'decoded_live_images': images.liveImageCount,
        'decoded_pending_images': images.pendingImageCount,
        'decoded_kb_per_image': images.currentSize == 0
            ? 0
            : images.currentSizeBytes / images.currentSize / 1024,
        'disk_cache_mb':
            (await tester.runAsync(() => _sizeOf(artwork.directory)))! /
            (1 << 20),
        'rss_growth_mb': (ProcessInfo.currentRss - rssBefore) / (1 << 20),
      };

      binding.reportData = {
        'poster_grid_scroll': {
          for (final MapEntry(:key, :value) in results.entries)
            key: value.toJson(),
        },
        'poster_grid_memory': memory,
      };
      for (final MapEntry(:key, :value) in results.entries) {
        // The measurement is this test's output, read by whoever runs it.
        // ignore: avoid_print
        print(
          'poster grid $key (${kProfileMode ? 'profile' : 'debug'} mode): '
          '$value · moved ${moved[key]}',
        );
      }
      final memoryLine = [
        for (final MapEntry(:key, :value) in memory.entries)
          '$key ${value is double ? value.toStringAsFixed(1) : value}',
      ].join(' · ');
      // ignore: avoid_print, the measurement is this test's output
      print('poster grid memory: $memoryLine');
      expect(images.currentSizeBytes, lessThanOrEqualTo(decodedArtworkBytes));
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 10)),
    // As the app runs without a screen reader: flutter_test builds the
    // semantics tree on every frame unless told not to.
    semanticsEnabled: false,
  );
}

Future<int> _sizeOf(Directory directory) async {
  if (!directory.existsSync()) return 0;
  var bytes = 0;
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File) bytes += await entity.length();
  }
  return bytes;
}
