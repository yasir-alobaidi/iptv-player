// Phase 8 step 6's walk, keys only, on the real app, database, download
// queue and player against the fake panel: Movies → D on a movie → the
// top bar's indicator → Ctrl+6, the Library → Downloads → Enter pauses
// it, Enter resumes it → it finishes → Enter plays its file → Esc →
// Movies → a movie of the user's own → Resume → Esc → its menu → Edit
// details → Save → its menu → Delete file → Keep.
//
// The test reads state to check it; everything it does goes through the
// keyboard, except the speed limit, which it sets so a download over
// loopback lasts long enough to be seen, and lifts again.
//
// Downloads go to a temporary folder, never the user's Videos. Needs the
// VOD sample vod_h264_aac_10min (CI makes a 120 s one) and an FFmpeg
// (the bundled one, else the system's).

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/library/quick_hash.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/presentation/download_actions.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_routes.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:path/path.dart' as p;

import 'support/cast_tv.dart';
import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';
  final binaries = castBinaries();

  testWidgets(
    'D on a movie → Downloads → it finishes → Play → a movie of your own '
    '→ Resume → Edit details → Delete file → Keep, by keyboard',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      final temp = Directory.systemTemp.createTempSync('iptv_library_walk');
      addTearDown(() => temp.deleteSync(recursive: true));
      final videos = p.join(temp.path, 'Videos');
      final panel = (await tester.runAsync(
        () => FakePanel.start(streams: true),
      ))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final app = (await tester.runAsync(
        () => PanelApp.open(
          panel,
          video: video,
          overrides: [
            ...downloadShellOverrides,
            // Never the user's own Videos folder.
            systemVideosProvider.overrideWith((ref) async => videos),
            ffmpegBinariesProvider.overrideWithValue(binaries),
            processFolderProvider.overrideWithValue(
              Directory(p.join(temp.path, 'processes')),
            ),
            libraryThumbnailFolderProvider.overrideWithValue(
              Directory(p.join(temp.path, 'thumbnails')),
            ),
          ],
        ),
      ))!;
      addTearDown(() => tester.runAsync(app.close));
      final container = app.container;
      final db = app.db;

      // A film of the user's own in a folder of theirs, left at 1:10.
      final sample = File('${samplesDirectory.path}/vod_h264_aac_10min.mp4');
      final hdd = p.join(temp.path, 'Movies HDD');
      const ownRel = 'Paper Kites (2019)/Paper Kites (2019).mp4';
      final ownFile = File(p.joinAll([hdd, ...ownRel.split('/')]));
      ownFile.parent.createSync(recursive: true);
      sample.copySync(ownFile.path);
      final now = DateTime.now().toUtc();
      final ownId = (await tester.runAsync(() async {
        final hash = await quickHash(ownFile);
        final folder = await db.libraryDao.addFolder(
          path: hdd,
          label: 'Movies HDD',
          at: now,
        );
        await db.watchHistoryDao.touchLocal(
          hash,
          now,
          positionMs: 70 * 1000,
          durationMs: 120 * 1000,
          completed: false,
          dismissed: false,
        );
        return await db.libraryDao.insertItem(
          LibraryItemsCompanion.insert(
            folderId: folder,
            relPath: ownRel,
            sizeBytes: ownFile.lengthSync(),
            mtime: ownFile.lastModifiedSync().millisecondsSinceEpoch,
            quickHash: hash,
            kind: LibraryKind.movie,
            title: 'Paper Kites',
            year: const Value(2019),
            durationMs: const Value(120 * 1000),
            addedAt: now,
          ),
        );
      }))!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      final k = Keys(tester)..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // What `bootstrap()` does after launch: the download folder is a
      // library folder, the queue's news are toasts, the queue starts. A
      // download over loopback is over in a moment: slowed, to be seen.
      final settings = container.read(
        downloadSettingsControllerProvider.notifier,
      );
      final downloadFolder = (await tester.runAsync(() async {
        final folder = await container.read(downloadFolderProvider.future);
        await registerDownloadFolder(db.libraryDao, folder, now: now);
        container.read(downloadToastsProvider);
        await container.read(downloadQueueProvider).startUp();
        await settings.update(
          const DownloadSettings(speedLimit: DownloadSpeedLimit.mbps10),
        );
        return folder;
      }))!;
      expect(p.isWithin(temp.path, downloadFolder), isTrue);

      final coordinator = container.read(playbackCoordinatorProvider);
      final failures = <PlaybackFailed>[];
      final listening = coordinator.states.listen((state) {
        if (state is PlaybackFailed) failures.add(state);
      });
      addTearDown(listening.cancel);
      final movie = (await tester.runAsync(
        () => container
            .read(movieRepositoryProvider)
            .byRemoteKey(app.sourceId, '$firstMovieId'),
      ))!.valueOrNull!;

      List<DownloadTask> tasks() =>
          container.read(downloadTasksProvider).value ?? const [];
      DownloadTask? task() => tasks().firstOrNull;

      /// ↓ in an open menu to the item labelled [label], and Enter.
      Future<void> choose(String label) async {
        await k.waitFor(byLabel(label));
        for (var i = 0; i < 14 && k.focusedLabel() != label; i++) {
          await k.press(LogicalKeyboardKey.arrowDown);
        }
        expect(k.focusedLabel(), label, reason: 'the menu item "$label"');
        await k.press(LogicalKeyboardKey.enter);
      }

      Future<void> playing(bool Function(Playable? item) item, String what) =>
          k.waitUntil(
            () =>
                item(coordinator.item) && coordinator.state is PlaybackPlaying,
            '$what playing (${coordinator.state})',
            seconds: 30,
          );

      // ── Home, where the film left part-way is first to continue; then
      // Ctrl+3: Movies; the movie's poster through the filter; D
      // downloads it.
      await k.waitFor(find.text('Continue watching'), seconds: 30);
      await k.chord(LogicalKeyboardKey.digit3);
      final filter = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SearchField && w.hint == 'Filter movies',
        ),
        matching: find.byType(EditableText),
      );
      await k.waitFor(filter);
      await k.tabTo(filter);
      await k.typeIn(filter, movie.name.split(' ').first.toLowerCase());
      await k.waitFor(byLabel(movie.name));
      await k.tabTo(find.byWidgetPredicate((w) => w is TitleGrid));
      for (var i = 0; i < 20 && k.focusedLabel() != movie.name; i++) {
        await k.press(LogicalKeyboardKey.arrowRight);
      }
      expect(k.focusedLabel(), movie.name, reason: 'the poster');
      expect(find.byType(DownloadedMark), findsNothing);
      await k.press(LogicalKeyboardKey.keyD);
      await k.waitFor(find.text('Downloading ${movie.name}'));
      await k.waitUntil(
        () => task()?.state == DownloadTaskState.downloading,
        'the download running (${task()?.state})',
      );

      // ── The top bar says one is on its way, and how far.
      await k.waitFor(find.textContaining(RegExp(r'^1 · \d+ %$')));
      expect(await tester.runAsync(panel.activeConnections), 1);

      // ── Ctrl+6: the Library; its Downloads tab; the download's row.
      // Enter pauses it; Enter again, with the limit lifted, resumes it.
      await k.chord(LogicalKeyboardKey.digit6);
      await k.waitUntil(
        () => app.location == AppDestination.library.path,
        'the Library (${app.location})',
      );
      final tab = byLabel('Downloads, 1');
      await k.waitFor(tab);
      await k.tabTo(tab);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text('IN PROGRESS'));
      // The row's label says how far it is: found by the title it starts
      // with.
      final row = find.byWidgetPredicate(
        (w) =>
            w is FocusableSurface &&
            (w.semanticLabel?.startsWith(movie.name) ?? false),
      );
      await k.tabTo(row);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => task()?.state == DownloadTaskState.paused,
        'the download paused (${task()?.state})',
      );
      await k.waitFor(find.textContaining('Paused'));
      expect(await tester.runAsync(panel.activeConnections), 0);
      await tester.runAsync(() => settings.update(const DownloadSettings()));
      await k.press(LogicalKeyboardKey.enter);

      // ── It finishes: the toast, FINISHED TODAY, the file under its
      // final name and in the library.
      await k.waitUntil(
        () => task()?.state == DownloadTaskState.completed,
        'the download finished (${task()?.state}, ${task()?.problem})',
        seconds: 90,
      );
      await k.waitFor(find.text('FINISHED TODAY'));
      await k.waitFor(find.textContaining('Download finished'));
      final file = (await tester.runAsync(
        () => container
            .read(libraryRepositoryProvider)
            .downloadOf(VodType.movie, app.sourceId, movie.remoteKey),
      ))!;
      expect(File(file.path!).lengthSync(), sample.lengthSync());
      expect(p.isWithin(downloadFolder, file.path!), isTrue);
      expect(
        Directory(downloadFolder)
            .listSync(recursive: true)
            .where((entry) => entry.path.endsWith('.part')),
        isEmpty,
      );
      expect(await tester.runAsync(panel.activeConnections), 0);

      // ── Enter on the finished row plays the file: no connection.
      await k.tabTo(row);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await playing(
        (item) => item is PlayableLibraryItem || item == PlayableMovie(movie),
        'the downloaded file',
      );
      expect(coordinator.local, isTrue);
      expect(await tester.runAsync(panel.activeConnections), 0);
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == AppDestination.library.path,
        'the Library again (${app.location})',
      );
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');

      // ── Movies: the download and the film of the user's own. Its
      // page, and Resume, from where it was left.
      final moviesTab = byLabel('Movies, 2');
      await k.waitFor(moviesTab);
      await k.tabTo(moviesTab);
      await k.press(LogicalKeyboardKey.enter);
      const own = 'Paper Kites (2019)';
      await k.waitFor(byLabel(own));
      await k.tabTo(find.byWidgetPredicate((w) => w is TitleGrid));
      for (var i = 0; i < 6 && k.focusedLabel() != own; i++) {
        await k.press(LogicalKeyboardKey.arrowRight);
      }
      expect(k.focusedLabel(), own, reason: 'the film of their own');
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => app.location == '/library/movie/$ownId',
        "the film's page (${app.location})",
      );
      await k.waitFor(find.text('Resume from 1:10'));
      await k.waitUntil(
        () => k.focusedLabel() == 'Resume from 1:10',
        'the focus on Resume (${focusPath()})',
        seconds: 5,
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await playing((item) => item is PlayableLibraryItem, 'the film');
      expect(coordinator.local, isTrue);
      expect(coordinator.startedFrom, const Duration(seconds: 70));
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == '/library/movie/$ownId',
        "the film's page again (${app.location})",
      );
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');

      // ── Its menu: Edit details, a new title, Save.
      final more = byLabel('More');
      await k.tabTo(more);
      await k.press(LogicalKeyboardKey.enter);
      await choose('Edit details…');
      await k.waitFor(find.text('Edit details'));
      await k.replaceText('Paper Kites Redux', into: 'Title');
      await k.tabTo(byLabel('Save'));
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text('Paper Kites Redux'));
      expect(find.byType(AppDialog), findsNothing);
      final edited = (await tester.runAsync(
        () => container.read(libraryRepositoryProvider).item(ownId),
      ))!;
      expect(edited.title, 'Paper Kites Redux');
      expect(edited.edit?.title, 'Paper Kites Redux');

      // ── Its menu: Delete file asks first, with the focus on Keep.
      await k.tabTo(more);
      await k.press(LogicalKeyboardKey.enter);
      await choose('Delete file…');
      await k.waitFor(find.text('Delete "Paper Kites (2019).mp4"?'));
      await k.waitUntil(
        () => k.focusedLabel() == 'Keep',
        'the focus on Keep (${focusPath()})',
        seconds: 5,
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => find.byType(AppDialog).evaluate().isEmpty,
        'the question gone',
      );
      expect(ownFile.existsSync(), isTrue, reason: 'kept');
      expect(app.location, libraryMoviePath(edited));
      expect(
        await tester.runAsync(
          () => container.read(libraryRepositoryProvider).item(ownId),
        ),
        isNotNull,
      );

      // Nothing in a folder of the user's was renamed or changed.
      expect(
        [
          for (final entry in Directory(hdd).listSync(recursive: true))
            p.relative(entry.path, from: hdd),
        ],
        unorderedEquals([
          'Paper Kites (2019)',
          p.join('Paper Kites (2019)', 'Paper Kites (2019).mp4'),
        ]),
      );
      expect(ownFile.lengthSync(), sample.lengthSync());
      expect(failures, isEmpty);
      expect(tester.takeException(), isNull);
    },
    skip: !vodAvailable || binaries == null,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
