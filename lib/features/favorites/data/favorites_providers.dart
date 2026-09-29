import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/favorites/data/db_favorites_repository.dart';
import 'package:iptv_player/features/favorites/domain/favorites.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'favorites_providers.g.dart';

@Riverpod(keepAlive: true)
FavoritesRepository favoritesRepository(Ref ref) => DbFavoritesRepository(
  ref.watch(appDatabaseProvider),
  clock: ref.watch(appClockProvider),
);

/// A source's groups of favorite channels, in their order, kept current.
@riverpod
Stream<List<FavoriteGroup>> favoriteGroups(Ref ref, String sourceId) =>
    ref.watch(favoritesRepositoryProvider).watchGroups(sourceId);
