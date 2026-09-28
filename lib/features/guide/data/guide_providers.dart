import 'dart:async';

import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/sync/epg_importer.dart';
import 'package:iptv_player/data/sync/epg_match_service.dart';
import 'package:iptv_player/data/sync/guide_scheduler.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/data/db_guide_settings_store.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'guide_providers.g.dart';

@Riverpod(keepAlive: true)
EpgRepository epgRepository(Ref ref) {
  final repository = DbEpgRepository(ref.watch(appDatabaseProvider));
  // Stops the Match… picker's ranking workers.
  ref.onDispose(repository.dispose);
  return repository;
}

/// The one match service: rematches a source after an import's swap and
/// after a sync (`syncServiceProvider` wires the second). Stops its runs
/// when the app closes.
///
/// It depends on nothing but the database and the log, so both the sync
/// engine and the importer can depend on it without a cycle.
@Riverpod(keepAlive: true)
EpgMatchService epgMatchService(Ref ref) {
  final service = EpgMatchService(
    database: ref.watch(appDatabaseProvider),
    log: ref.watch(appLogProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

/// The one guide importer, which rematches after every swap. Cancels its
/// imports when the app closes.
@Riverpod(keepAlive: true)
EpgImporter epgImporter(Ref ref) {
  final importer = EpgImporter(
    database: ref.watch(appDatabaseProvider),
    guide: ref.watch(epgRepositoryProvider),
    sources: ref.watch(sourceRepositoryProvider),
    log: ref.watch(appLogProvider),
    matches: ref.watch(epgMatchServiceProvider),
    // Read as each import starts, not watched: a change of the days kept
    // re-imports through the controller rather than rebuilding this. The
    // controller reads the importer only inside its methods, so this is
    // no cycle.
    settings: () => ref.read(guideSettingsControllerProvider),
  );
  ref.onDispose(importer.dispose);
  return importer;
}

/// Imports guides on its own: after the launch's syncs, hourly, and
/// after each sync (ADR-011 decision 5). `bootstrap()` starts it; the sync
/// engine tells it of every sync that succeeds.
@Riverpod(keepAlive: true)
GuideScheduler guideScheduler(Ref ref) {
  final scheduler = GuideScheduler(
    guide: ref.watch(epgRepositoryProvider),
    imports: ref.watch(guideImportServiceProvider),
    sources: ref.watch(sourceRepositoryProvider),
    log: ref.watch(appLogProvider),
    // Read when needed, not watched: the sync engine and the settings
    // read this scheduler in turn, and a watch would make a cycle.
    settingsLoaded: () =>
        ref.read(guideSettingsControllerProvider.notifier).loaded,
    syncing: (sourceId) =>
        ref.read(syncServiceProvider).statusOf(sourceId) is SyncRunning,
    busy: (sourceId) {
      // Never created means nothing ever played.
      if (!ref.exists(playbackCoordinatorProvider)) return false;
      return switch (ref.read(playbackCoordinatorProvider).state) {
        PlaybackOpening(:final item) ||
        PlaybackReconnecting(:final item) => item.sourceId == sourceId,
        _ => false,
      };
    },
    notify: ref.watch(appNoticesProvider).show,
    clock: ref.watch(appClockProvider),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
}

/// The importer as the screens see it.
@Riverpod(keepAlive: true)
GuideImportService guideImportService(Ref ref) =>
    ref.watch(epgImporterProvider);

/// The match service as the screens see it.
@Riverpod(keepAlive: true)
GuideMatching guideMatching(Ref ref) => ref.watch(epgMatchServiceProvider);

/// What the guide covers for [sourceId], live: Settings → Guide and the
/// Guide screen's empty states read it.
@riverpod
Stream<GuideCoverage> guideCoverage(Ref ref, String sourceId) =>
    ref.watch(epgRepositoryProvider).watchCoverage(sourceId);

/// One programme whole, description and all, for the Guide's detail
/// sheet: the grid reads programmes without their descriptions.
@riverpod
Future<EpgProgramme?> guideProgramme(Ref ref, int id) async =>
    (await ref.watch(epgRepositoryProvider).programme(id)).valueOrNull;

/// How far [sourceId]'s running import has got; nothing while none runs.
@riverpod
Stream<EpgImportProgress> guideImportProgress(Ref ref, String sourceId) => ref
    .watch(guideImportServiceProvider)
    .progress
    .where((event) => event.$1 == sourceId)
    .map((event) => event.$2);

/// How well [sourceId]'s guide covers the channels the user can see.
@riverpod
Stream<ChannelMatchCounts> channelMatchCounts(Ref ref, String sourceId) =>
    ref.watch(epgRepositoryProvider).watchChannelMatchCounts(sourceId);

/// Where [sourceId]'s guide comes from, or why it has none. Worked out
/// again whenever a source is edited (its EPG URL may have changed).
@riverpod
Future<Result<GuideOrigin>> guideOrigin(Ref ref, String sourceId) {
  ref.watch(sourcesProvider);
  return ref.watch(guideImportServiceProvider).guideOrigin(sourceId);
}

@Riverpod(keepAlive: true)
GuideSettingsStore guideSettingsStore(Ref ref) =>
    DbGuideSettingsStore(ref.watch(settingsRepositoryProvider));

/// Settings → Guide's choices: the days kept (global) and a source's time
/// offset. The defaults at once, the stored choices as soon as they are
/// read. A change is saved, then re-imports the guides it affects
/// (ADR-011 decision 4), one source at a time.
@Riverpod(keepAlive: true)
class GuideSettingsController extends _$GuideSettingsController {
  @override
  GuideSettings build() {
    unawaited(_load());
    return const GuideSettings();
  }

  var _changed = false;
  final _loaded = Completer<void>();

  /// Completes once the stored choices have been read, or couldn't be.
  /// An import at launch waits for it, or it would keep the default days.
  Future<void> get loaded => _loaded.future;

  /// Bumped by every change of the days kept, so an older round of
  /// re-imports stops at its next source.
  var _round = 0;
  Future<void> _reimporting = Future.value();

  /// The latest round of re-imports a change of the days kept started,
  /// for tests that must not race it.
  @visibleForTesting
  Future<void> get reimporting => _reimporting;

  Future<void> _load() async {
    try {
      final stored = await ref.read(guideSettingsStoreProvider).load();
      // A choice made while loading wins over what was stored.
      if (!_changed) state = stored.valueOrNull ?? const GuideSettings();
    } on Object catch (error, stackTrace) {
      // The store answers with a Result; this is the last line of
      // defence, and the defaults stay.
      ref
          .read(appLogProvider)
          .warning(
            'guide',
            'Could not read the guide settings',
            error: error,
            stackTrace: stackTrace,
          );
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  /// Keeps [days] of programmes ahead, then re-imports every source that
  /// has a guide or is importing one. Returns once the choice is saved;
  /// the imports carry on after it.
  Future<Result<void>> setKeepDays(int days) async {
    if (days < GuideSettings.minKeepDays || days > GuideSettings.maxKeepDays) {
      return Err(InvalidInputFailure('guide: keep $days days'));
    }
    final previous = state;
    final next = state.copyWith(keepDays: days);
    if (next == previous) return const Ok(null);
    _changed = true;
    state = next;
    final saved = await ref.read(guideSettingsStoreProvider).save(next);
    if (saved case Err(:final failure)) {
      // Imports must not use a choice that isn't kept; unless another
      // change came in meanwhile.
      if (state == next) state = previous;
      return Err(failure);
    }
    final round = ++_round;
    final sources = ref.read(sourceRepositoryProvider);
    final guide = ref.read(epgRepositoryProvider);
    final imports = ref.read(guideImportServiceProvider);
    unawaited(
      _reimporting = () async {
        final all = (await sources.all()).valueOrNull ?? const <Source>[];
        for (final source in all) {
          if (round != _round) return;
          if (await _hasGuide(guide, imports, source.id)) {
            await imports.reimport(source.id);
          }
        }
      }(),
    );
    return const Ok(null);
  }

  /// Saves [minutes] as [source]'s guide offset, then re-imports its
  /// guide if it has one. Returns once the offset is saved. The password
  /// stays as stored (a draft without one keeps it).
  Future<Result<void>> setOffset(Source source, int minutes) async {
    final sources = ref.read(sourceRepositoryProvider);
    final guide = ref.read(epgRepositoryProvider);
    final imports = ref.read(guideImportServiceProvider);
    final SourceCredentials credentials;
    switch (await sources.credentialsFor(source.id)) {
      case Ok(:final value):
        credentials = value;
      case Err(:final failure):
        return Err(failure);
    }
    final saved = await sources.update(
      source.id,
      SourceDraft(
        type: source.type,
        name: source.name,
        url: credentials.url,
        username: source.username,
        epgUrl: credentials.epgUrl,
        userAgent: source.userAgent,
        liveFormat: source.liveFormat,
        epgOffsetMinutes: minutes,
        refreshHours: source.refreshHours,
        maxConnectionsOverride: source.maxConnectionsOverride,
      ),
    );
    if (saved case Err(:final failure)) return Err(failure);
    if (await _hasGuide(guide, imports, source.id)) {
      unawaited(imports.reimport(source.id));
    }
    return const Ok(null);
  }

  static Future<bool> _hasGuide(
    EpgRepository guide,
    GuideImportService imports,
    String sourceId,
  ) async {
    if (imports.isImporting(sourceId)) return true;
    return (await guide.coverage(sourceId)).valueOrNull?.hasGuide ?? false;
  }
}
