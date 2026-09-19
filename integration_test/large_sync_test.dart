// Phase 2's exit test: onboarding with the keyboard against the fake
// provider's `large` profile (50,000 channels, 30,000 movies, 3,000
// series) → the sync within docs/06's 60 s budget → Pick categories →
// Home, where the shell names the source and Settings shows what it holds.
//
// The fake provider runs in its own process, which this test starts and
// stops: in-process, its JSON encoding would count as the app's jank
// (docs/06). The sync's frame times and the longest pause of the UI
// isolate are measured too, and reported rather than asserted (Phase 2
// decision 4): they mean something only in profile mode, on the laptop,
//
//     flutter drive --profile -d linux \
//       --driver=test_driver/integration_test.dart \
//       --target=integration_test/large_sync_test.dart
//
// which writes them to build/integration_response_data.json as well.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

/// docs/06: sync 50k channels + 30k movies (fake provider) ≤ 60 s.
const _syncBudget = Duration(seconds: 60);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the large profile: onboarding, sync, Home', (tester) async {
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);

    final panel = (await tester.runAsync(
      () => FakePanel.start(profile: 'large'),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('iptv_large'),
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
        startLocationProvider.overrideWithValue(welcomeRoutePath),
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
    String location() => container.read(routerProvider).state.uri.path;

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
    await tester.pump(const Duration(milliseconds: 300));

    // ── Welcome → Connect → Test.
    await k.waitFor(find.text('Add your first source'));
    // On a real desktop the window may open without keyboard focus.
    await k.tabTo(find.text('Add your first source'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Connect your provider'));
    await k.type('http://127.0.0.1:${panel.port}', into: 'Server address');
    await k.press(LogicalKeyboardKey.tab);
    await k.type('test', into: 'Username');
    await k.press(LogicalKeyboardKey.tab);
    await k.type('test', into: 'Password');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Connected'));
    expect(k.focusIsOn(find.text('Start sync')), isTrue);

    // ── The sync, measured. The engine draws frames on its own schedule
    // meanwhile; the test only watches.
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
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    final watch = Stopwatch()..start();
    await k.press(LogicalKeyboardKey.enter);
    final deadline = DateTime.now().add(_syncBudget * 2);
    while (find.textContaining('Done in').evaluate().isEmpty &&
        find.text('Retry').evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    watch.stop();
    ticker.cancel();
    // Timings arrive in batches; let the last one land.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    SchedulerBinding.instance.removeTimingsCallback(collect);
    binding.framePolicy = policy;
    await tester.pump();

    final stats = _FrameStats(frames, worstGap, watch.elapsed);
    binding.reportData = {'large_sync': stats.toJson()};
    // The measurement is this test's output, read by whoever runs it.
    // ignore: avoid_print
    print('large sync (${kProfileMode ? 'profile' : 'debug'} mode): $stats');

    expect(find.text('Retry'), findsNothing, reason: screenText(tester));
    expect(find.textContaining('Done in'), findsOneWidget);
    expect(watch.elapsed, lessThan(_syncBudget));
    expect(find.text('50,000'), findsOneWidget);
    expect(find.text('30,000'), findsOneWidget);
    expect(find.text('3,000'), findsOneWidget);

    // ── Pick categories → Finish → Home.
    expect(k.focusIsOn(find.text('Pick categories')), isTrue);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Pick what you watch'));
    await k.tabTo(find.text('Finish'));
    await k.press(LogicalKeyboardKey.enter);
    expect(location(), '/');
    expect(byLabel('Source: 127.0.0.1'), findsOneWidget);

    // Home's rows are Phase 5; what the source holds shows in Settings.
    await k.chord(LogicalKeyboardKey.comma);
    expect(location(), '/settings');
    await k.waitFor(
      find.text(
        '50,000 channels · 30,000 movies · 3,000 series · synced just now',
      ),
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Frame build and raster times over the sync, and the UI isolate's
/// longest pause (a 16 ms timer's worst late tick, as in step 5's
/// benchmark).
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
    'sync_ms': duration.inMilliseconds,
    'frames': build.length,
    'build_p50_ms': _pct(build, .5),
    'build_p90_ms': _pct(build, .9),
    'build_worst_ms': _pct(build, 1),
    'raster_p50_ms': _pct(raster, .5),
    'raster_p90_ms': _pct(raster, .9),
    'raster_worst_ms': _pct(raster, 1),
    'build_over_16ms': _over(build, 16),
    'build_over_32ms': _over(build, 32),
    'raster_over_32ms': _over(raster, 32),
    'ui_isolate_worst_gap_ms': worstGap.inMilliseconds,
  };

  @override
  String toString() => [
    for (final MapEntry(:key, :value) in toJson().entries)
      '$key ${value is double ? value.toStringAsFixed(1) : value}',
  ].join(' · ');
}
