// Phase 8 step 7's walk, keys only, on the real app — its database, the
// Library's pages, the cast coordinator, the relay with FFmpeg, our Cast
// client — with a film of the user's own (a Matroska file with AC-3
// sound and an English subtitle file beside it) and the fake TV
// (tools/fake_receiver), which fetches and checks what it is sent as a TV
// does. The provider is never asked for anything.
//
// Ctrl+6: the Library → Movies → the film → Enter: its page → C: the
// picker → Add device by IP address → the fake TV → Enter on it: the film
// plays on the TV through the relay, its subtitle file read by the TV as
// WebVTT and showing → S: off → S: on again → → three times: the relay
// starts again 30 s on → the MP4 made beside the relay is whole → → three
// times: the TV loads the MP4 and the relay stops (a short film's MP4 is
// whole before the first →: the TV loads it there) → →: the TV's own seek,
// no new LOAD → Stop casting: the film's place kept, the TV gone home, no
// FFmpeg and none of the cast's files left, the film's page offering
// Resume.
//
// The test reads state to check it; everything it does goes through the
// keyboard. The library's row is written here (the scanner's run end to
// end is step 8's test). Needs FFmpeg (bundled, else the system's) and
// the sample vod_h264_ac3_10min with its .en.srt (CI makes 120 s ones).

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/add_cast_device_dialog.dart';
import 'package:iptv_player/features/casting/presentation/cast_shell_slots.dart';
import 'package:iptv_player/features/casting/presentation/casting_view.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:path/path.dart' as p;

import 'support/cast_tv.dart';
import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

