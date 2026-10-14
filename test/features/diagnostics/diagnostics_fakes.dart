import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/diagnostics/data/diagnostics_providers.dart';
import 'package:iptv_player/features/diagnostics/domain/diagnostics_service.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';

/// A report a test scripts.
final class FakeDiagnostics implements DiagnosticsService {
  String text =
      'Bijou 0.1.0+1 · Ubuntu 22.04.5 LTS · Wayland · GNOME\n'
      'Graphics: Intel UHD Graphics 630 (i915)\n'
      'Player: mpv 0.34.1\n'
      'Decoding: H.264 1080p → vaapi · HEVC 2160p → vaapi\n'
      'Casting: ffmpeg version n8.1.2 · encoders h264_nvenc · libx264\n'
      'Source 1: Xtream · Active · 1 connection · 12,610 channels · 20,072 '
      'movies · 8,262 series\n'
      '  last sync: 2 h ago, 8 s, 0 rows skipped\n'
      '  guide: 142,880 programmes, last import 3 h ago, 41 s, 12 rows '
      'skipped\n'
      'Library: 3 folders · 412 items\n'
      'Downloads: 2 waiting or running · 14 finished\n'
      'Recent warnings and errors: none';
  AppFailure? failure;
  AppFailure? saveFailure;

  /// Makes [report] wait.
  Completer<void>? gate;
  final saved = <(String, String)>[];
  int reports = 0;

  @override
  Future<Result<String>> report() async {
    reports++;
    if (gate case final gate?) await gate.future;
    if (failure case final failure?) return Err(failure);
    return Ok(text);
  }

  @override
  Future<Result<void>> save(String path, String text) async {
    if (saveFailure case final failure?) return Err(failure);
    saved.add((path, text));
    return const Ok(null);
  }
}

/// A log held in memory: a cursor's offset is a place in [rows].
final class FakeLogReader implements LogReader {
  new([List<LogRow>? rows]) : rows = rows ?? [];

  /// The whole log, oldest first. A test adds to it to "write" lines.
  final List<LogRow> rows;

  @override
  String? currentFile = '/home/me/.local/share/app/logs/app.log';

  AppFailure? failure;

  /// Makes [page] wait.
  Completer<void>? gate;

  /// Makes the next [since] say the file was replaced.
  bool rotated = false;
  final queries = <LogQuery>[];

  bool _matches(LogRow row, LogQuery query) {
    if (query.problemsOnly && !row.level.isProblem) return false;
    final needle = query.text.trim().toLowerCase();
    return needle.isEmpty ||
        row.text.toLowerCase().contains(needle) ||
        row.tag.toLowerCase().contains(needle);
  }

  @override
  Future<Result<LogPage>> page(
    LogQuery query, {
    LogCursor? before,
    int limit = 2000,
  }) async {
    queries.add(query);
    if (gate case final gate?) await gate.future;
    if (failure case final failure?) return Err(failure);
    final end = before?.offset ?? rows.length;
    final found = <LogRow>[];
    var at = end;
    while (at > 0 && found.length < limit) {
      at--;
      if (_matches(rows[at], query)) found.add(rows[at]);
    }
    return Ok(
      LogPage(
        rows: found.reversed.toList(),
        older: at > 0 ? LogCursor(0, at) : null,
        end: LogCursor(0, rows.length),
      ),
    );
  }

  @override
  Future<Result<LogPage>> since(LogCursor after, LogQuery query) async {
    if (rotated) {
      rotated = false;
      return Ok(LogPage(rows: const [], end: after, rotated: true));
    }
    return Ok(
      LogPage(
        rows: [
          for (final row in rows.skip(after.offset))
            if (_matches(row, query)) row,
        ],
        end: LogCursor(0, rows.length),
      ),
    );
  }
}

/// `09:00:07 INFO [playback] line 7`, seven seconds after nine.
LogRow logRow(
  int n, {
  LogLevel level = LogLevel.info,
  String tag = 'playback',
  String? text,
}) => LogRow(
  time: DateTime(2026, 10, 13, 9).add(Duration(seconds: n)),
  level: level,
  tag: tag,
  text: text ?? 'line $n',
);

/// A file manager that records what it was asked to show.
final class FakeFileReveal implements FileReveal {
  final shown = <String>[];
  bool opens = true;

  @override
  Future<bool> showInFolder(String path) async {
    shown.add(path);
    return opens;
  }
}

/// The About page's diagnostics, faked.
List<Override> diagnosticsOverrides({
  required FakeDiagnostics diagnostics,
  required LogReader log,
  FileReveal? reveal,
  Future<String?> Function(String name)? savePicker,
}) => [
  diagnosticsProvider.overrideWithValue(diagnostics),
  logReaderProvider.overrideWithValue(log),
  if (reveal != null) fileRevealProvider.overrideWithValue(reveal),
  if (savePicker != null)
    reportSavePickerProvider.overrideWithValue(savePicker),
];
