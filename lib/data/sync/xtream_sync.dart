import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/data/sync/sync_work.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

/// One Xtream sync, inside the sync isolate: account → categories → live
/// → movies → series (docs/02), each list upserted in batches.
final class XtreamSync {
  new({
    required this._db,
    required this._client,
    required this._sourceId,
    required this._runId,
    required this._report,
    this._batchSize = 5000,
  });

  final AppDatabase _db;
  final XtreamClient _client;
  final String _sourceId;
  final int _runId;
  final void Function(SyncProgress progress) _report;
  final int _batchSize;

  var _progress = const SyncProgress(stage: SyncStage.account);
  var _skipped = 0;
  final _sweepItems = <CatalogueKind>{};
  final _sweepCategories = <CatalogueKind>{};
  final _emptyLists = <CatalogueKind>{};
  final _warnings = <String>[];

  Future<Result<SyncWorkResult>> run() async {
    _report(_progress);
    final signedIn = await _client.account();
    final XtreamAccount account;
    switch (signedIn) {
      case Ok(:final value):
        account = value;
      case Err(:final failure):
        return Err(failure);
    }
    await _db.sourcesDao.saveAccount(
      _sourceId,
      accountJson: jsonEncode(account.toStoredJson()),
      expiresAt: account.expiresAt,
    );
    _emit(
      _progress.copyWith(
        stage: SyncStage.categories,
        account: account.toProviderAccount(),
      ),
    );

    // All three category lists first: every item stage needs its kind's
    // remote key → row id map.
    final categoryLists = <CatalogueKind, XtreamRows<XtreamCategory>>{};
    for (final (kind, fetch) in [
      (CatalogueKind.live, _client.liveCategories),
      (CatalogueKind.movie, _client.movieCategories),
      (CatalogueKind.series, _client.seriesCategories),
    ]) {
      switch (await fetch()) {
        case Ok(:final value):
          categoryLists[kind] = value;
        case Err(:final failure):
          return Err(failure);
      }
    }
    final categoryIds = <CatalogueKind, Map<String, int>>{};
    var categoryCount = 0;
    for (final MapEntry(key: kind, value: list) in categoryLists.entries) {
      _skipped += list.skipped;
      await _db.categoriesDao.upsertAll([
        for (final (position, category) in list.items.indexed)
          CategoriesCompanion.insert(
            sourceId: _sourceId,
            kind: kind,
            remoteKey: category.id,
            name: category.name,
            position: Value(position),
            seenRun: Value(_runId),
          ),
      ]);
      categoryIds[kind] = await _db.categoriesDao.idsByRemoteKey(
        _sourceId,
        kind,
      );
      categoryCount += list.items.length;
      _emit(_progress.copyWith(categories: categoryCount));
    }

    _emit(_progress.copyWith(stage: SyncStage.live));
    final channels = await _client.liveStreams();
    if (channels case Err(:final failure)) return Err(failure);
    await _items(
      CatalogueKind.live,
      channels.valueOrNull!,
      categoryLists[CatalogueKind.live]!,
      toRow: (channel, position) => ChannelsCompanion.insert(
        sourceId: _sourceId,
        remoteKey: channel.streamId,
        name: channel.name,
        categoryId: Value(categoryIds[CatalogueKind.live]![channel.categoryId]),
        number: Value(channel.number),
        logoUrl: Value(channel.iconUrl),
        epgKey: Value(channel.epgChannelId),
        archiveDays: Value(channel.archiveDays),
        addedAt: Value(channel.addedAt),
        position: Value(position),
        seenRun: Value(_runId),
      ),
      write: _db.channelsDao.upsertAll,
      count: (progress, done) => progress.copyWith(channels: done),
    );

    _emit(_progress.copyWith(stage: SyncStage.movies, stageTotal: null));
    final movies = await _client.movies();
    if (movies case Err(:final failure)) return Err(failure);
    await _items(
      CatalogueKind.movie,
      movies.valueOrNull!,
      categoryLists[CatalogueKind.movie]!,
      toRow: (movie, position) => MoviesCompanion.insert(
        sourceId: _sourceId,
        remoteKey: movie.streamId,
        name: movie.name,
        categoryId: Value(categoryIds[CatalogueKind.movie]![movie.categoryId]),
        posterUrl: Value(movie.posterUrl),
        rating: Value(movie.rating),
        year: Value(movie.year),
        ext: Value(movie.ext),
        addedAt: Value(movie.addedAt),
        position: Value(position),
        seenRun: Value(_runId),
      ),
      write: _db.moviesDao.upsertAll,
      count: (progress, done) => progress.copyWith(movies: done),
    );

    _emit(_progress.copyWith(stage: SyncStage.series, stageTotal: null));
    final series = await _client.series();
    if (series case Err(:final failure)) return Err(failure);
    await _items(
      CatalogueKind.series,
      series.valueOrNull!,
      categoryLists[CatalogueKind.series]!,
      toRow: (show, position) => SeriesCompanion.insert(
        sourceId: _sourceId,
        remoteKey: show.seriesId,
        name: show.name,
        categoryId: Value(categoryIds[CatalogueKind.series]![show.categoryId]),
        posterUrl: Value(show.posterUrl),
        rating: Value(show.rating),
        year: Value(show.year),
        plot: Value(show.plot),
        updatedAt: Value(show.lastModified),
        position: Value(position),
        seenRun: Value(_runId),
      ),
      write: _db.seriesDao.upsertAll,
      count: (progress, done) => progress.copyWith(series: done),
    );

    return Ok(
      SyncWorkResult(
        report: SyncReport(
          categories: _progress.categories,
          channels: _progress.channels,
          movies: _progress.movies,
          series: _progress.series,
          skipped: _skipped,
        ),
        sweepItems: _sweepItems,
        sweepCategories: _sweepCategories,
        emptyLists: _emptyLists,
        warnings: _warnings,
      ),
    );
  }

