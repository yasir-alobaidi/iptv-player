import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/settings/domain/data_upkeep.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';

// Every sentence of Settings → Data, in one place (sketch C).

/// "412 MB", "1.2 GB", "77 MB": a whole number from 100 of a unit up, and
/// no ".0" under it.
String dataSize(int bytes) {
  const units = ['bytes', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes bytes';
  final tenths = size.toStringAsFixed(1);
  final number = size >= 100 || tenths.endsWith('.0')
      ? '${size.round()}'
      : tenths;
  return '$number ${units[unit]}';
}

String _plural(int count, String one, [String? many]) =>
    '${formatCount(count)} ${count == 1 ? one : many ?? '${one}s'}';

/// Under Pictures: what is kept, of how much, on [device] ("this
/// computer", "this TV").
String picturesLine({
  required int bytes,
  required int maxBytes,
  String device = 'this computer',
}) {
  final what = picturesKept(device);
  if (bytes <= 0) return '$what None are kept right now.';
  if (maxBytes <= 0) return '$what ${dataSize(bytes)}.';
  return '$what ${dataSize(bytes)} of ${dataSize(maxBytes)}.';
}

/// What Pictures is about, on [device].
String picturesKept(String device) =>
    'Posters, logos and stills kept on $device.';

/// Under Guide: what there is, and what Clear leaves.
String guideLine({
  required int programmes,
  required DateTime? until,
  required bool importing,
  String device = 'this computer',
}) {
  if (importing) {
    return 'A guide is being imported. It can be cleared once that is done.';
  }
  if (programmes <= 0) return 'There is no guide on $device.';
  final upTo = until == null ? '' : ' until ${formatShortDate(until)}';
  return '${_plural(programmes, 'programme')}$upTo. Your channel matches '
      'are kept, and the guide comes back at its next refresh.';
}

/// "12 channels, 38 films and episodes".
String _watched(HistoryCounts counts) => [
  if (counts.channels > 0) _plural(counts.channels, 'channel'),
  if (counts.titles > 0) _titles(counts.titles),
].join(', ');

String _titles(int count) => count == 1
    ? '1 film or episode'
    : '${formatCount(count)} films and episodes';

/// Under Watch history: what there is, and how long it is kept (ADR-031).
String historyLine(HistoryCounts counts, {String device = 'this computer'}) {
  if (counts.channels + counts.titles <= 0) {
    return 'Nothing watched on $device yet.';
  }
  return '${_watched(counts)}. Channels are forgotten after '
      '${Upkeep.channels.inDays ~/ 30} months unwatched, finished films and '
      'episodes after ${Upkeep.finished.inDays ~/ 30} months.';
}

/// Under Watch history while it is counted.
String historyCounting(String device) =>
    'Counting what was watched on $device…';

/// Each of Clear watch history's choices: its title, and what it holds.
String historyChoiceTitle(HistoryChoice choice) => switch (choice) {
  HistoryChoice.channels => 'Recently watched channels',
  HistoryChoice.titles => 'Continue watching and watched marks',
  HistoryChoice.everything => 'Everything',
};

/// Whether [choice] holds nothing to clear, by [counts]; never when they
/// couldn't be read.
bool historyChoiceEmpty(HistoryChoice choice, HistoryCounts? counts) =>
    switch ((choice, counts)) {
      (_, null) => false,
      (HistoryChoice.channels, final counts?) => counts.channels <= 0,
      (HistoryChoice.titles, final counts?) => counts.titles <= 0,
      (HistoryChoice.everything, final counts?) =>
        counts.channels + counts.titles <= 0,
    };

/// [counts] null: they couldn't be read, so no numbers.
String historyChoiceLine(HistoryChoice choice, HistoryCounts? counts) {
  if (historyChoiceEmpty(choice, counts)) return 'Nothing to clear';
  return switch (choice) {
    HistoryChoice.channels =>
      '${counts == null ? 'Channels' : _plural(counts.channels, 'channel')}'
          ', on Home and for Last channel',
    HistoryChoice.titles =>
      '${counts == null ? 'Films and episodes' : _titles(counts.titles)}'
          ', started or finished',
    HistoryChoice.everything => 'Channels, films and episodes',
  };
}

const clearHistoryKeeps = 'Your favorites, sources and settings stay.';

/// The toast after Clear watch history.
String historyCleared(HistoryChoice choice) => switch (choice) {
  HistoryChoice.everything => 'Watch history cleared',
  _ => '${historyChoiceTitle(choice)} cleared',
};

/// What the Database row is about, on [device].
String databaseKept(String device) =>
    'Your sources, catalogues, guide and history on $device';

/// Free room under this isn't worth a mention.
const int _roomWorthSaying = 1024 * 1024;

/// Under Database: its size, and the room Compact would give back.
String databaseLine(DatabaseRoom room, {String device = 'this computer'}) {
  final size = '${databaseKept(device)}: ${dataSize(room.bytes)}';
  return room.freeBytes >= _roomWorthSaying
      ? '$size, ${dataSize(room.freeBytes)} of it unused. Compact gives that '
            'room back.'
      : '$size.';
}

/// Why Compact is off just now.
String compactWaits(UpkeepBlocker blocker) =>
    'It can be compacted once ${switch (blocker) {
      UpkeepBlocker.playing => 'nothing is playing',
      UpkeepBlocker.syncing => 'the sync is done',
      UpkeepBlocker.importing => 'the guide is imported',
      UpkeepBlocker.downloading => 'the downloads are done',
    }}.';

/// Under Database while Compact works: everything else waits for it.
String databaseCompacting(String device) =>
    '${databaseKept(device)}. Compacting it now; lists may open slowly '
    'until it is done.';

/// The toast after Compact.
String databaseCompacted(Compacted sizes) => sizes.after < sizes.before
    ? 'Database compacted · ${dataSize(sizes.before)} → '
          '${dataSize(sizes.after)}'
    : 'Database compacted · ${dataSize(sizes.after)}';

const exportDescription =
    'Settings, favorites and groups, hidden and renamed channels and '
    'categories, guide matches and reminders, as one file for another '
    'computer. Never passwords, usernames or addresses.';

/// What Clear's dialog says before it clears.
String clearPicturesBody(int bytes, {String device = 'this computer'}) =>
    '${bytes > 0 ? '${dataSize(bytes)} of pictures' : 'Every kept picture'} '
    'will be deleted from $device. They are fetched again as you browse.';

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
        "This isn't a settings file from $appName. Choose a file made "
            'with Export… on Settings → Data.',
      SettingsFileProblem.newer =>
        'This file was made by a newer version of $appName'
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
