import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';
import 'package:path/path.dart' as p;

/// [LogReader] over the files `RotatingFileOutput` writes:
/// `<base>.log` (being written) and `<base>.1.log` … (older). Every read
/// runs in an isolate; a page of the newest lines reads one file's tail.
final class FileLogReader implements LogReader {
  const new({
    required this.directory,
    this.baseName = 'app',
    this.maxFiles = 5,
  });

  final Directory directory;
  final String baseName;
  final int maxFiles;

  @override
  String get currentFile => _path(directory.path, baseName, 0);

  @override
  Future<Result<LogPage>> page(
    LogQuery query, {
    LogCursor? before,
    int limit = 2000,
  }) => Result.guard(
    () => _pageInIsolate(
      directory.path,
      baseName,
      maxFiles,
      query.problemsOnly,
      query.text,
      before?.file,
      before?.offset,
      limit,
    ),
  );

  @override
  Future<Result<LogPage>> since(LogCursor after, LogQuery query) =>
      Result.guard(
        () => _sinceInIsolate(
          directory.path,
          baseName,
          query.problemsOnly,
          query.text,
          after.offset,
        ),
      );
}

// Built at the top level, so the closures sent to the isolate carry
// their arguments and nothing of their caller.
Future<LogPage> _pageInIsolate(
  String directory,
  String baseName,
  int maxFiles,
  bool problemsOnly,
  String text,
  int? beforeFile,
  int? beforeOffset,
  int limit,
) => Isolate.run(
  () => readLogPage(
    directory,
    baseName: baseName,
    maxFiles: maxFiles,
    problemsOnly: problemsOnly,
    text: text,
    beforeFile: beforeFile,
    beforeOffset: beforeOffset,
    limit: limit,
  ),
);

Future<LogPage> _sinceInIsolate(
  String directory,
  String baseName,
  bool problemsOnly,
  String text,
  int offset,
) => Isolate.run(
  () => readLogSince(
    directory,
    baseName: baseName,
    problemsOnly: problemsOnly,
    text: text,
    offset: offset,
  ),
);

String _path(String directory, String baseName, int file) =>
    p.join(directory, file == 0 ? '$baseName.log' : '$baseName.$file.log');

/// A record: its first line and the lines under it, oldest first.
typedef _Record = List<LogRow>;

bool _matches(_Record record, bool problemsOnly, String needle) {
  if (problemsOnly && !record.first.level.isProblem) return false;
  if (needle.isEmpty) return true;
  for (final row in record) {
    if (row.text.toLowerCase().contains(needle) ||
        row.tag.toLowerCase().contains(needle)) {
      return true;
    }
  }
  return false;
}

