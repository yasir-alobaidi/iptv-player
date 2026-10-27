import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/quit.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/app/window_setup.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/images/artwork_providers.dart';
import 'package:iptv_player/core/images/artwork_store.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/launch_mark.dart';
import 'package:iptv_player/core/logging/rotating_file_output.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/app_paths.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/core/platform/run_logs.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/core/platform/tool_licenses.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/player/unavailable_player_engine.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/data/cast/relay/relay_folders.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';
import 'package:iptv_player/data/images/cached_artwork.dart';
import 'package:iptv_player/data/images/cached_artwork_store.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/platform/android_display_modes.dart';
import 'package:iptv_player/data/platform/android_last_exits.dart';
import 'package:iptv_player/data/platform/android_run_logs.dart';
import 'package:iptv_player/data/platform/android_system_facts.dart';
import 'package:iptv_player/data/platform/file_reveals.dart';
import 'package:iptv_player/data/platform/system_facts_readers.dart';
import 'package:iptv_player/data/platform/system_networks.dart';
import 'package:iptv_player/data/platform/system_notifiers.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/data/secure/secure_credential_store.dart';
import 'package:iptv_player/data/settings/db_ui_preferences.dart';
import 'package:iptv_player/data/settings/db_window_bounds_store.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/design/focus/focus_visibility.dart';
import 'package:iptv_player/design/fonts.dart';
import 'package:iptv_player/features/casting/data/artwork_cast_pictures.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/presentation/cast_shell_slots.dart';
import 'package:iptv_player/features/diagnostics/data/diagnostics_providers.dart';
import 'package:iptv_player/features/diagnostics/data/file_log_reader.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/presentation/download_actions.dart';
import 'package:iptv_player/features/guide/data/db_guide_settings_store.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/playback/data/db_playback_settings_store.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/presentation/player_sound.dart';
import 'package:iptv_player/features/playback/presentation/tv_away.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_watch.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';
import 'package:iptv_player/features/settings/data/data_providers.dart';
import 'package:iptv_player/features/settings/data/db_appearance_store.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:logger/logger.dart';

