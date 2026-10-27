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
/// imports when the app closes. A TV keeps the last two hours behind now,
/// not a day (docs/07).
@Riverpod(keepAlive: true)
EpgImporter epgImporter(Ref ref) {
  final formFactor = ref.watch(formFactorProvider);
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
    keepBehind: GuideSettings.keepBehindOn(formFactor),
    keepAhead: GuideSettings.defaultsOn(formFactor).keepAhead,
  );
  ref.onDispose(importer.dispose);
  return importer;
}

/// Imports guides on its own: after the launch's syncs, hourly, and
/// after each sync (ADR-011 decision 5); nothing while the guide is
/// switched off (ADR-031), and on a TV nothing while anything plays.
/// `bootstrap()` starts it; the sync engine tells it of every sync that
/// succeeds, and Settings → Guide's switch of every change.
@Riverpod(keepAlive: true)
GuideScheduler guideScheduler(Ref ref) {
  bool coordinatorIn(bool Function(PlaybackState state) test) =>
      // Never created means nothing ever played.
      ref.exists(playbackCoordinatorProvider) &&
      test(ref.read(playbackCoordinatorProvider).state);
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
    enabled: () => ref.read(guideSettingsControllerProvider).enabled,
    busy: (sourceId) => coordinatorIn(
      (state) => switch (state) {
        PlaybackOpening(:final item) ||
        PlaybackReconnecting(:final item) => item.sourceId == sourceId,
        _ => false,
      },
    ),
    // A TV has one picture and 2 GB: the import waits for the end of
    // whatever plays, a paused film too (docs/07); a phone's the same.
    playing: ref.watch(formFactorProvider).isAndroidDevice
        ? () => coordinatorIn(
            (state) => switch (state) {
              PlaybackOpening() ||
              PlaybackPlaying() ||
              PlaybackReconnecting() => true,
              _ => false,
            },
          )
        : null,
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
GuideSettingsStore guideSettingsStore(Ref ref) => DbGuideSettingsStore(
  ref.watch(settingsRepositoryProvider),
  defaults: GuideSettings.defaultsOn(ref.watch(formFactorProvider)),
);

/// Settings → Guide's choices as `bootstrap()` read them, before the first
/// frame: the rail, the keys and the guide's page are right from the
/// start, with no Guide appearing a moment after launch. Null: read by the
/// controller once it is made (tests, a read that failed).
@Riverpod(keepAlive: true)
GuideSettings? launchGuideSettings(Ref ref) => null;

/// Completes once Settings → Guide's stored choices have been read, or
/// couldn't be.
@Riverpod(keepAlive: true)
Future<void> guideSettingsLoaded(Ref ref) =>
    ref.watch(guideSettingsControllerProvider.notifier).loaded;

/// Whether the Guide is switched on (ADR-031): its place in the rail, its
/// keys, its import. Off by default, and off until the stored choice has
/// been read. Its dependents hear only a change of the switch, not of the
/// days kept.
@Riverpod(keepAlive: true)
bool guideEnabled(Ref ref) =>
    ref.watch(guideSettingsControllerProvider).enabled;

/// True once the stored choice has been read and the Guide is off: its
/// page goes Home, and draws nothing. Until it is read the page is let
/// be (the app never opens on it).
@Riverpod(keepAlive: true)
bool guideSwitchedOff(Ref ref) =>
    ref.watch(guideSettingsLoadedProvider).hasValue &&
    !ref.watch(guideEnabledProvider);

/// Settings → Guide's choices: the switch and the days kept (global), and
/// a source's time offset. The choices bootstrap read at once
/// ([launchGuideSettings]); without them the device's defaults
/// (`GuideSettings.defaultsOn`), then the stored choices as soon as they
/// are read. A change is saved, then re-imports the guides it affects
/// (ADR-011 decision 4), one source at a time; the switch starts or ends
/// the guide's imports, and off clears it.
@Riverpod(keepAlive: true)
class GuideSettingsController extends _$GuideSettingsController {
  @override
  GuideSettings build() {
    _defaults = GuideSettings.defaultsOn(ref.watch(formFactorProvider));
    if (ref.read(launchGuideSettingsProvider) case final read?) {
      // Read before the first frame: nothing to read again.
      if (!_loaded.isCompleted) _loaded.complete();
      return read;
    }
    unawaited(_load());
    return _defaults;
  }

  var _defaults = const GuideSettings();
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
      if (!_changed) state = stored.valueOrNull ?? _defaults;
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

  /// Reads the stored choices again: an import replaced them (Settings →
  /// Data). Nothing is re-imported for the days kept: they apply from the
  /// guide's next refresh. A switch the import turned is acted on.
  Future<void> reload() async {
    final wasOn = state.enabled;
    _changed = false;
    await _load();
    if (state.enabled != wasOn) _switched(on: state.enabled);
  }

  /// Switches the guide on or off (ADR-031), at once. On, every source's
  /// guide is imported, as at a first launch; off, nothing more is, a
  /// running import is cancelled and the stored guides are cleared. The
  /// user's matches, offsets and reminders stay either way. Returns once
  /// the choice is saved; the imports or the clearing carry on after it.
  Future<Result<void>> setEnabled({required bool on}) async {
    final previous = state;
    final next = state.copyWith(enabled: on);
    if (next == previous) return const Ok(null);
    _changed = true;
    state = next;
    final saved = await ref.read(guideSettingsStoreProvider).save(next);
    if (saved case Err(:final failure)) {
      // Unless another change came in meanwhile.
      if (state == next) state = previous;
      return Err(failure);
    }
    _switched(on: on);
    return const Ok(null);
  }

  void _switched({required bool on}) {
    // A round of re-imports for the days kept stops at its next source.
    _round++;
    try {
      final scheduler = ref.read(guideSchedulerProvider);
      unawaited(on ? scheduler.switchedOn() : scheduler.switchedOff());
    } on Object catch (error, stackTrace) {
      // The choice is saved and shown; the imports or the clearing follow
      // at the scheduler's next check.
      ref
          .read(appLogProvider)
          .warning(
            'guide',
            'Could not act on the guide switch',
            error: error,
            stackTrace: stackTrace,
          );
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
