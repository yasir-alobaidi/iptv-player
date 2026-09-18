import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/providers/m3u/m3u_reader.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';
import 'package:iptv_player/data/sync/m3u_sync.dart';
import 'package:iptv_player/data/sync/xtream_sync.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

/// Everything the sync isolate needs, as plain sendable values: the
/// database travels as a [DriftIsolate] to connect to, the credentials
/// as the strings the clients take. It lives only as long as the run.
final class SyncWork {
  const new({
    required this.sourceId,
    required this.type,
    required this.runId,
    required this.connection,
    required this.url,
    this.username,
    this.password,
    this.userAgent,
    this.batchSize = 5000,
  });

  final String sourceId;
  final SourceType type;
  final int runId;
  final DriftIsolate connection;

  /// The Xtream server, the real playlist URL, or the file path.
  final String url;
  final String? username;
  final String? password;
  final String? userAgent;

  /// Rows per upsert; each batch is one transaction (docs/02).
  final int batchSize;

  @override
  String toString() =>
      'SyncWork($sourceId, ${type.name}, run $runId, '
      '${redact(url)})';
}

/// What the isolate hands back for the engine to finish the run with.
final class SyncWorkResult {
  const new({
    required this.report,
    required this.sweepItems,
    required this.sweepCategories,
    this.sweepEpisodes = false,
    this.emptyLists = const {},
    this.epgUrls = const [],
    this.warnings = const [],
  });

  /// Counts only; the engine adds `removed` and `duration`.
  final SyncReport report;

  /// The lists that came back whole, so the items the run didn't see can
  /// go. A list that came back empty keeps what it had (ADR-009).
  final Set<CatalogueKind> sweepItems;
  final Set<CatalogueKind> sweepCategories;

  /// Xtream only: the item lists that came back empty. The engine sweeps
  /// one after all when the previous successful run found it empty too.
  final Set<CatalogueKind> emptyLists;

  /// M3U only: episodes come with the playlist and are swept with it.
  final bool sweepEpisodes;

  /// M3U only: the `url-tvg` URLs from the playlist's header. They can
  /// carry credentials, so the engine puts them in the secure store.
  final List<String> epgUrls;

  /// For the engine to log; the isolate has no log of its own. Never
  /// holds a URL or a credential.
  final List<String> warnings;
}

/// Starts [work] in a new isolate. Top level, so the closure sent to the
/// isolate captures [work] and nothing else.
BackgroundJob<SyncProgress, Result<SyncWorkResult>> startSyncJob(
  SyncWork work, {
  Duration? timeout,
}) => startBackgroundJob<SyncProgress, Result<SyncWorkResult>>(
  (report) => runSyncWork(work, report),
  timeout: timeout,
  debugName: 'sync',
);

/// The sync isolate's body: connects to the app's database, reads the
/// provider, and upserts what it sends, reporting progress as it goes.
///
/// **Every write is a single batch, never a transaction.** The engine can
/// kill this isolate at any moment (cancel, timeout), and a batch is
/// applied whole by the database isolate or not at all, whereas a killed
/// isolate's open transaction blocks the database for everyone (ADR-009,
/// step 5 spike). Sweeping and finishing the run happen on the engine's
/// side, in one transaction, once this returns.
Future<Result<SyncWorkResult>> runSyncWork(
  SyncWork work,
  void Function(SyncProgress progress) report,
) async {
  final db = AppDatabase(await work.connection.connect());
  XtreamClient? client;
  try {
    switch (work.type) {
      case SourceType.xtream:
        client = XtreamClient(
          server: work.url,
          username: work.username ?? '',
          password: work.password ?? '',
          userAgent: work.userAgent,
        );
        return await XtreamSync(
          db: db,
          client: client,
          sourceId: work.sourceId,
          runId: work.runId,
          report: report,
          batchSize: work.batchSize,
        ).run();
      case SourceType.m3uUrl:
      case SourceType.m3uFile:
        return await M3uSync(
          db: db,
          input: work.type == SourceType.m3uUrl
              ? M3uUrlInput(work.url, userAgent: work.userAgent)
              : M3uFileInput(work.url),
          sourceId: work.sourceId,
          runId: work.runId,
          report: report,
          batchSize: work.batchSize,
        ).run();
    }
  } on Object catch (error) {
    return Err(syncWriteFailure(error));
  } finally {
    client?.close();
    await db.close();
  }
}

/// The providers' clients return their failures; anything thrown during a
/// sync comes from writing to the database.
AppFailure syncWriteFailure(Object error) => switch (error) {
  DriftRemoteException() ||
  SqliteException() ||
  InvalidDataException() => StorageFailure('sync write: $error'),
  _ => AppFailure.fromError(error),
};