const _film = 'vod_h264_ac3_10min.mkv';
const _words = 'vod_h264_ac3_10min.en.srt';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';
  final binaries = castBinaries();
  final sample = File(p.join(samplesDirectory.path, _film));
  final words = File(p.join(samplesDirectory.path, _words));

  testWidgets(
    'a film of your own cast from the Library: through the relay with its '
    'subtitles, then its MP4 and seeks of the TV, then Stop casting',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      final folder = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('iptv_library_cast'),
      ))!;
      addTearDown(() => tester.runAsync(() => folder.delete(recursive: true)));
      final panel = (await tester.runAsync(FakePanel.start))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final tv = (await tester.runAsync(
        () => FakeReceiver.start(
          playback: FakePlayback(ffprobe: binaries!.ffprobe),
        ),
      ))!;
      addTearDown(() => tester.runAsync(tv.close));
      final app = (await tester.runAsync(
        () => PanelApp.open(
          panel,
          video: video,
          overrides: castOverrides(binaries!, folder),
        ),
      ))!;
      addTearDown(() => tester.runAsync(app.close));
      // As `bootstrap()` does: the cast's notices as toasts.
      final container = app.container..read(castNoticeToastsProvider);

      // The film of the user's own, with its subtitle file beside it.
      final hdd = p.join(folder.path, 'Movies HDD');
      const rel = 'Paper Kites (2019)/Paper Kites (2019).mkv';
      final film = File(p.joinAll([hdd, ...rel.split('/')]));
      final filmId = (await tester.runAsync(() async {
        film.parent.createSync(recursive: true);
        sample.copySync(film.path);
        words.copySync(p.join(film.parent.path, 'Paper Kites (2019).en.srt'));
        final now = DateTime.now().toUtc();
        final own = await app.db.libraryDao.addFolder(
          path: hdd,
          label: 'Movies HDD',
          at: now,
        );
        return await app.db.libraryDao.insertItem(
          LibraryItemsCompanion.insert(
            folderId: own,
            relPath: rel,
            sizeBytes: film.lengthSync(),
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
          container: container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      final k = Keys(tester)..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final playback = container.read(playbackCoordinatorProvider);
      final cast = container.read(castCoordinatorProvider);
      Future<bool> tvPlaying({int after = 0}) async =>
          cast.state.phase == CastPhase.playing &&
          tv.playerState == 'PLAYING' &&
          tv.checks.length > after;
      String? loaded() => tv.loaded?['contentId'] as String?;
      List<FileSystemEntity> castFiles() {
        final run = Directory(p.join(folder.path, 'relay', '$pid'));
        return run.existsSync() ? run.listSync(recursive: true) : const [];
      }

      // ── Ctrl+6: the Library; Movies; the film; Enter: its page.
      await k.waitFor(find.text('Start watching'), seconds: 30);
      await k.chord(LogicalKeyboardKey.digit6);
      final moviesTab = byLabel('Movies, 1');
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
        () => app.location == '/library/movie/$filmId',
        "the film's page (${app.location})",
      );
      await k.waitUntil(
        () => k.focusedLabel() == 'Play',
        'the focus on Play (${focusPath()})',
        seconds: 5,
      );

      // ── C: the picker. Add device by IP address, the fake TV's.
      await k.press(LogicalKeyboardKey.keyC);
      await k.waitFor(find.text('Cast to a device'));
      await k.tabTo(find.text('Add device by IP address'));
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text('Add a device by address'));
      await k.typeIn(
        find.descendant(
          of: find.byType(AddCastDeviceDialog),
          matching: find.byType(EditableText),
        ),
        '127.0.0.1:${tv.port}',
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => find.byType(AddCastDeviceDialog).evaluate().isEmpty,
        'the device added',
        seconds: 30,
      );

      // ── Enter on it: the film on the TV, through the relay; the view.
      final fakeTv = find.byWidgetPredicate(
        (widget) =>
            widget is FocusableSurface &&
            (widget.semanticLabel?.startsWith('Fake TV') ?? false),
        description: 'the Fake TV row',
      );
      await k.waitFor(fakeTv, seconds: 30);
      await k.tabTo(fakeTv, back: true);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(CastingView));
      await k.waitUntil(
        tvPlaying,
        'the TV playing (${cast.state}, ${tv.playerState})',
        seconds: 60,
      );
      expect(cast.state.item, isA<PlayableLibraryItem>());
      expect(cast.state.plan!.delivery, CastDelivery.relayContinuous);
      expect(tv.checks.last.videoCodec, 'h264');
      expect(tv.checks.last.audioCodec, 'aac');
      expect(Uri.parse(loaded()!).path, startsWith('/p/'));
      expect(find.text('PLAYING ON FAKE TV'), findsOneWidget);
      expect(playback.state, isA<PlaybackCasting>());

      // Its subtitle file, read by the TV as WebVTT, showing from the
      // start: a file beside the video.
      await k.waitUntil(
        () => tv.textTracks.length == 1,
        'the subtitle read by the TV (${tv.textTracks})',
      );
      expect(tv.textTracks.single.problem, isNull);
      expect(tv.textTracks.single.language, 'en');
      expect(tv.textTracks.single.firstCue, Duration.zero);
      expect(tv.activeTrackIds, [1]);
      await k.waitFor(find.text('Subtitles: English'));

      // ── S: off. S: on again.
      await k.press(LogicalKeyboardKey.keyS);
      await k.waitUntil(
        () => tv.activeTrackIds.isEmpty,
        'the subtitles off on the TV (${tv.activeTrackIds})',
      );
      await k.waitFor(find.text('Subtitles: off'));
      await k.press(LogicalKeyboardKey.keyS);
      await k.waitUntil(
        () => tv.activeTrackIds.length == 1,
        'the subtitles on again (${tv.activeTrackIds})',
      );
      await k.waitFor(find.text('Subtitles: English'));
      expect(tv.requests('LOAD'), hasLength(1), reason: 'no LOAD for S');

      // ── → three times: 30 s on. Through the relay again (at the key
      // frame before it) while the MP4 is still being made; on the MP4
      // itself when a short film's is whole by now (CI's sample is two
      // minutes long, and its MP4 takes a second or two).
      Future<void> forward(int presses) async {
        for (var i = 0; i < presses; i++) {
          await k.press(LogicalKeyboardKey.arrowRight);
        }
      }

      bool onMp4() => loaded()?.endsWith('/media.mp4') ?? false;
      final relayed = loaded();
      await forward(3);
      await k.waitUntil(
        () async =>
            loaded() != relayed &&
            loaded() != null &&
            cast.timeline.position >= const Duration(seconds: 25) &&
            await tvPlaying(),
        'the film on from 0:30 (${loaded()}, ${cast.timeline.position})',
        seconds: 40,
      );

      if (!onMp4()) {
        expect(Uri.parse(loaded()!).path, startsWith('/p/'));
        expect(tv.activeTrackIds, [1], reason: 'the choice is kept');

        // ── The MP4 made beside the relay: whole after a while. Nothing
        // is interrupted for it.
        final again = loaded();
        await k.waitUntil(
          () => castFiles().any((file) => file.path.endsWith('media.mp4')),
          'the MP4 made beside the relay',
          seconds: 240,
        );
        expect(loaded(), again);

        // ── → three times: the TV loads the MP4 there, and the relay
        // stops.
        final before = cast.timeline.position;
        await forward(3);
        await k.waitUntil(
          () async => onMp4() && await tvPlaying(),
          'the MP4 on the TV (${loaded()}, ${cast.state.phase.name})',
          seconds: 40,
        );
        expect(
          cast.timeline.position,
          greaterThanOrEqualTo(before + const Duration(seconds: 25)),
        );
      }
      await k.waitUntil(
        () => runningProcesses(folder).isEmpty,
        'no FFmpeg left (${runningProcesses(folder)})',
      );
      await k.waitUntil(
        () => tv.textTracks.length == 1 && tv.activeTrackIds.length == 1,
        'the subtitle with the MP4 (${tv.textTracks})',
      );
      expect(tv.textTracks.single.firstCue, Duration.zero);

      // ── →: the TV's own seek. No new LOAD, no FFmpeg.
      final loads = tv.requests('LOAD').length;
      await forward(1);
      await k.waitUntil(
        () => tv.requests('SEEK').length == 1,
        "the TV's own seek",
      );
      expect(tv.requests('LOAD'), hasLength(loads));
      expect(runningProcesses(folder), isEmpty);
      await k.waitUntil(tvPlaying, 'playing after the seek');
      expect(await tester.runAsync(panel.activeConnections), 0);

      // ── Tab to Stop casting, in the view: the film's place is kept,
      // and nothing of the cast is left.
      final reached = cast.timeline.position;
      for (var i = 0; i < 12 && k.focusedLabel() != 'Stop casting'; i++) {
        await k.press(LogicalKeyboardKey.tab);
      }
      expect(k.focusedLabel(), 'Stop casting');
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => cast.state.phase == CastPhase.off,
        'casting stopped (${cast.state})',
      );
      final item = (await tester.runAsync(
        () => container.read(libraryRepositoryProvider).item(filmId),
      ))!;
      final mark = (await tester.runAsync(
        () => container
            .read(watchProgressProvider)
            .watch(PlayableLibraryItem(item).vodRef)
            .first,
      ))!;
      expect(
        mark.position,
        greaterThanOrEqualTo(reached - const Duration(seconds: 5)),
      );
      expect(find.byType(CastingView), findsNothing);
      await k.waitUntil(() => tv.app == null, 'the TV gone home');
      await k.waitUntil(
        () => runningProcesses(folder).isEmpty && castFiles().isEmpty,
        "none of the cast's files left (${castFiles()})",
      );
      expect(playback.state, isA<PlaybackIdle>(), reason: 'nothing here');
      expect(app.location, '/library/movie/$filmId');
      await k.waitFor(find.textContaining('Resume from'));
      expect(await tester.runAsync(panel.activeConnections), 0);
    },
    skip: binaries == null || !sample.existsSync() || !words.existsSync(),
  );
}
