import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';

// Every sentence of Settings → Data, in one place (sketch C).

/// "412 MB", "1.2 GB": a whole number from 100 of a unit up.
String dataSize(int bytes) {
  const units = ['bytes', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes bytes';
  return '${size >= 100 ? size.round() : size.toStringAsFixed(1)} '
      '${units[unit]}';
}

String _plural(int count, String one, [String? many]) =>
    '${formatCount(count)} ${count == 1 ? one : many ?? '${one}s'}';

/// Under Pictures: what is kept, of how much.
String picturesLine({required int bytes, required int maxBytes}) {
  const what = 'Posters, logos and stills kept on this computer.';
  if (bytes <= 0) return '$what None are kept right now.';
  if (maxBytes <= 0) return '$what ${dataSize(bytes)}.';
  return '$what ${dataSize(bytes)} of ${dataSize(maxBytes)}.';
}

/// Under Guide: what there is, and what Clear leaves.
String guideLine({
  required int programmes,
  required DateTime? until,
  required bool importing,
}) {
  if (importing) {
    return 'A guide is being imported. It can be cleared once that is done.';
  }
  if (programmes <= 0) return 'There is no guide on this computer.';
  final upTo = until == null ? '' : ' until ${formatShortDate(until)}';
  return '${_plural(programmes, 'programme')}$upTo. Your channel matches '
      'are kept, and the guide comes back at its next refresh.';
}

const exportDescription =
    'Settings, favorites and groups, hidden and renamed channels and '
    'categories, guide matches and reminders, as one file for another '
    'computer. Never passwords, usernames or addresses.';

/// What Clear's dialog says before it clears.
String clearPicturesBody(int bytes) =>
    '${bytes > 0 ? '${dataSize(bytes)} of pictures' : 'Every kept picture'} '
    'will be deleted from this computer. They are fetched again as you '
    'browse.';

const clearGuideBody =
    'Every programme goes, for every source. Your channel matches stay, '
    'and the guide comes back at its next refresh.';

/// The toast after Clear.
String picturesCleared(int bytes) => bytes > 0
    ? 'Pictures cleared · ${dataSize(bytes)} freed'
    : 'Pictures cleared';

/// The toast after an export.
String exportDone(ExportSummary summary) => [
  'Exported your settings and choices',
  if (summary.sources > 0) _plural(summary.sources, 'source'),
  if (summary.favorites > 0) _plural(summary.favorites, 'favorite'),
].join(' · ');

/// Why a file can't be imported, in the dialog that says so.
String fileProblem(SettingsFileProblem problem, {int? format}) =>
    switch (problem) {
      SettingsFileProblem.damaged =>
        "The file is damaged or incomplete: it can't be read as a "
            'settings file. Export it again on the other computer.',
      SettingsFileProblem.notOurs =>
        "This isn't a settings file from IPTV Player. Choose a file made "
            'with Export… on Settings → Data.',
      SettingsFileProblem.newer =>
        'This file was made by a newer version of IPTV Player'
            '${format == null ? '' : ' (format $format)'}. Update this '
            'app, then import it.',
    };

/// One source's line in the preview: what of it will be merged in.
String importSourceLine(ExportedSource source) {
  final parts = [
    if (source.favorites.isNotEmpty)
      _plural(source.favorites.length, 'favorite'),
    if (source.favoriteGroups.isNotEmpty)
      _plural(source.favoriteGroups.length, 'group'),
    if (source.hiddenCategories > 0)
      _plural(source.hiddenCategories, 'hidden category', 'hidden categories'),
    if (source.renamedCategories > 0)
      _plural(
        source.renamedCategories,
        'renamed category',
        'renamed categories',
      ),
    if (source.hiddenChannels > 0)
      _plural(source.hiddenChannels, 'hidden channel'),
    if (source.renamedChannels > 0)
      _plural(source.renamedChannels, 'renamed channel'),
    if (source.guideMatches.isNotEmpty)
      _plural(source.guideMatches.length, 'guide match', 'guide matches'),
    if (source.reminders.isNotEmpty)
      _plural(source.reminders.length, 'reminder'),
  ];
  return parts.isEmpty ? 'nothing to bring over' : parts.join(' · ');
}

const importMissingLine =
    'not on this computer — add it under Sources, then import again';

const importSettingsLine = "replaced with the file's";

/// The toast after an import.
String importDone(ImportSummary summary) {
  final parts = [
    if (summary.settingsPages.isNotEmpty) 'settings replaced',
    if (summary.sources > 0) '${_plural(summary.sources, 'source')} merged in',
    if (summary.favorites > 0) _plural(summary.favorites, 'favorite'),
    if (summary.guideMatches > 0)
      _plural(summary.guideMatches, 'guide match', 'guide matches'),
    if (summary.skippedSources > 0)
      '${_plural(summary.skippedSources, 'source')} not on this computer',
  ];
  return parts.isEmpty
      ? 'Nothing to import'
      : 'Imported · ${parts.join(' · ')}';
}
