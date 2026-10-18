import 'dart:async';

import 'package:iptv_player/core/platform/display_modes.dart';

/// The Bedroom TV's modes (`dumpsys display`, 2026-10-17): 3840×2160 and
/// 1920×1080 at 59.94, 60, 29.97, 30, 23.976 and 24 Hz, 1280×720 at
/// 59.94 and 60; no 25 or 50 Hz.
const tvModes = [
  DisplayMode(id: 1, width: 3840, height: 2160, refreshRate: 59.94006),
  DisplayMode(id: 2, width: 3840, height: 2160, refreshRate: 60),
  DisplayMode(id: 3, width: 3840, height: 2160, refreshRate: 29.97003),
  DisplayMode(id: 4, width: 3840, height: 2160, refreshRate: 30),
  DisplayMode(id: 5, width: 3840, height: 2160, refreshRate: 23.976025),
  DisplayMode(id: 6, width: 3840, height: 2160, refreshRate: 24),
  DisplayMode(id: 7, width: 1920, height: 1080, refreshRate: 59.94006),
  DisplayMode(id: 8, width: 1920, height: 1080, refreshRate: 60),
  DisplayMode(id: 9, width: 1920, height: 1080, refreshRate: 29.97003),
  DisplayMode(id: 10, width: 1920, height: 1080, refreshRate: 30),
  DisplayMode(id: 11, width: 1920, height: 1080, refreshRate: 23.976025),
  DisplayMode(id: 12, width: 1920, height: 1080, refreshRate: 24),
  DisplayMode(id: 13, width: 1280, height: 720, refreshRate: 59.94006),
  DisplayMode(id: 14, width: 1280, height: 720, refreshRate: 60),
];

DisplayMode tvMode(int id) => tvModes.firstWhere((m) => m.id == id);

/// 4K at 59.94 Hz, as the user set the Chromecast.
final DisplayMode uhd5994 = tvMode(1);
final DisplayMode uhd23976 = tvMode(5);
final DisplayMode uhd24 = tvMode(6);

DisplayFacts tvFacts({
  DisplayMode? current,
  MatchContentFrameRate preference = MatchContentFrameRate.always,
  List<double> alternatives = const [],
}) => DisplayFacts(
  current: current ?? uhd5994,
  modes: tvModes,
  alternativeRefreshRates: alternatives,
  matchContentFrameRate: preference,
  apiLevel: 34,
);

/// A TV's display: every request is recorded; one for a mode switches
/// the display to it [switchAfter] later (0 to the TV's own mode),
/// unless [switches] is false.
final class FakeDisplayModes implements DisplayModes {
  new({
    DisplayMode? current,
    this.preference = MatchContentFrameRate.always,
    this.alternatives = const [],
    this.switches = true,
    this.switchAfter = const Duration(milliseconds: 1800),
  }) : own = current ?? uhd5994,
       current = current ?? uhd5994;

  /// The TV's own mode: where a request for none takes the display.
  final DisplayMode own;
  DisplayMode current;
  MatchContentFrameRate preference;
  List<double> alternatives;
  bool switches;
  Duration switchAfter;

  /// Every mode asked for, in order; 0 is none.
  final List<int> requests = [];
  int reads = 0;

  final _changes = StreamController<DisplayMode>.broadcast(sync: true);

  @override
  bool get available => true;

  @override
  Future<DisplayFacts?> read() async {
    reads++;
    return tvFacts(
      current: current,
      preference: preference,
      alternatives: alternatives,
    );
  }

  Timer? _switching;

  /// The window's last request wins, as Android's does.
  @override
  Future<bool> request(int id) async {
    requests.add(id);
    _switching?.cancel();
    _switching = null;
    if (!switches) return true;
    final target = id == 0 ? own : tvMode(id);
    if (target.id == current.id) return true;
    _switching = Timer(switchAfter, () => show(target));
    return true;
  }

  /// The display reports [mode], as Android's DisplayListener does.
  void show(DisplayMode mode) {
    current = mode;
    _changes.add(mode);
  }

  @override
  Stream<DisplayMode> get changes => _changes.stream;
}
