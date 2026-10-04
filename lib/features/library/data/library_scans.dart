import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/library_scan.dart';
import 'package:meta/meta.dart';
import 'package:watcher/watcher.dart';

const _tag = 'library';

/// What the Library's header shows while a scan runs.
@immutable
final class LibraryScanState {
  const new({this.progress});

  /// Null when nothing is being scanned.
  final LibraryScanProgress? progress;

  bool get scanning => progress != null;
}

/// Runs the scanner (docs/09): one scan at a time, at launch, when asked
/// (Rescan, a folder added), and when a watched folder changes (Phase 8
/// decision 7: 3 s after the last change, only that folder). A folder the
/// system can't watch says so ([watched]), and is rescanned at launch and
/// when the Library opens instead.
final class LibraryScans {
  new({
    required this._db,
    required this._log,
    required this._run,
    this.settle = const Duration(seconds: 3),
    Watcher Function(String path)? watcher,
  }) : _watcher = watcher ?? DirectoryWatcher.new;

  final AppDatabase _db;
  final AppLog _log;

  /// Runs a scan: the guarded job in the app, the scan itself in tests.
  final Future<Result<LibraryScanResult>> Function(
    List<int>? folderIds,
    void Function(LibraryScanProgress progress) report,
  )
  _run;

  /// How long a folder must be quiet before its changes are scanned.
  final Duration settle;
  final Watcher Function(String path) _watcher;

  final _states = StreamController<LibraryScanState>.broadcast();
  final _watching = <int, StreamSubscription<WatchEvent>>{};
  final _watchedOk = <int, bool>{};
  final _settling = <int, Timer>{};
  final _changes = StreamController<void>.broadcast();
  StreamSubscription<List<LibraryFolderRow>>? _folders;
  LibraryScanState _state = const LibraryScanState();

  /// What is asked for and not yet running: null in it means every folder.
  final _queue = <int?>{};
  Future<void>? _running;
  bool _closed = false;

  Stream<LibraryScanState> get states => _states.stream;

  LibraryScanState get state => _state;

  /// Whether each folder is watched (Settings: "Updates automatically"),
  /// as it changes.
  Stream<void> get watchChanges => _changes.stream;

  bool? watched(int folderId) => _watchedOk[folderId];

  /// The scan at launch, and the folders' watches from then on.
  Future<void> startUp() async {
    _folders = _db.libraryDao.watchFolders().listen(_watchFolders);
    await scan();
  }

  /// Scans [folderId], or every folder; a scan already waiting covers a
  /// new ask for the same.
  Future<void> scan({int? folderId}) {
    if (_closed) return Future.value();
    if (_queue.contains(null)) return _running ?? Future.value();
    if (folderId == null) {
      _queue
        ..clear()
        ..add(null);
    } else {
      _queue.add(folderId);
    }
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty && !_closed) {
      final all = _queue.contains(null);
      final folders = all ? null : [..._queue.whereType<int>()];
      _queue.clear();
      final clock = Stopwatch()..start();
      final result = await _run(folders, (progress) {
        _set(LibraryScanState(progress: progress));
      });
      switch (result) {
        case Ok(:final value):
          _log.info(_tag, 'Scanned in ${clock.elapsedMilliseconds} ms: $value');
        case Err(:final failure):
          _log.warning(_tag, 'The scan failed: $failure');
      }
      _set(const LibraryScanState());
    }
  }

  void _set(LibraryScanState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  void _watchFolders(List<LibraryFolderRow> folders) {
    final ids = {for (final f in folders) f.id};
    for (final id in [..._watching.keys]) {
      if (!ids.contains(id)) _unwatch(id);
    }
    for (final folder in folders) {
      if (_watching.containsKey(folder.id) || !folder.isAvailable) continue;
      if (!Directory(folder.path).existsSync()) continue;
      _watch(folder);
    }
  }

  void _watch(LibraryFolderRow folder) {
    try {
      _watching[folder.id] = _watcher(folder.path).events.listen(
        (event) {
          if (!_counts(event.path)) return;
          _settling.remove(folder.id)?.cancel();
          _settling[folder.id] = Timer(settle, () {
            _settling.remove(folder.id);
            unawaited(scan(folderId: folder.id));
          });
        },
        onError: (Object error) {
          _log.info(_tag, 'Folder ${folder.id} not watched: $error');
          _unwatch(folder.id);
          _watchedOk[folder.id] = false;
          _changes.add(null);
        },
        cancelOnError: true,
      );
      _watchedOk[folder.id] = true;
    } on Object catch (error) {
      _log.info(_tag, 'Folder ${folder.id} not watched: $error');
      _watchedOk[folder.id] = false;
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  void _unwatch(int id) {
    unawaited(_watching.remove(id)?.cancel());
    _settling.remove(id)?.cancel();
    _watchedOk.remove(id);
  }

  /// A download's `.part` and hidden files change all the time and are
  /// never listed.
  static bool _counts(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return !name.startsWith('.') && !name.endsWith('.part');
  }

  Future<void> dispose() async {
    _closed = true;
    _queue.clear();
    unawaited(_folders?.cancel());
    [..._watching.keys].forEach(_unwatch);
    await _running;
    await _states.close();
    await _changes.close();
  }
}
