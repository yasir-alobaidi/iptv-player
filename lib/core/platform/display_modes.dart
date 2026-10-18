import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'display_modes.g.dart';

/// One of the display's modes: its size in pixels and its refresh rate.
@immutable
final class DisplayMode {
  const new({
    required this.id,
    required this.width,
    required this.height,
    required this.refreshRate,
  });

  /// The system's id for it; never 0, which asks for no mode at all.
  final int id;
  final int width;
  final int height;

  /// In Hz, as the system has it: 59.94006, 23.976025, 24.0.
  final double refreshRate;

  bool sameSize(DisplayMode other) =>
      other.width == width && other.height == height;

  /// `3840×2160 · 23.976 Hz`, as the stream-info overlay shows it.
  String get label => '$width×$height · ${formatRate(refreshRate)} Hz';

  /// `3840x2160 23.976 Hz`, as the log has it.
  String get logLabel => '${width}x$height ${formatRate(refreshRate)} Hz';

  @override
  bool operator ==(Object other) =>
      other is DisplayMode &&
      other.id == id &&
      other.width == width &&
      other.height == height &&
      other.refreshRate == refreshRate;

  @override
  int get hashCode => Object.hash(id, width, height, refreshRate);

  @override
  String toString() => 'DisplayMode($id: $logLabel)';
}

/// The TV's own Settings → Display & Sound → Match content frame rate
/// (Android 12 and later).
enum MatchContentFrameRate {
  /// Switches whenever what plays asks.
  always,

  /// Switches only when the screen doesn't go dark doing it.
  seamlessOnly,

  /// Never switches.
  never,

  /// Before Android 12, or the system didn't say.
  unknown;

  /// As the TV's Settings says it, for the log.
  String get label => switch (this) {
    always => 'Always',
    seamlessOnly => 'Seamless only',
    never => 'Never',
    unknown => 'not known',
  };
}

/// What the display says about itself, read now.
@immutable
final class DisplayFacts {
  const new({
    required this.current,
    this.modes = const [],
    this.alternativeRefreshRates = const [],
    this.matchContentFrameRate = MatchContentFrameRate.unknown,
    this.apiLevel,
  });

  /// The mode the display is in; null when the system didn't say.
  final DisplayMode? current;

  /// Every mode the display offers, [current] among them.
  final List<DisplayMode> modes;

  /// The rates [current] switches to without the screen going dark
  /// (Android 12 and later; empty before, or when there are none).
  final List<double> alternativeRefreshRates;

  final MatchContentFrameRate matchContentFrameRate;

  /// Android's API level, for the log.
  final int? apiLevel;
}

/// The display's modes, and asking the window for one: a TV's Match
/// frame rate. Never throws: what can't be read or asked says so.
abstract interface class DisplayModes {
  /// False where there are no modes to read or ask for: the desktop, a
  /// test.
  bool get available;

  /// The display now; null when it couldn't be read.
  Future<DisplayFacts?> read();

  /// Asks the app's window for mode [id]; 0 asks for none, so the TV's
  /// own mode comes back. False when it couldn't be asked.
  Future<bool> request(int id);

  /// The display's mode, every time it changes.
  Stream<DisplayMode> get changes;
}

/// No display to ask: the desktop and tests.
final class NoDisplayModes implements DisplayModes {
  const new();

  @override
  bool get available => false;

  @override
  Future<DisplayFacts?> read() async => null;

  @override
  Future<bool> request(int id) async => false;

  @override
  Stream<DisplayMode> get changes => const Stream.empty();
}

/// `bootstrap()` gives a TV's (`AndroidDisplayModes`).
@Riverpod(keepAlive: true)
DisplayModes displayModes(Ref ref) => const NoDisplayModes();

/// A refresh rate or a frame rate in as few figures as it needs, up to
/// three decimals: 23.976, 24, 59.94, 25.
String formatRate(double rate) {
  var text = rate.toStringAsFixed(3);
  if (!text.contains('.')) return text;
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return text;
}
