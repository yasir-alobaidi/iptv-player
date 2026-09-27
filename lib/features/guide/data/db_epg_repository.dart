import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/epg_dao.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/features/guide/data/guide_ranking_worker.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_channel_ranking.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:meta/meta.dart';

/// How far back a query looks for a programme that is still on. The
/// index is on `start_utc`, so every read is bounded rather than open
/// at the left; nothing in a guide runs longer than a day.
const _longestProgramme = Duration(hours: 24);

/// How far ahead "next" is looked for. Past it a channel simply has no
/// next programme, which is what the retention window means anyway.
const _nextHorizon = Duration(days: 7);

/// [EpgRepository] over the schema v5 EPG tables. The reads the guide
/// does per screen — now/next for a page of channels, a time window for
/// the grid — are one indexed statement each, joined through the
/// matcher's `epg_matches` rather than matched in Dart.
final class DbEpgRepository implements EpgRepository {
  /// [rankingIdle], [rankingTimeout] and `rankingWorker` are for tests:
  /// how long a ranking worker may sit unused, how long a query to one may
  /// take, and the worker's entry point.
  new(
    AppDatabase database, {
    this._clock = DateTime.now,
    this.rankingIdle = const Duration(seconds: 60),
    this.rankingTimeout = const Duration(seconds: 10),
    this._rankingWorker = runGuideRankingWorker,
  }) : _db = database;

  /// A guide with more channels than this is read, prepared and ranked
  /// for the Match… picker in a [GuideRankingWorker] (hard rule 2); a
  /// smaller one is ranked here, in less time than a worker takes to
  /// start.
  static const rankInBackgroundAbove = 2000;

  /// How long a worker may take to read and prepare its guide.
  static const _rankingStart = Duration(minutes: 1);

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// A ranking worker unused this long is stopped; the next query starts
  /// another.
  final Duration rankingIdle;

  /// A query a ranking worker hasn't answered in this long fails with a
  /// `TimeoutFailure`, and the worker is stopped.
  final Duration rankingTimeout;

  final GuideRankingWorkerMain _rankingWorker;

  /// Each source's live guide, ready to rank, and the import it was read
  /// from. One entry per source: a new live import replaces it.
  final _guides = <String, _GuideEntry>{};
  var _disposed = false;
  var _rankingWorkerStarts = 0;
  var _rankingQueries = 0;

  /// Ranking workers started so far.
  @visibleForTesting
  int get rankingWorkerStarts => _rankingWorkerStarts;

  /// Queries sent to ranking workers so far.
  @visibleForTesting
  int get rankingQueries => _rankingQueries;

  /// The ranking workers' isolates that are running.
  @visibleForTesting
  List<Isolate> get rankingWorkerIsolates => [
    for (final entry in _guides.values) ?entry.worker?.isolate,
  ];

  /// Stops every ranking worker. Other reads keep working; the picker's
  /// candidates are a `CancelledFailure` from now on.
  Future<void> dispose() async {
    _disposed = true;
    final entries = _guides.values.toList();
    _guides.clear();
    for (final entry in entries) {
      entry.close();
    }
  }

  EpgDao get _dao => _db.epgDao;

  static const _programColumns =
      'p.id AS id, p.epg_channel_id AS epg_channel_id, '
      'p.start_utc AS start_utc, p.end_utc AS end_utc, p.title AS title, '
      'p.subtitle AS subtitle, p.description AS description, '
      'p.category AS category';

  static const _matchedPrograms =
      'FROM epg_matches m JOIN epg_programs p '
      'ON p.source_id = m.source_id AND p.epg_channel_id = m.xmltv_id';

  @override
  Future<Result<int>> startImport(String sourceId) =>
      Result.guard(() => _dao.startImport(sourceId, _clock()));

  @override
  Future<Result<void>> stageChannels(int importRun, List<GuideChannel> rows) =>
      Result.guard(
        () => _dao.stageChannels([
          for (final channel in rows)
            EpgChannelsStagingCompanion.insert(
              importRun: importRun,
              xmltvId: channel.xmltvId,
              displayName: Value(channel.displayName),
              iconUrl: Value(channel.iconUrl),
            ),
        ]),
      );

