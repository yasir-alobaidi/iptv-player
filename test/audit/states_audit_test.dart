import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_system_ui.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:iptv_player/features/vod/data/db_movie_repository.dart';
import 'package:iptv_player/features/vod/data/db_series_repository.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

import '../app/app_harness.dart';
import '../features/casting/support/cast_ui_harness.dart';
import '../features/home/home_fakes.dart';
import '../features/live_tv/live_tv_fakes.dart';
import '../features/onboarding/onboarding_fakes.dart';
import '../features/playback/support/system_ui_fakes.dart';
import '../features/playback/support/vod_player_rig.dart';
import '../features/vod/vod_fakes.dart';
import 'audit_harness.dart';

/// The screens and the states no golden draws, in the audit (Phase 9
/// decision 14): with no source, offline, a movie's and a series' page
/// and what they say when their details can't be had, Connect, Sync, and
/// Settings → Casting. ADR-016 has the table of every screen by state and
/// where each is drawn.
void main() {
  const movie = XtreamMovieInfo(
    plot: 'A storm strands a ferry in a small fishing town.',
    cast: 'Tomas Lind, Mara Okafor',
    director: 'Ana Ribeiro',
    genre: 'Drama, Mystery',
    runtimeMinutes: 118,
    videoHeight: 1080,
    audioChannels: 6,
  );
  const series = XtreamSeriesInfo(
    plot: 'A harbor inspector follows the tide logs.',
    genre: 'Thriller',
    episodes: [
      XtreamEpisode(
        id: '7101',
        season: 1,
        episode: 1,
        title: 'Low Water',
        durationSeconds: 3120,
      ),
      XtreamEpisode(
        id: '7102',
        season: 1,
        episode: 2,
        title: 'Ledger',
        durationSeconds: 2880,
        plot: 'The missing pages turn up aboard the Meridian.',
      ),
      XtreamEpisode(
        id: '7201',
        season: 2,
        episode: 1,
        title: 'Undertow',
        durationSeconds: 3000,
      ),
    ],
  );

  final offline = appOfflineProvider.overrideWith((ref) => Stream.value(true));

  // ---------------------------------------------------------- no source
  auditScreen('with no source', [
    for (final destination in AppDestination.values)
      AuditScene(
        destination.label,
        // A phone has no Library (ADR-068).
        phone: destination != AppDestination.library,
        (tester, look) async {
          await pumpApp(
            tester,
            size: look.size,
            initialLocation: destination.path,
            overrides: emptyLibraryOverrides,
          );
        },
      ),
  ]);

  // ------------------------------------------------- movies and series
  Future<VodFakes> catalogue(
    WidgetTester tester,
    AuditLook look,
    String location, {
    void Function(VodFakes vod)? answers,
    bool isOffline = false,
  }) async {
    final vod = VodFakes();
    addTearDown(() => tester.runAsync(vod.db.close));
    await tester.runAsync(vod.seed);
    vod.details
      ..movieAnswer = const Ok(movie)
      ..seriesAnswer = const Ok(series);
    answers?.call(vod);
    await pumpApp(
      tester,
      size: look.size,
      initialLocation: location,
      overrides: [
        ...vod.overrides,
        ...sourceShellOverrides,
        if (isOffline) offline,
      ],
    );
    return vod;
  }

  auditScreen("a movie's page", [
    AuditScene(
      'its details',
      (tester, look) => catalogue(tester, look, '/movies/src-1/501'),
    ),
    AuditScene(
      "details that can't be fetched",
      (tester, look) => catalogue(
        tester,
        look,
        '/movies/src-1/501',
        answers: (vod) =>
            vod.details.movieAnswer = Err(NetworkFailure('offline')),
      ),
    ),
    AuditScene(
      'a provider with no plot',
      (tester, look) => catalogue(
        tester,
        look,
        '/movies/src-1/501',
        answers: (vod) => vod.details.movieAnswer = const Ok(XtreamMovieInfo()),
      ),
    ),
  ]);

  auditScreen("a series' page", [
    AuditScene(
      'its seasons and episodes',
      (tester, look) => catalogue(tester, look, '/series/src-1/77'),
    ),
    AuditScene(
      "episodes that can't be fetched",
      (tester, look) => catalogue(
        tester,
        look,
        '/series/src-1/77',
        answers: (vod) =>
            vod.details.seriesAnswer = Err(NetworkFailure('offline')),
      ),
    ),
    AuditScene(
      'no episodes',
      (tester, look) => catalogue(
        tester,
        look,
        '/series/src-1/77',
        answers: (vod) =>
            vod.details.seriesAnswer = const Ok(XtreamSeriesInfo()),
      ),
    ),
  ]);

  // ------------------------------------------------------------ offline
  auditScreen('offline', [
    AuditScene(
      'Movies',
      (tester, look) =>
          catalogue(tester, look, AppDestination.movies.path, isOffline: true),
    ),
    AuditScene(
      'Series',
      (tester, look) =>
          catalogue(tester, look, AppDestination.series.path, isOffline: true),
    ),
    () {
      late LiveTvFakes live;
      return AuditScene(
        'Live TV',
        (tester, look) async {
          live = LiveTvFakes();
          addTearDown(() => tester.runAsync(live.db.close));
          await tester.runAsync(live.seed);
          await pumpApp(
            tester,
            size: look.size,
            initialLocation: AppDestination.liveTv.path,
            overrides: [...live.overrides, ...sourceShellOverrides, offline],
          );
        },
        // The keyboard's walk through the list starts the preview.
        close: (tester) async {
          await live.rig.coordinator.stop();
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    }(),
    for (final destination in [
      AppDestination.home,
      AppDestination.favorites,
      AppDestination.library,
      AppDestination.settings,
    ])
      AuditScene(
        '${destination.label}, with no source',
        phone: destination != AppDestination.library,
        (tester, look) async {
          await pumpApp(
            tester,
            size: look.size,
            initialLocation: destination.path,
            overrides: [...emptyLibraryOverrides, offline],
          );
        },
      ),
  ]);

  // --------------------------------------------------------- onboarding
  auditScreen('Connect', [
    AuditScene('the form', (tester, look) async {
      await pumpApp(
        tester,
        size: look.size,
        initialLocation: addSourceRoutePath,
        overrides: OnboardingFakes().overrides,
      );
    }),
  ]);

  Future<void> sync(
    WidgetTester tester,
    AuditLook look,
    SyncStatus status,
  ) async {
    final fakes = OnboardingFakes();
    fakes.sources.seed();
    fakes.sync.emit('src-1', status);
    await pumpApp(
      tester,
      size: look.size,
      initialLocation: sourceSyncPath('src-1'),
      overrides: fakes.overrides,
    );
  }

  auditScreen('Sync', [
    AuditScene(
      'running',
      (tester, look) => sync(
        tester,
        look,
        const SyncRunning(
          SyncProgress(
            stage: SyncStage.movies,
            categories: 549,
            channels: 12340,
            movies: 8021,
            stageTotal: 13800,
          ),
        ),
      ),
      // The bar of a sync that runs is the one thing that moves.
      allow: const {
        'still moving with reduce motion': 'a running sync shows it runs',
      },
    ),
    AuditScene(
      'failed',
      (tester, look) =>
          sync(tester, look, SyncFailed(NetworkFailure('no route to host'))),
    ),
  ]);

  // ------------------------------------------------------- a first sync
  // A source's first sync still filling the screens: the loading stage,
  // in Live TV's channel list at its narrowest too.
  const running = SyncRunning(
    SyncProgress(stage: SyncStage.live, channels: 12340, stageTotal: 20000),
  );
  auditScreen('a first sync', [
    AuditScene('Live TV', (tester, look) async {
      final live = LiveTvFakes();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(() async {
        await live.seed();
        await live.db.customStatement('DELETE FROM channels');
      });
      live.fakes.sync.emit('src-1', running);
      await pumpApp(
        tester,
        size: look.size,
        initialLocation: AppDestination.liveTv.path,
        overrides: [...live.overrides, ...sourceShellOverrides],
      );
    }),
    AuditScene('Movies', (tester, look) async {
      final vod = VodFakes();
      addTearDown(() => tester.runAsync(vod.db.close));
      await tester.runAsync(() => vod.seed(movies: false));
      vod.fakes.sync.emit('src-1', running);
      await pumpApp(
        tester,
        size: look.size,
        initialLocation: AppDestination.movies.path,
        overrides: [...vod.overrides, ...sourceShellOverrides],
      );
    }),
    for (final search in [false, true])
      AuditScene(search ? 'Search' : 'Home', (tester, look) async {
        final home = HomeFakes();
        addTearDown(() => tester.runAsync(home.db.close));
        await tester.runAsync(() async {
          await home.seed();
          await home.db.customStatement('DELETE FROM favorites');
          await home.db.customStatement('DELETE FROM movies');
          await home.db.customStatement('DELETE FROM series');
        });
        home.vod.fakes.sync.emit('src-1', running);
        await pumpApp(
          tester,
          size: look.size,
          overrides: [...home.overrides, ...sourceShellOverrides],
        );
        if (!search) return;
        await auditSettle(tester);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }),
  ]);

  // ---------------------------------------------------------- settings
  auditScreen('Settings', [
    AuditScene('Casting', phone: false, (tester, look) async {
      final ui = CastUi();
      addTearDown(() => tester.runAsync(ui.live.db.close));
      addTearDown(ui.dispose);
      await tester.runAsync(ui.live.seed);
      await pumpApp(
        tester,
        size: look.size,
        initialLocation: AppDestination.settings.path,
        overrides: ui.overrides,
      );
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(settingsLocationProvider.notifier)
          .show(SettingsSection.casting);
      await auditSettle(tester);
    }),
  ]);

  // ------------------------------------------------------------ the player
  // What a phone's screen has to fit between the OSD's bars (ADR-068): the
  // channel panel, a track menu, the stream info and the next-episode
  // card. Drawn in every look; the player is opened by itself, as Play
  // and a channel open it (the pages under it are their own scenes).
  const playerKeys = {
    'no focus ring on "player"': 'the player is one stop; its keys are its own',
  };

  /// A movie (or, with [episode], the series' first episode) opened in
  /// the player with nothing under it, playing [at] into [length].
  Future<VodPlayerRig> playFile(
    WidgetTester tester, {
    bool episode = false,
    Duration length = vodPlayerHour,
    Duration at = const Duration(minutes: 24, seconds: 10),
  }) async {
    final t = VodPlayerRig();
    MovieItem? movie;
    SeriesItem? series;
    EpisodeItem? first;
    await t.open(
      tester,
      playerRoutePath,
      extra: [
        playerSystemUiProvider.overrideWithValue(RecordedPlayerSystemUi()),
      ],
      before: () async {
        final vod = t.vod;
        if (!episode) {
          movie = (await DbMovieRepository(
            vod.db,
            vod.details,
            clock: () => vod.now,
          ).byRemoteKey('src-1', '501')).valueOrNull;
          return;
        }
        final shows = DbSeriesRepository(
          vod.db,
          vod.details,
          clock: () => vod.now,
        );
        series = (await shows.byRemoteKey('src-1', '77')).valueOrNull;
        final ready = await shows
            .details(series!)
            .firstWhere(
              (d) =>
                  d is DetailsReady<SeriesDetails> &&
                  d.value.seasons.isNotEmpty,
            );
        first = (ready as DetailsReady<SeriesDetails>)
            .value
            .seasons
            .first
            .episodes
            .first;
      },
    );
    final launcher = ProviderScope.containerOf(
      tester.element(find.byType(PlayerScreen)),
    ).read(vodLauncherProvider);
    unawaited(
      episode
          ? launcher.playEpisode(series!, first!)
          : launcher.playMovie(movie!),
    );
    await settle(tester);
    await t.firstFrame(tester, length: length);
    t.rig.engine.progress(at, buffered: const Duration(minutes: 1));
    await settle(tester);
    return t;
  }

  AuditScene fileScene(
    String state, {
    Future<void> Function(WidgetTester tester)? then,
    bool episode = false,
    Duration length = vodPlayerHour,
    Duration at = const Duration(minutes: 24, seconds: 10),
  }) {
    late VodPlayerRig t;
    return AuditScene(
      state,
      (tester, look) async {
        t = await playFile(tester, episode: episode, length: length, at: at);
        await then?.call(tester);
        await auditSettle(tester);
      },
      keyboard: false,
      allow: playerKeys,
      close: (tester) => t.finish(tester),
    );
  }

  auditScreen('the player', [
    () {
      late LiveTvFakes live;
      return AuditScene(
        'a channel, its panel open',
        (tester, look) async {
          live = LiveTvFakes();
          addTearDown(() => tester.runAsync(live.db.close));
          await tester.runAsync(live.seed);
          ChannelItem? channel;
          await tester.runAsync(() async {
            channel = (await DbChannelRepository(
              live.db,
              clock: () => live.fakes.now,
            ).byNumber('src-1', 201)).valueOrNull;
          });
          await pumpApp(
            tester,
            size: look.size,
            initialLocation: playerRoutePath,
            overrides: [
              ...live.overrides,
              playerSystemUiProvider.overrideWithValue(
                RecordedPlayerSystemUi(),
              ),
            ],
          );
          unawaited(live.rig.coordinator.playLive(channel!));
          await auditSettle(tester);
          live.rig.engine.firstFrame();
          await auditSettle(tester);
          await tester.tap(findByLabel('Channels'));
          await auditSettle(tester);
        },
        keyboard: false,
        allow: playerKeys,
        close: (tester) async {
          await tester.pump(const Duration(seconds: 4));
          await live.rig.coordinator.stop();
          await auditSettle(tester);
        },
      );
    }(),
    fileScene(
      'a film, its Speed menu open',
      then: (tester) => tester.tap(findByLabel('Speed')),
    ),
    fileScene(
      'a film, its stream info open',
      then: (tester) => tester.tap(findByLabel('Stream info')),
    ),
    fileScene(
      "an episode's last minute: the next-episode card and the controls",
      episode: true,
      length: const Duration(minutes: 45),
      at: const Duration(minutes: 44, seconds: 10),
    ),
  ]);
}