/// Sets up logging and the global error handlers, then starts the app.
/// [args] are `main`'s: on Android the activity names the form factor
/// ([detectFormFactor], ADR-068).
Future<void> bootstrap({List<String> args = const []}) async {
  final sinceMain = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  registerToolLicenses();

  final secrets = SecretRegistry();
  // On Android logcat has the log too, and the file is where adb reads it
  // (`AppPaths.logs`, ADR-027); the lines are redacted before any output
  // sees them.
  final outputs = <LogOutput>[
    if (kDebugMode || Platform.isAndroid) ConsoleOutput(),
  ];
  AppPaths? paths;
  Object? logDirError;
  try {
    paths = await AppPaths.resolve();
    outputs.add(RotatingFileOutput(directory: paths.logs));
  } on Object catch (error) {
    // Keep running without a log file rather than failing to start.
    logDirError = error;
  }
  final log = AppLog(
    output: MultiOutput(outputs),
    secrets: secrets,
    level: kDebugMode ? Level.debug : Level.info,
  );
  if (logDirError != null) {
    log.warning('bootstrap', 'No log file', error: logDirError);
  }

  final errors = ErrorReporter(log)..install();
  log.info('bootstrap', 'Starting $appName');

  final database = await _openDatabase(paths, log);
  final settings = SettingsRepository(database);
  final windowBounds = DbWindowBoundsStore(settings);
  final uiPreferences = await _loadUiPreferences(settings, log);
  // Before the first frame, so the app never opens in one look and
  // changes to another (Phase 9 decision 2).
  final appearance = await DbAppearanceStore.open(settings);
  if (appearance.readFailure case final failure?) {
    log.warning('bootstrap', 'Could not read the appearance: $failure');
  }
  final firstRun = await _hasNoSources(database, log);

  // The TV is the player: no casting, no downloads, no library, no
  // FFmpeg (docs/07); a phone or tablet neither (ADR-068).
  final formFactor = detectFormFactor(
    platform: defaultTargetPlatform,
    args: args,
  );
  final onDesktop = formFactor.isDesktop;
  log.info('bootstrap', 'Form factor: ${formFactor.name}');
  if (!formFactor.isTv) {
    // The rings are the keyboard's: a click or a touch focuses what it
    // pressed and hides them, the next key shows them (as a browser does).
    FocusVisibility.install();
  } else {
    // Android starts in touch mode, which draws no focus; a remote has
    // no touch, and focus is all a TV shows of where you are (docs/07).
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }

  // A window of its own only on a desktop system; on Android the
  // activity is the window (`FORM_FACTOR=tv` on the laptop keeps it).
  final window = _hasDesktopWindow
      ? AppWindow(store: windowBounds, log: log)
      : null;
  try {
    await window?.setUp();
  } on Object catch (error, stackTrace) {
    // A window we could not size still opens; failing to start would be
    // worse than a wrong size.
    log.warning(
      'bootstrap',
      'Could not set the window up',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // The guide's switch (ADR-031), before the first frame: the rail never
  // gains its Guide a moment after launch.
  final guideSettings = (await DbGuideSettingsStore(
    settings,
    defaults: GuideSettings.defaultsOn(formFactor),
  ).load()).valueOrNull;

  // What the user chose for the decoder, before the player is made: its
  // video controller sets `hwdec` once by itself (Phase 9 decision 4).
  final playback =
      (await DbPlaybackSettingsStore(settings).load()).valueOrNull ??
      const PlaybackSettings();
  final player = await _createPlayer(
    log,
    secrets,
    hardwareDecoding: playback.hardwareDecoding,
  );
  capDecodedImages(
    PaintingBinding.instance.imageCache,
    bytes: onDesktop ? decodedArtworkBytes : decodedArtworkBytesOnTv,
  );
  final artwork = paths == null
      ? null
      : ArtworkCache(
          directory: paths.artwork,
          maxBytes: onDesktop ? artworkDiskBytes : artworkDiskBytesOnTv,
        );

  final container = ProviderContainer(
    overrides: [
      playerEngineProvider.overrideWithValue(player),
      formFactorProvider.overrideWithValue(formFactor),
      // A TV's display, for Match frame rate (ADR-035); the desktop's,
      // the laptop's `FORM_FACTOR=tv` and a phone's have none to ask.
      if (formFactor.isTv && Platform.isAndroid)
        displayModesProvider.overrideWithValue(AndroidDisplayModes(log: log)),
      // Why the last runs ended, and how the screen is drawn (ADR-058).
      if (!onDesktop && Platform.isAndroid)
        lastExitsProvider.overrideWithValue(AndroidLastExits(log: log)),
      // Each run's own log, for the report a phone takes, and the version
      // from the package: an APK has no `version.json` (ADR-059). A phone
      // or tablet's too (ADR-068).
      if (!onDesktop && Platform.isAndroid) ...[
        runLogsProvider.overrideWithValue(AndroidRunLogs(log: log)),
        appVersionProvider.overrideWith((_) => androidAppVersion()),
      ],
      if (window != null)
        windowControlsProvider.overrideWithValue(const WindowManagerControls()),
      fileRevealProvider.overrideWithValue(platformFileReveal(log)),
      systemNetworkProvider.overrideWithValue(platformSystemNetwork(log)),
      systemFactsReaderProvider.overrideWithValue(platformSystemFacts()),
      systemNotificationsProvider.overrideWithValue(
        platformSystemNotifier(log),
      ),
      if (paths != null)
        logReaderProvider.overrideWithValue(
          FileLogReader(directory: paths.logs),
        ),
      appLogProvider.overrideWithValue(log),
      secretRegistryProvider.overrideWithValue(secrets),
      errorReporterProvider.overrideWithValue(errors),
      launchMarkProvider.overrideWithValue(LaunchMark(log, sinceMain)),
      appDatabaseProvider.overrideWithValue(database),
      credentialStoreProvider.overrideWithValue(SecureCredentialStore()),
      windowBoundsStoreProvider.overrideWithValue(windowBounds),
      uiPreferencesProvider.overrideWithValue(uiPreferences),
      appearanceStoreProvider.overrideWithValue(appearance),
      launchGuideSettingsProvider.overrideWithValue(guideSettings),
      startLocationProvider.overrideWithValue(
        firstRun ? welcomeRoutePath : '/',
      ),
      if (artwork != null) ...[
        artworkStoreProvider.overrideWithValue(CachedArtworkStore(artwork)),
        artworkImagesProvider.overrideWithValue(CachedArtworkImages(artwork)),
        castPicturesProvider.overrideWithValue(ArtworkCastPictures(artwork)),
      ],
      if (paths != null) ...[
        processFolderProvider.overrideWithValue(paths.processes),
        castFolderProvider.overrideWithValue(paths.cast),
        relayFolderProvider.overrideWithValue(paths.relay),
        libraryThumbnailFolderProvider.overrideWithValue(paths.thumbnails),
      ],
      ...sourceShellOverrides,
      // A TV is the player: no Cast button, bar or view (docs/07); a
      // phone has no FFmpeg for the relay (ADR-068).
      if (onDesktop) ...castShellOverrides,
      ...downloadShellOverrides,
      if (Platform.isWindows)
        relayFirewallNoticeProvider.overrideWith(
          (ref) => windowsFirewallNotice(
            ref.read(castFirewallNoticeStoreProvider),
            () => ref
                .read(routerProvider)
                .routerDelegate
                .navigatorKey
                .currentContext,
          ),
        ),
    ],
  );
  if (onDesktop) {
    // Before anything starts a process: FFmpeg or ffprobe left running by
    // a run that didn't get to stop them (hard rule 8).
    // Then the relay's segments from those runs (docs/04 "On app start").
    unawaited(
      container
          .read(processSupervisorProvider)
          .sweep()
          .then(
            (_) => sweepRelayFolders(
              container.read(relayFolderProvider),
              log: log,
            ),
          ),
    );
    // The cast's quiet fallbacks and unexpected ends, as toasts.
    container.read(castNoticeToastsProvider);
  } else {
    WidgetsBinding.instance.addObserver(
      TvAwayObserver(container.read(playbackCoordinatorProvider)),
    );
  }
  window?.beforeClose = () => quitApp(container, log);
  container
    // What each play says about the network, for "You're offline".
    ..read(playbackReachabilityProvider)
    // The volume as the user left it, before the first thing plays.
    ..read(playerSoundControllerProvider);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const IptvPlayerApp(),
    ),
  );
  _syncAfterLaunch(container, artwork, onDesktop: onDesktop);
}

