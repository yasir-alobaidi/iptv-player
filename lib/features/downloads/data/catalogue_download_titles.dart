import 'dart:io';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:path/path.dart' as p;

/// [DownloadTitles] on the catalogue: a download's URL is built from its
/// title's row and its source by the [StreamResolver], as playback's is
/// (docs/09: never stored).
final class CatalogueDownloadTitles implements DownloadTitles {
  new(this._db, this._resolver, {required this._folder});

  final AppDatabase _db;
  final StreamResolver _resolver;
  final Future<String> Function() _folder;

  @override
  Future<String> folder() => _folder();

  @override
  Future<DownloadSourceAnswer> source(DownloadTask task) async {
    try {
      final Result<ResolvedStream> resolved;
      switch (task.type) {
        case VodType.movie:
          final row = await _db.moviesDao.byRemoteKey(
            task.sourceId,
            task.remoteKey,
          );
          if (row == null) {
            return const DownloadSourceGone(
              'the movie is gone from its source',
            );
          }
          resolved = await _resolver.movie(
            MovieItem(
              id: row.id,
              sourceId: task.sourceId,
              remoteKey: task.remoteKey,
              name: row.name,
              ext: row.ext,
            ),
          );
        case VodType.episode:
          final episode = await _episode(task);
          if (episode == null) {
            return const DownloadSourceGone(
              'the episode is gone from its source',
            );
          }
          resolved = await _resolver.episode(episode);
      }
      return switch (resolved) {
        Ok(:final value) => DownloadSource(
          DownloadUpstream(
            url: value.url,
            userAgent: value.userAgent,
            hls: value.hls,
          ),
          maxConnections: value.maxConnections,
        ),
        Err(:final failure)
            when failure is NotFoundFailure || failure is ParseFailure =>
          DownloadSourceGone(redact('$failure')),
        Err(:final failure) => DownloadSourceUnavailable(redact('$failure')),
      };
    } on Object catch (error) {
      return DownloadSourceUnavailable(redact('$error'));
    }
  }

  Future<EpisodeItem?> _episode(DownloadTask task) async {
    final seriesKey = task.seriesKey;
    if (seriesKey == null) return null;
    final series = await _db.seriesDao.byRemoteKey(task.sourceId, seriesKey);
    if (series == null) return null;
    final row =
        await (_db.select(_db.episodes)..where(
              (e) =>
                  e.seriesId.equals(series.id) &
                  e.remoteKey.equals(task.remoteKey),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return EpisodeItem(
      id: row.id,
      sourceId: task.sourceId,
      seriesKey: seriesKey,
      remoteKey: row.remoteKey,
      season: row.season,
      episode: row.episode,
      title: row.title,
      ext: row.ext,
    );
  }

  @override
  Future<bool> downloaded(DownloadRequest request) async {
    final item = await _db.libraryDao.itemForTitle(
      request.sourceId,
      request.type,
      request.remoteKey,
    );
    if (item == null) return false;
    final folder = await _db.libraryDao.folderById(item.folderId);
    if (folder == null) return false;
    // A file deleted outside the app is downloaded again.
    return File(p.joinAll([folder.path, ...item.relPath.split('/')]))
        .existsSync();
  }
}
