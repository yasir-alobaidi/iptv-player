import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';

/// Catches errors nothing else handled: framework errors
/// (`FlutterError.onError`) and uncaught async errors on the UI isolate
/// (`PlatformDispatcher.onError`). Each is logged (redacted) and published
/// on [nonFatalErrors], which the shell shows as a toast. The app keeps
/// running.
final class ErrorReporter {
  new(this._log);

  final AppLog _log;
  final _errors = StreamController<AppFailure>.broadcast();

  Stream<AppFailure> get nonFatalErrors => _errors.stream;

  /// Installs the global handlers. Call once, at startup.
  void install() {
    FlutterError.onError = handleFlutterError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      report(error, stackTrace, source: 'uncaught');
      return true;
    };
  }

  /// A *silent* error is one Flutter itself considers not worth showing —
  /// a picture that failed after the widget waiting for it had gone, say,
  /// which a grid of 30,000 posters does all the time. It is logged, and
  /// never a toast.
  void handleFlutterError(FlutterErrorDetails details) {
    final source = details.library ?? 'flutter';
    if (details.silent) {
      _log.warning(source, 'Silent error', error: details.exception);
      return;
    }
    report(details.exception, details.stack, source: source);
  }

  void report(Object error, StackTrace? stackTrace, {required String source}) {
    _log.error(source, 'Unhandled error', error: error, stackTrace: stackTrace);
    if (!_errors.isClosed) _errors.add(AppFailure.fromError(error));
  }

  Future<void> dispose() => _errors.close();
}
