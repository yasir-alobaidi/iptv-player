// Phase 5's exit walk, keys only, on the real app, database, sync and
// player against the fake panel: Home → Ctrl+4 Movies → the filter → a
// movie → Play → past a minute → Ctrl+1 Home, where Continue watching has
// it → Ctrl+5 Series → the filter → a series → its episodes → S1 · E2 →
// to its last seconds → the countdown → S1 · E3 plays → Esc → Ctrl+1
// Home, the series first in Continue watching → Enter plays S1 · E3.
//
// The test reads state to check it, and to know how many seek keys get to
// an episode's end; everything it does goes through the keyboard.
//
// Needs the VOD samples vod_h264_aac_10min (the movie, and S1 · E2) and
// vod_h264_ac3_10min (S1 · E3); CI makes 120 s ones.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

/// The fake panel's first series: S1 · E2 is the MP4 sample, S1 · E3 the
/// AC-3 one.
const _firstSeriesId = 200000;

bool get _samples =>
    vodAvailable &&
    File('${samplesDirectory.path}/vod_h264_ac3_10min.mkv').existsSync();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'Home → a movie → Home → an episode → the next one, by keyboard',
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
      addTearDown(() => tester.runAsync(panel.stop));
      final app = (await tester.runAsync(
        () => PanelApp.open(panel, video: video),
      ))!;
      addTearDown(() => tester.runAsync(app.close));

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

      final movie = (await tester.runAsync(
        () => app.container
            .read(movieRepositoryProvider)
            .byRemoteKey(app.sourceId, '$firstMovieId'),
      ))!.valueOrNull!;
      final series = (await tester.runAsync(
        () => app.container
            .read(seriesRepositoryProvider)
            .byRemoteKey(app.sourceId, '$_firstSeriesId'),
      ))!.valueOrNull!;

      Future<void> playing(bool Function(Playable? item) item, String what) =>
          k.waitUntil(
            () =>
                item(coordinator.item) && coordinator.state is PlaybackPlaying,
            '$what playing (${coordinator.state})',
            seconds: 30,
          );

      /// The grid's filter, the title's name typed into it, then Tab into
      /// the grid and → to the title's poster, and Enter.
      Future<void> openFromGrid(String hint, String name) async {
        final filter = find.descendant(
          of: find.byWidgetPredicate((w) => w is SearchField && w.hint == hint),
          matching: find.byType(EditableText),
        );
        await k.waitFor(filter);
        await k.tabTo(filter);
        await k.typeIn(filter, _typed(name));
        await k.waitFor(byLabel(name));
        await k.tabTo(find.byWidgetPredicate((w) => w is TitleGrid));
        for (var i = 0; i < 20 && k.focusedLabel() != name; i++) {
          await k.press(LogicalKeyboardKey.arrowRight);
        }
        expect(k.focusedLabel(), name, reason: 'the poster of "$name"');
        await k.press(LogicalKeyboardKey.enter);
      }

      /// Shift+→ (60 s) and → (10 s) until the playing file is at [target],
      /// or a little past it: the keys rest, then one seek.
      Future<void> seekByKeysTo(Duration target) async {
        var gap = target - coordinator.timeline.position;
        for (
          ;
          gap >= const Duration(seconds: 60);
          gap -= const Duration(seconds: 60)
        ) {
          await k.shift(LogicalKeyboardKey.arrowRight);
        }
        for (
          ;
          gap >= const Duration(seconds: 10);
          gap -= const Duration(seconds: 10)
        ) {
          await k.press(LogicalKeyboardKey.arrowRight);
        }
      }

      // ── Home, first run: the hero.
      await k.waitFor(find.text('Start watching'), seconds: 30);

      // ── Ctrl+4: Movies; the movie through the filter; its page; Play.
      await k.chord(LogicalKeyboardKey.digit4);
      await openFromGrid('Filter movies', movie.name);
      await k.waitUntil(
        () => app.location == movieDetailsPath(movie),
        'the movie page (${app.location})',
      );
      await k.waitFor(find.text('Play'));
      await k.waitUntil(
        () => k.focusedLabel() == 'Play',
        'the focus on Play (${focusPath()})',
        seconds: 5,
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await playing((item) => item == PlayableMovie(movie), 'the movie');

      // ── Past a minute: Shift+→ and →.
      await k.shift(LogicalKeyboardKey.arrowRight);
      await k.press(LogicalKeyboardKey.arrowRight);
      await k.waitUntil(
        () => coordinator.timeline.position >= const Duration(seconds: 70),
        'the movie past 70 s (${coordinator.timeline.position})',
        seconds: 30,
      );

      // ── Ctrl+1 from the player: Home, nothing playing, and the movie in
      // Continue watching, where the focus lands.
      await k.chord(LogicalKeyboardKey.digit1);
      await k.waitUntil(() => app.location == '/', 'Home');
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');
      await k.waitFor(find.text('Continue watching'));
      expect(find.text('Start watching'), findsNothing);
      expect(_continueCard(tester, movie.name).subtitle, startsWith('Movie'));
      await k.waitUntil(
        () => k.focusedLabel() == movie.name,
        'the focus on its card (${focusPath()})',
        seconds: 5,
      );

      // ── Ctrl+5: Series; the series through the filter; its page.
      await k.chord(LogicalKeyboardKey.digit5);
      await openFromGrid('Filter series', series.name);
      await k.waitUntil(
        () => app.location == seriesDetailsPath(series),
        'the series page (${app.location})',
      );

      // ── Its episodes: one Tab stop, on S1 · E1 (nothing watched); ↓ to
      // E2, Enter.
      final anEpisode = find.byWidgetPredicate(
        (w) =>
            w is FocusableSurface &&
            (w.semanticLabel?.startsWith('Episode ') ?? false),
      );
      await k.waitFor(anEpisode, seconds: 30);
      await k.tabTo(anEpisode);
      expect(k.focusedLabel(), startsWith('Episode 1, '));
      await k.press(LogicalKeyboardKey.arrowDown);
      expect(k.focusedLabel(), startsWith('Episode 2, '));
      await k.press(LogicalKeyboardKey.enter);
      bool isEpisode(Playable? item, int number) =>
          item is PlayableEpisode &&
          item.series.remoteKey == series.remoteKey &&
          item.episode.season == 1 &&
          item.episode.episode == number;
      await playing((item) => isEpisode(item, 2), 'S1 · E2');
      final e2Length = coordinator.timeline.duration!;

      // ── To its last 25 s by keys: the card counts down, and S1 · E3
      // plays on its own.
      await seekByKeysTo(e2Length - const Duration(seconds: 25));
      await k.waitFor(find.text('NEXT EPISODE'), seconds: 40);
      expect(find.textContaining('Play now · '), findsOneWidget);
      await playing((item) => isEpisode(item, 3), 'S1 · E3 after the count');
      expect(find.text('NEXT EPISODE'), findsNothing);

      // ── Esc: the series page. Ctrl+1: Home, with the series first in
      // Continue watching and the movie after it.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == seriesDetailsPath(series),
        'the series page again (${app.location})',
      );
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');
      await k.chord(LogicalKeyboardKey.digit1);
      await k.waitUntil(() => app.location == '/', 'Home again');
      await k.waitUntil(
        () => find
            .byWidgetPredicate(
              (w) => w is LandscapeCard && w.title == series.name,
            )
            .evaluate()
            .isNotEmpty,
        'the series in Continue watching',
      );
      expect(
        _continueCard(tester, series.name).subtitle,
        startsWith('S1 · E3'),
      );
      final cards = tester
          .widgetList<LandscapeCard>(find.byType(LandscapeCard))
          .map((c) => c.title)
          .toList();
      expect(cards.take(2), [series.name, movie.name]);

      // ── Enter on it: S1 · E3 again.
      await k.waitUntil(
        () => k.focusedLabel() == series.name,
        'the focus on the series card (${focusPath()})',
        seconds: 5,
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await playing((item) => isEpisode(item, 3), 'S1 · E3 from Home');

      // ── Esc: Home, nothing playing, the panel's slot free.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(() => app.location == '/', 'Home at the end');
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');
      await k.waitUntil(
        () async => await panel.activeConnections() == 0,
        'the panel to see the connection closed',
      );
      expect(tester.takeException(), isNull);
    },
    skip: !_samples,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// What a person types to find [name]: its first words, up to the year or
/// the first odd character; the grid's filter matches any part of a name.
String _typed(String name) =>
    RegExp("^[A-Za-z' ]+").firstMatch(name)?[0]?.trim() ?? name;

LandscapeCard _continueCard(WidgetTester tester, String title) =>
    tester.widget<LandscapeCard>(
      find.byWidgetPredicate((w) => w is LandscapeCard && w.title == title),
    );
