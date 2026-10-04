import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/downloads/download_paths.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/library/quick_hash.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:path/path.dart' as p;

const _tag = 'downloads';

/// [DownloadFinisher] on the files and the library (docs/09
/// "DownloadFinalizer"): the size matches what the provider said and
/// ffprobe reads a length, or the file is damaged and its `.part` goes;
/// then the `.part` becomes the final name — **a file under a final name
/// is always complete** (hard rule 11) — `poster.jpg` is written from the
/// app's picture cache, the title's details are copied (Phase 8 decision
/// 5), and the file joins the library, linked to its title so progress is
/// shared with streaming.
final class FileDownloadFinisher implements DownloadFinisher {
  new({
    required this._db,
    required this._probe,
    required this._pictureFile,
    required this._log,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final StreamProbe _probe;

  /// A picture's file in the app's cache (fetched into it when missing);
  /// null when there is none.
  final Future<String?> Function(String url) _pictureFile;
  final AppLog _log;
  final DateTime Function() _now;

  @override
  Future<DownloadFinish> finish(DownloadTask task) async {
    final part = File('${task.targetPath}.part');
    var file = File(task.targetPath);
    final int size;
    // After a crash between the rename and the database: already final.
    final renamed = !part.existsSync() && file.existsSync();
    try {
      size = renamed ? file.lengthSync() : part.lengthSync();
    } on FileSystemException catch (error) {
      return DownloadNotFinished(redact('No file to finish: ${error.message}'));
    }
    final checked = renamed ? file : part;
    final total = task.totalBytes;
    if (total != null && size != total) {
      return _damaged(
        task,
        'It has $size bytes of the $total the provider said.',
      );
    }
    final probed = await _probe.probe(checked.path);
    final Duration? duration;
    switch (probed) {
      case StreamProbed(:final facts)
          when (facts.duration ?? Duration.zero) > Duration.zero:
        duration = facts.duration;
      case StreamProbed():
        return _damaged(task, 'ffprobe read no length in it.');
      case StreamProbeFailed(
        reason: StreamProbeFailure.couldNotStart || StreamProbeFailure.timedOut,
        :final detail,
      ):
        // Not a verdict on the file: the size check stands alone.
        _log.warning(_tag, 'Download ${task.id} not probed: $detail');
        duration = null;
      case StreamProbeFailed(:final reason, :final detail):
        final why = detail == null ? reason.name : '${reason.name}: $detail';
        return _damaged(task, 'ffprobe could not read it ($why).');
    }

    if (!renamed) {
      try {
        file = File(
          freeName(task.targetPath, (path) => File(path).existsSync()),
        );
        file = await part.rename(file.path);
      } on FileSystemException catch (error) {
        return DownloadNotFinished(
          redact('Could not rename it: ${error.message}'),
        );
      }
    }

    try {
      final poster = await _poster(task, file);
      final itemId = await _addToLibrary(
        task,
        file,
        size: size,
        duration: duration,
        poster: poster,
      );
      return DownloadFinished(itemId, bytes: size);
    } on Object catch (error) {
      _log.warning(
        _tag,
        'Download ${task.id} not added to the library',
        error: error,
      );
      return DownloadNotFinished(
        redact('Could not add it to the library: $error'),
      );
    }
  }

  DownloadDamaged _damaged(DownloadTask task, String detail) {
    _log.warning(_tag, 'Download ${task.id} is damaged: $detail');
    try {
      final part = File('${task.targetPath}.part');
      if (part.existsSync()) part.deleteSync();
    } on FileSystemException catch (error) {
      _log.warning(_tag, 'Could not delete a damaged .part', error: error);
    }
    return DownloadDamaged(detail);
  }

  @override
  Future<void> discard(DownloadTask task) async {
    try {
      final part = File('${task.targetPath}.part');
      if (part.existsSync()) await part.delete();
    } on FileSystemException catch (error) {
      _log.warning(_tag, 'Could not delete a .part', error: error);
    }
  }

  @override
  Future<int> partSize(DownloadTask task) async {
    try {
      final part = File('${task.targetPath}.part');
      return part.existsSync() ? part.lengthSync() : 0;
    } on FileSystemException {
      return 0;
    }
  }

  /// `poster.jpg` beside a movie, or in its show's folder for an episode
  /// (docs/09's layout), from the app's picture cache; kept when there.
  Future<String?> _poster(DownloadTask task, File file) async {
    final folder = switch (task.type) {
      VodType.movie => file.parent,
      VodType.episode => file.parent.parent,
    };
    final poster = File(p.join(folder.path, 'poster.jpg'));
    if (poster.existsSync()) return poster.path;
    final url = switch (task.type) {
      VodType.movie => task.artworkUrl,
      VodType.episode => await _seriesPoster(task) ?? task.artworkUrl,
    };
    if (url == null || url.isEmpty) return null;
    final cached = await _pictureFile(url);
    if (cached == null) return null;
    try {
      await File(cached).copy(poster.path);
      return poster.path;
    } on FileSystemException catch (error) {
      _log.info(_tag, 'No poster for download ${task.id}: ${error.message}');
      return null;
    }
  }

  Future<String?> _seriesPoster(DownloadTask task) async {
    final key = task.seriesKey;
    if (key == null) return null;
    return (await _db.seriesDao.byRemoteKey(task.sourceId, key))?.posterUrl;
  }

  /// The folder the download went into: the library's folder holding it,
  /// else the layout's root, added as one.
  Future<int> _folderOf(DownloadTask task, File file) async {
    final depth = task.type == VodType.movie ? 3 : 4;
    var root = file.path;
    for (var i = 0; i < depth; i++) {
      root = p.dirname(root);
    }
    final kept = await _db.libraryDao.folderByPath(root);
    if (kept != null) return kept.id;
    return await _db.libraryDao.addFolder(
      path: root,
      label: downloadFolderLabel,
      at: _now().toUtc(),
    );
  }

  Future<int> _addToLibrary(
    DownloadTask task,
    File file, {
    required int size,
    required Duration? duration,
    required String? poster,
  }) async {
    final folderId = await _folderOf(task, file);
    final folder = (await _db.libraryDao.folderById(folderId))!;
    final relPath = p.split(p.relative(file.path, from: folder.path)).join('/');
    final details = await _details(task);
    final item = LibraryItemsCompanion.insert(
      folderId: folderId,
      relPath: relPath,
      sizeBytes: size,
      mtime: file.statSync().modified.millisecondsSinceEpoch,
      quickHash: await quickHash(file),
      kind: task.type == VodType.movie
          ? LibraryKind.movie
          : LibraryKind.episode,
      title: task.title,
      year: Value(task.year),
      showTitle: Value(task.showTitle),
      season: Value(task.season),
      episode: Value(task.episode),
      durationMs: Value(duration?.inMilliseconds),
      artworkPath: Value(poster),
      detailsJson: Value(details == null ? null : jsonEncode(details)),
      providerSourceId: Value(task.sourceId),
      providerItemType: Value(task.type),
      providerRemoteKey: Value(task.remoteKey),
      providerSeriesKey: Value(task.seriesKey),
      addedAt: _now().toUtc(),
    );
    final existing = (await _db.libraryDao.itemsIn(folderId))
        .where((row) => row.relPath == relPath)
        .firstOrNull;
    if (existing != null) {
      await _db.libraryDao.changeItem(existing.id, item);
      return existing.id;
    }
    return await _db.libraryDao.insertItem(item);
  }

  /// The title's details as the provider gave them (Phase 8 decision 5).
  Future<Map<String, Object?>?> _details(DownloadTask task) async {
    switch (task.type) {
      case VodType.movie:
        final movie = await _db.moviesDao.byRemoteKey(
          task.sourceId,
          task.remoteKey,
        );
        if (movie == null) return null;
        final more = await (_db.select(
          _db.movieDetails,
        )..where((d) => d.movieId.equals(movie.id))).getSingleOrNull();
        return _compact({
          'name': movie.name,
          'year': movie.year,
          'rating': movie.rating,
          'poster_url': movie.posterUrl,
          'plot': more?.plot,
          'genre': more?.genre,
          'cast': more?.castNames,
          'director': more?.director,
          'runtime_minutes': more?.runtimeMinutes,
          'backdrop_url': more?.backdropUrl,
        });
      case VodType.episode:
        final key = task.seriesKey;
        final series = key == null
            ? null
            : await _db.seriesDao.byRemoteKey(task.sourceId, key);
        final episode = series == null
            ? null
            : await (_db.select(_db.episodes)..where(
                    (e) =>
                        e.seriesId.equals(series.id) &
                        e.remoteKey.equals(task.remoteKey),
                  ))
                  .getSingleOrNull();
        if (series == null && episode == null) return null;
        return _compact({
          'series_name': series?.name,
          'series_plot': series?.plot,
          'series_poster_url': series?.posterUrl,
          'series_backdrop_url': series?.backdropUrl,
          'genre': series?.genre,
          'rating': series?.rating,
          'year': series?.year,
          'title': episode?.title,
          'plot': episode?.plot,
          'still_url': episode?.stillUrl,
          'duration_seconds': episode?.durationSeconds,
        });
    }
  }

  static Map<String, Object?> _compact(Map<String, Object?> map) => {
    for (final MapEntry(:key, :value) in map.entries) key: ?value,
  };
}
