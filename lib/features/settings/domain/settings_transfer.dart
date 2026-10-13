import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:meta/meta.dart';

/// What an export wrote.
@immutable
final class ExportSummary {
  const new({
    required this.path,
    required this.sources,
    required this.favorites,
    required this.bytes,
  });

  final String path;
  final int sources;
  final int favorites;
  final int bytes;
}

/// One source of a settings file, and the source it belongs to here.
@immutable
final class ImportSourcePlan {
  const new({required this.exported, this.sourceId, this.sourceName});

  final ExportedSource exported;

  /// The source on this computer the file's source is; null when it
  /// isn't here, and then nothing of it is imported.
  final String? sourceId;

  /// That source's name here.
  final String? sourceName;

  bool get isHere => sourceId != null;
}

/// What an import will do, shown before it does it (Phase 9 decision 6).
@immutable
final class ImportPlan {
  const new({required this.path, required this.file, required this.sources});

  final String path;
  final SettingsExport file;
  final List<ImportSourcePlan> sources;

  /// The settings pages the file carries, which replace this computer's.
  List<String> get settingsPages => file.settings.keys.toList();

  bool get replacesSettings => file.settings.isNotEmpty;

  List<ImportSourcePlan> get here => [
    for (final source in sources)
      if (source.isHere) source,
  ];

  List<ImportSourcePlan> get missing => [
    for (final source in sources)
      if (!source.isHere) source,
  ];

  /// True when applying it would change nothing at all.
  bool get isEmpty => !replacesSettings && here.isEmpty;
}

/// What reading a file gave.
sealed class SettingsFileRead {
  const new();
}

/// The file can be imported: [plan] says what that will do.
final class SettingsFileReadable extends SettingsFileRead {
  const new(this.plan);

  final ImportPlan plan;
}

/// The file is damaged, isn't one of ours, or is from a newer version.
final class SettingsFileUnusable extends SettingsFileRead {
  const new(this.problem, {this.format});

  final SettingsFileProblem problem;
  final int? format;
}

/// The file couldn't be opened, or this computer's sources couldn't be
/// read to compare it with.
final class SettingsFileUnread extends SettingsFileRead {
  const new(this.failure);

  final AppFailure failure;
}

/// What an import changed.
@immutable
final class ImportSummary {
  const new({
    required this.settingsPages,
    required this.sources,
    required this.skippedSources,
    required this.favorites,
    required this.categories,
    required this.channels,
    required this.guideMatches,
    required this.reminders,
    required this.notHere,
  });

  /// The settings pages replaced.
  final List<String> settingsPages;

  /// Sources whose choices were merged in, and sources of the file that
  /// aren't on this computer.
  final int sources;
  final int skippedSources;

  final int favorites;
  final int categories;
  final int channels;
  final int guideMatches;
  final int reminders;

  /// Categories and channels the file names that this computer's copy of
  /// the source doesn't have (the provider's list changed): left out.
  final int notHere;

  /// The ids of the sources whose guide matches changed, to match again.
  bool get changedAnything => settingsPages.isNotEmpty || sources > 0;
}

/// Settings → Data's Export… and Import… (Phase 9 decision 6): the
/// settings and the user's choices, never a password, a username or an
/// address; an import adds no source.
abstract interface class SettingsTransfer {
  /// Writes everything to [path], replacing a file already there.
  Future<Result<ExportSummary>> exportTo(String path);

  /// Reads [path] and works out what importing it would do. Changes
  /// nothing.
  Future<SettingsFileRead> read(String path);

  /// Applies [plan] whole, or not at all.
  Future<Result<ImportSummary>> apply(ImportPlan plan);
}
