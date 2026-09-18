import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/providers/m3u/m3u_identity.dart';
import 'package:iptv_player/data/providers/m3u/m3u_models.dart';
import 'package:iptv_player/data/providers/m3u/m3u_reader.dart';
import 'package:iptv_player/data/sync/sync_work.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

/// One M3U sync, inside the sync isolate. The playlist is read as a
/// stream (`readM3u`) and written in batches as it arrives; reading pauses
/// while a batch is written, so memory holds one batch, not the playlist.
///
/// Playlists have no category or series lists, so both are built from the
/// entries (ADR-009):
/// - a `group-title` becomes a category of the entry's kind, the first
///   time the run meets it;
/// - episodes are grouped into series by the name they carry (`Dark S01
///   E02` → "Dark", within its group). An episode whose name gives no
///   numbering joins a series named after its group, numbered in playlist
///   order; with no group either, it is filed as a movie — a lone video
///   the user can still find and play.
final class M3uSync {
  new({
    required this._db,
    required this._input,
    required this._sourceId,
    required this._runId,
    required this._report,
    this._batchSize = 5000,
  });

  final AppDatabase _db;
  final M3uInput _input;
  final String _sourceId;
  final int _runId;
  final void Function(SyncProgress progress) _report;
  final int _batchSize;

  var _progress = const SyncProgress(stage: SyncStage.playlist);
  final _pending = <M3uEntry>[];

  /// Group → category row id, for the groups this run has upserted.
  final Map<CatalogueKind, Map<String, int>> _categoryIds = {
    for (final kind in CatalogueKind.values) kind: {},
  };
  final Map<CatalogueKind, int> _categoryPositions = {
    for (final kind in CatalogueKind.values) kind: 0,
  };

  /// Series key → row id, for the series this run has upserted.
  final _seriesIds = <String, int>{};

  /// Unnumbered episodes seen so far per series key.
  final _unnumbered = <String, int>{};
  AppFailure? _writeFailure;

