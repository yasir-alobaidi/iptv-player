import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/epg_tables.dart';

part 'epg_dao.g.dart';

/// The failure recorded for an import the app was closed or killed during.
const epgInterruptedFailure = 'interrupted';

/// What a finished swap put in place. The caller turns it into the
/// import's `counts_json` inside the same transaction, so the guide and
/// the numbers describing it are written together.
typedef EpgTotals = ({
  int channels,
  int programs,
  int? firstStartMs,
  int? lastEndMs,
});

/// The EPG store: the import's lifecycle, the staged rows, the swap, and
/// the guide's own tables. Reads that join the catalogue live in
/// `DbEpgRepository`; everything here is one table's own business.
@DriftAccessor(
  tables: [
    EpgImports,
    EpgChannels,
    EpgPrograms,
    EpgChannelsStaging,
    EpgProgramsStaging,
    EpgMappings,
    EpgMatches,
  ],
)
class EpgDao extends DatabaseAccessor<AppDatabase> with _$EpgDaoMixin {
  new(super.attachedDatabase);

  /// Opens an import and returns its id, the marker staged rows carry.
  Future<int> startImport(String sourceId, DateTime at) => into(epgImports)
      .insert(EpgImportsCompanion.insert(sourceId: sourceId, startedAt: at));

  Future<void> finishImport(
    int id, {
    required SyncOutcome outcome,
    required DateTime at,
    String? failure,
    int? failureStatus,
    String? countsJson,
  }) => (update(epgImports)..where((t) => t.id.equals(id))).write(
    EpgImportsCompanion(
      outcome: Value(outcome),
      finishedAt: Value(at),
      failure: Value(failure),
      failureStatus: Value(failureStatus),
      countsJson: Value(countsJson),
    ),
  );

  /// Called once on launch, beside `SyncRunsDao.failInterrupted()`: an
  /// import still marked running belongs to a process that is gone.
  Future<int> failInterruptedImports(DateTime at) =>
      (update(
        epgImports,
      )..where((t) => t.outcome.equalsValue(SyncOutcome.running))).write(
        EpgImportsCompanion(
          outcome: const Value(SyncOutcome.failed),
          finishedAt: Value(at),
          failure: const Value(epgInterruptedFailure),
        ),
      );

  /// Drops staged rows left by an import that is no longer running.
  /// Called on launch after [failInterruptedImports], so a killed import
  /// costs disk until the next start and nothing after it. Returns how
  /// many programme rows went.
  Future<int> sweepStaging() async {
    const abandoned =
        'import_run NOT IN (SELECT id FROM epg_imports '
        "WHERE outcome = 'running')";
    final programs = await customUpdate(
      'DELETE FROM epg_programs_staging WHERE $abandoned',
      updates: {epgProgramsStaging},
      updateKind: UpdateKind.delete,
    );
    await customUpdate(
      'DELETE FROM epg_channels_staging WHERE $abandoned',
      updates: {epgChannelsStaging},
      updateKind: UpdateKind.delete,
    );
    return programs;
  }

  /// One batch, never a transaction: the import runs in an isolate that
  /// can be killed, and a killed isolate's open transaction blocks the
  /// database for everyone (hard rule 2, the Phase 2 spike).
  ///
  /// A duplicate channel id is dropped rather than raised: the first one
  /// the file declares wins, and the parser counts the rest.
  Future<void> stageChannels(List<EpgChannelsStagingCompanion> rows) => batch(
    (b) =>
        b.insertAll(epgChannelsStaging, rows, mode: InsertMode.insertOrIgnore),
  );

  Future<void> stagePrograms(List<EpgProgramsStagingCompanion> rows) =>
      batch((b) => b.insertAll(epgProgramsStaging, rows));

  /// Puts import [importRun] in place: the source's live guide is
  /// replaced by the staged rows, the import becomes the live one, and
  /// its staging is dropped — all in one transaction, so the guide is
  /// never half a file. Returns the channel and programme counts.
  ///
  /// This runs on the app's side, not in the import isolate: the isolate
  /// is killed on cancel, and this transaction must not be.
  Future<EpgTotals> swapIn({
    required String sourceId,
    required int importRun,
    required DateTime at,
    required String Function(EpgTotals totals) countsJson,
  }) => transaction(() async {
    await customStatement('DELETE FROM epg_programs WHERE source_id = ?', [
      sourceId,
    ]);
    await customStatement('DELETE FROM epg_channels WHERE source_id = ?', [
      sourceId,
    ]);
    await customStatement(
      'INSERT INTO epg_channels (source_id, xmltv_id, display_name, icon_url) '
      'SELECT ?, xmltv_id, display_name, icon_url '
      'FROM epg_channels_staging WHERE import_run = ?',
      [sourceId, importRun],
    );
    await customStatement(
      'INSERT INTO epg_programs (source_id, epg_channel_id, start_utc, '
      'end_utc, title, subtitle, description, category) '
      'SELECT ?, epg_channel_id, start_utc, end_utc, title, subtitle, '
      'description, category FROM epg_programs_staging WHERE import_run = ?',
      [sourceId, importRun],
    );
    final totals = await _totalsFor(sourceId);
    await customStatement(
      'DELETE FROM epg_programs_staging WHERE import_run = ?',
      [importRun],
    );
    await customStatement(
      'DELETE FROM epg_channels_staging WHERE import_run = ?',
      [importRun],
    );
    await customStatement(
      'UPDATE epg_imports SET is_live = 0 WHERE source_id = ? AND is_live = 1',
      [sourceId],
    );
    await (update(epgImports)..where((t) => t.id.equals(importRun))).write(
      EpgImportsCompanion(
        outcome: const Value(SyncOutcome.succeeded),
        finishedAt: Value(at),
        failure: const Value(null),
        failureStatus: const Value(null),
        countsJson: Value(countsJson(totals)),
        isLive: const Value(true),
      ),
    );
    return totals;
  });

