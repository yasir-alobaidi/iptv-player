// Phase 8 step 8: the scanner end to end on the real app — its database,
// the library's scans (the guarded job, ffprobe, the frame grabbed for a
// picture), the Library's pages and the player (media_kit) — on a folder
// of the user's own, keys only:
//
// Ctrl+7: the Library, with nothing in it → Add folder: the system's
// dialog, answered here with the folder → the scan: each video read by
// ffprobe; a text file and a clip too small to be a film left out →
// Movies: the film, named by its folder, with what ffprobe read in it
// and the subtitle file beside it → Play: its file, no connection →
// past a minute → Esc: its page offers Resume from there → Enter: it
// plays on from there → Esc → Series: the show its episode's name made.
//
// The other walks write their library rows themselves; this one doesn't
// touch the database. The user's folder is the same before and after
// (hard rule 11). Needs FFmpeg (bundled, else the system's) and the VOD
// sample vod_h264_aac_10min (CI makes a 120 s one).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_folders.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:path/path.dart' as p;

import 'support/cast_tv.dart';
import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

const _subtitles = '''
1
00:00:01,000 --> 00:00:30,000
The ferry is late again.
''';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';
  final binaries = castBinaries();
  final sample = File('${samplesDirectory.path}/vod_h264_aac_10min.mp4');

  testWidgets(
    'Add folder → the scan finds a film and a show → the film plays from '
    'its file → Resume from where it was left',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      final temp = Directory.systemTemp.createTempSync('iptv_library_scan');
      addTearDown(() => temp.deleteSync(recursive: true));

      // The user's folder: a film with its subtitle file, an episode of a
      // show, and two things that aren't videos of theirs.
      final hdd = p.join(temp.path, 'Movies HDD');
      const film = 'Paper Kites (2019)/Paper Kites (2019).mp4';
      const episode = 'Tide Line/Season 1/Tide Line - S01E02 - The Ferry.mp4';
      for (final rel in [film, episode]) {
        final file = File(p.joinAll([hdd, ...rel.split('/')]));
        file.parent.createSync(recursive: true);
        sample.copySync(file.path);
      }
      File(p.join(hdd, 'Paper Kites (2019)', 'Paper Kites (2019).en.srt'))
          .writeAsStringSync(_subtitles);
      File(p.join(hdd, 'notes.txt')).writeAsStringSync('Not a video.');
      File(p.join(hdd, 'Intro.mp4')).writeAsBytesSync(List.filled(4096, 0));
      Map<String, int> listing() => {
        for (final entity in Directory(hdd).listSync(recursive: true))
          if (entity is File)
            p.relative(entity.path, from: hdd): entity.lengthSync(),
      };
      final before = listing();

      final panel = (await tester.runAsync(FakePanel.start))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final app = (await tester.runAsync(
        () => PanelApp.open(
          panel,
          video: video,
          overrides: [
            // The system's folder dialog, answered with the folder.
            folderPickerProvider.overrideWithValue(() async => hdd),
            // Never the user's own Videos folder.
            systemVideosProvider.overrideWith(
              (ref) async => p.join(temp.path, 'Videos'),
            ),
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
      // What `bootstrap()` does after launch: the library's scans start.
      await tester.runAsync(
        () => container.read(libraryScansProvider).startUp(),
      );
      final coordinator = container.read(playbackCoordinatorProvider);
      final library = container.read(libraryRepositoryProvider);

      // ── Ctrl+7: the Library, with nothing in it yet. Add folder.
      await k.waitFor(find.text('Start watching'), seconds: 30);
      await k.chord(LogicalKeyboardKey.digit7);
      final add = byLabel('Add folder');
      await k.waitFor(add);
      await k.tabTo(add.first);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(
        find.text('Added Movies HDD. Its videos appear as it is scanned.'),
      );

      // ── The scan: the film and the episode; nothing else.
      await k.waitFor(byLabel('Movies, 1'), seconds: 60);
      await k.waitFor(byLabel('Series, 1'), seconds: 60);
      final folder = (await tester.runAsync(
        () => library.watchFolders().first,
      ))!.singleWhere((f) => f.path == hdd);
      expect(folder.label, 'Movies HDD');

      // ── Movies → the film, named by its folder → Enter: its page says
      // what ffprobe read in it, and its subtitle file.
      final moviesTab = byLabel('Movies, 1');
      await k.tabTo(moviesTab);
      await k.press(LogicalKeyboardKey.enter);
      const own = 'Paper Kites (2019)';
      await k.waitFor(byLabel(own));
      await k.tabTo(find.byWidgetPredicate((w) => w is TitleGrid));
      for (var i = 0; i < 6 && k.focusedLabel() != own; i++) {
        await k.press(LogicalKeyboardKey.arrowRight);
      }
      expect(k.focusedLabel(), own);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => app.location.startsWith('/library/movie/'),
        "the film's page (${app.location})",
      );
      final id = int.parse(app.location.split('/').last);
      final item = (await tester.runAsync(() => library.item(id)))!;
      expect(item.kind, LibraryKind.movie);
      expect(item.title, 'Paper Kites');
      expect(item.year, 2019);
      expect(item.media?.video?.codec, 'h264');
      expect(item.media?.audio.single.codec, 'aac');
      expect(item.duration, isNotNull);
      expect(item.subtitles.single.language, 'en');
      await k.waitFor(find.textContaining('H.264'));
      await k.waitFor(find.textContaining('Subtitles: English'));
      await k.waitUntil(
        () => k.focusedLabel() == 'Play',
        'the focus on Play (${focusPath()})',
        seconds: 5,
      );

      // ── Play: its file, with no connection to anything.
      Future<void> playing(String what) => k.waitUntil(
        () =>
            coordinator.item is PlayableLibraryItem &&
            coordinator.state is PlaybackPlaying,
        '$what (${coordinator.state})',
        seconds: 30,
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await playing('the film playing');
      expect(coordinator.local, isTrue);
      expect(await tester.runAsync(panel.activeConnections), 0);

      // ── Past a minute, then Esc: its page offers Resume from there.
      await k.shift(LogicalKeyboardKey.arrowRight);
      await k.press(LogicalKeyboardKey.arrowRight);
      await k.waitUntil(
        () => coordinator.timeline.position >= const Duration(seconds: 70),
        'the film past a minute (at ${coordinator.timeline.position})',
        seconds: 40,
      );
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == '/library/movie/$id',
        "the film's page again (${app.location})",
      );
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');
      await k.waitFor(find.textContaining('Resume from 1:'));
      await k.waitUntil(
        () => k.focusedLabel()?.startsWith('Resume from 1:') ?? false,
        'the focus on Resume (${focusPath()})',
        seconds: 5,
      );

      // ── Enter: it plays on from there.
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await playing('the film playing again');
      expect(
        coordinator.startedFrom,
        greaterThanOrEqualTo(const Duration(seconds: 60)),
      );
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');

      // ── The show its episode's name made.
      final shows = (await tester.runAsync(() => library.watchShows().first))!;
      expect(shows.single.title, 'Tide Line');
      expect(shows.single.episodes, 1);

      // Nothing in the user's folder was touched, and no FFmpeg is left.
      expect(listing(), before);
      await k.waitUntil(
        () => runningProcesses(temp).isEmpty,
        'no ffprobe or FFmpeg left (${runningProcesses(temp)})',
      );
    },
    skip: binaries == null || !sample.existsSync(),
  );
}
