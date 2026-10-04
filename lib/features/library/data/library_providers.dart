import 'dart:async';
import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/library/library_scan.dart';
import 'package:iptv_player/data/library/library_thumbnails.dart';
import 'package:iptv_player/data/library/system_trash.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/library/data/db_library_repository.dart';
import 'package:iptv_player/features/library/data/library_scans.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_providers.g.dart';

/// The scanner's runs (docs/09): one at a time, each a guarded job on the
/// app's database. `bootstrap()` starts them after launch.
@Riverpod(keepAlive: true)
LibraryScans libraryScans(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final binaries = ref.watch(ffmpegBinariesProvider);
  final processes = ref.watch(processFolderProvider);
  final scans = LibraryScans(
    db: db,
    log: ref.watch(appLogProvider),
    run: (folderIds, report) async {
      final connection = await db.serializableConnection();
      final job = startLibraryScanJob(
        LibraryScanWork(
          now: DateTime.now(),
          connection: connection,
          folderIds: folderIds,
          ffprobe: binaries?.ffprobe,
          processFolder: processes.path,
        ),
      );
      final listening = job.progress.listen(report);
      final result = await job.result;
      await listening.cancel();
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => Err(failure),
      };
    },
  );
  ref.onDispose(() => unawaited(scans.dispose()));
  return scans;
}

/// The library as the screens use it (docs/09).
@Riverpod(keepAlive: true)
LibraryRepository libraryRepository(Ref ref) => DbLibraryRepository(
  ref.watch(appDatabaseProvider),
  scans: ref.watch(libraryScansProvider),
  trash: SystemTrash(),
);

/// Where library videos' frames are kept. `bootstrap()` points it into
/// the app's cache; this is the fallback when it has none.
@Riverpod(keepAlive: true)
Directory libraryThumbnailFolder(Ref ref) => Directory(
  p.join(Directory.systemTemp.path, 'iptv_player', 'library', 'thumbnails'),
);

/// Frames for library videos, made when first shown (docs/09).
@Riverpod(keepAlive: true)
LibraryThumbnails libraryThumbnails(Ref ref) => LibraryThumbnails(
  db: ref.watch(appDatabaseProvider),
  supervisor: ref.watch(processSupervisorProvider),
  ffmpeg: ref.watch(ffmpegBinariesProvider)?.ffmpeg,
  folder: ref.watch(libraryThumbnailFolderProvider),
);

/// A library video's frame, made on first ask.
@riverpod
Future<String?> libraryThumbnail(Ref ref, int itemId) =>
    ref.watch(libraryThumbnailsProvider).thumbnailFor(itemId);

/// The scan's progress, for the Library's header.
@Riverpod(keepAlive: true)
Stream<LibraryScanState> libraryScanState(Ref ref) async* {
  final scans = ref.watch(libraryScansProvider);
  yield scans.state;
  yield* scans.states;
}
