import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_service.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/downloads/db_download_store.dart';
import 'package:iptv_player/data/downloads/file_download_finisher.dart';
import 'package:iptv_player/data/downloads/isolate_download_runner.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/platform/disk_space.dart';
import 'package:iptv_player/data/platform/platform_providers.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/downloads/data/catalogue_download_titles.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/downloads/domain/download_queue.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_providers.g.dart';

/// Settings → Downloads & library's download half. The defaults at once,
/// the stored choices as soon as they are read; a change is saved, and
/// applies to downloads that start after it.
@Riverpod(keepAlive: true)
class DownloadSettingsController extends _$DownloadSettingsController {
  @override
  DownloadSettings build() {
    unawaited(_load());
    return const DownloadSettings();
  }

  var _changed = false;

  Future<void> _load() async {
    final stored = await ref
        .read(settingsRepositoryProvider)
        .readValue<Object?>(SettingsKeys.downloads, null);
    // A choice made while loading wins over what was stored.
    if (!_changed && ref.mounted) {
      state = DownloadSettings.fromJson(stored.valueOrNull);
    }
  }

  Future<Result<void>> update(DownloadSettings settings) {
    _changed = true;
    state = settings;
    return ref
        .read(settingsRepositoryProvider)
        .writeValue(SettingsKeys.downloads, settings.toJson());
  }
}

/// The system's Videos folder. Tests point it elsewhere.
@Riverpod(keepAlive: true)
Future<String> systemVideos(Ref ref) => systemVideosFolder();

/// Where new downloads go now (docs/09): the folder chosen in Settings,
/// else the system's Videos folder + `IPTV Player`.
@Riverpod(keepAlive: true)
Future<String> downloadFolder(Ref ref) async {
  final stored = await ref
      .read(settingsRepositoryProvider)
      .readValue<Object?>(SettingsKeys.downloads, null);
  final chosen =
      ref.watch(downloadSettingsControllerProvider).folder ??
      DownloadSettings.fromJson(stored.valueOrNull).folder;
  return await downloadFolderPath(
    chosen: chosen,
    videos: () => ref.read(systemVideosProvider.future),
  );
}

/// Moves downloads' bytes, in its own isolate (Phase 8 decision 2).
@Riverpod(keepAlive: true)
DownloadRunner downloadRunner(Ref ref) => IsolateDownloadRunner(
  processFolder: ref.watch(processFolderProvider),
  log: ref.watch(appLogProvider),
  ffmpeg: ref.watch(ffmpegBinariesProvider)?.ffmpeg,
);

/// The download queue (docs/09). `bootstrap()` starts it after launch and
/// shuts it down on quit; it gives way to the player and the cast on the
/// connections they share.
@Riverpod(keepAlive: true)
DownloadQueue downloadQueue(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final pictures = ref.watch(castPicturesProvider);
  final queue = DownloadQueue(
    store: DbDownloadStore(db),
    titles: CatalogueDownloadTitles(
      db,
      ref.watch(streamResolverProvider),
      folder: () => ref.read(downloadFolderProvider.future),
    ),
    runner: ref.watch(downloadRunnerProvider),
    finisher: FileDownloadFinisher(
      db: db,
      probe: ref.watch(streamProbeProvider),
      pictureFile: pictures.fileFor,
      log: ref.watch(appLogProvider),
    ),
    connections: ref.watch(playbackCoordinatorProvider).connections,
    sleep: ref.watch(sharedSleepProvider).view('downloads'),
    settings: () => ref.read(downloadSettingsControllerProvider),
    log: ref.watch(appLogProvider),
    freeSpace: freeBytes,
    fileExists: (path) => File(path).existsSync(),
    windows: Platform.isWindows,
  );
  ref.onDispose(() => unawaited(queue.shutdown()));
  return queue;
}

/// The queue as the screens use it.
@Riverpod(keepAlive: true)
DownloadService downloadService(Ref ref) => ref.watch(downloadQueueProvider);

/// Every download in the queue's order, with their speed while they run.
@Riverpod(keepAlive: true)
Stream<List<DownloadTask>> downloadTasks(Ref ref) =>
    ref.watch(downloadQueueProvider).tasks;

/// The queue's toasts and banners.
@Riverpod(keepAlive: true)
Stream<DownloadNotice> downloadNotices(Ref ref) =>
    ref.watch(downloadQueueProvider).notices;
