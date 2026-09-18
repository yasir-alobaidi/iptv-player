import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/app/window_setup.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/rotating_file_output.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/app_paths.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/secure/secure_credential_store.dart';
import 'package:iptv_player/data/settings/db_ui_preferences.dart';
import 'package:iptv_player/data/settings/db_window_bounds_store.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/design/fonts.dart';
import 'package:logger/logger.dart';

/// Sets up logging and the global error handlers, then starts the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();

  final secrets = SecretRegistry();
  final outputs = <LogOutput>[if (kDebugMode) ConsoleOutput()];
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
  log.info('bootstrap', 'Starting IPTV Player');

  final database = await _openDatabase(paths, log);
  final settings = SettingsRepository(database);
  final windowBounds = DbWindowBoundsStore(settings);
  final uiPreferences = await _loadUiPreferences(settings, log);

  try {
    await AppWindow(store: windowBounds, log: log).setUp();
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

  runApp(
    ProviderScope(
      overrides: [
        appLogProvider.overrideWithValue(log),
        secretRegistryProvider.overrideWithValue(secrets),
        errorReporterProvider.overrideWithValue(errors),
        appDatabaseProvider.overrideWithValue(database),
        credentialStoreProvider.overrideWithValue(SecureCredentialStore()),
        windowBoundsStoreProvider.overrideWithValue(windowBounds),
        uiPreferencesProvider.overrideWithValue(uiPreferences),
      ],
      child: const IptvPlayerApp(),
    ),
  );
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
    final database = AppDatabase(openAppDatabase(paths.root));
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
