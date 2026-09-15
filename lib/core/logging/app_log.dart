import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:logger/logger.dart';

/// App-wide logger. Messages, errors, and stack traces all pass through
/// [redact] with the registered secrets before any output sees them.
final class AppLog {
  new({
    required LogOutput output,
    required SecretRegistry secrets,
    Level level = Level.info,
  }) : _logger = Logger(
         filter: ProductionFilter(),
         printer: _LinePrinter(secrets),
         output: output,
         level: level,
       );

  final Logger _logger;

  void debug(String tag, String message) => _logger.d(_Record(tag, message));

  void info(String tag, String message) => _logger.i(_Record(tag, message));

  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _logger.w(_Record(tag, message), error: error, stackTrace: stackTrace);

  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _logger.e(_Record(tag, message), error: error, stackTrace: stackTrace);

  /// Flushes and closes the outputs.
  Future<void> close() => _logger.close();
}

final class _Record {
  const new(this.tag, this.message);

  final String tag;
  final String message;

  @override
  String toString() => '[$tag] $message';
}

/// One line per record: `2026-09-15T17:20:01.123Z WARN [tag] message`,
/// followed by indented error and stack trace lines.
final class _LinePrinter extends LogPrinter {
  new(this._secrets);

  final SecretRegistry _secrets;

  static const Map<Level, String> _levelNames = {
    Level.trace: 'TRACE',
    Level.debug: 'DEBUG',
    Level.info: 'INFO',
    Level.warning: 'WARN',
    Level.error: 'ERROR',
    Level.fatal: 'FATAL',
  };

  @override
  List<String> log(LogEvent event) {
    final time = event.time.toUtc().toIso8601String();
    final level = _levelNames[event.level] ?? event.level.name.toUpperCase();
    final text = StringBuffer('$time $level ${event.message}');
    if (event.error != null) text.write('\n  error: ${event.error}');
    final stack = event.stackTrace?.toString().trimRight();
    if (stack != null && stack.isNotEmpty) {
      text.write('\n  ${stack.replaceAll('\n', '\n  ')}');
    }
    return redact(text.toString(), secrets: _secrets.values).split('\n');
  }
}
