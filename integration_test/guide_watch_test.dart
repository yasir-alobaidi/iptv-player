// Phase 4 end to end: the real app, database, sync, guide import and
// player (media_kit), against the fake panel in its own process with the
// media samples.
//
// The scheduler imports the guide on its own and says so ("Guide updated
// · N channels matched") → Live TV's first row shows what the guide says
// is on → G → the Guide, on that programme → → the next one → Enter: its
// sheet, on Watch channel → Enter: the player plays the channel → Esc:
// back on the Guide, the stream stopped.
//
// Only channel 1 is played: its sample is one CI generates.

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
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_sheet.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
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
    'the guide, from its import to watching from the Guide',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
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

      // ── The launch's guide check: none yet, so it imports, and says so.
      await tester.runAsync(
        () => app.container.read(guideSchedulerProvider).startUp(),
      );
      await k.waitFor(find.textContaining('Guide updated · '), seconds: 60);
      expect(find.textContaining('channels matched'), findsOneWidget);

      // What the guide says is on channel 1 now, and next.
      final guide = app.container.read(epgRepositoryProvider);
      final one = (await tester.runAsync(
        () => app.container
            .read(sourceRepositoryProvider)
            .all()
            .then((all) => all.valueOrNull!.single.id),
      ))!;
      final channel = (await tester.runAsync(
        () => app.db.channelsDao.byRemoteKey(one, '1'),
      ))!;
      final nowNext = (await tester.runAsync(
        () => guide.nowNextForChannels([channel.id], DateTime.now()),
      ))!.valueOrNull![channel.id]!;
      final onNow = nowNext.now!.title;
      final upNext = nowNext.next!.title;

      // ── Live TV: the first row says what is on.
      await k.chord(LogicalKeyboardKey.digit2);
      await k.waitFor(find.text('All channels'));
      await k.press(LogicalKeyboardKey.arrowDown);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text(onNow));
      await k.waitUntil(
        () => coordinator.state is PlaybackPlaying,
        'the preview of channel 1 (${coordinator.state})',
        seconds: 30,
      );

      // ── G: the Guide, on what is on now on channel 1; Live TV's preview
      // stops as it is left.
      await k.press(LogicalKeyboardKey.keyG);
      await k.waitUntil(
        () => app.location == AppDestination.guide.path,
        'the Guide',
      );
      await k.waitUntil(
        () => coordinator.state is PlaybackIdle,
        'the preview to stop',
      );
      await k.waitUntil(() => _ringed() == onNow, 'the ring on $onNow');

      // ── →: the next programme; Enter: its sheet, on Watch channel.
      await k.press(LogicalKeyboardKey.arrowRight);
      await k.waitUntil(() => _ringed() == upNext, 'the ring on $upNext');
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(GuideProgrammeSheet));
      expect(
        find.descendant(
          of: find.byType(GuideProgrammeSheet),
          matching: find.text(upNext),
        ),
        findsOneWidget,
      );
      expect(k.focusedLabel(), 'Watch channel');

      // ── Enter: the player, playing channel 1.
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      expect(app.location, playerRoutePath);
      await k.waitUntil(
        () =>
            coordinator.current?.remoteKey == '1' &&
            coordinator.state is PlaybackPlaying,
        'channel 1 playing (${coordinator.state})',
        seconds: 30,
      );

      // ── Esc: back on the Guide, the stream stopped.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => app.location == AppDestination.guide.path,
        'the Guide again',
      );
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

/// The title of the programme the Guide's cursor is on; null with none.
String? _ringed() {
  final grid = find.byWidgetPredicate(
    (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
  );
  if (find
      .descendant(
        of: grid,
        matching: find.byWidgetPredicate((w) => w is FocusRing && w.visible),
      )
      .evaluate()
      .isEmpty) {
    return null;
  }
  final selected = find
      .descendant(
        of: grid,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.selected ?? false),
        ),
      )
      .evaluate();
  if (selected.isEmpty) return null;
  final label = (selected.first.widget as Semantics).properties.label ?? '';
  return label.split(', ').first;
}

/// The app as `bootstrap()` builds it, with the real player, a throwaway
/// database and keyring, and the fake panel added and synced as a source.
final class _App {
  new _(this.container, this._directory, this.db);

  static Future<_App> open(FakePanel panel, {required bool video}) async {
    final directory = await Directory.systemTemp.createTemp('iptv_watch');
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
  final AppDatabase db;

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
