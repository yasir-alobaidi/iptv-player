import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/result.dart';
import 'package:meta/meta.dart';

/// Which of the Library's items a screen lists (docs/05: the tabs and
/// the chips).
enum LibraryOrigin { all, downloaded, localFolders }

/// What a Library list shows.
@immutable
final class LibraryQuery {
  const new({
    this.kind,
    this.origin = LibraryOrigin.all,
    this.hidden = false,
    this.folderId,
  });

  /// Null: every kind (Settings' Hidden videos).
  final LibraryKind? kind;
  final LibraryOrigin origin;

  /// True lists only hidden items (Settings' Hidden videos); false leaves
  /// them out.
  final bool hidden;

  /// One folder's items only.
  final int? folderId;

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.kind == kind &&
      other.origin == origin &&
      other.hidden == hidden &&
      other.folderId == folderId;

  @override
  int get hashCode => Object.hash(kind, origin, hidden, folderId);
}

/// How many items a Library list holds and their size on disk (the
/// header's "42 movies · 186 GB on this computer"). [revision] moves with
/// every change to the library or its history, so a grid reads its pages
/// again even when the count stays.
@immutable
final class LibraryCount {
  const new({required this.count, required this.bytes, this.revision = 0});

  final int count;
  final int bytes;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is LibraryCount &&
      other.count == count &&
      other.bytes == bytes &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(count, bytes, revision);
}

/// A show of the Library's Series tab (sketch B): the user's own episodes
/// of one show, across folders, or the downloaded episodes of one of a
/// provider's series.
@immutable
final class LibraryShow {
  const new({
    required this.key,
    required this.title,
    required this.episodes,
    required this.seasons,
    required this.bytes,
    this.artworkPath,
    this.folderId,
    this.downloaded = false,
    this.providerSourceId,
    this.providerSeriesKey,
    this.available = true,
  });

  /// The same show from one read to the next.
  final String key;
  final String title;
  final int episodes;
  final int seasons;
  final int bytes;

  /// A poster on disk (the show folder's, or a download's).
  final String? artworkPath;

  /// Its folder, when all its episodes are in one; null across several.
  final int? folderId;
  final bool downloaded;

  /// The provider's series its downloads came from.
  final String? providerSourceId;
  final String? providerSeriesKey;

  /// False when none of its episodes is on a drive that is connected.
  final bool available;

  @override
  bool operator ==(Object other) =>
      other is LibraryShow &&
      other.key == key &&
      other.title == title &&
      other.episodes == episodes &&
      other.seasons == seasons &&
      other.bytes == bytes &&
      other.artworkPath == artworkPath &&
      other.folderId == folderId &&
      other.downloaded == downloaded &&
      other.providerSourceId == providerSourceId &&
      other.providerSeriesKey == providerSeriesKey &&
      other.available == available;

  @override
  int get hashCode => Object.hash(
    key,
    title,
    episodes,
    seasons,
    bytes,
    artworkPath,
    folderId,
    downloaded,
    providerSourceId,
    providerSeriesKey,
    available,
  );
}

/// A folder's videos and their size (the folder rows: "1,204 videos").
typedef LibraryFolderTotals = ({int items, int bytes});

/// How a Delete file went (docs/09).
enum DeleteOutcome {
  /// In the system's trash, from where the user can put it back.
  trashed,

  /// Gone for good (asked twice, where there was no trash).
  deleted,

  /// There is no trash for it: ask again before deleting for good.
  noTrash,
}

/// The library: the folders, their videos, and what the user does to
/// them (docs/01, docs/09). Nothing here renames, moves or changes a
/// file in a folder the user added (hard rule 11); only Delete file
/// touches one, after a confirmation.
abstract interface class LibraryRepository {
  Stream<List<LibraryFolder>> watchFolders();

  Stream<List<LibraryItem>> watch(LibraryQuery query);

  /// [query]'s count and size now, then on every change.
  Stream<LibraryCount> watchCount(LibraryQuery query);

  /// [limit] of [query]'s items from [offset], in [watch]'s order: a grid
  /// reads its window, never the whole list (hard rule 2).
  Future<Result<List<LibraryItem>>> range(
    LibraryQuery query,
    int offset,
    int limit,
  );

  /// The Series tab's shows, by title.
  Stream<List<LibraryShow>> watchShows({
    LibraryOrigin origin = LibraryOrigin.all,
  });

  /// The episodes of the show keyed [showKey], by season and episode.
  Stream<List<LibraryItem>> watchShowEpisodes(String showKey);

  /// Every folder's videos and their size.
  Stream<Map<int, LibraryFolderTotals>> watchFolderTotals();

  /// One item; null when it isn't in the library.
  Future<LibraryItem?> item(int itemId);

  /// The downloaded file of a provider's title, when there is one.
  Future<LibraryItem?> downloadOf(
    VodType type,
    String sourceId,
    String remoteKey,
  );

  Future<Result<LibraryFolder>> addFolder(String path);

  /// Takes the folder and its items out of the library; the files stay.
  Future<Result<void>> removeFolder(int folderId);

  Future<Result<void>> renameFolder(int folderId, String label);

  /// Scans [folderId], or every folder.
  Future<void> rescan({int? folderId});

  /// Sets what the user said the item is; null goes back to the name.
  Future<Result<void>> editItem(int itemId, LibraryItemEdit? edit);

  Future<Result<void>> setHidden(int itemId, {required bool hidden});

  /// Takes the item out of the library; the file stays.
  Future<Result<void>> removeItem(int itemId);

  /// The next file of [episode]'s show (by season and episode), across
  /// the library's folders; null after the last.
  Future<LibraryItem?> episodeAfter(LibraryItem episode);

  /// Moves the video and its subtitle files to the trash, or, with
  /// [permanently], deletes them.
  Future<Result<DeleteOutcome>> deleteFile(
    int itemId, {
    bool permanently = false,
  });
}
