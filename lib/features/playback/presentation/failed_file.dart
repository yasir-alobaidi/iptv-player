import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'failed_file.g.dart';

/// The file on this computer a play that failed was reading (Phase 8
/// decision 8): a library file, or a title's download. The failure card
/// offers Show in folder and Remove from library for it.
@riverpod
Future<LibraryItem?> failedFile(Ref ref, Playable item) {
  final library = ref.watch(libraryRepositoryProvider);
  return switch (item) {
    PlayableLibraryItem(:final item) => library.item(item.id),
    PlayableMovie(:final movie) => library.downloadOf(
      VodType.movie,
      movie.sourceId,
      movie.remoteKey,
    ),
    PlayableEpisode(:final episode) => library.downloadOf(
      VodType.episode,
      episode.sourceId,
      episode.remoteKey,
    ),
    PlayableChannel() => Future.value(),
  };
}
