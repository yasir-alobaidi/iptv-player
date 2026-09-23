import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/epg_dao.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';

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
  new(AppDatabase database, {this._clock = DateTime.now}) : _db = database;

  final AppDatabase _db;
  final DateTime Function() _clock;

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
  Future<Result<void>> clearGuide(String sourceId) =>
      Result.guard(() => _dao.clearLiveGuide(sourceId));

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
