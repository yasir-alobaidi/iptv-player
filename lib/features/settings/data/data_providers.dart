import 'package:file_selector/file_selector.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_store.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/settings/data/db_settings_transfer.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'data_providers.g.dart';

/// Settings → Data's Export… and Import….
@Riverpod(keepAlive: true)
SettingsTransfer settingsTransfer(Ref ref) => DbSettingsTransfer(
  ref.watch(appDatabaseProvider),
  appVersion: ref.watch(appVersionProvider).value?.short ?? '',
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
