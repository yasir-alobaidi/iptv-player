import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_category_repository.dart';
import 'package:iptv_player/features/sources/data/db_source_overview_repository.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/data/provider_source_checker.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_check.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
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

/// One source, kept current; null once it is removed.
@riverpod
Stream<Source?> sourceById(Ref ref, String sourceId) => ref
    .watch(sourceRepositoryProvider)
    .watchAll()
    .map((all) => all.where((s) => s.id == sourceId).firstOrNull);

/// "Test connection" in onboarding.
@Riverpod(keepAlive: true)
SourceChecker sourceChecker(Ref ref) => ProviderSourceChecker();

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) =>
    DbCategoryRepository(ref.watch(appDatabaseProvider));

/// A source's categories of one kind with their item counts, for the
/// pickers.
@riverpod
Stream<CategoryList> categoryList(
  Ref ref,
  String sourceId,
  CatalogueKind kind,
) => ref.watch(categoryRepositoryProvider).watch(sourceId, kind);

@Riverpod(keepAlive: true)
SourceOverviewRepository sourceOverviewRepository(Ref ref) =>
    DbSourceOverviewRepository(ref.watch(appDatabaseProvider));

/// A source's account, counts and latest sync, for Settings → Sources and
/// the top bar; null once the source is gone.
@riverpod
Stream<SourceOverview?> sourceOverview(Ref ref, String sourceId) =>
    ref.watch(sourceOverviewRepositoryProvider).watch(sourceId);
