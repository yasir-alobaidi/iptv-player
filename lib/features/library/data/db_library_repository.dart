import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_media.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/library_scan.dart';
import 'package:iptv_player/data/library/name_parser.dart';
import 'package:iptv_player/data/library/system_trash.dart';
import 'package:iptv_player/features/library/data/library_scans.dart';
import 'package:path/path.dart' as p;

/// [LibraryRepository] on the library's tables (docs/09), with the scans
/// and the system's trash. Nothing here renames, moves or changes a file
/// in a folder the user added (hard rule 11): Delete file moves it to the
/// trash, after the screens asked.
final class DbLibraryRepository implements LibraryRepository {
  new(
    this._db, {
    required this._scans,
    required this._trash,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final LibraryScans _scans;
  final SystemTrash _trash;
  final DateTime Function() _now;

  @override
  Stream<List<LibraryFolder>> watchFolders() => _db.libraryDao
      .watchFolders()
      .map((rows) => [for (final row in rows) libraryFolderFromRow(row)]);

  @override
  Stream<List<LibraryItem>> watch(LibraryQuery query) {
    final items = _db.libraryDao.watchItems(
      kind: query.kind,
      hidden: query.hidden,
      folderId: query.folderId,
      downloaded: switch (query.origin) {
        LibraryOrigin.all => null,
        LibraryOrigin.downloaded => true,
        LibraryOrigin.localFolders => false,
      },
    );
    return Stream.multi((listener) {
      var folders = <int, LibraryFolderRow>{};
      List<LibraryItemRow>? rows;
      void emit() {
        final list = rows;
        if (list == null) return;
        listener.add([
          for (final row in list)
            libraryItemFromRow(row, folders[row.folderId]),
        ]);
      }

      final watchingFolders = _db.libraryDao.watchFolders().listen((list) {
        folders = {for (final f in list) f.id: f};
        emit();
      }, onError: listener.addError);
      final watchingItems = items.listen((list) {
        rows = list;
        emit();
      }, onError: listener.addError);
      listener.onCancel = () async {
        await watchingFolders.cancel();
        await watchingItems.cancel();
      };
    });
  }

  @override
  Future<Result<LibraryFolder>> addFolder(String path) => Result.guard(
    () async {
      final folder = p.normalize(p.absolute(path));
      if (!Directory(folder).existsSync()) {
        throw InvalidInputFailure('No folder at $folder.');
      }
      for (final kept in await _db.libraryDao.folders()) {
        if (p.equals(kept.path, folder)) {
          throw InvalidInputFailure('${kept.label} is already in the library.');
        }
        if (p.isWithin(kept.path, folder)) {
          throw InvalidInputFailure(
            'It is inside ${kept.label}, which is already in the library.',
          );
        }
        if (p.isWithin(folder, kept.path)) {
          throw InvalidInputFailure(
            '${kept.label} is inside it and already in the library: remove '
            'that one first.',
          );
        }
      }
      final id = await _db.libraryDao.addFolder(
        path: folder,
        label: folderLabel(folder),
        at: _now().toUtc(),
      );
      unawaited(_scans.scan(folderId: id));
      return libraryFolderFromRow((await _db.libraryDao.folderById(id))!);
    },
  );

  @override
  Future<Result<void>> removeFolder(int folderId) => Result.guard(() async {
    final folder = await _db.libraryDao.folderById(folderId);
    if (folder == null) return;
    if (folder.isDownloadFolder) {
      throw InvalidInputFailure(
        'The download folder stays in the library; choose another one in '
        'Settings first.',
      );
    }
    await _db.libraryDao.removeFolder(folderId);
    final removed = await _removed();
    if (removed.remove('$folderId') != null) await _saveRemoved(removed);
  });

  @override
  Future<Result<void>> renameFolder(int folderId, String label) =>
      Result.guard(() async {
        final name = label.trim();
        if (name.isEmpty) throw InvalidInputFailure('A name is needed.');
        await _db.libraryDao.changeFolder(
          folderId,
          LibraryFoldersCompanion(label: Value(name)),
        );
      });

  @override
  Future<void> rescan({int? folderId}) => _scans.scan(folderId: folderId);

  @override
  Future<Result<void>> editItem(
    int itemId,
    LibraryItemEdit? edit,
  ) => Result.guard(() async {
    final row = await _db.libraryDao.itemById(itemId);
    if (row == null) return;
    if (edit == null) {
      final parsed = parseVideoName(row.relPath);
      await _db.libraryDao.changeItem(
        itemId,
        LibraryItemsCompanion(
          kind: Value(parsed.kind),
          title: Value(parsed.title),
          year: Value(parsed.year),
          showTitle: Value(parsed.showTitle),
          season: Value(parsed.season),
          episode: Value(parsed.episode),
          episodeEnd: Value(parsed.episodeEnd),
          userEditsJson: const Value(null),
        ),
      );
      return;
    }
    final title = edit.title.trim();
    if (title.isEmpty && edit.kind != LibraryKind.episode) {
      throw InvalidInputFailure('A title is needed.');
    }
    final show = edit.showTitle?.trim();
    await _db.libraryDao.changeItem(
      itemId,
      LibraryItemsCompanion(
        kind: Value(edit.kind),
        title: Value(title),
        year: Value(edit.year),
        showTitle: Value(show == null || show.isEmpty ? null : show),
        season: Value(edit.kind == LibraryKind.episode ? edit.season : null),
        episode: Value(edit.kind == LibraryKind.episode ? edit.episode : null),
        episodeEnd: const Value(null),
        userEditsJson: Value(jsonEncode(edit.toJson())),
      ),
    );
  });

  @override
  Future<Result<void>> setHidden(int itemId, {required bool hidden}) =>
      Result.guard(
        () => _db.libraryDao.changeItem(
          itemId,
          LibraryItemsCompanion(isHidden: Value(hidden)),
        ),
      );

  @override
  Future<Result<void>> removeItem(int itemId) => Result.guard(() async {
    final row = await _db.libraryDao.itemById(itemId);
    if (row == null) return;
    final removed = await _removed();
    (removed['${row.folderId}'] ??= <String>{}).add(row.relPath);
    await _saveRemoved(removed);
    await _db.libraryDao.removeItem(itemId);
  });

  @override
  Future<Result<DeleteOutcome>> deleteFile(
    int itemId, {
    bool permanently = false,
  }) => Result.guard(() async {
    final row = await _db.libraryDao.itemById(itemId);
    if (row == null) return DeleteOutcome.deleted;
    final folder = await _db.libraryDao.folderById(row.folderId);
    if (folder == null) return DeleteOutcome.deleted;
    final video = p.joinAll([folder.path, ...row.relPath.split('/')]);
    final beside = p.dirname(video);
    final subtitles = [
      for (final s in subtitlesFromJson(row.subtitlesJson))
        p.join(beside, s.fileName),
    ];
    final files = [video, ...subtitles.where((s) => File(s).existsSync())];

    if (!permanently) {
      // The video first: no trash for it, nothing moved, and the screen
      // asks again.
      if (await _trash.trash(video) == TrashOutcome.noTrash) {
        return DeleteOutcome.noTrash;
      }
      for (final file in files.skip(1)) {
        if (await _trash.trash(file) == TrashOutcome.noTrash) {
          File(file).deleteSync();
        }
      }
    } else {
      for (final file in files) {
        final f = File(file);
        if (f.existsSync()) f.deleteSync();
      }
    }
    // A download's own folder: its poster, then the folder once empty
    // (docs/09: the app's artwork and the emptied folder).
    if (row.providerRemoteKey != null && folder.isDownloadFolder) {
      _tidyDownloadFolder(beside, folder.path);
    }
    await _db.libraryDao.removeItem(itemId);
    return permanently ? DeleteOutcome.deleted : DeleteOutcome.trashed;
  });

  /// The movie's or the show's folder the app made: its poster goes,
  /// then every folder left empty, up to the download folder.
  void _tidyDownloadFolder(String from, String root) {
    var dir = Directory(from);
    while (p.isWithin(root, dir.path)) {
      try {
        final left = dir.listSync();
        final posterOnly =
            left.length == 1 && p.basename(left.single.path) == 'poster.jpg';
        if (posterOnly) left.single.deleteSync();
        if (left.isEmpty || posterOnly) {
          dir.deleteSync();
        } else {
          return;
        }
      } on FileSystemException {
        return;
      }
      dir = dir.parent;
    }
  }

  Future<Map<String, Set<String>>> _removed() async {
    final text = await _db.settingsDao.read(libraryRemovedKey);
    return removedFromJson(text);
  }

  Future<void> _saveRemoved(Map<String, Set<String>> removed) =>
      _db.settingsDao.write(
        libraryRemovedKey,
        jsonEncode({
          for (final MapEntry(:key, :value) in removed.entries)
            if (value.isNotEmpty) key: [...value],
        }),
      );
}

/// A new folder's name: a removable drive's own name when it is the
/// drive itself (`/media/me/USB STICK`), else the folder's.
String folderLabel(String path) {
  final name = p.basename(path);
  return name.isEmpty ? path : name;
}

LibraryFolder libraryFolderFromRow(LibraryFolderRow row) => LibraryFolder(
  id: row.id,
  path: row.path,
  label: row.label,
  isDownloadFolder: row.isDownloadFolder,
  isAvailable: row.isAvailable,
  addedAt: row.addedAt,
  lastScanAt: row.lastScanAt,
);

LibraryItem libraryItemFromRow(LibraryItemRow row, LibraryFolderRow? folder) {
  final provider =
      row.providerSourceId != null &&
          row.providerItemType != null &&
          row.providerRemoteKey != null
      ? ProviderLink(
          sourceId: row.providerSourceId!,
          type: row.providerItemType!,
          remoteKey: row.providerRemoteKey!,
          seriesKey: row.providerSeriesKey,
        )
      : null;
  Object? decode(String? text) {
    if (text == null) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  final details = decode(row.detailsJson);
  return LibraryItem(
    id: row.id,
    folderId: row.folderId,
    relPath: row.relPath,
    sizeBytes: row.sizeBytes,
    modifiedAt: DateTime.fromMillisecondsSinceEpoch(row.mtime, isUtc: true),
    quickHash: row.quickHash,
    kind: row.kind,
    title: row.title,
    addedAt: row.addedAt,
    year: row.year,
    showTitle: row.showTitle,
    season: row.season,
    episode: row.episode,
    episodeEnd: row.episodeEnd,
    duration: row.durationMs == null
        ? null
        : Duration(milliseconds: row.durationMs!),
    thumbnailPath: row.thumbnailPath,
    artworkPath: row.artworkPath,
    subtitles: subtitlesFromJson(row.subtitlesJson),
    edit: LibraryItemEdit.fromJson(decode(row.userEditsJson)),
    provider: provider,
    hidden: row.isHidden,
    unavailableSince: row.unavailableSince,
    path: folder == null
        ? null
        : p.joinAll([folder.path, ...row.relPath.split('/')]),
    media: row.probeJson == null
        ? null
        : LibraryMedia.fromJson(decode(row.probeJson)),
    details: details is Map<String, Object?> ? details : null,
    downloaded: row.providerRemoteKey != null,
  );
}

/// The scanner's `subtitles_json`, read tolerantly.
List<ExternalSubtitle> subtitlesFromJson(String? text) {
  if (text == null) return const [];
  try {
    final json = jsonDecode(text);
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (entry is Map &&
            entry['file'] is String &&
            entry['format'] is String)
          ExternalSubtitle(
            fileName: entry['file'] as String,
            format: entry['format'] as String,
            language: entry['language'] is String
                ? entry['language'] as String
                : null,
            forced: entry['forced'] == true,
          ),
    ];
  } on FormatException {
    return const [];
  }
}
