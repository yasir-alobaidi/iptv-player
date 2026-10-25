import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/diagnostics/data/db_diagnostics.dart';
import 'package:iptv_player/features/diagnostics/domain/diagnostics_service.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnostics_providers.g.dart';

/// The app's log files, read off the UI isolate. `bootstrap()` gives the
/// real one; a run with no log file has none.
@Riverpod(keepAlive: true)
LogReader logReader(Ref ref) => const NoLogReader();

/// Settings → About & diagnostics' report.
@Riverpod(keepAlive: true)
DiagnosticsService diagnostics(Ref ref) => DbDiagnostics(
  db: ref.watch(appDatabaseProvider),
  version: () => ref.read(appVersionProvider.future),
  system: ref.watch(systemFactsReaderProvider),
  decoders: ref.watch(decoderNotesProvider),
  log: ref.watch(logReaderProvider),
  secrets: ref.watch(secretRegistryProvider),
  player: ref.watch(playerEngineProvider),
  castFolder: ref.watch(castFolderProvider),
  exits: ref.watch(lastExitsProvider),
  homeFolder:
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'],
  clock: ref.watch(appClockProvider),
);

/// The report as the page shows it: made when the page opens, and again
/// when asked.
@riverpod
Future<Result<String>> diagnosticsReport(Ref ref) =>
    ref.watch(diagnosticsProvider).report();

/// Asks where to save the report; null when the dialog is closed.
typedef ReportSavePicker = Future<String?> Function(String suggestedName);

/// The system's Save dialog for the report. Tests override it.
@Riverpod(keepAlive: true)
ReportSavePicker reportSavePicker(Ref ref) =>
    (suggestedName) async => (await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Text files', extensions: ['txt']),
      ],
      confirmButtonText: 'Save',
    ))?.path;
