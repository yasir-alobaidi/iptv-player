import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/rotating_file_output.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/app_paths.dart';
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

  runApp(
    ProviderScope(
      overrides: [
        appLogProvider.overrideWithValue(log),
        secretRegistryProvider.overrideWithValue(secrets),
        errorReporterProvider.overrideWithValue(errors),
      ],
      child: const IptvPlayerApp(),
    ),
  );
}