/// Linux, Windows and macOS: a window the app sizes, titles and closes.
bool get _hasDesktopWindow =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Waits for Home's rows on screen ([LaunchMark.settled]; at most
/// [_launchHomeCap] for a launch that opens elsewhere) and a moment
/// after, so starting up never competes with a sync, then gives channels
/// synced before schema v7 their cleaned names (once), records runs the
/// last session left unfinished and refreshes sources older than their
/// `refresh_hours` (docs/02), then imports the guides that are due. The
/// fill, the sync and the import each run in a background isolate.
///
/// A guide import the last session was killed during is recorded the
/// same way, and the rows it staged go with it: they are the one thing
/// an interrupted import leaves behind (Phase 4 decision 2).
///
/// Downloads and the library are the desktop's ([onDesktop]): a TV has
/// neither (docs/07).
void _syncAfterLaunch(
  ProviderContainer container,
  ArtworkCache? artwork, {
  required bool onDesktop,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      Future<void>(() async {
        // Home's reads first: a sync's batches went before them on the
        // Bedroom TV (Home 19.9 s after main()).
        await container.read(launchMarkProvider).settled(cap: _launchHomeCap);
        await Future<void>.delayed(_launchSyncDelay);
        // In its own isolate: the picture cache's size cap (docs/06).
        unawaited(artwork?.sweep());
        // Reminders that fell due while the app was closed show now, if
        // their programmes are still on; then the scheduler keeps watch
        // (Phase 9 decision 10). Before the syncs: it reads only its own
        // table.
        // Watch on a reminder plays its channel, from before the first
        // one can show.
        container.read(reminderWatchesProvider);
        unawaited(container.read(reminderServiceProvider).start());
        if (onDesktop) {
          // The download folder is a library folder (docs/09), and what
          // was downloading when the app went picks up again.
          await _registerDownloadFolder(container);
          // The queue's news as toasts, from before it starts.
          container.read(downloadToastsProvider);
          await container.read(downloadQueueProvider).startUp();
          // The library's folders: scanned now, watched from then on.
          unawaited(container.read(libraryScansProvider).startUp());
        }
        await container.read(epgRepositoryProvider).recoverInterrupted();
        // Before the syncs, which write names of their own (ADR-013).
        await container.read(channelNameFillProvider).run();
        await container.read(syncServiceProvider).startUp();
        // Guides after the syncs, never beside them (ADR-011 decision 5).
        await container.read(guideSchedulerProvider).startUp();
        // Last, once: old history and run records go, and the file gives
        // back the room they and a cleared guide left, if nothing is at
        // work (ADR-031). It logs and swallows its own failures.
        await container.read(launchTidyUpProvider).run();
      }),
    );
  });
}

