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
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/design/fonts.dart';
import 'package:logger/logger.dart';

/// Sets up logging and the global error handlers, then starts the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();

  final secrets = SecretRegistry();
  final outputs = <LogOutput>[if (kDebugMode) ConsoleOutput()];
  Object? logDirError;
  try {
    final paths = await AppPaths.resolve();
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

  // Step 5 swaps this for the settings-table store; until then the
  // window opens at its default size every run.
  final windowBounds = InMemoryWindowBoundsStore();
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
        windowBoundsStoreProvider.overrideWithValue(windowBounds),
      ],
      child: const IptvPlayerApp(),
    ),
  );
}