  @override
  Future<Result<void>> stagePrograms(int importRun, List<EpgProgramme> rows) =>
      Result.guard(
        () => _dao.stagePrograms([
          for (final programme in rows)
            EpgProgramsStagingCompanion.insert(
              importRun: importRun,
              epgChannelId: programme.channelId,
              startUtc: programme.start.millisecondsSinceEpoch,
              endUtc: programme.end.millisecondsSinceEpoch,
              title: programme.title,
              subtitle: Value(programme.subtitle),
              description: Value(programme.description),
              category: Value(programme.category),
            ),
        ]),
      );

  @override
  Future<Result<EpgImportCounts>> commitImport({
    required String sourceId,
    required int importRun,
    EpgImportCounts counts = const EpgImportCounts(),
  }) => Result.guard(() async {
    late EpgImportCounts written;
    await _dao.swapIn(
      sourceId: sourceId,
      importRun: importRun,
      at: _clock(),
      countsJson: (totals) {
        written = counts.withTotals(
          channels: totals.channels,
          programmes: totals.programs,
          firstStart: _time(totals.firstStartMs),
          lastEnd: _time(totals.lastEndMs),
        );
        return written.toJson();
      },
    );
    return written;
  });

  @override
  Future<Result<void>> abandonImport(
    int importRun, {
    required GuideImportOutcome outcome,
    AppFailure? failure,
    EpgImportCounts counts = const EpgImportCounts(),
  }) => Result.guard(
    () => _dao.finishImport(
      importRun,
      outcome: _storedOutcome(outcome),
      at: _clock(),
      failure: failure?.code,
      failureStatus: failure?.statusCode,
      countsJson: counts.toJson(),
    ),
  );

  @override
  Future<Result<int>> recoverInterrupted() => Result.guard(() async {
    final interrupted = await _dao.failInterruptedImports(_clock());
    await _dao.sweepStaging();
    return interrupted;
  });

  @override
  Future<Result<GuideCoverage>> coverage(String sourceId) =>
      Result.guard(() => _coverage(sourceId));

  @override
  Stream<GuideCoverage> watchCoverage(String sourceId) => _db
      .customSelect(
        'SELECT (SELECT MAX(id) FROM epg_imports WHERE source_id = ?1) '
        'AS latest, '
        '(SELECT COUNT(*) FROM epg_matches WHERE source_id = ?1) AS matched, '
        '(SELECT outcome FROM epg_imports WHERE source_id = ?1 '
        'ORDER BY id DESC LIMIT 1) AS outcome',
        variables: [Variable.withString(sourceId)],
        // Not `epg_programs`: an import writes hundreds of thousands of
        // rows, and everything shown here comes from the import's own
        // counts instead.
        readsFrom: {_db.epgImports, _db.epgMatches},
      )
      .watchSingle()
      .asyncMap((_) => _coverage(sourceId))
      .handleError(
        (Object error) => throw StorageFailure('guide coverage: $error'),
        test: (error) => error is! AppFailure,
      );

