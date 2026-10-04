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