  /// One pass over what the swap just inserted, so Settings → Guide can
  /// say what the guide covers without aggregating hundreds of thousands
  /// of rows every time it opens.
  Future<EpgTotals> _totalsFor(String sourceId) async {
    final row = await customSelect(
      'SELECT (SELECT COUNT(*) FROM epg_channels WHERE source_id = ?1) '
      'AS channels, COUNT(*) AS programs, MIN(start_utc) AS first_start, '
      'MAX(end_utc) AS last_end FROM epg_programs WHERE source_id = ?1',
      variables: [Variable.withString(sourceId)],
      readsFrom: {epgChannels, epgPrograms},
    ).getSingle();
    return (
      channels: row.read<int>('channels'),
      programs: row.read<int>('programs'),
      firstStartMs: row.read<int?>('first_start'),
      lastEndMs: row.read<int?>('last_end'),
    );
  }

  /// Removes the source's live guide (it has no source of truth any
  /// more, for instance after its EPG URL is cleared).
  Future<void> clearLiveGuide(String sourceId) => transaction(() async {
    await (delete(epgPrograms)..where((t) => t.sourceId.equals(sourceId))).go();
    await (delete(epgChannels)..where((t) => t.sourceId.equals(sourceId))).go();
    await (update(epgImports)
          ..where((t) => t.sourceId.equals(sourceId) & t.isLive.equals(true)))
        .write(const EpgImportsCompanion(isLive: Value(false)));
  });

  Future<EpgImportRow?> latestImport(String sourceId) =>
      (select(epgImports)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  Stream<EpgImportRow?> watchLatestImport(String sourceId) =>
      (select(epgImports)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .watchSingleOrNull();

  /// The import whose rows are live, if the source has a guide at all.
  Future<EpgImportRow?> liveImport(String sourceId) =>
      (select(epgImports)
            ..where((t) => t.sourceId.equals(sourceId) & t.isLive.equals(true))
            ..limit(1))
          .getSingleOrNull();

  Future<List<EpgChannelRow>> guideChannels(
    String sourceId, {
    String? nameLike,
    int limit = 50,
  }) {
    final query = select(epgChannels)
      ..where((t) => t.sourceId.equals(sourceId))
      ..orderBy([(t) => OrderingTerm(expression: t.displayName)])
      ..limit(limit);
    if (nameLike != null && nameLike.trim().isNotEmpty) {
      final pattern = '%${nameLike.trim()}%';
      query.where((t) => t.displayName.like(pattern) | t.xmltvId.like(pattern));
    }
    return query.get();
  }

  Future<void> setMapping(
    String sourceId,
    String channelRemoteKey,
    String xmltvId,
    DateTime at,
  ) => into(epgMappings).insertOnConflictUpdate(
    EpgMappingsCompanion.insert(
      sourceId: sourceId,
      channelRemoteKey: channelRemoteKey,
      xmltvId: xmltvId,
      updatedAt: at,
    ),
  );

  Future<int> removeMapping(String sourceId, String channelRemoteKey) =>
      (delete(epgMappings)..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                t.channelRemoteKey.equals(channelRemoteKey),
          ))
          .go();

  Future<List<EpgMappingRow>> mappingsFor(String sourceId) =>
      (select(epgMappings)..where((t) => t.sourceId.equals(sourceId))).get();

  /// Replaces what the matcher resolved for a source. Derived state, so
  /// it is rewritten whole; the user's mappings in `epg_mappings` are a
  /// different table and are never touched here.
  Future<void> replaceMatches(
    String sourceId,
    List<EpgMatchesCompanion> rows,
  ) => transaction(() async {
    await (delete(epgMatches)..where((t) => t.sourceId.equals(sourceId))).go();
    await batch((b) => b.insertAll(epgMatches, rows));
  });

  Future<EpgMatchRow?> matchFor(int channelId) => (select(
    epgMatches,
  )..where((t) => t.channelId.equals(channelId))).getSingleOrNull();
}
