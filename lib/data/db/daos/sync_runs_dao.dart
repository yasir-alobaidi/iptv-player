import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';

part 'sync_runs_dao.g.dart';

/// The failure recorded for a run the app was closed or killed during.
const syncInterruptedFailure = 'interrupted';

@DriftAccessor(tables: [SyncRuns])
class SyncRunsDao extends DatabaseAccessor<AppDatabase>
    with _$SyncRunsDaoMixin {
  new(super.attachedDatabase);

  /// Opens a run and returns its id, the marker its upserts carry.
  Future<int> start(String sourceId, DateTime at) =>
      into(syncRuns)
          .insert(SyncRunsCompanion.insert(sourceId: sourceId, startedAt: at));

  Future<void> finish(
    int id, {
    required SyncOutcome outcome,
    required DateTime at,
    String? failure,
    String? countsJson,
  }) => (update(syncRuns)..where((t) => t.id.equals(id))).write(
    SyncRunsCompanion(
      outcome: Value(outcome),
      finishedAt: Value(at),
      failure: Value(failure),
      countsJson: Value(countsJson),
    ),
  );

  Future<SyncRunRow?> latest(String sourceId) =>
      (select(syncRuns)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  /// The source's last successful run before [before], the run id.
  Future<SyncRunRow?> lastSucceeded(String sourceId, {required int before}) =>
      (select(syncRuns)
            ..where(
              (t) =>
                  t.sourceId.equals(sourceId) &
                  t.id.isSmallerThanValue(before) &
                  t.outcome.equalsValue(SyncOutcome.succeeded),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  Stream<SyncRunRow?> watchLatest(String sourceId) =>
      (select(syncRuns)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .watchSingleOrNull();

  /// Called once on launch: a run still marked running belongs to a
  /// process that is gone. Returns how many there were.
  Future<int> failInterrupted(DateTime at) =>
      (update(
        syncRuns,
      )..where((t) => t.outcome.equalsValue(SyncOutcome.running))).write(
        SyncRunsCompanion(
          outcome: const Value(SyncOutcome.failed),
          finishedAt: Value(at),
          failure: const Value(syncInterruptedFailure),
        ),
      );
}
