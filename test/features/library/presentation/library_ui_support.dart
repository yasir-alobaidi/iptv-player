import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/library_scan.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/data/library_scans.dart';
import 'package:iptv_player/features/library/presentation/library_folders.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/vod_launcher.dart';
import 'package:logger/logger.dart';
import 'package:watcher/watcher.dart';

import '../../../app/app_harness.dart';
import '../../downloads/support/fake_downloads.dart';
import '../../vod/vod_fakes.dart';

export '../../downloads/support/fake_downloads.dart';

const int gb = 1024 * 1024 * 1024;

final class _Reveal implements FileReveal {
  const new(this._asked);

  final List<String> _asked;

  @override
  Future<bool> showInFolder(String path) async {
    _asked.add(path);
    return true;
  }
}

/// What a Play asked for: the title, and from which second.
final class LibraryLauncher implements VodLauncher {
  final played = <String>[];

  @override
  Future<void> playMovie(MovieItem movie, {Duration? from}) async =>
      played.add('${movie.name} from ${from?.inSeconds ?? 0}');

  @override
  Future<void> playEpisode(
    SeriesItem series,
    EpisodeItem episode, {
    Duration? from,
  }) async => played.add('${episode.title} from ${from?.inSeconds ?? 0}');

  @override
  Future<void> playLibraryItem(LibraryItem item, {Duration? from}) async =>
      played.add('${item.title} from ${from?.inSeconds ?? 0}');
}

/// The Library's screens on a real in-memory database, read through the
/// real repository: the provider's catalogue of [VodFakes] (source
/// `src-1`), the download folder and two folders of the user's own. Scans
/// are scripted, thumbnails are never made, and Play is recorded.
final class LibraryUi {
  new({Watcher Function(String path)? watcher}) : vod = VodFakes() {
    scans = LibraryScans(
      db: db,
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
      watcher: watcher,
      run: (folders, report) async {
        scanned.addAll(folders ?? [null]);
        final progress = scanProgress;
        if (progress != null) report(progress);
        await scanGate?.future;
        return const Ok(LibraryScanResult());
      },
    );
  }

  final VodFakes vod;
  final launcher = LibraryLauncher();

  /// The paths Show in folder was asked for.
  final revealed = <String>[];

  /// The drive the download folder is on.
  ({int free, int total})? disk = (free: 118 * gb, total: 512 * gb);

  /// The folders Change folder chose.
  final downloadFolders = <String>[];
  late final LibraryScans scans;

  /// The folders a scan was asked for; null is every folder.
  final scanned = <int?>[];

  /// What a scan reports, and what it waits for before it ends.
  LibraryScanProgress? scanProgress;
  Completer<void>? scanGate;

  /// What the folder dialog answers.
  String? picked;

  late int downloads;
  late int hdd;
  late int home;

  /// The download queue ([VodFakes] has it: the provider's pages show
  /// a title's download too).
  FakeDownloads get queue => vod.queue;

  AppDatabase get db => vod.db;
  DateTime get now => vod.now;

  /// The source and its catalogue, the download folder, "Movies HDD" and
  /// "Home videos".
  Future<void> seed() async {
    await vod.seed();
    downloads = (await db.libraryDao.makeDownloadFolder(
      '/home/me/Videos/IPTV Player',
      label: 'Downloads',
      at: now,
    )).id;
    hdd = await db.libraryDao.addFolder(
      path: '/media/hdd/Movies',
      label: 'Movies HDD',
      at: now,
    );
    home = await db.libraryDao.addFolder(
      path: '/home/me/Home videos',
      label: 'Home videos',
      at: now,
    );
  }

  /// A file in the library; its id. [provider] links a download to its
  /// title at `src-1`; [away] says its drive isn't connected.
  Future<int> add(
    int folder,
    String relPath,
    String title, {
    LibraryKind kind = LibraryKind.movie,
    int? year,
    int bytes = gb,
    Duration? duration,
    String? show,
    int? season,
    int? episode,
    String? provider,
    String? series,
    bool away = false,
    Map<String, Object?>? media,
    Map<String, Object?>? details,
    List<Map<String, Object?>>? subtitles,
  }) => db.libraryDao.insertItem(
    LibraryItemsCompanion.insert(
      folderId: folder,
      relPath: relPath,
      sizeBytes: bytes,
      mtime: 0,
      quickHash: 'hash:$relPath',
      kind: kind,
      title: title,
      addedAt: now,
      year: Value(year),
      durationMs: Value(duration?.inMilliseconds),
      showTitle: Value(show),
      season: Value(season),
      episode: Value(episode),
      providerSourceId: Value(provider == null ? null : 'src-1'),
      providerItemType: Value(
        provider == null
            ? null
            : kind == LibraryKind.episode
            ? VodType.episode
            : VodType.movie,
      ),
      providerRemoteKey: Value(provider),
      providerSeriesKey: Value(series),
      unavailableSince: Value(away ? now : null),
      probeJson: Value(media == null ? null : jsonEncode(media)),
      detailsJson: Value(details == null ? null : jsonEncode(details)),
      subtitlesJson: Value(subtitles == null ? null : jsonEncode(subtitles)),
    ),
  );

  /// Where the user's own file at [relPath] was left.
  Future<void> leftAt(
    String relPath,
    Duration position,
    Duration duration, {
    bool completed = false,
    DateTime? at,
  }) => db.watchHistoryDao.touchLocal(
    'hash:$relPath',
    at ?? now,
    positionMs: position.inMilliseconds,
    durationMs: duration.inMilliseconds,
    completed: completed,
    dismissed: false,
  );

  List<Override> get overrides => [
    ...vod.overrides,
    libraryScansProvider.overrideWithValue(scans),
    downloadFolderProvider.overrideWith(
      (ref) async =>
          downloadFolders.lastOrNull ?? '/home/me/Videos/IPTV Player',
    ),
    downloadDiskSpaceProvider.overrideWith((ref) async => disk),
    changeDownloadFolderProvider.overrideWithValue((path) async {
      downloadFolders.add(path);
      return const Ok(null);
    }),
    fileRevealProvider.overrideWithValue(_Reveal(revealed)),
    ffmpegBinariesProvider.overrideWithValue(null),
    libraryThumbnailProvider.overrideWith((ref, id) async => null),
    folderPickerProvider.overrideWithValue(() async => picked),
    homeFolderProvider.overrideWithValue('/home/me'),
    vodLauncherProvider.overrideWithValue(launcher),
  ];
}

/// The app at [location] over a seeded [LibraryUi]; [before] writes the
/// library's rows (a write once a screen watches the database would wait
/// for good).
Future<(LibraryUi, AppUnderTest)> openLibrary(
  WidgetTester tester, {
  String location = '/library',
  FutureOr<void> Function(LibraryUi ui)? before,
  List<Override> overrides = const [],
  Watcher Function(String path)? watcher,
  Size size = const Size(1440, 900),
  DateTime? now,
}) async {
  final ui = LibraryUi(watcher: watcher);
  if (now != null) ui.vod.fakes.now = now;
  addTearDown(
    () => tester.runAsync(() async {
      await ui.scans.dispose();
      await ui.db.close();
    }),
  );
  await tester.runAsync(() async {
    await ui.seed();
    await before?.call(ui);
  });
  final app = await pumpApp(
    tester,
    size: size,
    initialLocation: location,
    overrides: [...ui.overrides, ...overrides],
  );
  await settle(tester);
  return (ui, app);
}
