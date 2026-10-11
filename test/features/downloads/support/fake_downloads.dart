import 'dart:async';

import 'package:iptv_player/core/downloads/download_service.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/result.dart';

/// The download queue in memory: what the screens show, and what they
/// asked of it, in order.
final class FakeDownloads implements DownloadService {
  final _changes = StreamController<List<DownloadTask>>.broadcast();
  var _list = <DownloadTask>[];
  final calls = <String>[];

  /// What reading the queue fails with, when it should.
  Object? failure;

  List<DownloadTask> get list => _list;

  /// Replaces the queue, in this order.
  void set(List<DownloadTask> tasks) {
    _list = [
      for (final (i, task) in tasks.indexed) task.copyWith(sortOrder: i),
    ];
    _changes.add(_list);
  }

  void _change(int id, DownloadTask Function(DownloadTask task) change) => set([
    for (final task in _list)
      if (task.id == id) change(task) else task,
  ]);

  @override
  Stream<List<DownloadTask>> get tasks => Stream.multi((listener) {
    if (failure case final failure?) {
      listener.addError(failure);
      return;
    }
    listener.add(_list);
    final changes = _changes.stream.listen(listener.add);
    listener.onCancel = changes.cancel;
  });

  @override
  Future<Result<void>> enqueue(List<DownloadRequest> requests) async {
    calls.addAll([for (final r in requests) 'enqueue ${r.remoteKey}']);
    return const Ok(null);
  }

  @override
  Future<void> pause(int taskId) async {
    calls.add('pause $taskId');
    _change(
      taskId,
      (t) => t.copyWith(state: DownloadTaskState.paused, speed: null),
    );
  }

  @override
  Future<void> resume(int taskId) async {
    calls.add('resume $taskId');
    _change(taskId, (t) => t.copyWith(state: DownloadTaskState.queued));
  }

  @override
  Future<void> retry(int taskId) async {
    calls.add('retry $taskId');
    _change(
      taskId,
      (t) => t.copyWith(state: DownloadTaskState.queued, problem: null),
    );
  }

  @override
  Future<void> cancel(int taskId) async {
    calls.add('cancel $taskId');
    set([..._list.where((t) => t.id != taskId)]);
  }

  @override
  Future<void> remove(int taskId) async {
    calls.add('remove $taskId');
    set([..._list.where((t) => t.id != taskId)]);
  }

  @override
  Future<void> move(int taskId, int index) async {
    calls.add('move $taskId to $index');
    final moved = _list.firstWhere((t) => t.id == taskId);
    final rest = [..._list.where((t) => t.id != taskId)];
    set(rest..insert(index.clamp(0, rest.length), moved));
  }

  @override
  Future<void> pauseAll() async {
    calls.add('pauseAll');
    set([
      for (final t in _list)
        if (t.state.isFinished)
          t
        else
          t.copyWith(state: DownloadTaskState.paused),
    ]);
  }

  @override
  Future<void> resumeAll() async {
    calls.add('resumeAll');
    set([
      for (final t in _list)
        if (t.state == DownloadTaskState.paused)
          t.copyWith(state: DownloadTaskState.queued)
        else
          t,
    ]);
  }

  @override
  Future<void> clearFinished() async {
    calls.add('clearFinished');
    set([..._list.where((t) => t.state != DownloadTaskState.completed)]);
  }
}

/// A download of `src-1`'s, as the queue lists one.
DownloadTask download(
  int id,
  String title, {
  DownloadTaskState state = DownloadTaskState.queued,
  VodType type = VodType.movie,
  int? year,
  String? show,
  int? season,
  int? episode,
  int downloaded = 0,
  int? total,
  double? speed,
  DownloadProblem? problem,
  int? libraryItemId,
  DateTime? completedAt,
}) => DownloadTask(
  id: id,
  sourceId: 'src-1',
  type: type,
  remoteKey: '$id',
  title: title,
  targetPath: '/home/me/Videos/IPTV Player/$title.mp4',
  state: state,
  downloadedBytes: downloaded,
  totalBytes: total,
  sortOrder: id,
  createdAt: DateTime.utc(2026, 10, 11),
  year: year,
  showTitle: show,
  season: season,
  episode: episode,
  speed: speed,
  problem: problem,
  libraryItemId: libraryItemId,
  completedAt: completedAt,
);