  Future<Result<SyncWorkResult>> run() async {
    _report(_progress);
    final read = await readM3u(_input, _onEntry);
    if (_writeFailure case final failure?) return Err(failure);
    final M3uSummary summary;
    switch (read) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        return Err(failure);
    }
    await _flush();
    if (summary.entries == 0) {
      // Nothing to show, and sweeping would empty a source that had
      // channels yesterday: a failure, so the old data stays.
      return Err(ParseFailure('the playlist has no entries'));
    }
    return Ok(
      SyncWorkResult(
        report: SyncReport(
          categories: _progress.categories,
          channels: _progress.channels,
          movies: _progress.movies,
          series: _progress.series,
          episodes: _progress.episodes,
          skipped: summary.skipped,
        ),
        // One file is one answer: whatever it left out is gone.
        sweepItems: CatalogueKind.values.toSet(),
        sweepCategories: CatalogueKind.values.toSet(),
        sweepEpisodes: true,
        epgUrls: summary.epgUrls,
      ),
    );
  }

  FutureOr<void> _onEntry(M3uEntry entry) {
    _pending.add(entry);
    if (_pending.length < _batchSize) return null;
    return _flush().catchError((Object error, StackTrace stackTrace) {
      // Remembered, so the run reports the write that failed rather than
      // the parse it interrupted.
      _writeFailure ??= syncWriteFailure(error);
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final entries = List.of(_pending);
    _pending.clear();

    final filed = [for (final entry in entries) _file(entry)];
    await _upsertCategories(filed);
    await _upsertSeries(filed);

    final channels = <ChannelsCompanion>[];
    final movies = <MoviesCompanion>[];
    final episodes = <EpisodesCompanion>[];
    for (final item in filed) {
      final entry = item.entry;
      final categoryId = item.group == null
          ? null
          : _categoryIds[item.kind]![item.group];
      switch (item.kind) {
        case CatalogueKind.live:
          channels.add(
            ChannelsCompanion.insert(
              sourceId: _sourceId,
              remoteKey: entry.identity,
              name: entry.name,
              categoryId: Value(categoryId),
              number: Value(entry.channelNumber),
              logoUrl: Value(entry.logoUrl),
              epgKey: Value(entry.tvgId),
              archiveDays: Value(entry.catchupDays ?? 0),
              streamUrl: Value(entry.streamUrl),
              extrasJson: Value(_extras(entry)),
              position: Value(entry.position),
              seenRun: Value(_runId),
            ),
          );
        case CatalogueKind.movie:
          movies.add(
            MoviesCompanion.insert(
              sourceId: _sourceId,
              remoteKey: entry.identity,
              name: entry.name,
              categoryId: Value(categoryId),
              posterUrl: Value(entry.logoUrl),
              ext: Value(_extension(entry.streamUrl)),
              streamUrl: Value(entry.streamUrl),
              extrasJson: Value(_extras(entry)),
              position: Value(entry.position),
              seenRun: Value(_runId),
            ),
          );
        case CatalogueKind.series:
          episodes.add(
            EpisodesCompanion.insert(
              seriesId: _seriesIds[item.seriesKey]!,
              remoteKey: entry.identity,
              season: item.season!,
              episode: item.episode!,
              title: entry.name,
              ext: Value(_extension(entry.streamUrl)),
              stillUrl: Value(entry.logoUrl),
              streamUrl: Value(entry.streamUrl),
              extrasJson: Value(_extras(entry)),
              seenRun: Value(_runId),
            ),
          );
      }
    }
    if (channels.isNotEmpty) await _db.channelsDao.upsertAll(channels);
    if (movies.isNotEmpty) await _db.moviesDao.upsertAll(movies);
    if (episodes.isNotEmpty) await _db.seriesDao.upsertEpisodes(episodes);
    _emit(
      _progress.copyWith(
        channels: _progress.channels + channels.length,
        movies: _progress.movies + movies.length,
        episodes: _progress.episodes + episodes.length,
      ),
    );
  }

  /// Where [entry] goes: its catalogue kind, category group, and for an
  /// episode its series and numbering.
  _Filed _file(M3uEntry entry) {
    switch (entry.kind) {
      case M3uKind.live:
        return _Filed(entry, CatalogueKind.live, entry.group);
      case M3uKind.movie:
        return _Filed(entry, CatalogueKind.movie, entry.group);
      case M3uKind.episode:
        final name = entry.seriesName ?? entry.group;
        if (name == null) {
          return _Filed(entry, CatalogueKind.movie, entry.group);
        }
        final key = seriesIdentity(group: entry.group, name: name);
        final numbered = entry.season != null && entry.episode != null;
        return _Filed(
          entry,
          CatalogueKind.series,
          entry.group,
          seriesKey: key,
          seriesName: name,
          season: numbered ? entry.season : 1,
          episode: numbered
              ? entry.episode
              : _unnumbered.update(key, (n) => n + 1, ifAbsent: () => 1),
        );
    }
  }

  Future<void> _upsertCategories(List<_Filed> filed) async {
    final fresh = <CatalogueKind, List<String>>{};
    for (final item in filed) {
      final group = item.group;
      if (group == null || _categoryIds[item.kind]!.containsKey(group)) {
        continue;
      }
      final groups = fresh.putIfAbsent(item.kind, () => []);
      if (!groups.contains(group)) groups.add(group);
    }
    if (fresh.isEmpty) return;
    await _db.categoriesDao.upsertAll([
      for (final MapEntry(key: kind, value: groups) in fresh.entries)
        for (final group in groups)
          CategoriesCompanion.insert(
            sourceId: _sourceId,
            kind: kind,
            remoteKey: group,
            name: group,
            position: Value(_categoryPositions.update(kind, (n) => n + 1) - 1),
            seenRun: Value(_runId),
          ),
    ]);
    for (final MapEntry(key: kind, value: groups) in fresh.entries) {
      final ids = await _db.categoriesDao.idsByRemoteKey(_sourceId, kind);
      for (final group in groups) {
        _categoryIds[kind]![group] = ids[group]!;
      }
    }
    _emit(
      _progress.copyWith(
        categories: _categoryIds.values.fold(0, (n, ids) => n + ids.length),
      ),
    );
  }

  Future<void> _upsertSeries(List<_Filed> filed) async {
    final fresh = <String, _Filed>{};
    for (final item in filed) {
      final key = item.seriesKey;
      if (key == null || _seriesIds.containsKey(key)) continue;
      fresh.putIfAbsent(key, () => item);
    }
    if (fresh.isEmpty) return;
    final known = _seriesIds.length;
    await _db.seriesDao.upsertAll([
      for (final (index, MapEntry(:key, value: first)) in fresh.entries.indexed)
        SeriesCompanion.insert(
          sourceId: _sourceId,
          remoteKey: key,
          name: first.seriesName!,
          categoryId: Value(
            first.group == null
                ? null
                : _categoryIds[CatalogueKind.series]![first.group],
          ),
          // An export's episode logo is usually the series poster.
          posterUrl: Value(first.entry.logoUrl),
          position: Value(known + index),
          seenRun: Value(_runId),
        ),
    ]);
    _seriesIds.addAll(
      await _db.seriesDao.idsByRemoteKey(_sourceId, fresh.keys),
    );
    _emit(_progress.copyWith(series: _seriesIds.length));
  }

  void _emit(SyncProgress progress) {
    _progress = progress;
    _report(progress);
  }
}

final class _Filed {
  const new(
    this.entry,
    this.kind,
    this.group, {
    this.seriesKey,
    this.seriesName,
    this.season,
    this.episode,
  });

  final M3uEntry entry;
  final CatalogueKind kind;
  final String? group;
  final String? seriesKey;
  final String? seriesName;
  final int? season;
  final int? episode;
}

/// The per-entry options playback needs, as `extras_json`; null when the
/// entry has none.
String? _extras(M3uEntry entry) {
  final extras = {
    'user_agent': ?entry.userAgent,
    'referrer': ?entry.referrer,
    'catchup': ?entry.catchup,
    'catchup_days': ?entry.catchupDays,
    'catchup_source': ?entry.catchupSource,
    'tvg_name': ?entry.tvgName,
  };
  return extras.isEmpty ? null : jsonEncode(extras);
}

final _extensionPattern = RegExp(r'\.([A-Za-z0-9]{2,4})$');

/// `mkv` from `…/movie/u/p/42.mkv`: the container the player is told.
String? _extension(String streamUrl) {
  final path = Uri.tryParse(streamUrl)?.path ?? streamUrl;
  return _extensionPattern.firstMatch(path)?[1]?.toLowerCase();
}