  Future<GuideCoverage> _coverage(String sourceId) async {
    final latest = await _dao.latestImport(sourceId);
    final live = latest != null && latest.isLive
        ? latest
        : await _dao.liveImport(sourceId);
    final liveCounts = EpgImportCounts.fromJson(live?.countsJson);
    final row = await _db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM epg_matches WHERE source_id = ?1) '
          'AS matched, '
          '(SELECT COUNT(*) FROM channels WHERE source_id = ?1) AS channels',
          variables: [Variable.withString(sourceId)],
          readsFrom: {_db.epgMatches, _db.channels},
        )
        .getSingle();
    return GuideCoverage(
      lastImport: latest == null ? null : _import(latest),
      guideChannels: liveCounts.channels,
      programmes: liveCounts.programmes,
      firstStart: liveCounts.firstStart,
      lastEnd: liveCounts.lastEnd,
      matchedChannels: row.read<int>('matched'),
      totalChannels: row.read<int>('channels'),
      updatedAt: live?.finishedAt,
    );
  }

  /// Drift's own table notifications, which reach this connection from
  /// every isolate that writes (the import and match jobs connect to the
  /// same database isolate). Not `epg_programs`: an import writes hundreds
  /// of thousands of rows, and its swap ends by updating its
  /// `epg_imports` row in the same transaction anyway.
  @override
  Stream<void> watchChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([_db.epgImports, _db.epgMatches]),
      )
      .map((_) {})
      .handleError((Object _) {});

  @override
  Future<Result<Map<int, EpgNowNext>>> nowNextForChannels(
    List<int> channelIds,
    DateTime at,
  ) => Result.guard(() async {
    if (channelIds.isEmpty) return const <int, EpgNowNext>{};
    final ms = at.millisecondsSinceEpoch;
    final placeholders = List.filled(channelIds.length, '?').join(', ');
    // The two earliest programmes still running or still to come: the
    // first is "now" when it contains [at], otherwise it is already
    // "next" and the channel has a gap.
    final rows = await _db
        .customSelect(
          'SELECT channel_id, id, epg_channel_id, start_utc, end_utc, title, '
          'subtitle, description, category FROM ( '
          'SELECT m.channel_id AS channel_id, $_programColumns, '
          'ROW_NUMBER() OVER (PARTITION BY m.channel_id '
          'ORDER BY p.start_utc) AS rn '
          '$_matchedPrograms '
          'WHERE m.channel_id IN ($placeholders) '
          'AND p.start_utc >= ? AND p.start_utc < ? AND p.end_utc > ? '
          ') WHERE rn <= 2 ORDER BY channel_id, start_utc',
          variables: [
            for (final id in channelIds) Variable.withInt(id),
            Variable.withInt(ms - _longestProgramme.inMilliseconds),
            Variable.withInt(ms + _nextHorizon.inMilliseconds),
            Variable.withInt(ms),
          ],
          readsFrom: {_db.epgMatches, _db.epgPrograms},
        )
        .get();
    final found = <int, EpgNowNext>{};
    for (final row in rows) {
      final channelId = row.read<int>('channel_id');
      final programme = _programme(row);
      final entry = found[channelId] ?? EpgNowNext.none;
      found[channelId] = programme.isOnAt(at)
          ? EpgNowNext(now: programme, next: entry.next)
          : EpgNowNext(now: entry.now, next: entry.next ?? programme);
    }
    return found;
  });

  @override
  Future<Result<Map<int, List<EpgProgramme>>>> windowForChannels(
    List<int> channelIds,
    DateTime from,
    DateTime to,
  ) => Result.guard(() async {
    if (channelIds.isEmpty) return const <int, List<EpgProgramme>>{};
    final fromMs = from.millisecondsSinceEpoch;
    final placeholders = List.filled(channelIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT m.channel_id AS channel_id, $_programColumns '
          '$_matchedPrograms '
          'WHERE m.channel_id IN ($placeholders) '
          'AND p.start_utc >= ? AND p.start_utc < ? AND p.end_utc > ? '
          'ORDER BY m.channel_id, p.start_utc',
          variables: [
            for (final id in channelIds) Variable.withInt(id),
            Variable.withInt(fromMs - _longestProgramme.inMilliseconds),
            Variable.withInt(to.millisecondsSinceEpoch),
            Variable.withInt(fromMs),
          ],
          readsFrom: {_db.epgMatches, _db.epgPrograms},
        )
        .get();
    final found = <int, List<EpgProgramme>>{};
    for (final row in rows) {
      (found[row.read<int>('channel_id')] ??= []).add(_programme(row));
    }
    return found;
  });

  @override
  Future<Result<Set<int>>> channelsWithGuide(List<int> channelIds) =>
      Result.guard(() async {
        if (channelIds.isEmpty) return const <int>{};
        final placeholders = List.filled(channelIds.length, '?').join(', ');
        // One probe of the programmes index per matched channel.
        final rows = await _db
            .customSelect(
              'SELECT m.channel_id AS channel_id FROM epg_matches m '
              'WHERE m.channel_id IN ($placeholders) AND EXISTS ( '
              'SELECT 1 FROM epg_programs p WHERE p.source_id = m.source_id '
              'AND p.epg_channel_id = m.xmltv_id)',
              variables: [for (final id in channelIds) Variable.withInt(id)],
              readsFrom: {_db.epgMatches, _db.epgPrograms},
            )
            .get();
        return {for (final row in rows) row.read<int>('channel_id')};
      });

  @override
  Future<Result<List<GuideChannel>>> guideChannels(
    String sourceId, {
    String? query,
    int limit = 50,
  }) => Result.guard(() async {
    final rows = await _dao.guideChannels(
      sourceId,
      nameLike: query,
      limit: limit,
    );
    return [
      for (final row in rows)
        GuideChannel(
          xmltvId: row.xmltvId,
          displayName: row.displayName,
          iconUrl: row.iconUrl,
        ),
    ];
  });

  @override
  Future<Result<void>> setMapping({
    required String sourceId,
    required String channelRemoteKey,
    required String xmltvId,
  }) => Result.guard(
    () => _dao.setMapping(sourceId, channelRemoteKey, xmltvId, _clock()),
  );

  @override
  Future<Result<void>> removeMapping({
    required String sourceId,
    required String channelRemoteKey,
  }) => Result.guard(() => _dao.removeMapping(sourceId, channelRemoteKey));

  @override
  Future<Result<List<EpgMapping>>> mappings(String sourceId) =>
      Result.guard(() async {
        final rows = await _dao.mappingsFor(sourceId);
        return [
          for (final row in rows)
            EpgMapping(
              channelRemoteKey: row.channelRemoteKey,
              xmltvId: row.xmltvId,
              updatedAt: row.updatedAt,
            ),
        ];
      });

  @override
  Future<Result<List<ChannelGuideMatch>>> channelMatches(
    String sourceId, {
    ChannelMatchFilter filter = ChannelMatchFilter.unmatched,
    String query = '',
    int offset = 0,
    int limit = 100,
  }) => Result.guard(() async {
    if (limit <= 0) return const <ChannelGuideMatch>[];
    final (where, variables) = _matchWhere(sourceId, filter, query);
    final rows = await _db
        .customSelect(
          'SELECT $_matchColumns $_matchFrom $where '
          'ORDER BY c.number IS NULL, c.number, c.position, c.id '
          'LIMIT ? OFFSET ?',
          variables: [
            ...variables,
            Variable.withInt(limit),
            Variable.withInt(offset < 0 ? 0 : offset),
          ],
          readsFrom: _matchTables,
        )
        .get();
    return [for (final row in rows) _channelMatch(row)];
  });

  @override
  Future<Result<int>> countChannelMatches(
    String sourceId, {
    ChannelMatchFilter filter = ChannelMatchFilter.unmatched,
    String query = '',
  }) => Result.guard(() async {
    final (where, variables) = _matchWhere(sourceId, filter, query);
    // No `epg_channels` here: it only names the match, and its unique
    // (source, id) key means it never adds a row.
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n $_visibleFrom $where',
          variables: variables,
          readsFrom: _matchTables,
        )
        .getSingle();
    return row.read<int>('n');
  });

  @override
  Future<Result<ChannelGuideMatch?>> channelMatch(int channelId) =>
      Result.guard(() async {
        final row = await _db
            .customSelect(
              'SELECT $_matchColumns $_matchFrom WHERE c.id = ?',
              variables: [Variable.withInt(channelId)],
              readsFrom: _matchTables,
            )
            .getSingleOrNull();
        return row == null ? null : _channelMatch(row);
      });

  @override
  Stream<ChannelMatchCounts> watchChannelMatchCounts(String sourceId) => _db
      .customSelect(
        'SELECT COUNT(*) AS channels, COUNT(m.channel_id) AS matched, '
        'COUNT(CASE WHEN m.rule = ? THEN 1 END) AS manual '
        '$_visibleFrom WHERE c.source_id = ? AND $_visible',
        variables: [
          Variable.withString(EpgMatchRule.manual.name),
          Variable.withString(sourceId),
        ],
        readsFrom: {_db.channels, _db.categories, _db.epgMatches},
      )
      .watchSingle()
      .map(
        (row) => ChannelMatchCounts(
          channels: row.read<int>('channels'),
          matched: row.read<int>('matched'),
          manual: row.read<int>('manual'),
        ),
      )
      // A sync rewrites channels in many batches that change no count.
      .distinct()
      .handleError(
        (Object error) => throw StorageFailure('channel match counts: $error'),
        test: (error) => error is! AppFailure,
      );

  @override
  Future<Result<List<GuideChannelCandidate>>> matchCandidates(
    String sourceId, {
    required String channelName,
    String query = '',
    int limit = 50,
  }) async {
    if (_disposed) return Err(CancelledFailure('the guide is closing'));
    if (limit <= 0) return const Ok(<GuideChannelCandidate>[]);
    _GuideEntry? entry;
    try {
      final live = await _dao.liveImport(sourceId);
      if (live == null || _disposed) {
        _dropGuide(sourceId);
        return live == null
            ? const Ok(<GuideChannelCandidate>[])
            : Err(CancelledFailure('the guide is closing'));
      }
      entry = _guides[sourceId];
      if (entry == null || entry.importId != live.id) {
        entry?.close();
        // Made and stored before anything is awaited, so calls that
        // arrive meanwhile share its start.
        final fresh = entry = _guides[sourceId] = _GuideEntry(live.id);
        fresh.started = _startGuide(sourceId, fresh);
      }
      await entry.started;
      final worker = entry.worker;
      if (worker == null) {
        return Ok(
          rankGuideChannels(
            entry.inline,
            channelName: channelName,
            query: query,
            limit: limit,
          ),
        );
      }
      _rankingQueries++;
      return Ok(
        await worker.rank(channelName: channelName, query: query, limit: limit),
      );
    } on Object catch (error) {
      // The next call starts over.
      if (entry != null) _dropGuide(sourceId, only: entry);
      return Err(error is AppFailure ? error : AppFailure.fromError(error));
    }
  }

  /// Gets [entry] ready: a small guide read and prepared here, a large
  /// one in a worker that reads it itself.
  Future<void> _startGuide(String sourceId, _GuideEntry entry) async {
    final size = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM epg_channels WHERE source_id = ?',
          variables: [Variable.withString(sourceId)],
          readsFrom: {_db.epgChannels},
        )
        .getSingle();
    if (size.read<int>('n') <= rankInBackgroundAbove) {
      final rows = await _dao.guideChannelsOf(sourceId);
      entry.inline = prepareGuideChannels([
        for (final row in rows)
          GuideChannel(
            xmltvId: row.xmltvId,
            displayName: row.displayName,
            iconUrl: row.iconUrl,
          ),
      ]);
      return;
    }
    final connection = await _db.serializableConnection();
    if (entry.isClosed) {
      throw CancelledFailure('guide ranking: the guide was replaced');
    }
    _rankingWorkerStarts++;
    final worker = entry.worker = GuideRankingWorker(
      connection: connection,
      sourceId: sourceId,
      idleAfter: rankingIdle,
      queryTimeout: rankingTimeout,
      startTimeout: _rankingStart,
      onStopped: () => _dropGuide(sourceId, only: entry),
      main: _rankingWorker,
    );
    await worker.ready;
  }

  /// Forgets [sourceId]'s guide ([only] that entry, when given) and stops
  /// its worker.
  void _dropGuide(String sourceId, {_GuideEntry? only}) {
    final entry = _guides[sourceId];
    if (entry == null || (only != null && !identical(entry, only))) return;
    _guides.remove(sourceId);
    entry.close();
  }

  @override
  Future<Result<void>> clearGuide(String sourceId) =>
      Result.guard(() => _dao.clearLiveGuide(sourceId));

  /// Live TV's "All channels": not hidden, and not in a hidden category.
  static const _visible =
      'c.is_hidden = 0 AND (k.id IS NULL OR k.is_hidden = 0)';

  static const _visibleFrom =
      'FROM channels c '
      'LEFT JOIN categories k ON k.id = c.category_id '
      'LEFT JOIN epg_matches m ON m.channel_id = c.id';

  /// `epg_channels` is unique on (source, id), so its join never adds a
  /// row: it only says whether the live guide declares the match, and
  /// what it calls it.
  static const _matchFrom =
      '$_visibleFrom '
      'LEFT JOIN epg_channels g '
      'ON g.source_id = c.source_id AND g.xmltv_id = m.xmltv_id';

  static const _matchColumns =
      'c.id AS id, c.source_id AS source_id, c.remote_key AS remote_key, '
      'c.name AS name, c.display_name AS display_name, c.number AS number, '
      'c.logo_url AS logo_url, c.epg_key AS epg_key, '
      'm.xmltv_id AS xmltv_id, m.rule AS rule, g.xmltv_id AS guide_id, '
      'g.display_name AS guide_name';

  Set<ResultSetImplementation<dynamic, dynamic>> get _matchTables => {
    _db.channels,
    _db.categories,
    _db.epgMatches,
    _db.epgChannels,
  };

  static final _digits = RegExp(r'^[0-9]+$');

  /// The WHERE of [channelMatches]: the source's visible channels that
  /// [filter] keeps, and whose name (the user's or the provider's)
  /// contains [query], or whose number it is. Escaped the way Live TV's
  /// search is, so `%` and `_` are only themselves.
  static (String, List<Variable<Object>>) _matchWhere(
    String sourceId,
    ChannelMatchFilter filter,
    String query,
  ) {
    final clauses = <String>['c.source_id = ?', _visible];
    final variables = <Variable<Object>>[Variable.withString(sourceId)];
    switch (filter) {
      case ChannelMatchFilter.unmatched:
        clauses.add('m.channel_id IS NULL');
      case ChannelMatchFilter.manual:
        clauses.add('m.rule = ?');
        variables.add(Variable.withString(EpgMatchRule.manual.name));
      case ChannelMatchFilter.all:
        break;
    }
    final text = query.trim();
    if (text.isNotEmpty) {
      final escaped = text
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      final pattern = Variable.withString('%$escaped%');
      // Too many digits for an int is no channel's number.
      final number = _digits.hasMatch(text) ? int.tryParse(text) : null;
      clauses.add(
        r"(COALESCE(c.display_name, c.name) LIKE ? ESCAPE '\' "
        r"OR c.name LIKE ? ESCAPE '\'"
        '${number == null ? '' : ' OR c.number = ?'})',
      );
      variables.addAll([pattern, pattern]);
      if (number != null) variables.add(Variable.withInt(number));
    }
    return ('WHERE ${clauses.join(' AND ')}', variables);
  }

  static ChannelGuideMatch _channelMatch(QueryRow row) {
    final name = row.read<String>('name');
    final xmltvId = row.read<String?>('xmltv_id');
    final stored = row.read<String?>('rule');
    // A match whose id the live guide doesn't declare: only the user's
    // own mapping can be one.
    final inGuide = xmltvId != null && row.read<String?>('guide_id') != null;
    return ChannelGuideMatch(
      channelId: row.read<int>('id'),
      sourceId: row.read<String>('source_id'),
      remoteKey: row.read<String>('remote_key'),
      name: row.read<String?>('display_name') ?? name,
      providerName: name,
      number: row.read<int?>('number'),
      logoUrl: row.read<String?>('logo_url'),
      epgKey: row.read<String?>('epg_key'),
      xmltvId: xmltvId,
      // A name this build doesn't know (a newer one wrote it) is a match
      // all the same, just not one we can name the rule of.
      rule: stored == null
          ? null
          : GuideMatchRule.values.where((r) => r.name == stored).firstOrNull,
      inGuide: inGuide,
      guideLabel: inGuide
          ? GuideChannel(
              xmltvId: xmltvId,
              displayName: row.read<String?>('guide_name'),
            ).label
          : null,
    );
  }

  static EpgProgramme _programme(QueryRow row) => EpgProgramme(
    id: row.read<int>('id'),
    channelId: row.read<String>('epg_channel_id'),
    start: _time(row.read<int>('start_utc'))!,
    end: _time(row.read<int>('end_utc'))!,
    title: row.read<String>('title'),
    subtitle: row.read<String?>('subtitle'),
    description: row.read<String?>('description'),
    category: row.read<String?>('category'),
  );

  static GuideImport _import(EpgImportRow row) => GuideImport(
    id: row.id,
    outcome: switch (row.outcome) {
      SyncOutcome.succeeded => GuideImportOutcome.succeeded,
      SyncOutcome.failed => GuideImportOutcome.failed,
      SyncOutcome.cancelled => GuideImportOutcome.cancelled,
      SyncOutcome.running => GuideImportOutcome.running,
    },
    startedAt: row.startedAt,
    finishedAt: row.finishedAt,
    failureCode: row.failure,
    failureStatus: row.failureStatus,
    counts: EpgImportCounts.fromJson(row.countsJson),
    isLive: row.isLive,
  );

  static SyncOutcome _storedOutcome(GuideImportOutcome outcome) =>
      switch (outcome) {
        GuideImportOutcome.succeeded => SyncOutcome.succeeded,
        GuideImportOutcome.failed => SyncOutcome.failed,
        GuideImportOutcome.cancelled => SyncOutcome.cancelled,
        GuideImportOutcome.running => SyncOutcome.running,
      };

  static DateTime? _time(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// One source's live guide, ready to rank: prepared here ([inline]) or
/// held by a [worker].
final class _GuideEntry {
  new(this.importId);

  final int importId;

  /// Completes when [inline] or [worker] is ready.
  late final Future<void> started;
  List<RankableGuideChannel> inline = const [];
  GuideRankingWorker? worker;
  bool isClosed = false;

  void close() {
    isClosed = true;
    worker?.stop();
  }
}