/// [FileLogReader.page]'s work, synchronous, for the isolate: walks the
/// files back from the end (or from the cursor) until [limit] lines
/// match.
LogPage readLogPage(
  String directory, {
  String baseName = 'app',
  int maxFiles = 5,
  bool problemsOnly = false,
  String text = '',
  int? beforeFile,
  int? beforeOffset,
  int limit = 2000,
}) {
  final needle = text.trim().toLowerCase();
  // Newest record first while collecting; turned round at the end.
  final found = <_Record>[];
  var rows = 0;
  LogCursor? older;
  LogCursor? end;
  var full = false;

  for (var file = beforeFile ?? 0; file < maxFiles && !full; file++) {
    final handle = File(_path(directory, baseName, file));
    if (!handle.existsSync()) break;
    final length = handle.lengthSync();
    final upTo = file == beforeFile
        ? (beforeOffset ?? length).clamp(0, length)
        : length;
    if (file == 0 && beforeFile == null) end = LogCursor(0, length);
    if (upTo == 0) continue;
    final bytes = _readHead(handle, upTo);

    // Line spans, walked from the last line back. A file whose last line
    // has no newline yet (being written) ends on a partial line: left
    // for the next read of the tail.
    var lineEnd = bytes.length;
    if (file == 0 && beforeFile == null) {
      final lastNewline = bytes.lastIndexOf(10);
      lineEnd = lastNewline + 1;
      end = LogCursor(0, lineEnd);
    }
    final under = <String>[];
    while (lineEnd > 0) {
      // lineEnd is just past a newline (or the end): the line before it.
      final contentEnd = bytes[lineEnd - 1] == 10 ? lineEnd - 1 : lineEnd;
      var start = contentEnd;
      while (start > 0 && bytes[start - 1] != 10) {
        start--;
      }
      final line = utf8.decode(
        Uint8List.sublistView(bytes, start, contentEnd),
        allowMalformed: true,
      );
      final row = parseLogLine(line);
      if (row.continuation) {
        under.add(line);
      } else {
        final record = <LogRow>[
          row,
          for (final more in under.reversed)
            parseLogLine(more, under: row.level),
        ];
        under.clear();
        if (_matches(record, problemsOnly, needle)) {
          found.add(record);
          rows += record.length;
          older = LogCursor(file, start);
          if (rows >= limit) {
            full = true;
            break;
          }
        }
      }
      lineEnd = start;
    }
    // Lines at the top of a file with no record above them: on their
    // own, so nothing written is ever hidden.
    if (!full && under.isNotEmpty) {
      final record = [for (final more in under.reversed) parseLogLine(more)];
      if (_matches(record, problemsOnly, needle)) {
        found.add(record);
        rows += record.length;
        older = LogCursor(file, 0);
      }
    }
  }

  // Stopped at the limit: older lines start where the oldest one taken
  // does, if anything is before it. Ran out of files: there are none.
  LogCursor? next;
  if (full) {
    final at = older!;
    final more =
        at.offset > 0 ||
        (at.file + 1 < maxFiles &&
            File(_path(directory, baseName, at.file + 1)).existsSync());
    next = more ? at : null;
  }
  return LogPage(
    rows: [for (final record in found.reversed) ...record],
    older: next,
    end: end ?? LogCursor(beforeFile ?? 0, beforeOffset ?? 0),
  );
}

Uint8List _readHead(File file, int length) {
  final handle = file.openSync();
  try {
    return handle.readSync(length);
  } finally {
    handle.closeSync();
  }
}

/// [FileLogReader.since]'s work: what the file being written gained
/// after [offset]. A file shorter than that was replaced (it filled up
/// and a new one was started).
LogPage readLogSince(
  String directory, {
  required int offset,
  String baseName = 'app',
  bool problemsOnly = false,
  String text = '',
}) {
  final file = File(_path(directory, baseName, 0));
  final at = LogCursor(0, offset);
  if (!file.existsSync()) {
    return LogPage(rows: const [], end: at, rotated: offset > 0);
  }
  final length = file.lengthSync();
  if (length < offset) return LogPage(rows: const [], end: at, rotated: true);
  if (length == offset) return LogPage(rows: const [], end: at);
  final handle = file.openSync();
  final Uint8List bytes;
  try {
    handle.setPositionSync(offset);
    bytes = handle.readSync(length - offset);
  } finally {
    handle.closeSync();
  }
  // Up to the last whole line: the rest is still being written.
  final whole = bytes.lastIndexOf(10) + 1;
  if (whole == 0) return LogPage(rows: const [], end: at);
  final lines = utf8
      .decode(Uint8List.sublistView(bytes, 0, whole - 1), allowMalformed: true)
      .split('\n');

  final needle = text.trim().toLowerCase();
  final rows = <LogRow>[];
  _Record? record;
  void close() {
    final done = record;
    if (done != null && _matches(done, problemsOnly, needle)) {
      rows.addAll(done);
    }
    record = null;
  }

  for (final line in lines) {
    final row = parseLogLine(line, under: record?.first.level ?? LogLevel.info);
    if (row.continuation && record != null) {
      record!.add(row);
    } else {
      close();
      record = [row];
    }
  }
  close();
  return LogPage(rows: rows, end: LogCursor(0, offset + whole));
}
