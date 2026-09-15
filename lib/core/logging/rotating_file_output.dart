import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// Log output that appends to `<directory>/<baseName>.log`. When a line
/// would push that file past [maxFileBytes], the file becomes
/// `<baseName>.1.log` (older ones shift up) and at most [maxFiles] files are
/// kept. docs/06 sets 5 × 5 MB.
///
/// Lines are buffered and written in order on dart:io's thread pool.
/// Warnings and errors are flushed at once, so a crash loses little. Write
/// failures are reported on stderr and never reach the caller.
final class RotatingFileOutput extends LogOutput {
  new({
    required this.directory,
    this.baseName = 'app',
    this.maxFileBytes = 5 * 1024 * 1024,
    this.maxFiles = 5,
    this.flushDelay = const Duration(milliseconds: 500),
  }) : assert(maxFiles >= 1, 'maxFiles includes the current file');

  final Directory directory;
  final String baseName;
  final int maxFileBytes;
  final int maxFiles;
  final Duration flushDelay;

  List<Uint8List> _pending = [];
  Future<void> _writes = Future.value();
  RandomAccessFile? _file;
  int _fileBytes = 0;
  Timer? _flushTimer;
  bool _closed = false;

  File get currentFile => File(p.join(directory.path, '$baseName.log'));

  File _rotatedFile(int index) =>
      File(p.join(directory.path, '$baseName.$index.log'));

  @override
  Future<void> init() => _writes = _writes.then((_) => _ensureOpen());

  @override
  void output(OutputEvent event) {
    if (_closed) return;
    for (final line in event.lines) {
      _pending.add(utf8.encode('$line\n'));
    }
    if (event.level.value >= Level.warning.value) {
      unawaited(flush());
    } else {
      _flushTimer ??= Timer(flushDelay, flush);
    }
  }

  /// Writes buffered lines; completes when they are in the file.
  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return _writes;
    final lines = _pending;
    _pending = [];
    return _writes = _writes.then((_) => _write(lines));
  }

  @override
  Future<void> destroy() async {
    _closed = true;
    await flush();
    await _file?.close();
    _file = null;
  }

  Future<RandomAccessFile> _ensureOpen() async {
    final open = _file;
    if (open != null) return open;
    await directory.create(recursive: true);
    final file = await currentFile.open(mode: FileMode.append);
    _fileBytes = await file.length();
    return _file = file;
  }

  Future<void> _write(List<Uint8List> lines) async {
    try {
      var file = await _ensureOpen();
      final chunk = BytesBuilder(copy: false);
      for (final line in lines) {
        if (_fileBytes > 0 && _fileBytes + line.length > maxFileBytes) {
          await file.writeFrom(chunk.takeBytes());
          await _rotate(file);
          file = await _ensureOpen();
        }
        chunk.add(line);
        _fileBytes += line.length;
      }
      await file.writeFrom(chunk.takeBytes());
    } on FileSystemException catch (error) {
      stderr.writeln('Log write failed: ${error.message} (${error.path})');
      await _file?.close().catchError((Object _) {});
      _file = null;
    }
  }

  Future<void> _rotate(RandomAccessFile file) async {
    await file.close();
    _file = null;
    final oldest = _rotatedFile(maxFiles - 1);
    if (maxFiles == 1) {
      await currentFile.delete();
    } else {
      if (oldest.existsSync()) await oldest.delete();
      for (var i = maxFiles - 2; i >= 1; i--) {
        final from = _rotatedFile(i);
        if (from.existsSync()) await from.rename(_rotatedFile(i + 1).path);
      }
      await currentFile.rename(_rotatedFile(1).path);
    }
  }
}
