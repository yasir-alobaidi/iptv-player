import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'source_providers.g.dart';

@Riverpod(keepAlive: true)
SourceRepository sourceRepository(Ref ref) => DbSourceRepository(
  database: ref.watch(appDatabaseProvider),
  store: ref.watch(credentialStoreProvider),
  secrets: ref.watch(secretRegistryProvider),
  log: ref.watch(appLogProvider),
);

/// The configured sources in the user's order, kept current.
@Riverpod(keepAlive: true)
Stream<List<Source>> sources(Ref ref) =>
    ref.watch(sourceRepositoryProvider).watchAll();

/// The one sync engine. Cancels every run when the app closes.
@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final engine = SyncEngine(
    database: ref.watch(appDatabaseProvider),
    sources: ref.watch(sourceRepositoryProvider),
    log: ref.watch(appLogProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
}

/// A source's sync as it happens: idle, running with progress, or how the
/// last run this session ended.
@riverpod
Stream<SyncStatus> syncStatus(Ref ref, String sourceId) =>
    ref.watch(syncServiceProvider).watch(sourceId);
