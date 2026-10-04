import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:path/path.dart' as p;

/// A frame of a library video, made the first time it is shown (docs/09
/// "ThumbnailGenerator"): the bundled FFmpeg grabs the picture at 10 % of
/// its length into the app's cache, named by the file's quick hash, 2 at
/// a time, 15 s each. A file's own `poster.jpg` comes first, so most
/// movies never need one.
final class LibraryThumbnails {
  new({
    required this._db,
    required this._supervisor,
    required this.ffmpeg,
    required this.folder,
    this.atOnce = 2,
    this.timeout = const Duration(seconds: 15),
  });

  final AppDatabase _db;
  final ProcessSupervisor _supervisor;

  /// Null: no frames (the build has no FFmpeg).
  final String? ffmpeg;
  final Directory folder;
  final int atOnce;
  final Duration timeout;

  final _making = <int, Future<String?>>{};
  final _waiting = <Completer<void>>[];
  var _running = 0;

  /// [itemId]'s frame, made when it has none; null when none can be made.
  Future<String?> thumbnailFor(int itemId) =>
      _making[itemId] ??= _make(itemId)
          .whenComplete(() => _making.removeWhere((k, _) => k == itemId));

  Future<String?> _make(int itemId) async {
    final row = await _db.libraryDao.itemById(itemId);
    if (row == null) return null;
    final kept = row.thumbnailPath;
    if (kept != null && File(kept).existsSync()) return kept;
    final out = File(p.join(folder.path, '${row.quickHash}.jpg'));
    if (out.existsSync()) return await _keep(itemId, out.path);
    final binary = ffmpeg;
    if (binary == null) return null;
    final library = await _db.libraryDao.folderById(row.folderId);
    if (library == null || !library.isAvailable) return null;
    final source = p.joinAll([library.path, ...row.relPath.split('/')]);

    await _turn();
    try {
      folder.createSync(recursive: true);
      final part = File('${out.path}.part.jpg');
      final at = (row.durationMs ?? 60000) / 10 / 1000;
      final run = await _supervisor.run(
        binary,
        [
          ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
          ...['-ss', at.toStringAsFixed(2), '-i', source],
          ...['-frames:v', '1', '-vf', 'scale=480:-2', '-q:v', '4'],
          ...['-f', 'image2', '-y', part.path],
        ],
        owner: 'thumbnail',
        timeout: timeout,
      );
      if (run.exitCode != 0 || !part.existsSync() || part.lengthSync() == 0) {
        if (part.existsSync()) part.deleteSync();
        return null;
      }
      part.renameSync(out.path);
      return await _keep(itemId, out.path);
    } on FileSystemException {
      return null;
    } finally {
      _done();
    }
  }

  Future<String> _keep(int itemId, String path) async {
    await _db.libraryDao.changeItem(
      itemId,
      LibraryItemsCompanion(thumbnailPath: Value(path)),
    );
    return path;
  }

  Future<void> _turn() async {
    if (_running < atOnce) {
      _running++;
      return;
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future;
  }

  void _done() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _running--;
    }
  }
}
