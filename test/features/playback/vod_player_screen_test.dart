import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/library/data/db_library_repository.dart'
    show libraryItemFromRow;
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/playback/presentation/vod_osd.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';
import '../vod/vod_fakes.dart';
import 'support/playback_fakes.dart';

const _movie = XtreamMovieInfo(
  plot: 'A storm strands a ferry in a small fishing town.',
  runtimeMinutes: 60,
);

const _series = XtreamSeriesInfo(
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

const _hour = Duration(hours: 1);

/// Show in folder, recorded.
final class _Reveal implements FileReveal {
  final shown = <String>[];

  @override
  Future<bool> showInFolder(String path) async {
    shown.add(path);
    return true;
  }
}

/// The details pages, the real launcher and the full-screen player, on the
/// fake engine; where a file was left goes to the real database.
final class _Vod {
  new() : vod = VodFakes() {
    rig = Rig(watchProgress: progress);
  }

  final VodFakes vod;
  late final Rig rig;
  final window = FakeWindow();
  final reveal = _Reveal();
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
  }) async {
    addTearDown(() => tester.runAsync(vod.db.close));
    await tester.runAsync(vod.seed);
    vod.details
      ..movieAnswer = const Ok(_movie)
      ..seriesAnswer = const Ok(_series);
    if (before != null) await tester.runAsync(before);
    app = await pumpApp(
      tester,
      initialLocation: location,
      overrides: overrides,
    );
    await settle(tester);
  }

  /// The player reports the file's length and its first frame.
  Future<void> firstFrame(
    WidgetTester tester, {
    Duration length = _hour,
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

/// A test with a [_Vod] that is always stopped at the end, pass or fail:
/// a failed expectation otherwise leaves the watchdog's timers running,
/// and the test hangs instead of failing.
void _vodTest(
  String description,
  Future<void> Function(WidgetTester tester, _Vod t) body,
) => testWidgets(description, (tester) async {
  final t = _Vod();
  try {
    await body(tester, t);
  } finally {
    await t.finish(tester);
  }
});

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await settle(tester);
}

void main() {
  group('a movie', () {
    _vodTest('Play opens the player on it, full screen, with its own face', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');

      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);

      expect(t.app.location, playerRoutePath);
      expect(t.window.changes, [true]);
      final request = t.rig.engine.opened.single;
      expect(request.live, isFalse);
      expect(request.start, isNull);
      expect(find.byType(VodOsdTop), findsOneWidget);
      expect(find.byType(OsdTop), findsNothing);
      expect(find.text('The Quiet Harbor'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      expect(find.byType(AppSlider), findsOneWidget);
      expect(find.text('−1:00:00'), findsOneWidget);
      expect(findByLabel('Pause'), findsOneWidget);
    });

    _vodTest('until the picture comes the OSD stays up and says Preparing', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Preparing…'), findsOneWidget);
      final osd = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(VodOsdTop),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(osd.opacity, 1);

      await t.firstFrame(tester);
      expect(find.text('Preparing…'), findsNothing);
    });

    _vodTest('Esc saves where it was, stops, and its page offers Resume', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 25, seconds: 3));
      await settle(tester);

      await _key(tester, LogicalKeyboardKey.escape);

      expect(t.app.location, '/movies/src-1/501');
      expect(t.window.changes, [true, false]);
      expect(t.rig.state, isA<PlaybackIdle>());
      expect(t.rig.engine.calls, contains('stop'));
      final mark = await tester.runAsync(
        () => t.progress.watch(const MovieRef('src-1', '501')).first,
      );
      expect(mark?.position, const Duration(minutes: 25, seconds: 3));
      expect(mark?.duration, _hour);
      expect(find.text('Resume from 25:03'), findsOneWidget);
    });

    _vodTest('Resume opens where it was left and says so for 5 s; Home '
        'starts over', (tester, t) async {
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () => t.progress.save(
          const MovieRef('src-1', '501'),
          position: const Duration(minutes: 24, seconds: 10),
          duration: _hour,
        ),
      );
      expect(find.text('Resume from 24:10'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);

      expect(
        t.rig.engine.opened.single.start,
        const Duration(minutes: 24, seconds: 10),
      );
      expect(
        find.text('Resumed from 24:10 · Home starts over'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('Resumed from'), findsNothing);

      await _key(tester, LogicalKeyboardKey.home);
      expect(t.rig.engine.calls, contains('seek:0'));
    });

    _vodTest('Start over opens at the start', (tester, t) async {
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () => t.progress.save(
          const MovieRef('src-1', '501'),
          position: const Duration(minutes: 24),
          duration: _hour,
        ),
      );
      await tester.tap(find.text('Start over'));
      await settle(tester);
      await t.firstFrame(tester);

      expect(t.rig.engine.opened.single.start, isNull);
      expect(find.textContaining('Resumed from'), findsNothing);
    });

    _vodTest('←/→ and Shift seek once the keys rest; Space pauses; the '
        "live player's zapping keys do nothing", (tester, t) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 5));
      await settle(tester);
      List<String> seeks() => [
        for (final c in t.rig.engine.calls)
          if (c.startsWith('seek:')) c,
      ];

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      // The bar is already there; the bubble says where.
      expect(find.text('4:20'), findsWidgets);
      expect(seeks(), isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks(), ['seek:260000']);

      await _key(tester, LogicalKeyboardKey.space);
      expect(t.rig.engine.calls, contains('paused:true'));
      expect(findByLabel('Play'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.space);
      expect(t.rig.engine.calls.last, 'paused:false');

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.digit4);
      await tester.pump(const Duration(seconds: 2));
      expect(t.rig.engine.opened, hasLength(1));
      expect(t.app.location, playerRoutePath);
    });

    _vodTest('a movie that ends goes back to its page, watched', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(_hour - const Duration(seconds: 2));
      t.rig.engine.end();
      await settle(tester);

      expect(t.app.location, '/movies/src-1/501');
      final mark = await tester.runAsync(
        () => t.progress.watch(const MovieRef('src-1', '501')).first,
      );
      expect(mark?.completed, isTrue);
    });

    _vodTest('leaving the player any other way stops the movie too', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 7));
      await settle(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);

      expect(t.app.location, '/live');
      expect(t.rig.state, isA<PlaybackIdle>());
      final mark = await tester.runAsync(
        () => t.progress.watch(const MovieRef('src-1', '501')).first,
      );
      expect(mark?.position, const Duration(minutes: 7));
    });

    _vodTest("a movie the provider doesn't have any more says so", (
      tester,
      t,
    ) async {
      t.rig.prober.next = PlaybackProblem(
        PlaybackProblemKind.offline,
        failure: NotFoundFailure('stream: HTTP 404', 404),
      );
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      t.rig.engine.fail('404 Not Found');
      await settle(tester);

      expect(find.text('No longer available'), findsOneWidget);
      expect(
        find.textContaining(
          'This movie is no longer available from your provider.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Next episode'), findsNothing);
    });
  });

  group('an episode', () {
    /// Series 77's page, then its primary action (Play S1 · E1).
    Future<void> playFirst(WidgetTester tester, _Vod t) async {
      await t.open(tester, '/series/src-1/77');
      expect(find.text('Play S1 · E1'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester, length: const Duration(minutes: 45));
    }

    /// The last [seconds] of the episode start playing.
    Future<void> credits(_Vod t, WidgetTester tester, int seconds) async {
      t.rig.engine.progress(
        const Duration(minutes: 45) - Duration(seconds: seconds),
      );
      await settle(tester);
    }

    _vodTest('the top says the series and S · E', (tester, t) async {
      await playFirst(tester, t);
      expect(find.text('Glass Tide'), findsOneWidget);
      expect(find.text('S1 · E1 · Low Water'), findsOneWidget);
    });

    _vodTest('at 20 s left the card counts down, and Enter plays the next '
        'now', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 19);

      expect(find.text('NEXT EPISODE'), findsOneWidget);
      expect(find.text('Ledger'), findsOneWidget);
      expect(find.text('Play now · 10'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Play now · 9'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.enter);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
      expect(t.rig.state.item, isA<PlayableEpisode>());
      await t.firstFrame(tester, length: const Duration(minutes: 48));
      expect(find.text('S1 · E2 · Ledger'), findsOneWidget);
      expect(find.text('NEXT EPISODE'), findsNothing);
    });

    _vodTest('at the end of the count the next plays on its own', (
      tester,
      t,
    ) async {
      await playFirst(tester, t);
      await credits(t, tester, 19);
      await tester.pump(const Duration(seconds: 10));
      await settle(tester);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
    });

    _vodTest('Esc cancels; at the end the card is back without the count, '
        'and Back to series goes to its page', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 15);
      expect(find.text('Play now · 10'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.text('NEXT EPISODE'), findsNothing);
      expect(t.app.location, playerRoutePath, reason: 'Esc only cancelled');
      // Past where the count would have ended, playing all the while.
      for (var s = 1; s <= 12; s++) {
        t.rig.engine.progress(
          const Duration(minutes: 45) - Duration(seconds: 15 - s),
        );
        await tester.pump(const Duration(seconds: 1));
      }
      expect(t.rig.engine.opened, hasLength(1));

      t.rig.engine.end();
      await settle(tester);
      expect(find.text('Play next episode'), findsOneWidget);
      expect(find.text('Back to series'), findsOneWidget);

      await tester.tap(find.text('Back to series'));
      await settle(tester);
      expect(t.app.location, '/series/src-1/77');
      final mark = await tester.runAsync(
        () => t.progress
            .watch(const EpisodeRef('src-1', '7101', seriesKey: '77'))
            .first,
      );
      expect(mark?.completed, isTrue);
    });

    _vodTest('a failed episode offers the next one', (tester, t) async {
      await playFirst(tester, t);
      t.rig.prober.next = const PlaybackProblem(PlaybackProblemKind.offline);
      t.rig.engine.fail();
      await settle(tester);

      expect(find.text('No longer available'), findsOneWidget);
      await tester.tap(find.text('Next episode'));
      await settle(tester);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
    });
  });

  group("a file on this computer that can't be read (Phase 8 decision 8)", () {
    _vodTest('a library file offers Show in folder, which leaves full '
        'screen first, and Remove from library, which leaves the player', (
      tester,
      t,
    ) async {
      late final LibraryItem file;
      await t.open(
        tester,
        '/',
        before: () async => file = await t.addLibraryItem(),
      );
      t.rig.resolver.missingFiles.add(file.id);
      unawaited(
        PlayerVodLauncher(
          t.rig.coordinator,
          () => t.app.router,
        ).playLibraryItem(file),
      );
      await settle(tester);

      expect(t.app.location, playerRoutePath);
      expect(find.text('This file is missing or damaged'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Show in folder'));
      await settle(tester);
      expect(t.reveal.shown, [file.path]);
      expect(t.window.changes.last, isFalse);

      await tester.tap(find.text('Remove from library'));
      await settle(tester);
      expect(
        await tester.runAsync(() => t.vod.db.libraryDao.itemById(file.id)),
        isNull,
      );
      expect(t.app.location, isNot(playerRoutePath));
      expect(
        find.text('Removed from the library. The file stays where it is.'),
        findsOneWidget,
      );
    });

    _vodTest("a downloaded movie's damaged file offers them too; Remove "
        'goes back to its page', (tester, t) async {
      late final LibraryItem file;
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () async => file = await t.addLibraryItem(download: true),
      );
      t.rig.resolver.downloads['501'] = file.path!;
      await _key(tester, LogicalKeyboardKey.enter);
      t.rig.engine.fail('Failed to recognize file format.');
      await settle(tester);

      expect(find.text('This file is missing or damaged'), findsOneWidget);
      expect(find.text('Show in folder'), findsOneWidget);
      await tester.tap(find.text('Remove from library'));
      await settle(tester);

      expect(t.app.location, '/movies/src-1/501');
      expect(
        find.text('Removed from the library. Play uses your provider again.'),
        findsOneWidget,
      );
    });

    _vodTest("a provider's movie that fails offers neither", (tester, t) async {
      t.rig.prober.next = const PlaybackProblem(PlaybackProblemKind.offline);
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () => t.addLibraryItem(download: true),
      );
      await _key(tester, LogicalKeyboardKey.enter);
      t.rig.engine.fail();
      await settle(tester);

      expect(find.text('No longer available'), findsOneWidget);
      expect(find.text('Show in folder'), findsNothing);
      expect(find.text('Remove from library'), findsNothing);
    });
  });
}
