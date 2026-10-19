import 'dart:async';

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
  final _shown = Completer<void>();

  /// Home's first frame with its rows; only the first call is logged.
  void homeShown() {
    if (!_shown.isCompleted) _shown.complete();
    final log = _log;
    final clock = _sinceMain;
    if (_marked || log == null || clock == null) return;
    _marked = true;
    log.info(
      'startup',
      'Home is on screen, ${clock.elapsedMilliseconds} ms after main()',
    );
  }

  /// Once Home has read its rows and shown them, or after [cap] for a
  /// launch that opens elsewhere: the launch's own work (syncs, guides)
  /// waits for it. On the Bedroom TV a sync begun 2 s after the first
  /// frame went before Home's reads, which then waited behind its
  /// batches (Home 19.9 s after main()).
  Future<void> settled({required Duration cap}) =>
      Future.any([_shown.future, Future<void>.delayed(cap)]);
}
