// Frame times over a scroll, for the frame-budget measurements (docs/06),
// meaningful in profile mode only. The Linux embedder reports raster time
// as 0, so build time is the number.

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Waits [ms] of real time.
Future<void> waitReal(WidgetTester tester, int ms) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

/// Frame timings while [scroll] runs with every frame drawn, and the UI
/// isolate's longest pause: a 16 ms timer's worst late tick.
Future<FrameStats> measureFrames(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  Future<void> Function() scroll,
) async {
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
  await scroll();
  await waitReal(tester, 600);
  watch.stop();
  ticker.cancel();
  SchedulerBinding.instance.removeTimingsCallback(collect);
  binding.framePolicy = policy;
  await tester.pump();
  return FrameStats(frames, worstGap, watch.elapsed);
}

/// Frame build and raster times over one kind of scroll, and the UI
/// isolate's longest pause.
final class FrameStats {
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
