import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/library/library_media.dart';

part 'library_item.freezed.dart';

/// What a file in the library is (docs/09's NameParser): a movie, an
/// episode of a show, or a video that is neither.
enum LibraryKind { movie, episode, unsorted }

/// A movie or an episode at a source: what a download is of, and what a
/// downloaded file stays linked to (docs/09).
enum VodType { movie, episode }

/// A folder whose videos are in the library (`library_folders`, schema
/// v9): the download folder, or one the user added.
@freezed
abstract class LibraryFolder with _$LibraryFolder {
  const factory({
    required int id,

    /// Absolute, as the system gave it.
    required String path,

    /// What the screens call it ("Movies HDD"): the drive's name for a
    /// folder on a removable drive, else the folder's own; the user can
    /// rename it.
    required String label,

    /// Where new downloads go. One folder at a time is; a folder that was
    /// stays in the library.
    required bool isDownloadFolder,

    /// False while the folder can't be read (a drive unplugged): its
    /// items show as "Drive not connected" (docs/09).
    required bool isAvailable,
    required DateTime addedAt,
    DateTime? lastScanAt,
  }) = _LibraryFolder;
}

/// A subtitle file beside a video (docs/09): `Movie.en.srt`,
/// `Movie.eng.forced.srt`.
@freezed
abstract class ExternalSubtitle with _$ExternalSubtitle {
  const factory({
    /// Its file name, in the video's own folder.
    required String fileName,

    /// srt, ass, ssa or vtt.
    required String format,

    /// The language tag as the name has it (`en`, `eng`); null when the
    /// name has none.
    String? language,
    @Default(false) bool forced,
  }) = _ExternalSubtitle;
}

/// The provider's title a downloaded file came from. Watch history and
/// favorites stay keyed to it, so progress is shared between streaming
/// and the file (docs/09).
@freezed
abstract class ProviderLink with _$ProviderLink {
  const factory({
    required String sourceId,
    required VodType type,
    required String remoteKey,

    /// An episode's series (its remote key).
    String? seriesKey,
  }) = _ProviderLink;
}

/// What the user set in Edit details (docs/09). It is kept apart from
/// what the name said, so a rescan never undoes it, and "Use the file's
/// name" can drop it.
@freezed
abstract class LibraryItemEdit with _$LibraryItemEdit {
  const factory({
    required LibraryKind kind,
    required String title,
    int? year,
    String? showTitle,
    int? season,
    int? episode,
  }) = _LibraryItemEdit;

  const new _();

  /// Tolerant: null when it isn't an edit.
  static LibraryItemEdit? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = LibraryKind.values.asNameMap()[json['kind']];
    final title = json['title'];
    if (kind == null || title is! String) return null;
    int? number(Object? value) => value is int ? value : null;
    final show = json['show'];
    return LibraryItemEdit(
      kind: kind,
      title: title,
      year: number(json['year']),
      showTitle: show is String ? show : null,
      season: number(json['season']),
      episode: number(json['episode']),
    );
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'year': ?year,
    'show': ?showTitle,
    'season': ?season,
    'episode': ?episode,
  };
}

/// A video in the library (`library_items`, schema v9). [title], [year],
/// [kind], [showTitle], [season] and [episode] are what the screens show:
/// the user's edit when there is one, else what the name said.
@freezed
abstract class LibraryItem with _$LibraryItem {
  const factory({
    required int id,
    required int folderId,

    /// Inside its folder, with `/` between parts on every system.
    required String relPath,
    required int sizeBytes,
    required DateTime modifiedAt,

    /// Size + the first and last 64 KB (docs/09): history, favorites and
    /// edits follow a file across renames and moves by it.
    required String quickHash,
    required LibraryKind kind,
    required String title,
    required DateTime addedAt,
    int? year,
    String? showTitle,
    int? season,
    int? episode,

    /// The last episode of a file holding several (`S02E04E05`).
    int? episodeEnd,

    /// Null until the file was probed.
    Duration? duration,
    String? thumbnailPath,
    String? artworkPath,
    @Default(<ExternalSubtitle>[]) List<ExternalSubtitle> subtitles,

    /// What the user set, when anything.
    LibraryItemEdit? edit,

    /// Set for a download.
    ProviderLink? provider,
    @Default(false) bool hidden,

    /// When its folder stopped being readable; the item goes 30 days
    /// later (docs/09).
    DateTime? unavailableSince,

    /// The file, absolute.
    String? path,

    /// What ffprobe said of it; null until the scanner's probe pass.
    LibraryMedia? media,

    /// A download's copy of its title's details (Phase 8 decision 5).
    Map<String, Object?>? details,

    /// Downloaded from a source (it may since have been removed).
    @Default(false) bool downloaded,
  }) = _LibraryItem;

  const new _();

  bool get isDownload => downloaded || provider != null;

  bool get available => unavailableSince == null;
}
