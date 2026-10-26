import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'run_logs.g.dart';

/// What a TV logged in its two runs before this one and in this one, as
/// logcat had it (`RunLog.kt`, ADR-059): the engine's lines, a GPU
/// driver's, the app's log, the keys and the activity's steps, up to the
/// moment the run ended. Each is its newest part; empty when none was
/// kept.
@immutable
final class RunLogs {
  const new({
    this.older = const [],
    this.previous = const [],
    this.current = const [],
  });

  /// The run before [previous]: still there after the launch that told
  /// of a crash (ADR-060).
  final List<String> older;
  final List<String> previous;
  final List<String> current;

  bool get isEmpty => older.isEmpty && previous.isEmpty && current.isEmpty;
}

/// The renderer the engine named as it started, in a run's log:
/// `Impeller (OpenGLES)` from "Using the Impeller rendering backend
/// (OpenGLES).", `Skia` from its warning that the app opted out of
/// Impeller; null when no line says (a long run's log keeps only its
/// newest part). The last such line: a Vulkan the engine tried and
/// refused is named before the OpenGL ES it fell back to (ADR-061).
/// What the TV drew with, not what was asked for: a release engine
/// ignored Impeller's OpenGL ES (ADR-060).
String? rendererIn(List<String> lines) {
  const said = 'Using the Impeller rendering backend (';
  String? renderer;
  for (final line in lines) {
    if (line.contains('Impeller opt-out deprecated')) {
      renderer = 'Skia';
      continue;
    }
    final at = line.indexOf(said);
    if (at < 0) continue;
    final rest = line.substring(at + said.length);
    final end = rest.indexOf(')');
    renderer = 'Impeller (${end < 0 ? rest.trim() : rest.substring(0, end)})';
  }
  return renderer;
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
    older: lines(answer['older']),
    previous: lines(answer['previous']),
    current: lines(answer['current']),
  );
}