const _launchSyncDelay = Duration(seconds: 2);
const _launchHomeCap = Duration(seconds: 15);

Future<void> _registerDownloadFolder(ProviderContainer container) async {
  final log = container.read(appLogProvider);
  try {
    final path = await container.read(downloadFolderProvider.future);
    final registered = await registerDownloadFolder(
      container.read(appDatabaseProvider).libraryDao,
      path,
      now: DateTime.now().toUtc(),
    );
    if (registered.failureOrNull case final failure?) {
      log.warning('bootstrap', 'Download folder not registered: $failure');
    }
  } on Object catch (error) {
    log.warning('bootstrap', 'No download folder', error: error);
  }
}

/// The one player (docs/03). A libmpv that won't start leaves the app
/// running without playback rather than not running (hard rule 1).
Future<PlayerEngine> _createPlayer(
  AppLog log,
  SecretRegistry secrets, {
  required bool hardwareDecoding,
}) async {
  try {
    return await MediaKitPlayerEngine.create(
      log: log,
      secrets: secrets,
      hardwareDecoding: hardwareDecoding,
    );
  } on Object catch (error, stackTrace) {
    log.error(
      'bootstrap',
      'The video player could not start',
      error: error,
      stackTrace: stackTrace,
    );
    return UnavailablePlayerEngine('$error');
  }
}

/// Opens the database file, or falls back to a temporary in-memory one so
/// a broken file can't stop the app from starting (hard rule 1). The file
/// itself is left untouched, so the next launch can still recover it.
Future<AppDatabase> _openDatabase(AppPaths? paths, AppLog log) async {
  if (paths == null) {
    log.warning('bootstrap', 'No app directory; nothing will be saved');
    return AppDatabase.memory();
  }
  try {
    final database = AppDatabase(await openAppDatabase(paths.root));
    // LazyDatabase opens on the first query. Running one here means a
    // broken file is reported now, not during the first frame.
    await database.settingsDao.read(SettingsKeys.windowBounds);
    return database;
  } on Object catch (error, stackTrace) {
    log.error(
      'bootstrap',
      'Could not open the database; nothing will be saved',
      error: error,
      stackTrace: stackTrace,
    );
    return AppDatabase.memory();
  }
}

/// True when no source is configured, so the app opens on Welcome rather
/// than an empty Home (docs/05). Read before the first frame, so the
/// window never shows one and then jumps to the other.
Future<bool> _hasNoSources(AppDatabase database, AppLog log) async {
  try {
    return (await database.sourcesDao.all()).isEmpty;
  } on Object catch (error, stackTrace) {
    log.warning(
      'bootstrap',
      'Could not read the sources',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}

/// Reads the remembered UI choices before the first frame, so the shell
/// draws the right rail immediately instead of flipping after a frame.
Future<UiPreferences> _loadUiPreferences(
  SettingsRepository settings,
  AppLog log,
) async {
  try {
    return await DbUiPreferences.load(settings);
  } on Object catch (error, stackTrace) {
    log.warning(
      'bootstrap',
      'Could not read the saved UI preferences',
      error: error,
      stackTrace: stackTrace,
    );
    return InMemoryUiPreferences();
  }
}
