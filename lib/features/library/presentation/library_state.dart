import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
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
