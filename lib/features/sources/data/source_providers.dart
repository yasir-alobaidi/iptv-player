import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
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
