import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'guide_providers.g.dart';

@Riverpod(keepAlive: true)
EpgRepository epgRepository(Ref ref) =>
    DbEpgRepository(ref.watch(appDatabaseProvider));

/// What the guide covers for [sourceId], live: Settings → Guide and the
/// Guide screen's empty states read it.
@riverpod
Stream<GuideCoverage> guideCoverage(Ref ref, String sourceId) =>
    ref.watch(epgRepositoryProvider).watchCoverage(sourceId);
