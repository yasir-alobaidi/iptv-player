import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/search/data/db_search_repository.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_providers.g.dart';

/// Search over the database (Phase 6 step 3). One for the app: it keeps
/// each source's first programme on now for a few minutes.
@Riverpod(keepAlive: true)
SearchRepository searchRepository(Ref ref) => DbSearchRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(settingsRepositoryProvider),
);
