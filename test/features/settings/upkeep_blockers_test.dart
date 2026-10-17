import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/domain/download_queue.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:iptv_player/features/settings/data/data_providers.dart';
import 'package:iptv_player/features/settings/domain/data_upkeep.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:logger/logger.dart';

import '../downloads/support/queue_doubles.dart';
import '../guide/presentation/guide_settings_fakes.dart';
import '../onboarding/onboarding_fakes.dart';
import '../playback/support/playback_fakes.dart';

/// What keeps a compaction from running (ADR-031: "only with nothing
/// syncing, importing, downloading or playing"), each read from where the
/// app keeps it: the one playback coordinator, the sync service, the
/// guide's importer and its recorded runs, and the download queue. Both
/// readings: Settings → Data's, which follows them, and the last look
/// taken just before a compaction starts (the launch's, and Compact's).
void main() {
  late GuideFakes fakes;
  late Rig player;
  late MemoryStore downloads;
  late DownloadQueue queue;

  setUp(() {
    fakes = GuideFakes(OnboardingFakes());
    fakes.base.sources.seed(id: 'src');
    player = Rig();
    downloads = MemoryStore();
    queue = DownloadQueue(
      store: downloads,
      titles: ScriptedTitles(),
      // A stopped download says where it halted, as the real runner does.
      runner: ScriptedRunner()..haltOnStop = true,
      finisher: ScriptedFinisher(),
      connections: SourceConnections(),
      sleep: SleepLog(),
      settings: () => const DownloadSettings(),
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
      freeSpace: (_) => null,
      fileExists: (_) => false,
    );
    addTearDown(queue.shutdown);
  });

  /// The app as a form factor has it, with the queue made (the desktop
  /// makes it at launch) or not.
  Future<ProviderContainer> app({
    FormFactor formFactor = FormFactor.desktop,
    bool withQueue = true,
  }) async {
    if (withQueue) await queue.startUp();
    final container = ProviderContainer(
      overrides: [
        ...fakes.overrides,
        formFactorProvider.overrideWithValue(formFactor),
        playbackCoordinatorProvider.overrideWithValue(player.coordinator),
        downloadQueueProvider.overrideWithValue(queue),
      ],
    );
    addTearDown(container.dispose);
    // The player and the queue exist from launch, as in the app.
    container.read(playbackCoordinatorProvider);
    if (withQueue) container.read(downloadQueueProvider);
    container.listen(compactBlockerProvider, (_, _) {});
    await pumpEventQueue();
    return container;
  }

  /// Both readings at once: what the page shows, and the last look.
  Future<(UpkeepBlocker?, UpkeepBlocker?)> blockers(
    ProviderContainer container,
  ) async {
    await pumpEventQueue();
    return (
      container.read(compactBlockerProvider),
      await container.read(upkeepBlockerCheckProvider)(),
    );
  }

  test('nothing at work: nothing in the way', () async {
    final container = await app();

    expect(await blockers(container), (null, null));
  });

  test('playing: from the moment a channel opens, paused or not, until it '
      'stops', () async {
    final container = await app();

    unawaited(player.coordinator.playLive(channel(1)));
    await pumpEventQueue();
    expect(player.state, isA<PlaybackOpening>());
    expect(await blockers(container), (
      UpkeepBlocker.playing,
      UpkeepBlocker.playing,
    ));

    player.engine.firstFrame();
    await pumpEventQueue();
    expect(player.state, isA<PlaybackPlaying>());
    expect(await blockers(container), (
      UpkeepBlocker.playing,
      UpkeepBlocker.playing,
    ));

    await player.coordinator.setPaused(paused: true);
    expect(await blockers(container), (
      UpkeepBlocker.playing,
      UpkeepBlocker.playing,
    ), reason: 'a paused film still holds its stream');

    await player.coordinator.stop();
    expect(player.state, isA<PlaybackIdle>());
    expect(await blockers(container), (null, null));
  });

  test('syncing: while the sync service says a source is running', () async {
    final container = await app();

    fakes.base.sync.emit(
      'src',
      const SyncRunning(SyncProgress(stage: SyncStage.live)),
    );
    expect(await blockers(container), (
      UpkeepBlocker.syncing,
      UpkeepBlocker.syncing,
    ));

    fakes.base.sync.emit('src', const SyncIdle());
    expect(await blockers(container), (null, null));
  });

  test('importing: while the importer runs one (the last look) and while '
      'its run is recorded as running (the page)', () async {
    final container = await app();
    final gate = fakes.imports.gate = Completer<void>();

    final importing = fakes.imports.importGuide('src');
    fakes.guide.setCoverage(
      'src',
      GuideCoverage(
        lastImport: GuideImport(
          id: 3,
          outcome: GuideImportOutcome.running,
          startedAt: DateTime.utc(2026, 10, 17),
        ),
      ),
    );
    expect(await blockers(container), (
      UpkeepBlocker.importing,
      UpkeepBlocker.importing,
    ));

    gate.complete();
    await importing;
    fakes.guide.setCoverage(
      'src',
      GuideCoverage(
        lastImport: GuideImport(
          id: 3,
          outcome: GuideImportOutcome.succeeded,
          startedAt: DateTime.utc(2026, 10, 17),
          finishedAt: DateTime.utc(2026, 10, 17),
          isLive: true,
        ),
      ),
    );
    expect(await blockers(container), (null, null));
  });

  test('downloading: a download the queue resumes holds it; a paused one '
      'does not', () async {
    // One was downloading when the app closed: the launch resumes it.
    downloads
      ..seed(DownloadTaskState.downloading)
      ..seed(DownloadTaskState.paused);
    final container = await app();
    final resumed = queue.current.first;
    expect(resumed.state.isActive, isTrue, reason: '${resumed.state}');

    expect(await blockers(container), (
      UpkeepBlocker.downloading,
      UpkeepBlocker.downloading,
    ));

    await queue.pause(resumed.id);
    expect(queue.current.map((task) => task.state), [
      DownloadTaskState.paused,
      DownloadTaskState.paused,
    ]);
    expect(await blockers(container), (null, null));
  });

  test('a TV has no downloads: its queue is never made', () async {
    final container = await app(formFactor: FormFactor.tv, withQueue: false);

    expect(await blockers(container), (null, null));
    expect(container.exists(downloadQueueProvider), isFalse);
  });
}
