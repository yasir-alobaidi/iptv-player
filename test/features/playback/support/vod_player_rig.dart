import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/features/library/data/db_library_repository.dart'
    show libraryItemFromRow;
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';

import '../../../app/app_harness.dart';
import '../../live_tv/live_tv_fakes.dart';
import '../../vod/vod_fakes.dart';
import 'playback_fakes.dart';

/// The movie and the series the provider answers with: an hour's film,
/// and two episodes of one season.
const vodPlayerMovie = XtreamMovieInfo(
  plot: 'A storm strands a ferry in a small fishing town.',
  runtimeMinutes: 60,
);

const vodPlayerSeries = XtreamSeriesInfo(
  plot: 'A harbor inspector follows the tide logs.',
  episodes: [
    XtreamEpisode(
      id: '7101',
      season: 1,
      episode: 1,
      title: 'Low Water',
      durationSeconds: 2700,
    ),
    XtreamEpisode(
      id: '7102',
      season: 1,
      episode: 2,
      title: 'Ledger',
      durationSeconds: 2880,
    ),
  ],
);

const vodPlayerHour = Duration(hours: 1);

/// Show in folder, recorded.
final class RecordedReveal implements FileReveal {
  final shown = <String>[];

  @override
  Future<bool> showInFolder(String path) async {
    shown.add(path);
    return true;
  }
}

/// The details pages, the real launcher and the full-screen player, on the
/// fake engine; where a file was left goes to the real database.
final class VodPlayerRig {
  new() : vod = VodFakes() {
    rig = Rig(watchProgress: progress);
  }

  final VodFakes vod;
  late final Rig rig;
  final window = FakeWindow();
  final reveal = RecordedReveal();
  late final progress = DbWatchProgress(vod.db, clock: () => vod.now);
  late AppUnderTest app;

  List<Override> get overrides => [
    ...vod.overrides,
    playerEngineProvider.overrideWithValue(rig.engine),
    playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
    windowControlsProvider.overrideWithValue(window),
    fileRevealProvider.overrideWithValue(reveal),
  ];

  /// A library item in a folder at /videos: the user's own file, or
  /// [download] of the provider's movie 501. Written in [open]'s `before`:
  /// once a page watches the database, a write from `runAsync` waits on
  /// it for good.
  Future<LibraryItem> addLibraryItem({bool download = false}) async {
    final db = vod.db;
    final folder = await db.libraryDao.addFolder(
      path: '/videos',
      label: 'Videos',
      at: vod.now,
    );
    final id = await db.libraryDao.insertItem(
      LibraryItemsCompanion.insert(
        folderId: folder,
        relPath: 'Paper Kites (2019).mkv',
        sizeBytes: 1,
        mtime: 0,
        quickHash: 'hash-kites',
        kind: LibraryKind.movie,
        title: 'Paper Kites',
        addedAt: vod.now,
        providerSourceId: Value(download ? 'src-1' : null),
        providerItemType: Value(download ? VodType.movie : null),
        providerRemoteKey: Value(download ? '501' : null),
      ),
    );
    return libraryItemFromRow(
      (await db.libraryDao.itemById(id))!,
      await db.libraryDao.folderById(folder),
    );
  }

  Future<void> open(
    WidgetTester tester,
    String location, {
    Future<void> Function()? before,
    Size? size,
  }) async {
    addTearDown(() => tester.runAsync(vod.db.close));
    await tester.runAsync(vod.seed);
    vod.details
      ..movieAnswer = const Ok(vodPlayerMovie)
      ..seriesAnswer = const Ok(vodPlayerSeries);
    if (before != null) await tester.runAsync(before);
    app = size == null
        ? await pumpApp(tester, initialLocation: location, overrides: overrides)
        : await pumpApp(
            tester,
            size: size,
            initialLocation: location,
            overrides: overrides,
          );
    await settle(tester);
  }

  /// The player reports the file's length and its first frame.
  Future<void> firstFrame(
    WidgetTester tester, {
    Duration length = vodPlayerHour,
  }) async {
    rig.engine
      ..duration(length)
      ..firstFrame();
    await settle(tester);
  }

  /// Stops what plays. The save goes to drift, which only answers while
  /// the test pumps: started here, finished by [settle].
  Future<void> finish(WidgetTester tester) async {
    unawaited(rig.coordinator.stop());
    await settle(tester);
    await tester.pump(const Duration(seconds: 6));
  }
}
