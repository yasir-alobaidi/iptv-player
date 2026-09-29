import 'package:iptv_player/core/logging/app_log.dart';

/// The moment a launch became usable, for the log: `bootstrap()` starts
/// the clock first thing, and Home marks the first frame that shows its
/// rows. docs/06's cold start budget is read from this line
/// (test/app/cold_start_benchmark_test.dart).
final class LaunchMark {
  new(AppLog this._log, Stopwatch this._sinceMain);

  /// Marks nothing: tests, and anything not started by `bootstrap()`.
  new none() : _log = null, _sinceMain = null;

  final AppLog? _log;
  final Stopwatch? _sinceMain;
  bool _marked = false;

  /// Home's first frame with its rows; only the first call is logged.
  void homeShown() {
    final log = _log;
    final clock = _sinceMain;
    if (_marked || log == null || clock == null) return;
    _marked = true;
    log.info(
      'startup',
      'Home is on screen, ${clock.elapsedMilliseconds} ms after main()',
    );
  }
}
