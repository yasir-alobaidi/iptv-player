import 'package:iptv_player/core/result.dart';
import 'package:meta/meta.dart';

/// How loud a log line is, in the log's own order.
enum LogLevel {
  trace('TRACE'),
  debug('DEBUG'),
  info('INFO'),
  warning('WARN'),
  error('ERROR'),
  fatal('FATAL');

  new(this.label);

  /// As the log writes it.
  final String label;

  bool get isProblem => index >= LogLevel.warning.index;

  static LogLevel? named(String label) {
    for (final level in values) {
      if (level.label == label) return level;
    }
    return null;
  }
}

/// One line of the log as the viewer draws it. A record's first line
/// has its time, level and tag; the lines under it (an error, a stack
/// trace) are [continuation]s and carry their record's level.
@immutable
final class LogRow {
  const new({
    required this.level,
    required this.text,
    this.time,
    this.tag = '',
    this.continuation = false,
  });

  /// When it was written; null on a continuation, and on a line that
  /// isn't in the log's format.
  final DateTime? time;
  final LogLevel level;
  final String tag;

  /// The message, or the continuation's own text without its indent.
  final String text;
  final bool continuation;

  /// The line as the file has it, for Copy shown.
  String get raw {
    if (continuation) return '  $text';
    final at = time?.toUtc().toIso8601String();
    return [?at, level.label, if (tag.isNotEmpty) '[$tag]', text].join(' ');
  }
}

final _header = RegExp(
  r'^(\d{4}-\d{2}-\d{2}T[\d:.]+Z) (TRACE|DEBUG|INFO|WARN|ERROR|FATAL) (?:\[([^\]]*)\] ?)?(.*)$',
);

/// Reads one line of the log file. A line that isn't a record's first
/// line is a continuation of the record before it, which gives it
/// [under]'s level.
LogRow parseLogLine(String line, {LogLevel under = LogLevel.info}) {
  final match = _header.firstMatch(line);
  if (match == null) {
    return LogRow(
      level: under,
      text: line.startsWith('  ') ? line.substring(2) : line,
      continuation: true,
    );
  }
  return LogRow(
    time: DateTime.tryParse(match[1]!),
    level: LogLevel.named(match[2]!) ?? LogLevel.info,
    tag: match[3] ?? '',
    text: match[4] ?? '',
  );
}

/// What the viewer asks for: every line or only warnings and errors,
/// and lines holding [text] (any case).
@immutable
final class LogQuery {
  const new({this.problemsOnly = false, this.text = ''});

  final bool problemsOnly;
  final String text;

  bool get isEmpty => !problemsOnly && text.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is LogQuery &&
      other.problemsOnly == problemsOnly &&
      other.text == text;

  @override
  int get hashCode => Object.hash(problemsOnly, text);
}

/// A place in the log files: [file] counts back from the one being
/// written (0), [offset] is a byte offset in it.
@immutable
final class LogCursor {
  const new(this.file, this.offset);

  final int file;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is LogCursor && other.file == file && other.offset == offset;

  @override
  int get hashCode => Object.hash(file, offset);

  @override
  String toString() => 'LogCursor($file, $offset)';
}

/// Some of the log, oldest line first.
@immutable
final class LogPage {
  const new({
    required this.rows,
    required this.end,
    this.older,
    this.rotated = false,
  });

  final List<LogRow> rows;

  /// Where older lines start; null when [rows] reaches the oldest line
  /// kept.
  final LogCursor? older;

  /// The end of what was read: what is written after it is new.
  final LogCursor end;

  /// The file being written was replaced since the cursor was taken (it
  /// filled up): the viewer reads from the end again.
  final bool rotated;
}

/// Reads the app's log files off the UI isolate (Phase 9 decision 8).
/// Lines are redacted when they are written, so the viewer shows
/// nothing the file doesn't.
abstract interface class LogReader {
  /// The file being written, to show in the file manager; null when
  /// this run keeps no log file.
  String? get currentFile;

  /// The newest [limit] lines matching [query] before [before], or
  /// before the end of the log.
  Future<Result<LogPage>> page(
    LogQuery query, {
    LogCursor? before,
    int limit = 2000,
  });

  /// What was written after [after] and matches [query].
  Future<Result<LogPage>> since(LogCursor after, LogQuery query);
}

/// A run with no log file.
final class NoLogReader implements LogReader {
  const new();

  @override
  String? get currentFile => null;

  @override
  Future<Result<LogPage>> page(
    LogQuery query, {
    LogCursor? before,
    int limit = 2000,
  }) async => const Ok(LogPage(rows: [], end: LogCursor(0, 0)));

  @override
  Future<Result<LogPage>> since(LogCursor after, LogQuery query) async =>
      Ok(LogPage(rows: const [], end: after));
}