  /// Upserts one list in batches, reporting after each, and decides
  /// whether the run may sweep it.
  Future<void> _items<T, R extends Insertable<Object?>>(
    CatalogueKind kind,
    XtreamRows<T> rows,
    XtreamRows<XtreamCategory> categories, {
    required R Function(T item, int position) toRow,
    required Future<void> Function(List<R> rows) write,
    required SyncProgress Function(SyncProgress progress, int done) count,
  }) async {
    _skipped += rows.skipped;
    final items = rows.items;
    _emit(count(_progress.copyWith(stageTotal: items.length), 0));
    for (var start = 0; start < items.length; start += _batchSize) {
      final end = min(start + _batchSize, items.length);
      await write([for (var i = start; i < end; i++) toRow(items[i], i)]);
      _emit(count(_progress, end));
    }

    // An empty list is far more often a panel's hiccup than a provider
    // that dropped every channel, so it keeps what the last sync stored
    // rather than wiping it — and the user's hidden categories with it.
    // The engine sweeps it when the next run finds it empty again.
    if (items.isEmpty) {
      _emptyLists.add(kind);
      return;
    }
    _sweepItems.add(kind);
    if (categories.items.isNotEmpty) {
      _sweepCategories.add(kind);
    } else {
      _warnings.add(
        'the ${kind.name} categories came back empty; kept the last ones',
      );
    }
  }

  void _emit(SyncProgress progress) {
    _progress = progress;
    _report(progress);
  }
}

extension XtreamAccountDomain on XtreamAccount {
  ProviderAccount toProviderAccount() => ProviderAccount(
    status: status,
    expiresAt: expiresAt,
    isTrial: isTrial,
    activeConnections: activeConnections,
    maxConnections: maxConnections,
    allowedFormats: allowedOutputFormats,
    serverTimezone: serverTimezone,
  );
}
