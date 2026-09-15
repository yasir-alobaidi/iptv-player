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

  void handleFlutterError(FlutterErrorDetails details) {
    report(
      details.exception,
      details.stack,
      source: details.library ?? 'flutter',
    );
  }

  void report(Object error, StackTrace? stackTrace, {required String source}) {
    _log.error(source, 'Unhandled error', error: error, stackTrace: stackTrace);
    if (!_errors.isClosed) _errors.add(AppFailure.fromError(error));
  }

  Future<void> dispose() => _errors.close();
}
