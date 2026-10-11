import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:iptv_player/features/vod/presentation/details_state.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_state.g.dart';

/// The Library's tabs (canvas `Library`).
enum LibraryTab { movies, series, videos, folders }

/// The tab and the chip the Library shows: kept while the app runs, so
/// coming back finds them, and other screens can open a tab.
@immutable
final class LibraryViewState {
  const new({this.tab = LibraryTab.movies, this.origin = LibraryOrigin.all});

  final LibraryTab tab;

  /// All · Downloaded · Local folders, for Movies and Series.
  final LibraryOrigin origin;

  @override
  bool operator ==(Object other) =>
      other is LibraryViewState && other.tab == tab && other.origin == origin;

  @override
  int get hashCode => Object.hash(tab, origin);
}

@Riverpod(keepAlive: true)
class LibraryView extends _$LibraryView {
  @override
  LibraryViewState build() => const LibraryViewState();

  void showTab(LibraryTab tab) =>
      state = LibraryViewState(tab: tab, origin: state.origin);

  void showOrigin(LibraryOrigin origin) =>
      state = LibraryViewState(tab: state.tab, origin: origin);
}

/// The query a grid tab lists.
LibraryQuery libraryQueryFor(LibraryTab tab, LibraryOrigin origin) =>
    switch (tab) {
      LibraryTab.movies => LibraryQuery(
        kind: LibraryKind.movie,
        origin: origin,
      ),
      // Videos are the user's own: nothing downloaded is unsorted.
      _ => const LibraryQuery(kind: LibraryKind.unsorted),
    };

@riverpod
Stream<LibraryCount> libraryCount(Ref ref, LibraryQuery query) =>
    ref.watch(libraryRepositoryProvider).watchCount(query);

@riverpod
Stream<List<LibraryShow>> libraryShows(Ref ref, LibraryOrigin origin) =>
    ref.watch(libraryRepositoryProvider).watchShows(origin: origin);

@riverpod
Stream<List<LibraryItem>> libraryShowEpisodes(Ref ref, String showKey) =>
    ref.watch(libraryRepositoryProvider).watchShowEpisodes(showKey);

@riverpod
Stream<List<LibraryFolder>> libraryFolders(Ref ref) =>
    ref.watch(libraryRepositoryProvider).watchFolders();

@riverpod
Stream<Map<int, LibraryFolderTotals>> libraryFolderTotals(Ref ref) =>
    ref.watch(libraryRepositoryProvider).watchFolderTotals();

/// One item, read again when the library changes (its page).
@riverpod
Stream<LibraryItem?> libraryItem(Ref ref, int itemId) async* {
  final library = ref.watch(libraryRepositoryProvider);
  yield await library.item(itemId);
  await for (final _ in library.watchCount(const LibraryQuery())) {
    yield await library.item(itemId);
  }
}

/// Where a library item was left (its card's bar, its page's Resume).
@riverpod
Stream<WatchMark?> libraryMark(Ref ref, LibraryItem item) =>
    ref.watch(watchProgressProvider).watch(libraryVodRef(item));

/// Whether a library item is a favorite (its card's star, F).
@riverpod
Stream<bool> libraryFavorite(Ref ref, LibraryItem item) =>
    ref.watch(libraryFavoritesProvider).watchFavorite(item);

/// Where the user's own files were left, by quick hash.
@riverpod
Stream<Map<String, WatchMark>> libraryLocalMarks(Ref ref) =>
    ref.watch(watchProgressProvider).watchLocalFiles();

/// Where a show's episodes were left, by item id (its page: the rows'
/// bars and Continue); null until every mark has been read, so the page
/// decides once where to continue. A file of the user's own is found by
/// its quick hash, a download under its series at the provider
/// ([libraryVodRef]).
@riverpod
Map<int, WatchMark>? libraryShowMarks(Ref ref, String showKey) {
  final episodes = ref.watch(libraryShowEpisodesProvider(showKey)).value;
  if (episodes == null) return null;
  final marks = <int, WatchMark>{};
  var read = true;
  for (final episode in episodes) {
    final AsyncValue<WatchMark?> mark;
    switch (libraryVodRef(episode)) {
      case EpisodeRef(:final sourceId, :final remoteKey, :final seriesKey):
        mark = ref
            .watch(seriesMarksProvider(sourceId, seriesKey))
            .whenData((marks) => marks[remoteKey]);
      case LocalRef(:final quickHash):
        mark = ref
            .watch(libraryLocalMarksProvider)
            .whenData((marks) => marks[quickHash]);
      case final MovieRef movie:
        mark = ref.watch(watchMarkProvider(movie));
    }
    // A mark that can't be read is no mark: the episode still plays.
    if (!mark.hasValue && !mark.hasError) read = false;
    if (mark.value case final value?) marks[episode.id] = value;
  }
  return read ? marks : null;
}
