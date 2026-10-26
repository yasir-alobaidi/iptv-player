import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'run_logs.g.dart';

/// What a TV logged in its run before this one and in this one, as
/// logcat had it (`RunLog.kt`, ADR-059): the engine's lines, a GPU
/// driver's, the app's log, the keys and the activity's steps, up to the
/// moment the run ended. Each is its newest part; empty when none was
/// kept.
@immutable
final class RunLogs {
  const new({this.previous = const [], this.current = const []});

  final List<String> previous;
  final List<String> current;

  bool get isEmpty => previous.isEmpty && current.isEmpty;
}

/// Each run's own log (ADR-059). Never throws: what can't be read is
/// null.
abstract interface class RunLogsSource {
  /// False where nothing keeps them: the desktop (its log file has it
  /// all), a test.
  bool get available;

  /// Each run's newest [maxBytes] at most.
  Future<RunLogs?> read({int maxBytes});
}

/// Nothing to read: the desktop and tests.
final class NoRunLogs implements RunLogsSource {
  const new();

  @override
  bool get available => false;

  @override
  Future<RunLogs?> read({int maxBytes = 0}) async => null;
}

/// `bootstrap()` gives a TV's (`AndroidRunLogs`).
@Riverpod(keepAlive: true)
RunLogsSource runLogs(Ref ref) => const NoRunLogs();

/// `runLogs`' answer, read tolerantly: a part that isn't text is empty;
/// null when the answer isn't a map.
RunLogs? runLogsFrom(Object? answer) {
  if (answer is! Map) return null;
  List<String> lines(Object? text) => text is String
      ? [
          for (final line in text.split('\n'))
            if (line.trim().isNotEmpty) line.trimRight(),
        ]
      : const [];
  return RunLogs(
    previous: lines(answer['previous']),
    current: lines(answer['current']),
  );
}
