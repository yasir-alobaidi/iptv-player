// Phase 5 step 6 end to end: the real app, database, sync and player
// (media_kit) against the fake panel's movie and episode files, with the
// keyboard where a viewer would use it.
//
// A movie: Play → the keys seek past a minute → Esc: its page offers
// Resume from where it was left → Resume opens there ("Resumed from") →
// Start over opens at 0 → a connection dropped mid-movie comes back where
// it was → the end of the file: back on its page, watched.
//
// An episode: at 20 s left the card counts down and the next episode
// plays → on that one, Esc cancels the count: it plays to its end and the
// card is back without the count → Esc: back on the series page.
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
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

/// The fake panel's first series: S1 · E2 is the MP4 sample, S1 · E3 the
/// AC-3 one (the panel picks by series, season and episode).
const _firstSeriesId = 200000;

bool get _samples =>
    vodAvailable &&
    File('${samplesDirectory.path}/vod_h264_ac3_10min.mkv').existsSync();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'a movie and an episode in the player: resume, progress, the end, a '
    'drop, and the next episode',
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
      final router = app.container.read(routerProvider);
      final progress = app.container.read(watchProgressProvider);
      final states = <PlaybackState>[];
      final listening = coordinator.states.listen(states.add);
      addTearDown(listening.cancel);

      Future<WatchMark?> markOf(VodRef ref) =>
          tester.runAsync<WatchMark?>(() => progress.watch(ref).first);

      Future<void> playing(Playable item, String what) => k.waitUntil(
        () => coordinator.item == item && coordinator.state is PlaybackPlaying,
        '$what playing (${coordinator.state})',
        seconds: 30,
      );

      Future<void> at(Duration position, String what) => k.waitUntil(
        () => coordinator.timeline.position >= position,
        '$what (at ${coordinator.timeline.position})',
        seconds: 40,
      );

      final movie = (await tester.runAsync(
        () => app.container
            .read(movieRepositoryProvider)
            .byRemoteKey(app.sourceId, '$firstMovieId'),
      ))!.valueOrNull!;
      final film = PlayableMovie(movie);

      // ── Its page: nothing watched, so Play, with the focus on it.
      router.go(movieDetailsPath(movie));
      await k.waitFor(find.text('Play'));
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      expect(app.location, playerRoutePath);
      await playing(film, 'the movie');
      final length = coordinator.timeline.duration!;
      expect(length, greaterThan(const Duration(seconds: 90)));
      expect(coordinator.startedFrom, isNull);

      // ── The keys: Shift+→ 60 s and → 10 s, one seek once they rest.
      await k.shift(LogicalKeyboardKey.arrowRight);
      await k.press(LogicalKeyboardKey.arrowRight);
      await at(const Duration(seconds: 70), 'past a minute after the seek');

      // ── Esc: back on its page, which offers Resume from where it was.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == movieDetailsPath(movie),
        'the movie page again',
      );
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');
      final left = (await markOf(movie.ref))!;
      expect(left.position, greaterThanOrEqualTo(const Duration(seconds: 70)));
      expect(left.duration, length);
      expect(left.resumable, isTrue);
      await k.waitFor(find.textContaining('Resume from'));
      await k.waitUntil(
        () async => await panel.activeConnections() == 0,
        'the panel to see the connection closed',
      );

      // ── Resume: one open that starts where it was left.
      await k.press(LogicalKeyboardKey.enter);
      await playing(film, 'the movie, resumed');
      expect(coordinator.startedFrom, left.position);
      expect(
        coordinator.timeline.position,
        greaterThanOrEqualTo(left.position - const Duration(seconds: 2)),
      );
      await k.waitFor(find.textContaining('Resumed from'));
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');

      // ── Start over: from the beginning.
      await k.waitFor(find.text('Start over'));
      await k.tabTo(byLabel('Start over'));
      await k.press(LogicalKeyboardKey.enter);
      await playing(film, 'the movie from the start');
      expect(coordinator.startedFrom, isNull);
      expect(
        coordinator.timeline.position,
        lessThan(const Duration(seconds: 15)),
      );
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');

      // ── A drop: the panel closes the connection half-way through the
      // file; the movie carries on past it. (mpv's own reconnect usually
      // absorbs it; the coordinator's, back where it was, is the fallback.)
      final size = File('${samplesDirectory.path}/vod_h264_aac_10min.mp4')
          .lengthSync();
      await tester.runAsync(
        () => panel.setFaults({'drop_after_bytes': size ~/ 2}),
      );
      states.clear();
      await tester.runAsync(
        () => app.container
            .read(vodLauncherProvider)
            .playMovie(movie, from: length * 0.5 - const Duration(seconds: 8)),
      );
      await playing(film, 'the movie before the drop');
      await at(length * 0.5 + const Duration(seconds: 8), 'past the drop');
      expect(coordinator.item, film);
      expect(states.whereType<PlaybackFailed>(), isEmpty);
      await tester.runAsync(() => panel.setFaults(const {}));

      // ── The end: Shift+→ to the end of the file, then back on its page,
      // watched.
      for (var i = 0; i < 12; i++) {
        await k.shift(LogicalKeyboardKey.arrowRight);
      }
      await k.waitUntil(
        () => app.location == movieDetailsPath(movie),
        'the movie page after its end (${coordinator.state})',
        seconds: 40,
      );
      final watched = (await markOf(movie.ref))!;
      expect(watched.completed, isTrue);
      expect(coordinator.state, isNot(isA<PlaybackPlaying>()));

      // ── An episode: its series' page fetches the episodes.
      final series = (await tester.runAsync(
        () => app.container
            .read(seriesRepositoryProvider)
            .byRemoteKey(app.sourceId, '$_firstSeriesId'),
      ))!.valueOrNull!;
      router.go(seriesDetailsPath(series));
      final details =
          (await tester.runAsync(
                () => app.container
                    .read(seriesRepositoryProvider)
                    .details(series)
                    .firstWhere((d) => d is DetailsReady<SeriesDetails>),
              ))!
              as DetailsReady<SeriesDetails>;
      final season = details.value.seasons.firstWhere((s) => s.number == 1);
      final e2 = season.episodes.firstWhere((e) => e.episode == 2);
      final e3 = season.episodes.firstWhere((e) => e.episode == 3);

      await tester.runAsync(
        () => app.container.read(vodLauncherProvider).playEpisode(series, e2),
      );
      await playing(PlayableEpisode(series, e2), 'S1 · E2');
      final e2Length = coordinator.timeline.duration!;

      // ── Its last 25 s: the card counts, then S1 · E3 plays on its own.
      await tester.runAsync(
        () => coordinator.seek(e2Length - const Duration(seconds: 25)),
      );
      await k.waitFor(find.text('NEXT EPISODE'), seconds: 30);
      expect(find.textContaining('Play now · '), findsOneWidget);
      await playing(PlayableEpisode(series, e3), 'S1 · E3 after the count');
      expect(find.text('NEXT EPISODE'), findsNothing);

      // ── S1 · E3's last seconds: Esc cancels the count; it plays to its
      // end; the card is back without the count.
      final e3Length = coordinator.timeline.duration!;
      await tester.runAsync(
        () => coordinator.seek(e3Length - const Duration(seconds: 18)),
      );
      await k.waitFor(find.textContaining('Play now · '), seconds: 30);
      await k.press(LogicalKeyboardKey.escape);
      expect(find.text('NEXT EPISODE'), findsNothing);
      expect(app.location, playerRoutePath);
      await k.waitUntil(
        () => coordinator.state is PlaybackEnded,
        'S1 · E3 to end (${coordinator.state})',
        seconds: 40,
      );
      await k.waitFor(find.text('Play next episode'));
      expect(find.text('Back to series'), findsOneWidget);
      expect((await markOf(e3.ref))!.completed, isTrue);

      // ── Esc: back on the series page; nothing plays.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == seriesDetailsPath(series),
        'the series page',
      );
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
