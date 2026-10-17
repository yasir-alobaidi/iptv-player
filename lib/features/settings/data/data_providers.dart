import 'package:file_selector/file_selector.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_store.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/reminders/data/db_reminder_repository.dart';
import 'package:iptv_player/features/settings/data/db_data_upkeep.dart';
import 'package:iptv_player/features/settings/data/db_settings_transfer.dart';
import 'package:iptv_player/features/settings/domain/data_upkeep.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'data_providers.g.dart';

/// Settings → Data's Export… and Import….
@Riverpod(keepAlive: true)
SettingsTransfer settingsTransfer(Ref ref) => DbSettingsTransfer(
  ref.watch(appDatabaseProvider),
  appVersion: ref.watch(appVersionProvider).value?.short ?? '',
  reminders: DbReminderTransfer(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(appClockProvider),
  ),
  clock: ref.watch(appClockProvider),
);

/// How much room the kept pictures take; measured again after Clear.
@riverpod
Future<Result<ArtworkUsage>> artworkUsage(Ref ref) =>
    ref.watch(artworkStoreProvider).usage();

/// The guide on this computer, every source's together.
typedef GuideTotals = ({
  int programmes,

  /// When the furthest guide ends; null with no programmes.
  DateTime? until,

  /// True while any source's guide is being imported.
  bool importing,

  /// The sources that have a guide, for clearing them.
  List<String> sourceIds,
});

/// What Settings → Data says about the guide: null while it is read.
/// A source whose guide can't be read counts as having none.
@riverpod
GuideTotals? guideTotals(Ref ref) {
  final sources = ref.watch(sourcesProvider).value;
  if (sources == null) return null;
  var programmes = 0;
  DateTime? until;
  var importing = false;
  final withGuide = <String>[];
  for (final source in sources) {
    final coverage = ref.watch(guideCoverageProvider(source.id));
    if (coverage.isLoading && !coverage.hasValue) return null;
    final guide = coverage.value;
    if (guide == null) continue;
    importing = importing || guide.isImporting;
    if (!guide.hasGuide) continue;
    withGuide.add(source.id);
    programmes += guide.programmes;
    final end = guide.lastEnd;
    if (end != null && (until == null || end.isAfter(until))) until = end;
  }
  return (
    programmes: programmes,
    until: until,
    importing: importing,
    sourceIds: withGuide,
  );
}

/// The tidy-up of the database: Settings → Data's Watch history and
/// Database rows, and the launch's own (ADR-031).
@Riverpod(keepAlive: true)
DataUpkeep dataUpkeep(Ref ref) => DbDataUpkeep(ref.watch(appDatabaseProvider));

/// What was watched, as Settings → Data counts it.
@riverpod
Stream<HistoryCounts> historyCounts(Ref ref) =>
    ref.watch(dataUpkeepProvider).watchHistoryCounts();

/// The database file's size and free room; measured again after Compact.
@riverpod
Future<Result<DatabaseRoom>> databaseRoom(Ref ref) =>
    ref.watch(dataUpkeepProvider).measure();

/// Whether [state] holds a stream (or a cast) right now.
bool _plays(PlaybackState state) => switch (state) {
  PlaybackOpening() ||
  PlaybackPlaying() ||
  PlaybackReconnecting() ||
  PlaybackCasting() => true,
  PlaybackIdle() || PlaybackFailed() || PlaybackEnded() => false,
};

/// What keeps Compact from running now, as it changes; null when nothing
/// does. The player, never made, has played nothing; a TV has no
/// downloads.
@riverpod
UpkeepBlocker? compactBlocker(Ref ref) {
  if (ref.exists(playbackCoordinatorProvider)) {
    final state =
        ref.watch(playbackStateProvider).value ??
        ref.read(playbackCoordinatorProvider).state;
    if (_plays(state)) return UpkeepBlocker.playing;
  }
  for (final source in ref.watch(sourcesProvider).value ?? const <Source>[]) {
    if (ref.watch(syncStatusProvider(source.id)).value is SyncRunning) {
      return UpkeepBlocker.syncing;
    }
  }
  if (ref.watch(guideTotalsProvider)?.importing ?? false) {
    return UpkeepBlocker.importing;
  }
  if (ref.watch(formFactorProvider) == FormFactor.desktop &&
      ref.exists(downloadQueueProvider)) {
    final tasks = ref.watch(downloadTasksProvider).value ?? const [];
    if (tasks.any((task) => task.state.isActive)) {
      return UpkeepBlocker.downloading;
    }
  }
  return null;
}

/// What is at work at this moment, read once: the last look before a
/// compaction starts.
typedef UpkeepBlockerCheck = Future<UpkeepBlocker?> Function();

@Riverpod(keepAlive: true)
UpkeepBlockerCheck upkeepBlockerCheck(Ref ref) => () async {
  if (ref.exists(playbackCoordinatorProvider) &&
      _plays(ref.read(playbackCoordinatorProvider).state)) {
    return UpkeepBlocker.playing;
  }
  final sources =
      (await ref.read(sourceRepositoryProvider).all()).valueOrNull ??
      const <Source>[];
  final sync = ref.read(syncServiceProvider);
  if (sources.any((source) => sync.statusOf(source.id) is SyncRunning)) {
    return UpkeepBlocker.syncing;
  }
  final imports = ref.read(guideImportServiceProvider);
  if (sources.any((source) => imports.isImporting(source.id))) {
    return UpkeepBlocker.importing;
  }
  if (ref.exists(downloadQueueProvider)) {
    final tasks = ref.read(downloadQueueProvider).current;
    if (tasks.any((task) => task.state.isActive)) {
      return UpkeepBlocker.downloading;
    }
  }
  return null;
};

/// The launch's tidy-up; `bootstrap()` runs it once the launch's syncs
/// and guide imports are done.
@Riverpod(keepAlive: true)
LaunchTidyUp launchTidyUp(Ref ref) => LaunchTidyUp(
  upkeep: ref.watch(dataUpkeepProvider),
  blocker: ref.watch(upkeepBlockerCheckProvider),
  log: ref.watch(appLogProvider),
  clock: ref.watch(appClockProvider),
);

/// Asks where to save a file named [suggestedName]; null when the dialog
/// is closed.
typedef SaveFilePicker = Future<String?> Function(String suggestedName);

/// Asks for a file to open; null when the dialog is closed.
typedef OpenFilePicker = Future<String?> Function();

const _settingsFiles = XTypeGroup(
  label: 'Settings files',
  extensions: ['json'],
  mimeTypes: ['application/json'],
);

/// The system's Save dialog for a settings file. Tests override it.
@Riverpod(keepAlive: true)
SaveFilePicker settingsSavePicker(Ref ref) =>
    (suggestedName) async => (await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [_settingsFiles],
      confirmButtonText: 'Export',
    ))?.path;

/// The system's Open dialog for a settings file. Tests override it.
@Riverpod(keepAlive: true)
OpenFilePicker settingsOpenPicker(Ref ref) =>
    () async => (await openFile(
      acceptedTypeGroups: const [
        _settingsFiles,
        XTypeGroup(label: 'All files'),
      ],
      confirmButtonText: 'Import',
    ))?.path;
