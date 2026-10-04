import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/result.dart';

/// The download queue as the screens use it (docs/01, docs/09). Every
/// call answers at once; the work happens in the queue's own time, and
/// [tasks] says how it goes.
abstract interface class DownloadService {
  /// Every download in the queue's order, finished ones included, with
  /// their speed while they run.
  Stream<List<DownloadTask>> get tasks;

  /// Adds [requests] at the end of the queue, in order ("Download season"
  /// is one call). A title already queued or downloaded is left as it
  /// is.
  Future<Result<void>> enqueue(List<DownloadRequest> requests);

  Future<void> pause(int taskId);

  /// Back in the queue, from where its `.part` file ends.
  Future<void> resume(int taskId);

  /// Stops it and deletes its `.part` file.
  Future<void> cancel(int taskId);

  /// A failed download, from the start of its trouble.
  Future<void> retry(int taskId);

  /// Takes a finished or failed download off the list; its file, if
  /// any, stays.
  Future<void> remove(int taskId);

  /// Puts [taskId] at [index] in the queue's order.
  Future<void> move(int taskId, int index);

  Future<void> pauseAll();

  Future<void> resumeAll();

  /// Takes every completed download off the list (Clear list).
  Future<void> clearFinished();
}
