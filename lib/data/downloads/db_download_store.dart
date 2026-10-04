import 'package:drift/drift.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';

/// [DownloadStore] on the `downloads` table (schema v9).
final class DbDownloadStore implements DownloadStore {
  new(this._db);

  final AppDatabase _db;

  @override
  Future<List<DownloadTask>> all() async => [
    for (final row in await _db.downloadsDao.all()) downloadFromRow(row),
  ];

  @override
  Future<DownloadTask?> add(
    DownloadRequest request, {
    required String targetPath,
    required DateTime at,
  }) async {
    final id = await _db.downloadsDao.enqueue(
      DownloadsCompanion.insert(
        sourceId: request.sourceId,
        itemType: request.type,
        remoteKey: request.remoteKey,
        seriesRemoteKey: Value(request.seriesKey),
        season: Value(request.season),
        episode: Value(request.episode),
        title: request.title,
        showTitle: Value(request.showTitle),
        year: Value(request.year),
        artworkUrl: Value(request.artworkUrl),
        targetPath: targetPath,
        state: DownloadTaskState.queued,
        sortOrder: 0,
        createdAt: at,
      ),
    );
    if (id == null) return null;
    final row = await _db.downloadsDao.byId(id);
    return row == null ? null : downloadFromRow(row);
  }

  @override
  Future<void> save(DownloadTask task) => _db.downloadsDao.change(
    task.id,
    DownloadsCompanion(
      targetPath: Value(task.targetPath),
      state: Value(task.state),
      downloadedBytes: Value(task.downloadedBytes),
      totalBytes: Value(task.totalBytes),
      etag: Value(task.etag),
      lastModified: Value(task.lastModified),
      errorClass: Value(task.problem),
      errorDetail: Value(
        task.problemDetail == null ? null : redact(task.problemDetail!),
      ),
      attempts: Value(task.attempts),
      libraryItemId: Value(task.libraryItemId),
      completedAt: Value(task.completedAt),
    ),
  );

  @override
  Future<void> remove(int id) => _db.downloadsDao.remove(id);

  @override
  Future<List<DownloadTask>> move(int id, int index) async {
    await _db.downloadsDao.move(id, index);
    return await all();
  }
}

DownloadTask downloadFromRow(DownloadRow row) => DownloadTask(
  id: row.id,
  sourceId: row.sourceId,
  type: row.itemType,
  remoteKey: row.remoteKey,
  title: row.title,
  targetPath: row.targetPath,
  state: row.state,
  downloadedBytes: row.downloadedBytes,
  sortOrder: row.sortOrder,
  createdAt: row.createdAt,
  year: row.year,
  seriesKey: row.seriesRemoteKey,
  showTitle: row.showTitle,
  season: row.season,
  episode: row.episode,
  artworkUrl: row.artworkUrl,
  totalBytes: row.totalBytes,
  etag: row.etag,
  lastModified: row.lastModified,
  problem: row.errorClass,
  problemDetail: row.errorDetail,
  attempts: row.attempts,
  libraryItemId: row.libraryItemId,
  completedAt: row.completedAt,
);
