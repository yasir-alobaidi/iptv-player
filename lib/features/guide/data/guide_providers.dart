import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/sync/epg_importer.dart';
import 'package:iptv_player/data/sync/epg_match_service.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'guide_providers.g.dart';

@Riverpod(keepAlive: true)
EpgRepository epgRepository(Ref ref) =>
    DbEpgRepository(ref.watch(appDatabaseProvider));

/// The one match service: rematches a source after an import's swap and
/// after a sync (`syncServiceProvider` wires the second). Stops its runs
/// when the app closes.
///
/// It depends on nothing but the database and the log, so both the sync
/// engine and the importer can depend on it without a cycle.
@Riverpod(keepAlive: true)
EpgMatchService epgMatchService(Ref ref) {
  final service = EpgMatchService(
    database: ref.watch(appDatabaseProvider),
    log: ref.watch(appLogProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

/// The one guide importer, which rematches after every swap. Cancels its
/// imports when the app closes.
@Riverpod(keepAlive: true)
EpgImporter epgImporter(Ref ref) {
  final importer = EpgImporter(
    database: ref.watch(appDatabaseProvider),
    guide: ref.watch(epgRepositoryProvider),
    sources: ref.watch(sourceRepositoryProvider),
    log: ref.watch(appLogProvider),
    matches: ref.watch(epgMatchServiceProvider),
  );
  ref.onDispose(importer.dispose);
  return importer;
}

/// What the guide covers for [sourceId], live: Settings → Guide and the
/// Guide screen's empty states read it.
@riverpod
Stream<GuideCoverage> guideCoverage(Ref ref, String sourceId) =>
    ref.watch(epgRepositoryProvider).watchCoverage(sourceId);
