import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/downloads/download_format.dart';
import 'package:iptv_player/core/downloads/download_paths.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_media.dart';
import 'package:iptv_player/core/library/name_parser.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/downloads/download_remux.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/library/quick_hash.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:path/path.dart' as p;

const _tag = 'downloads';

/// [DownloadFinisher] on the files and the library (docs/09
/// "DownloadFinalizer"): the size matches what the provider said and
/// ffprobe reads a length, or the file is damaged and its `.part` goes;
/// then it is remade as MP4 when that loses nothing (docs/09 "Format");
/// then the `.part` becomes the final name — **a file under a final name
/// is always complete** (hard rule 11) — `poster.jpg` is written from the
/// app's picture cache, the title's details are copied (Phase 8 decision
/// 5), and the file joins the library, linked to its title so progress is
/// shared with streaming.
///
/// The MP4 is written beside the `.part` as `<name>.mp4.part`. The
/// download's own `.part` is deleted only once that copy is whole and
/// checked, and the copy takes its final name last: whatever is on disk
/// when the app stops says how far it got ([whole]).
final class FileDownloadFinisher implements DownloadFinisher {
  new({
    required this._db,
    required this._probe,
    required this._pictureFile,
    required this._log,
    this._remux,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final StreamProbe _probe;

  /// A picture's file in the app's cache (fetched into it when missing);
  /// null when there is none.
  final Future<String?> Function(String url) _pictureFile;
  final AppLog _log;

  /// Null keeps every download in the container it came in.
  final DownloadRemux? _remux;
  final DateTime Function() _now;

  /// The `.part` of the MP4 [task]'s file is remade as; null when the
  /// provider's file is named `.mp4` already.
  static File? _copyOf(DownloadTask task) {
    final mp4 = mp4PathFor(task.targetPath);
    return mp4 == task.targetPath ? null : File('$mp4.part');
  }

  /// What an earlier try left under a name that says it is whole: the
  /// file itself, the MP4 it was remade as, or that MP4 still to be
  /// renamed. Null while the `.part` is there (it is the truth, docs/09).
  static File? _left(DownloadTask task) {
    if (File('${task.targetPath}.part').existsSync()) return null;
    final file = File(task.targetPath);
    if (file.existsSync()) return file;
    final copy = _copyOf(task);
    if (copy == null) return null;
    if (copy.existsSync()) return copy;
    final mp4 = File(mp4PathFor(task.targetPath));
    return mp4.existsSync() ? mp4 : null;
  }

  @override
  Future<bool> whole(DownloadTask task) async {
    try {
      return _left(task) != null;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<DownloadFinish> finish(DownloadTask task) async {
    final part = File('${task.targetPath}.part');
    final copy = _copyOf(task);
    // After a stop between the last steps: whole already, under the name
    // it has.
    final File? left;
    final int partSize;
    try {
      left = _left(task);
      partSize = (left ?? part).lengthSync();
    } on FileSystemException catch (error) {
      return DownloadNotFinished(redact('No file to finish: ${error.message}'));
    }
    final total = task.totalBytes;
    if (left == null && total != null && partSize != total) {
      return _damaged(
        task,
        'It has $partSize bytes of the $total the provider said.',
      );
    }
    final probed = await _probe.probe((left ?? part).path);
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

    // docs/09 "Format": as MP4 when that loses nothing.
    var ready = left ?? part;
    var name = task.targetPath;
    LibraryMedia? media;
    if (left != null) {
      if (left.path != task.targetPath) name = mp4PathFor(task.targetPath);
    } else if (_remux != null && copy != null) {
      switch (await _remux.toMp4(part.path, copy.path)) {
        case RemuxDone(media: final made):
          try {
            part.deleteSync();
          } on FileSystemException catch (error) {
            return DownloadNotFinished(
              redact('Could not replace it with its MP4: ${error.message}'),
            );
          }
          ready = copy;
          name = mp4PathFor(task.targetPath);
          media = made;
          _log.info(_tag, 'Download ${task.id} is kept as MP4');
        case RemuxKept(:final why, media: final read):
          media = read;
          _log.info(_tag, 'Download ${task.id} stays as it came: $why');
        case RemuxStopped():
          return const DownloadFinishStopped();
      }
    }

    var file = ready;
    if (ready.path.endsWith('.part')) {
      try {
        file = await ready.rename(
          freeName(name, (path) => File(path).existsSync()),
        );
      } on FileSystemException catch (error) {
        return DownloadNotFinished(
          redact('Could not rename it: ${error.message}'),
        );
      }
    }

    try {
      final size = file.lengthSync();
      final poster = await _poster(task, file);
      final itemId = await _addToLibrary(
        task,
        file,
        size: size,
        duration: media?.duration ?? duration,
        media: media,
        poster: poster,
      );
      return DownloadFinished(itemId, bytes: size, path: file.path);
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
    _deleteParts(task);
    return DownloadDamaged(detail);
  }

  /// The `.part`, and the MP4 being made from it.
  void _deleteParts(DownloadTask task) {
    for (final file in [File('${task.targetPath}.part'), ?_copyOf(task)]) {
      try {
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException catch (error) {
        _log.warning(_tag, 'Could not delete a .part', error: error);
      }
    }
  }

  @override
  Future<void> discard(DownloadTask task) async {
    if (_copyOf(task) case final copy?) await _remux?.stop(copy.path);
    _deleteParts(task);
  }

  @override
  Future<void> close() async {
    await _remux?.close();
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

  /// A file was just written into a folder the library had as "not
  /// connected" (the download folder before its first download, a drive
  /// plugged in again): it is there, as a scan would find.
  Future<void> _folderIsBack(int folderId) => _db.transaction(() async {
    await _db.libraryDao.changeFolder(
      folderId,
      const LibraryFoldersCompanion(isAvailable: Value(true)),
    );
    await (_db.update(_db.libraryItems)
          ..where((t) => t.folderId.equals(folderId)))
        .write(const LibraryItemsCompanion(unavailableSince: Value(null)));
  });

  Future<int> _addToLibrary(
    DownloadTask task,
    File file, {
    required int size,
    required Duration? duration,
    required LibraryMedia? media,
    required String? poster,
  }) async {
    final folderId = await _folderOf(task, file);
    final folder = (await _db.libraryDao.folderById(folderId))!;
    if (!folder.isAvailable) await _folderIsBack(folderId);
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
      // As the scanner would read the file's name: an episode's title is
      // what it says beyond its number.
      title: task.type == VodType.episode && task.showTitle != null
          ? providerEpisodeTitle(task.title)
          : task.title,
      year: Value(task.year),
      showTitle: Value(task.showTitle),
      season: Value(task.season),
      episode: Value(task.episode),
      durationMs: Value(duration?.inMilliseconds),
      // Read already: the quality line shows without waiting for a scan.
      probeJson: Value(media == null ? null : jsonEncode(media.toJson())),
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
