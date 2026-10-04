// Phase 8 step 5 end to end: the real app, database and player
// (media_kit) playing files on this computer (Phase 8 decision 8).
//
// A downloaded movie: Play on the provider's page plays its file, with no
// connection to the panel → the keys seek past a minute → Esc: the page
// offers Resume from there, as for the provider's stream.
//
// A file of the user's own, with the fake panel stopped: it plays, its
// subtitle file beside it is one of its tracks → past a minute, Esc: its
// place is kept and Continue watching lists it → played again from there,
// it opens there.
//
// The library's rows are written here; the scanner's run end to end is
// step 8's test. Needs the VOD sample vod_h264_aac_10min (CI makes a
// 120 s one).

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';
import 'package:path/path.dart' as p;

import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

const _subtitles = '''
1
00:00:01,000 --> 00:00:30,000
The ferry is late again.

2
00:01:00,000 --> 00:05:00,000
Nobody leaves the harbour tonight.
''';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'a downloaded movie plays from its file; a library file plays with '
    'the panel stopped, with its subtitles, and resumes',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      final panel = (await tester.runAsync(
        () => FakePanel.start(streams: true),
      ))!;
      var panelUp = true;
      addTearDown(() async {
        if (panelUp) await tester.runAsync(panel.stop);
      });
      final app = (await tester.runAsync(
        () => PanelApp.open(panel, video: video),
      ))!;
      addTearDown(() => tester.runAsync(app.close));

      // The files: a download of the panel's first movie, and a film of
      // the user's own with an English subtitle file beside it.
      final temp = Directory.systemTemp.createTempSync('iptv_library');
      addTearDown(() => temp.deleteSync(recursive: true));
      final sample = File('${samplesDirectory.path}/vod_h264_aac_10min.mp4');
      final downloads = p.join(temp.path, 'Downloads');
      const downloadRel = 'Movies/Harbor Lights/Harbor Lights.mp4';
      final mine = p.join(temp.path, 'Movies HDD');
      const mineRel = 'Paper Kites (2019)/Paper Kites (2019).mp4';
      for (final path in [
        p.joinAll([downloads, ...downloadRel.split('/')]),
        p.joinAll([mine, ...mineRel.split('/')]),
      ]) {
        Directory(p.dirname(path)).createSync(recursive: true);
        sample.copySync(path);
      }
      File(p.join(mine, 'Paper Kites (2019)', 'Paper Kites (2019).en.srt'))
          .writeAsStringSync(_subtitles);

      final db = app.db;
      final now = DateTime.now().toUtc();
      final ownId = (await tester.runAsync(() async {
        final folder = await db.libraryDao.makeDownloadFolder(
          downloads,
          label: 'Downloads',
          at: now,
        );
        await db.libraryDao.insertItem(
          LibraryItemsCompanion.insert(
            folderId: folder.id,
            relPath: downloadRel,
            sizeBytes: sample.lengthSync(),
            mtime: 0,
            quickHash: 'download-hash',
            kind: LibraryKind.movie,
            title: 'Harbor Lights',
            addedAt: now,
            providerSourceId: Value(app.sourceId),
            providerItemType: const Value(VodType.movie),
            providerRemoteKey: const Value('$firstMovieId'),
          ),
        );
        final own = await db.libraryDao.addFolder(
          path: mine,
          label: 'Movies HDD',
          at: now,
        );
        return await db.libraryDao.insertItem(
          LibraryItemsCompanion.insert(
            folderId: own,
            relPath: mineRel,
            sizeBytes: sample.lengthSync(),
            mtime: 0,
            quickHash: 'own-hash',
            kind: LibraryKind.movie,
            title: 'Paper Kites',
            year: const Value(2019),
            addedAt: now,
            subtitlesJson: Value(
              jsonEncode([
                {
                  'file': 'Paper Kites (2019).en.srt',
                  'format': 'srt',
                  'language': 'en',
                },
              ]),
            ),
          ),
        );
      }))!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app.container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      final k = Keys(tester)..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final coordinator = app.container.read(playbackCoordinatorProvider);
      final router = app.container.read(routerProvider);
      final progress = app.container.read(watchProgressProvider);
      final failures = <PlaybackFailed>[];
      final listening = coordinator.states.listen((state) {
        if (state is PlaybackFailed) failures.add(state);
      });
      addTearDown(listening.cancel);

      Future<WatchMark?> markOf(VodRef ref) =>
          tester.runAsync<WatchMark?>(() => progress.watch(ref).first);

      Future<void> playing(Playable item, String what) => k.waitUntil(
        () => coordinator.item == item && coordinator.state is PlaybackPlaying,
        '$what playing (${coordinator.state})',
        seconds: 30,
      );

      Future<void> pastAMinute(String what) async {
        await k.shift(LogicalKeyboardKey.arrowRight);
        await k.press(LogicalKeyboardKey.arrowRight);
        await k.waitUntil(
          () => coordinator.timeline.position >= const Duration(seconds: 70),
          '$what past a minute (at ${coordinator.timeline.position})',
          seconds: 40,
        );
      }

      // ── The downloaded movie, from its page: its file, no connection.
      final movie = (await tester.runAsync(
        () => app.container
            .read(movieRepositoryProvider)
            .byRemoteKey(app.sourceId, '$firstMovieId'),
      ))!.valueOrNull!;
      router.go(movieDetailsPath(movie));
      await k.waitFor(find.text('Play'));
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await playing(PlayableMovie(movie), 'the downloaded movie');
      expect(coordinator.local, isTrue);
      expect(await tester.runAsync(panel.activeConnections), 0);
      await pastAMinute('the downloaded movie');
      expect(await tester.runAsync(panel.activeConnections), 0);

      // ── Esc: the provider's page offers Resume from where the file was
      // left.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == movieDetailsPath(movie),
        'the movie page again',
      );
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');
      final left = (await markOf(movie.ref))!;
      expect(left.position, greaterThanOrEqualTo(const Duration(seconds: 70)));
      await k.waitFor(find.textContaining('Resume from'));

      // ── The panel stops: the user's own film plays all the same.
      await tester.runAsync(panel.stop);
      panelUp = false;
      final own = (await tester.runAsync(
        () => app.container.read(libraryRepositoryProvider).item(ownId),
      ))!;
      final film = PlayableLibraryItem(own);
      final openedFrom = app.location;
      await tester.runAsync(
        () => app.container.read(vodLauncherProvider).playLibraryItem(own),
      );
      await k.waitFor(find.byType(PlayerScreen));
      await playing(film, 'the library film');
      expect(coordinator.local, isTrue);
      expect(coordinator.timeline.duration, isNotNull);

      // Its subtitle file is a track.
      await k.waitUntil(
        () =>
            (app.container.read(playerTracksProvider).value?.subtitles ??
                    const [])
                .isNotEmpty,
        'the subtitle file among the tracks',
      );
      final subtitles = app.container
          .read(playerTracksProvider)
          .value!
          .subtitles;
      expect(subtitles, hasLength(1), reason: '$subtitles');

      // ── Past a minute, Esc: back where it was opened from, its place
      // kept. (With nothing to go back to, the Library: step 6's screen
      // will be what opens it.)
      await pastAMinute('the library film');
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == openedFrom,
        'the page it was opened from (at ${app.location})',
      );
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');
      final kept = (await markOf(const LocalRef('own-hash')))!;
      expect(kept.position, greaterThanOrEqualTo(const Duration(seconds: 70)));
      expect(kept.resumable, isTrue);
      final row = (await tester.runAsync(
        () => progress.continueWatching().first,
      ))!;
      expect(row.whereType<ContinueLibraryFile>().map((c) => c.item.id), [
        ownId,
      ]);

      // ── Played again from there: it opens there.
      await tester.runAsync(
        () => app.container
            .read(vodLauncherProvider)
            .playLibraryItem(own, from: kept.position),
      );
      await playing(film, 'the library film, resumed');
      expect(coordinator.startedFrom, kept.position);
      expect(
        coordinator.timeline.position,
        greaterThanOrEqualTo(kept.position - const Duration(seconds: 2)),
      );
      await k.waitFor(find.textContaining('Resumed from'));
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');

      expect(failures, isEmpty);
      expect(app.location, isNot(playerRoutePath));
      expect(tester.takeException(), isNull);
    },
    skip: !vodAvailable,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
