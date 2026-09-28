// Phase 5 step 7 end to end: Home's Continue watching with the real app,
// database, sync and player against the fake panel. A movie played to
// 75 s and left with Esc shows on Home with its progress; Enter there
// resumes it where it was left.
//
// Needs the VOD sample vod_h264_aac_10min (CI makes a 120 s one: 75 s is
// past the minute Continue watching asks for, and short of 95 %).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'a movie left part-way is on Home, and Enter resumes it there',
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
        () => _App.open(panel, video: video),
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

      // ── First run: Home leads with its hero.
      await k.waitFor(find.text('Start watching'), seconds: 30);

      final movie = (await tester.runAsync(
        () => app.container
            .read(movieRepositoryProvider)
            .byRemoteKey(app.sourceId, '$firstMovieId'),
      ))!.valueOrNull!;
      final film = PlayableMovie(movie);

      // ── Play it from its page, to 75 s, and leave with Esc.
      router.go(movieDetailsPath(movie));
      await k.waitFor(find.text('Play'));
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await k.waitUntil(
        () => coordinator.item == film && coordinator.state is PlaybackPlaying,
        'the movie playing (${coordinator.state})',
        seconds: 30,
      );
      final length = coordinator.timeline.duration!;
      const left = Duration(seconds: 75);
      await tester.runAsync(() => coordinator.seek(left));
      await k.waitUntil(
        () => coordinator.timeline.position >= left,
        'the movie at 75 s',
      );
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');

      // ── Home: no hero now, and the movie in Continue watching with what
      // is left of it.
      await k.chord(LogicalKeyboardKey.digit1);
      await k.waitFor(find.text('Continue watching'));
      expect(find.text('Start watching'), findsNothing);
      final card = tester.widget<LandscapeCard>(
        find.byWidgetPredicate(
          (w) => w is LandscapeCard && w.title == movie.name,
        ),
      );
      expect(card.subtitle, startsWith('Movie · '));
      expect(card.subtitle, endsWith('min left'));
      expect(
        card.progress,
        closeTo(left.inMilliseconds / length.inMilliseconds, 0.05),
      );

      // ── Ctrl+1 put the focus on it (Home's first control); Enter
      // resumes it where it was left.
      await k.waitUntil(
        () => k.focusedLabel() == movie.name,
        'the focus on its card (${focusPath()})',
        seconds: 5,
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      // Continue watching's copy of the movie carries its watch mark, so
      // it is the same title rather than an equal item.
      await k.waitUntil(
        () =>
            coordinator.item?.remoteKey == movie.remoteKey &&
            coordinator.state is PlaybackPlaying,
        'the movie resumed (${coordinator.state})',
        seconds: 30,
      );
      expect(coordinator.startedFrom, greaterThanOrEqualTo(left));
      expect(
        coordinator.timeline.position,
        greaterThanOrEqualTo(left - const Duration(seconds: 2)),
      );

      // ── Esc: back on Home, nothing playing.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(() => app.location == '/', 'Home again');
      await k.waitUntil(() => coordinator.state is PlaybackIdle, 'the stop');
      await k.waitUntil(
        () async => await panel.activeConnections() == 0,
        'the panel to see the connection closed',
      );
      expect(tester.takeException(), isNull);
    },
    skip: !vodAvailable,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

/// The app as `bootstrap()` builds it, with the real player, a throwaway
/// database and keyring, and the fake panel added and synced as a source.
final class _App {
  new _(this.container, this._directory, this.db, this.sourceId);

  static Future<_App> open(FakePanel panel, {required bool video}) async {
    final directory = await Directory.systemTemp.createTemp('iptv_vod');
    final db = AppDatabase(await openAppDatabase(directory));
    final secrets = SecretRegistry();
    final log = AppLog(output: SilentOutput(), secrets: secrets);
    final engine = await MediaKitPlayerEngine.create(
      log: log,
      secrets: secrets,
      video: video,
    );
    final container = ProviderContainer(
      overrides: [
        appLogProvider.overrideWithValue(log),
        secretRegistryProvider.overrideWithValue(secrets),
        errorReporterProvider.overrideWithValue(ErrorReporter(log)),
        appDatabaseProvider.overrideWithValue(db),
        credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
        startLocationProvider.overrideWithValue('/'),
        playerEngineProvider.overrideWithValue(engine),
        ...sourceShellOverrides,
      ],
    );
    final added = await container
        .read(sourceRepositoryProvider)
        .add(
          SourceDraft(
            type: SourceType.xtream,
            name: 'Fake panel',
            url: panel.url,
            username: 'test',
            password: 'test',
          ),
        );
    final id = added.valueOrNull!.id;
    final synced = await container.read(syncServiceProvider).sync(id);
    if (!synced.isOk) throw StateError('sync failed: ${synced.failureOrNull}');
    return _App._(container, directory, db, id);
  }

  final ProviderContainer container;
  final Directory _directory;
  final AppDatabase db;
  final String sourceId;

  String get location => container.read(routerProvider).state.uri.path;

  Future<void> close() async {
    final coordinator = container.read(playbackCoordinatorProvider);
    await coordinator.stop();
    final engine = coordinator.engine;
    container.dispose();
    await engine.dispose();
    await db.close();
    await _directory.delete(recursive: true);
  }
}
