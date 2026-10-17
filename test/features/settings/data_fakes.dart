import 'dart:async';

import 'package:iptv_player/core/images/artwork_store.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/settings/domain/data_upkeep.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';

const int _mb = 1024 * 1024;

/// The database's tidy-up, as a test scripts it: 12 channels and 38
/// titles watched, 77 MB with 25 MB free, compacted to 52 MB.
final class FakeDataUpkeep implements DataUpkeep {
  HistoryCounts _counts = (channels: 12, titles: 38);
  final _changes = StreamController<HistoryCounts>.broadcast();
  AppFailure? countsFailure;

  DatabaseRoom room = const DatabaseRoom(
    bytes: 77 * _mb,
    pagesBytes: 77 * _mb,
    freeBytes: 25 * _mb,
  );
  AppFailure? measureFailure;
  int measures = 0;

  /// Holds [measure] until completed.
  Completer<void>? measureGate;

  /// What a compaction leaves.
  int compactedTo = 52 * _mb;
  AppFailure? compactFailure;
  int compactions = 0;
  int trims = 0;

  /// Holds [compact] until completed.
  Completer<void>? compactGate;

  final cleared = <HistoryChoice>[];
  AppFailure? clearFailure;

  final pruned = <DateTime>[];
  AppFailure? pruneFailure;

  /// Thrown by [prune] instead of answering: a bug, not a failure.
  Error? pruneThrows;

  HistoryCounts get counts => _counts;
  set counts(HistoryCounts value) {
    _counts = value;
    _changes.add(value);
  }

  @override
  Future<Result<TidyCounts>> prune(DateTime now) async {
    if (pruneThrows case final error?) throw error;
    pruned.add(now);
    if (pruneFailure case final failure?) return Err(failure);
    return const Ok((channels: 4, titles: 2, syncRuns: 7, guideImports: 3));
  }

  @override
  Stream<HistoryCounts> watchHistoryCounts() => Stream.multi((listener) {
    if (countsFailure case final failure?) {
      listener
        ..addError(failure)
        ..closeSync();
      return;
    }
    listener.add(_counts);
    final changes = _changes.stream.listen(listener.add);
    listener.onCancel = changes.cancel;
  });

  @override
  Future<Result<int>> clearHistory(HistoryChoice what) async {
    if (clearFailure case final failure?) return Err(failure);
    cleared.add(what);
    final gone = switch (what) {
      HistoryChoice.channels => _counts.channels,
      HistoryChoice.titles => _counts.titles,
      HistoryChoice.everything => _counts.channels + _counts.titles,
    };
    counts = switch (what) {
      HistoryChoice.channels => (channels: 0, titles: _counts.titles),
      HistoryChoice.titles => (channels: _counts.channels, titles: 0),
      HistoryChoice.everything => (channels: 0, titles: 0),
    };
    return Ok(gone);
  }

  @override
  Future<Result<DatabaseRoom>> measure() async {
    measures++;
    if (measureGate case final gate?) await gate.future;
    if (measureFailure case final failure?) return Err(failure);
    return Ok(room);
  }

  @override
  Future<Result<Compacted>> compact() async {
    compactions++;
    if (compactGate case final gate?) await gate.future;
    if (compactFailure case final failure?) return Err(failure);
    final before = room.bytes;
    room = DatabaseRoom(
      bytes: compactedTo,
      pagesBytes: compactedTo,
      freeBytes: 0,
    );
    return Ok((before: before, after: compactedTo));
  }

  @override
  Future<Result<Compacted>> trimLog() async {
    trims++;
    final before = room.bytes;
    room = DatabaseRoom(
      bytes: room.pagesBytes,
      pagesBytes: room.pagesBytes,
      freeBytes: room.freeBytes,
    );
    return Ok((before: before, after: room.bytes));
  }
}

/// A picture cache a test scripts.
final class FakeArtworkStore implements ArtworkStore {
  int bytes = 412 * _mb;
  int clears = 0;
  AppFailure? usageFailure;
  AppFailure? clearFailure;

  /// Makes [usage] wait.
  Completer<void>? gate;

  @override
  Future<Result<ArtworkUsage>> usage() async {
    if (gate case final gate?) await gate.future;
    if (usageFailure case final failure?) return Err(failure);
    return Ok((bytes: bytes, maxBytes: 500 * _mb));
  }

  @override
  Future<Result<void>> clear() async {
    if (clearFailure case final failure?) return Err(failure);
    clears++;
    bytes = 0;
    return const Ok(null);
  }
}

/// An export and import a test scripts.
final class FakeTransfer implements SettingsTransfer {
  final exported = <String>[];
  final applied = <ImportPlan>[];
  AppFailure? exportFailure;
  AppFailure? applyFailure;

  /// What [read] answers.
  SettingsFileRead? reading;

  @override
  Future<Result<ExportSummary>> exportTo(String path) async {
    if (exportFailure case final failure?) return Err(failure);
    exported.add(path);
    return Ok(ExportSummary(path: path, sources: 2, favorites: 212, bytes: 9));
  }

  @override
  Future<SettingsFileRead> read(String path) async => reading!;

  @override
  Future<Result<ImportSummary>> apply(ImportPlan plan) async {
    if (applyFailure case final failure?) return Err(failure);
    applied.add(plan);
    return Ok(
      ImportSummary(
        settingsPages: plan.settingsPages,
        sources: plan.here.length,
        skippedSources: plan.missing.length,
        favorites: 212,
        categories: 41,
        channels: 0,
        guideMatches: 9,
        reminders: 0,
        notHere: 0,
      ),
    );
  }
}

/// Sketch C's file: Northwind TV is here, Harbor IPTV is not.
ImportPlan sketchPlan({bool settings = true}) {
  final northwind = ExportedSource(
    name: 'Northwind TV',
    type: 'xtream',
    fingerprint: 'a',
    favorites: [
      for (var i = 0; i < 212; i++) ExportedFavorite(type: 'live', key: '$i'),
    ],
    favoriteGroups: const [
      ExportedFavoriteGroup(name: 'Sport'),
      ExportedFavoriteGroup(name: 'News'),
      ExportedFavoriteGroup(name: 'Kids'),
    ],
    categories: [
      for (var i = 0; i < 41; i++)
        ExportedCategory(kind: 'live', key: '$i', hidden: true),
    ],
    guideMatches: [
      for (var i = 0; i < 9; i++)
        ExportedGuideMatch(channel: '$i', xmltvId: 'g$i'),
    ],
  );
  const harbor = ExportedSource(
    name: 'Harbor IPTV',
    type: 'm3uUrl',
    fingerprint: 'b',
  );
  return ImportPlan(
    path: '/home/me/Documents/iptv-player-settings-2026-10-12.json',
    file: SettingsExport(
      exportedAt: DateTime.utc(2026, 10, 12),
      settings: settings
          ? const {
              'appearance': {'accent': 'rose'},
            }
          : const {},
      sources: [northwind, harbor],
    ),
    sources: [
      ImportSourcePlan(
        exported: northwind,
        sourceId: 'src-1',
        sourceName: 'Northwind TV',
      ),
      const ImportSourcePlan(exported: harbor),
    ],
  );
}
