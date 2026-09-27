// Phase 4's exit measurement for the Guide grid (docs/06: no frame over
// 16 ms): the fake panel's `large` catalogue (50,000 channels) synced,
// its ~300 MB guide imported (the first 2,150 channels' guide ids, 7 days
// ahead and one behind — 41,902 of the 50,000 channels match it), then
// the grid scrolled every way a user scrolls it: flings and the wheel
// down the channels, the sideways wheel and → through time, PageDown and
// Home. Frame build times and the UI isolate's longest pause are
// reported per kind of scroll, meaningful in profile mode only:
//
//     xvfb-run -a flutter drive --profile -d linux \
//       --driver=test_driver/integration_test.dart \
//       --target=integration_test/guide_scroll_test.dart
//
// which writes them to build/integration_response_data.json as well. The
// Linux embedder reports raster time as 0, so build time is the number.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/presentation/guide_grid.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the Guide grid scrolls 50,000 channels × 7 days',
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
        () => Directory.systemTemp.createTemp('iptv_guide_scroll'),
      ))!;
      final db = AppDatabase(
        (await tester.runAsync(() => openAppDatabase(directory)))!,
      );
      final log = AppLog(output: SilentOutput(), secrets: SecretRegistry());
      final container = ProviderContainer(
        overrides: [
          appLogProvider.overrideWithValue(log),
          secretRegistryProvider.overrideWithValue(SecretRegistry()),
          errorReporterProvider.overrideWithValue(ErrorReporter(log)),
          appDatabaseProvider.overrideWithValue(db),
          credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
          startLocationProvider.overrideWithValue(AppDestination.guide.path),
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

      // The catalogue and the guide first; the measurement is the grid.
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
                epgUrl:
                    '${panel.url}/xmltv.php?username=test&password=test'
                    '&channels=2150&days=7',
              ),
            );
        final id = added.valueOrNull!.id;
        final synced = await container.read(syncServiceProvider).sync(id);
        if (!synced.isOk) return 'sync: ${synced.failureOrNull}';
        final imported = await container
            .read(guideImportServiceProvider)
            .importGuide(id);
        if (!imported.isOk) return 'import: ${imported.failureOrNull}';
        return 'ready';
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
      await k.waitFor(find.byType(GuideGrid));
      // Opened on the Guide itself, with no jump to it to bring the focus.
      // Found by its place, not its debug label: profile builds have none.
      final gridFocus = find.descendant(
        of: find.byType(GuideGrid),
        matching: find.byWidgetPredicate(
          (w) => w is Focus && w.child is Listener,
        ),
      );
      await k.waitFor(gridFocus);
      final node = tester.widget<Focus>(gridFocus).focusNode!..requestFocus();
      await k.waitUntil(
        () =>
            FocusManager.instance.primaryFocus == node &&
            find
                .byWidgetPredicate((w) => w is FocusRing && w.visible)
                .evaluate()
                .isNotEmpty,
        'the grid, its rows and the cursor',
      );
      final list = find.descendant(
        of: find.byType(GuideGrid),
        matching: find.byType(ListView),
      );
      final center = tester.getCenter(list);

      Future<void> wait(int ms) => tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      Future<void> wheel(Offset delta) async {
        await tester.sendEventToBinding(pointer.hover(center));
        await tester.sendEventToBinding(pointer.scroll(delta));
      }

      Future<_FrameStats> measure(Future<void> Function() scroll) async {
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> timings) => frames.addAll(timings);
        var last = DateTime.now();
        var worstGap = Duration.zero;
        final ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
          final now = DateTime.now();
          if (now.difference(last) > worstGap) worstGap = now.difference(last);
          last = now;
        });
        SchedulerBinding.instance.addTimingsCallback(collect);
        final policy = binding.framePolicy;
        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
        final watch = Stopwatch()..start();
        await scroll();
        await wait(600);
        watch.stop();
        ticker.cancel();
        SchedulerBinding.instance.removeTimingsCallback(collect);
        binding.framePolicy = policy;
        await tester.pump();
        return _FrameStats(frames, worstGap, watch.elapsed);
      }

      // With --dart-define=GUIDE_TIMELINE=true: the keys again, traced,
      // into build/integration_response_data.json instead of measured.
      if (const bool.fromEnvironment('GUIDE_TIMELINE')) {
        // Per-widget events only when asked: they cost time of their own,
        // and the trace buffer drops frames when it fills.
        const widgets = bool.fromEnvironment('GUIDE_TIMELINE_WIDGETS');
        debugProfileBuildsEnabled = widgets;
        debugProfileLayoutsEnabled = widgets;
        final policy = binding.framePolicy;
        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
        await binding.traceAction(() async {
          for (var i = 0; i < 20; i++) {
            await tester.sendKeyEvent(
              LogicalKeyboardKey.arrowRight,
              physicalKey: PhysicalKeyboardKey.arrowRight,
            );
            await wait(120);
          }
          for (var i = 0; i < 10; i++) {
            await tester.sendKeyEvent(
              LogicalKeyboardKey.pageDown,
              physicalKey: PhysicalKeyboardKey.pageDown,
            );
            await wait(80);
          }
        }, reportKey: 'guide_timeline');
        binding.framePolicy = policy;
        debugProfileBuildsEnabled = false;
        debugProfileLayoutsEnabled = false;
        return;
      }

      final results = <String, _FrameStats>{
        // Down the channels: flings, then the wheel, a notch a frame.
        'fling': await measure(() async {
          for (var i = 0; i < 12; i++) {
            await tester.fling(list, const Offset(0, -1400), 4000);
            await wait(450);
          }
        }),
        'wheel_down': await measure(() async {
          for (var i = 0; i < 120; i++) {
            await wheel(const Offset(0, 120));
            await wait(16);
          }
        }),
        // Through time: the sideways wheel, then → between programmes.
        'wheel_sideways': await measure(() async {
          for (var i = 0; i < 120; i++) {
            await wheel(const Offset(60, 0));
            await wait(16);
          }
        }),
        // Through time by programme: → animates the view along.
        'arrow_right': await measure(() async {
          for (var i = 0; i < 20; i++) {
            await tester.sendKeyEvent(
              LogicalKeyboardKey.arrowRight,
              physicalKey: PhysicalKeyboardKey.arrowRight,
            );
            await wait(120);
          }
        }),
        // Down by a screen at a time, then back to now.
        'page_down': await measure(() async {
          for (var i = 0; i < 20; i++) {
            await tester.sendKeyEvent(
              LogicalKeyboardKey.pageDown,
              physicalKey: PhysicalKeyboardKey.pageDown,
            );
            await wait(80);
          }
          await tester.sendKeyEvent(
            LogicalKeyboardKey.home,
            physicalKey: PhysicalKeyboardKey.home,
          );
          await wait(300);
        }),
      };

      binding.reportData = {
        'guide_scroll': {
          for (final MapEntry(:key, :value) in results.entries)
            key: value.toJson(),
        },
      };
      for (final MapEntry(:key, :value) in results.entries) {
        // The measurement is this test's output, read by whoever runs it.
        // ignore: avoid_print
        print(
          'guide scroll $key (${kProfileMode ? 'profile' : 'debug'} mode): '
          '$value',
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

/// Frame build and raster times over one kind of scroll, and the UI
/// isolate's longest pause (a 16 ms timer's worst late tick).
final class _FrameStats {
  new(List<FrameTiming> frames, this.worstGap, this.duration)
    : build = [for (final f in frames) f.buildDuration]..sort(),
      raster = [for (final f in frames) f.rasterDuration]..sort();

  final List<Duration> build;
  final List<Duration> raster;
  final Duration worstGap;
  final Duration duration;

  static double _ms(Duration d) => d.inMicroseconds / 1000;

  double _pct(List<Duration> sorted, double p) =>
      sorted.isEmpty ? 0 : _ms(sorted[((sorted.length - 1) * p).round()]);

  int _over(List<Duration> sorted, int ms) =>
      sorted.where((d) => d > Duration(milliseconds: ms)).length;

  Map<String, Object> toJson() => {
    'ms': duration.inMilliseconds,
    'frames': build.length,
    'build_p50_ms': _pct(build, .5),
    'build_p90_ms': _pct(build, .9),
    'build_p99_ms': _pct(build, .99),
    'build_worst_ms': _pct(build, 1),
    'build_over_16ms': _over(build, 16),
    'raster_worst_ms': _pct(raster, 1),
    'ui_isolate_worst_gap_ms': worstGap.inMilliseconds,
  };

  @override
  String toString() => [
    for (final MapEntry(:key, :value) in toJson().entries)
      '$key ${value is double ? value.toStringAsFixed(1) : value}',
  ].join(' · ');
}
