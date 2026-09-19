// Phase 3 end to end, with the keyboard only: the real app, database,
// sync and player (media_kit), a source on the fake panel (in its own
// process, with the media samples).
//
// Ctrl+2 → Live TV → All channels → the first channel previews → Enter:
// full screen → ↓ zaps → digits reach channel 3 → Backspace goes back →
// ← opens the channel panel, Enter plays from it → Esc back to Live TV,
// the stream carrying on → Ctrl+1 leaves Live TV and playback stops.
//
// Only channels 1–3 are played: their samples are the ones CI generates.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
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
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'Live TV and the player with the keyboard only',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      // The player's picture needs frames on the engine's schedule.
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

      String? playingKey() => coordinator.current?.remoteKey;
      Future<void> playingPicture(String key) => k.waitUntil(
        () => playingKey() == key && coordinator.state is PlaybackPlaying,
        'channel $key to show a picture (${coordinator.state})',
        seconds: 30,
      );

      // ── Ctrl+2: Live TV, the focus in its first control (Favorites).
      await k.chord(LogicalKeyboardKey.digit2);
      expect(app.location, AppDestination.liveTv.path);
      await k.waitFor(find.text('All channels'));
      await k.waitUntil(
        () => k.focusIsOn(find.text('Favorites').first),
        'the focus on Favorites',
      );

      // ── ↓ Enter: All channels; the list takes the focus on its first
      // row, which previews after a moment.
      await k.press(LogicalKeyboardKey.arrowDown);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () =>
            app.container.read(liveTvControllerProvider)?.selected?.remoteKey ==
            '1',
        'the first channel row focused (${k.focusedLabel()})',
      );
      await playingPicture('1');

      // ── Enter: full screen.
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      expect(app.location, playerRoutePath);
      await k.waitFor(find.byType(OsdTop));

      // ── ↓: the banner at once, channel 2 after a moment.
      await k.press(LogicalKeyboardKey.arrowDown);
      expect(find.byType(ChannelBanner), findsOneWidget);
      await playingPicture('2');

      // ── Digits: 3, committed after 1.5 s.
      await k.press(LogicalKeyboardKey.digit3);
      expect(find.byType(NumberEntry), findsOneWidget);
      await playingPicture('3');

      // ── Backspace: the last channel (2).
      await k.press(LogicalKeyboardKey.backspace);
      await playingPicture('2');

      // ── ←: the channel panel on the playing channel; ↑ Enter plays 1.
      await k.press(LogicalKeyboardKey.arrowLeft);
      await k.waitFor(find.byType(ChannelPanel));
      final two = coordinator.current!.name;
      await k.waitUntil(
        () => k.focusedLabel() == two,
        'the panel on the playing channel (${k.focusedLabel()})',
      );
      await k.press(LogicalKeyboardKey.arrowUp);
      await k.press(LogicalKeyboardKey.enter);
      expect(find.byType(ChannelPanel), findsNothing);
      await playingPicture('1');

      // ── Esc: back to Live TV, still playing.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == AppDestination.liveTv.path,
        'Live TV again',
      );
      expect(coordinator.state, isA<PlaybackPlaying>());

      // ── Ctrl+1: leaving Live TV stops the stream.
      await k.chord(LogicalKeyboardKey.digit1);
      await k.waitUntil(
        () => coordinator.state is PlaybackIdle,
        'playback to stop',
      );
      await k.waitUntil(
        () async => await panel.activeConnections() == 0,
        'the panel to see the connection closed',
      );
      expect(tester.takeException(), isNull);
    },
    skip: !streamsAvailable,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// The app as `bootstrap()` builds it, with the real player, a throwaway
/// database and keyring, and the fake panel added and synced as a source.
final class _App {
  new _(this.container, this._directory, this._db);

  static Future<_App> open(FakePanel panel, {required bool video}) async {
    final directory = await Directory.systemTemp.createTemp('iptv_live');
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
    final synced = await container
        .read(syncServiceProvider)
        .sync(added.valueOrNull!.id);
    if (!synced.isOk) throw StateError('sync failed: ${synced.failureOrNull}');
    return _App._(container, directory, db);
  }

  final ProviderContainer container;
  final Directory _directory;
  final AppDatabase _db;

  String get location => container.read(routerProvider).state.uri.path;

  Future<void> close() async {
    final coordinator = container.read(playbackCoordinatorProvider);
    await coordinator.stop();
    final engine = coordinator.engine;
    container.dispose();
    await engine.dispose();
    await _db.close();
    await _directory.delete(recursive: true);
  }
}
