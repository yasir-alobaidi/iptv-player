import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_media.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/job_database.dart';
import 'package:iptv_player/data/library/library_probe.dart';
import 'package:iptv_player/data/library/name_parser.dart';
import 'package:iptv_player/data/library/quick_hash.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// docs/09's video files.
const videoExtensions = {
  'mkv', 'mp4', 'm4v', 'mov', 'avi', 'ts', 'm2ts', 'mts', 'webm', 'wmv', //
  'mpg', 'mpeg',
};

/// docs/09's subtitle files.
const subtitleExtensions = {'srt', 'ass', 'ssa', 'vtt'};

/// docs/09: files under this are left out (configurable; tests lower it).
const int defaultMinVideoBytes = 20 * 1000 * 1000;

/// docs/09: items of a folder that can't be read go after this.
const unavailableFor = Duration(days: 30);

/// The settings key of the files the user took out of the library, so a
/// rescan leaves them out: `{"<folder id>": ["<rel path>", …]}`.
const libraryRemovedKey = 'library.removed';

/// [libraryRemovedKey]'s value, read tolerantly.
Map<String, Set<String>> removedFromJson(String? text) {
  if (text == null) return {};
  try {
    final json = jsonDecode(text);
    if (json is! Map) return {};
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (key is String && value is List)
          key: {
            for (final path in value)
              if (path is String) path,
          },
    };
  } on FormatException {
    return {};
  }
}

/// Everything a scan needs, as sendable values.
final class LibraryScanWork {
  const new({
    required this.now,
    this.connection,
    this.folderIds,
    this.minBytes = defaultMinVideoBytes,
    this.ffprobe,
    this.processFolder,
    this.probeAtOnce = 4,
    this.batchSize = 500,
  });

  /// The app's database to connect to; null when a test runs the scan
  /// on its own database.
  final DriftIsolate? connection;

  /// The folders to scan; null is every one.
  final List<int>? folderIds;
  final int minBytes;

  /// For the second pass; null skips it.
  final String? ffprobe;
  final String? processFolder;
  final int probeAtOnce;
  final int batchSize;
  final DateTime now;
}

/// How a scan is going: [folderId]'s walk has found [found] videos, of
/// which [written] are written; the probe pass has read [probed].
final class LibraryScanProgress {
  const new({
    required this.folderId,
    required this.found,
    required this.written,
    this.probed = 0,
    this.probing = false,
  });

  final int folderId;
  final int found;
  final int written;
  final int probed;
  final bool probing;

  @override
  String toString() =>
      'LibraryScanProgress($folderId: $found found, $written written, '
      '$probed probed)';
}

/// What a scan did.
final class LibraryScanResult {
  const new({
    this.added = 0,
    this.changed = 0,
    this.moved = 0,
    this.removed = 0,
    this.probed = 0,
    this.unreadable = 0,
    this.unavailableFolders = 0,
  });

  final int added;
  final int changed;

  /// Found again by its quick hash under another name or folder: its
  /// history, favorites and edits went with it (docs/09).
  final int moved;
  final int removed;
  final int probed;
  final int unreadable;
  final int unavailableFolders;

  @override
  String toString() =>
      'LibraryScanResult(+$added, ~$changed, moved $moved, −$removed, '
      'probed $probed, unreadable $unreadable, '
      'folders not there $unavailableFolders)';
}

/// Starts [work] in a guarded isolate (docs/09: the scanner is a
/// background isolate; a stop never cuts a batch in half).
BackgroundJob<LibraryScanProgress, Result<LibraryScanResult>>
startLibraryScanJob(LibraryScanWork work) =>
    startGuardedJob<LibraryScanProgress, Result<LibraryScanResult>>(
      (report, cancellation) =>
          runLibraryScan(work, report, cancellation: cancellation),
      debugName: 'library-scan',
    );

/// The scan (Phase 8 decision 6), folder by folder:
///
/// 1. **The walk:** every video file (docs/09's skips: hidden files and
///    folders, `.part`, under the minimum size, samples, trailers,
///    featurettes); a file with the same path, size and time is done; a
///    new or changed one is quick-hashed and its name parsed; a new hash
///    that matches a file gone missing is that file, moved; what is gone
///    is removed. Written every [LibraryScanWork.batchSize] files, so the
///    Library fills while it runs. A folder that can't be read has its
///    items marked "Drive not connected", and they go after 30 days.
/// 2. **The probe:** ffprobe on each item not probed yet, 4 at a time.
///
/// The user's edits are never overwritten; nothing on disk is changed
/// (hard rule 11). Never throws.
Future<Result<LibraryScanResult>> runLibraryScan(
  LibraryScanWork work,
  void Function(LibraryScanProgress progress)? report, {
  JobCancellation? cancellation,
  AppDatabase? database,
}) async {
  AppDatabase? opened;
  try {
    final db =
        database ??
        (opened = await openJobDatabase(work.connection!, cancellation));
    final scan = _Scan(work, db, report, cancellation);
    return Ok(await scan.run());
  } on Object catch (error) {
    return Err(switch (error) {
      AppFailure() => error,
      _ => UnexpectedFailure('library scan: ${'$error'.split('\n').first}'),
    });
  } finally {
    await opened?.close();
  }
}

final class _Scan {
  new(this.work, this.db, this.report, this.cancellation);

  final LibraryScanWork work;
  final AppDatabase db;
  final void Function(LibraryScanProgress progress)? report;
  final JobCancellation? cancellation;

  int added = 0;
  int changed = 0;
  int moved = 0;
  int removed = 0;
  int probed = 0;
  int unreadable = 0;
  int unavailableFolders = 0;

  /// Rows whose file is gone, removed once every folder is walked (their
  /// history stays, keyed by the hash, should the file come back).
  final _gone = <int, LibraryItemRow>{};

  Future<LibraryScanResult> run() async {
    final folders = await db.libraryDao.folders();
    final wanted = work.folderIds?.toSet();
    for (final folder in folders) {
      if (wanted != null && !wanted.contains(folder.id)) continue;
      if (cancellation?.isRequested ?? false) break;
      await _folder(folder);
    }
    if (_gone.isNotEmpty && !(cancellation?.isRequested ?? false)) {
      final rows = [..._gone.values];
      await db.transaction(() async {
        for (final row in rows) {
          await db.libraryDao.removeItem(row.id);
        }
      });
      removed += rows.length;
    }
    if (work.ffprobe != null) {
      for (final folder in folders) {
        if (wanted != null && !wanted.contains(folder.id)) continue;
        if (cancellation?.isRequested ?? false) break;
        await _probe(folder);
      }
    }
    return LibraryScanResult(
      added: added,
      changed: changed,
      moved: moved,
      removed: removed,
      probed: probed,
      unreadable: unreadable,
      unavailableFolders: unavailableFolders,
    );
  }

  // ---- Pass 1.

  Future<void> _folder(LibraryFolderRow folder) async {
    final dao = db.libraryDao;
    final root = Directory(folder.path);
    if (!root.existsSync()) {
      await _unavailable(folder);
      return;
    }
    if (!folder.isAvailable) {
      await db.transaction(() async {
        await dao.changeFolder(
          folder.id,
          const LibraryFoldersCompanion(isAvailable: Value(true)),
        );
        await (db.update(db.libraryItems)
              ..where((t) => t.folderId.equals(folder.id)))
            .write(const LibraryItemsCompanion(unavailableSince: Value(null)));
      });
    }

    final found = <String, _Found>{};
    _walk(root, '', found);
    // What the user took out of the library stays out.
    final removedPaths = removedFromJson(
      await db.settingsDao.read(libraryRemovedKey),
    )['${folder.id}'];
    if (removedPaths != null) {
      found.removeWhere((k, _) => removedPaths.contains(k));
    }
    final existing = {
      for (final row in await dao.itemsIn(folder.id)) row.relPath: row,
    };
    final pending = <Future<void> Function()>[];
    var written = 0;

    Future<void> flush() async {
      if (pending.isEmpty) return;
      final batch = [...pending];
      pending.clear();
      await db.transaction(() async {
        for (final write in batch) {
          await write();
        }
      });
      written += batch.length;
      report?.call(
        LibraryScanProgress(
          folderId: folder.id,
          found: found.length,
          written: written,
        ),
      );
    }

    final gone = {
      for (final entry in existing.entries)
        if (!found.containsKey(entry.key)) entry.key: entry.value,
    };
    final goneByHash = <String, List<LibraryItemRow>>{};
    for (final row in gone.values) {
      goneByHash.putIfAbsent(row.quickHash, () => []).add(row);
    }

    for (final MapEntry(key: relPath, value: file) in found.entries) {
      if (cancellation?.isRequested ?? false) break;
      final row = existing[relPath];
      if (row != null &&
          row.sizeBytes == file.size &&
          row.mtime == file.mtime) {
        // Unchanged: only what lies beside it may have.
        final subtitles = _subtitlesJson(file.subtitles);
        if (row.subtitlesJson != subtitles ||
            (row.artworkPath != file.artwork && file.artwork != null)) {
          pending.add(
            () => dao.changeItem(
              row.id,
              LibraryItemsCompanion(
                subtitlesJson: Value(subtitles),
                artworkPath: Value(file.artwork ?? row.artworkPath),
              ),
            ),
          );
        }
      } else {
        final String hash;
        try {
          hash = await quickHash(File(file.path));
        } on FileSystemException {
          continue;
        }
        final parsed = parseVideoName(relPath);
        if (row != null) {
          changed++;
          pending.add(
            () => dao.changeItem(
              row.id,
              _named(row.userEditsJson, parsed).copyWith(
                sizeBytes: Value(file.size),
                mtime: Value(file.mtime),
                quickHash: Value(hash),
                probeJson: const Value(null),
                durationMs: const Value(null),
                thumbnailPath: const Value(null),
                subtitlesJson: Value(_subtitlesJson(file.subtitles)),
                artworkPath: Value(file.artwork),
              ),
            ),
          );
        } else {
          final mine = goneByHash[hash];
          final was = mine != null && mine.isNotEmpty
              ? mine.removeLast()
              : await _goneElsewhere(hash, folder.id);
          if (was != null) {
            if (gone[was.relPath]?.id == was.id) gone.remove(was.relPath);
            _gone.remove(was.id);
            moved++;
            pending.add(
              () => dao.changeItem(
                was.id,
                _named(was.userEditsJson, parsed).copyWith(
                  folderId: Value(folder.id),
                  relPath: Value(relPath),
                  sizeBytes: Value(file.size),
                  mtime: Value(file.mtime),
                  subtitlesJson: Value(_subtitlesJson(file.subtitles)),
                  artworkPath: Value(file.artwork ?? was.artworkPath),
                  unavailableSince: const Value(null),
                ),
              ),
            );
          } else {
            added++;
            pending.add(
              () => dao.insertItem(
                LibraryItemsCompanion.insert(
                  folderId: folder.id,
                  relPath: relPath,
                  sizeBytes: file.size,
                  mtime: file.mtime,
                  quickHash: hash,
                  kind: parsed.kind,
                  title: parsed.title,
                  year: Value(parsed.year),
                  showTitle: Value(parsed.showTitle),
                  season: Value(parsed.season),
                  episode: Value(parsed.episode),
                  episodeEnd: Value(parsed.episodeEnd),
                  subtitlesJson: Value(_subtitlesJson(file.subtitles)),
                  artworkPath: Value(file.artwork),
                  addedAt: work.now.toUtc(),
                ),
              ),
            );
          }
        }
      }
      if (pending.length >= work.batchSize) await flush();
    }
    // What is gone goes once every folder is walked: a later folder may
    // find it moved there.
    for (final row in gone.values) {
      _gone[row.id] = row;
    }
    await flush();
    await dao.changeFolder(
      folder.id,
      LibraryFoldersCompanion(lastScanAt: Value(work.now.toUtc())),
    );
    report?.call(
      LibraryScanProgress(
        folderId: folder.id,
        found: found.length,
        written: written,
      ),
    );
  }

  /// A row of another folder with [hash] whose file is gone: the same
  /// file, moved between library folders.
  Future<LibraryItemRow?> _goneElsewhere(String hash, int folderId) async {
    for (final row in await db.libraryDao.itemsWithHash(hash)) {
      if (row.folderId == folderId) continue;
      if (_gone.containsKey(row.id)) return row;
      final folder = await db.libraryDao.folderById(row.folderId);
      if (folder == null || !folder.isAvailable) continue;
      final path = p.joinAll([folder.path, ...row.relPath.split('/')]);
      if (!File(path).existsSync()) return row;
    }
    return null;
  }

  /// The parsed fields, unless the user set them (docs/09: edits survive
  /// rescans).
  LibraryItemsCompanion _named(String? edits, ParsedName parsed) {
    if (edits != null) return const LibraryItemsCompanion();
    return LibraryItemsCompanion(
      kind: Value(parsed.kind),
      title: Value(parsed.title),
      year: Value(parsed.year),
      showTitle: Value(parsed.showTitle),
      season: Value(parsed.season),
      episode: Value(parsed.episode),
      episodeEnd: Value(parsed.episodeEnd),
    );
  }

  /// docs/09: dimmed as "Drive not connected", gone after 30 days.
  Future<void> _unavailable(LibraryFolderRow folder) async {
    unavailableFolders++;
    final now = work.now.toUtc();
    await db.transaction(() async {
      await db.libraryDao.changeFolder(
        folder.id,
        const LibraryFoldersCompanion(isAvailable: Value(false)),
      );
      await (db.update(db.libraryItems)..where(
            (t) => t.folderId.equals(folder.id) & t.unavailableSince.isNull(),
          ))
          .write(LibraryItemsCompanion(unavailableSince: Value(now)));
      removed +=
          await (db.delete(db.libraryItems)..where(
                (t) =>
                    t.folderId.equals(folder.id) &
                    t.unavailableSince.isSmallerThanValue(
                      now.subtract(unavailableFor),
                    ),
              ))
              .go();
    });
  }

  // ---- The walk.

  static final _junk = RegExp(
    r'(^|[\s._\-\[(])(sample|trailer|featurette)s?([\s._\-\])]|$)',
    caseSensitive: false,
  );

  static final _junkFolder = RegExp(
    r'^(samples?|trailers?|featurettes?|extras|behind the scenes)$',
    caseSensitive: false,
  );

  void _walk(Directory dir, String rel, Map<String, _Found> found) {
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    final videos = <String, ({String path, int size, int mtime})>{};
    final subtitles = <String>[];
    final pictures = <String, String>{};
    for (final entry in entries) {
      final name = p.basename(entry.path);
      if (name.startsWith('.')) continue;
      final relPath = rel.isEmpty ? name : '$rel/$name';
      if (entry is Directory) {
        if (_junkFolder.hasMatch(name)) continue;
        _walk(entry, relPath, found);
        continue;
      }
      if (entry is! File) continue;
      final dot = name.lastIndexOf('.');
      final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
      if (videoExtensions.contains(ext)) {
        if (_junk.hasMatch(name.substring(0, dot))) continue;
        final FileStat stat;
        try {
          stat = entry.statSync();
        } on FileSystemException {
          continue;
        }
        if (stat.size < work.minBytes) continue;
        videos[relPath] = (
          path: entry.path,
          size: stat.size,
          mtime: stat.modified.millisecondsSinceEpoch,
        );
      } else if (subtitleExtensions.contains(ext)) {
        subtitles.add(name);
      } else if (const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
        pictures[name.toLowerCase()] = entry.path;
      }
    }
    if (videos.isEmpty) return;
    // A season folder's videos take the show's poster from the folder
    // above.
    final above = rel.isEmpty ? null : _folderPoster(dir.parent);
    for (final MapEntry(key: relPath, value: video) in videos.entries) {
      final name = p.basename(video.path);
      final stem = name.substring(0, name.lastIndexOf('.'));
      found[relPath] = _Found(
        path: video.path,
        size: video.size,
        mtime: video.mtime,
        subtitles: _subtitlesFor(stem, subtitles),
        artwork:
            pictures['$stem-poster.jpg'.toLowerCase()] ??
            pictures['$stem.jpg'.toLowerCase()] ??
            _poster(pictures) ??
            above,
      );
    }
  }

  static String? _poster(Map<String, String> pictures) {
    for (final name in const [
      'poster.jpg', 'poster.png', 'folder.jpg', 'folder.png', 'cover.jpg', //
      'cover.png', 'poster.jpeg', 'folder.jpeg', 'cover.jpeg',
    ]) {
      if (pictures[name] case final path?) return path;
    }
    return null;
  }

  static String? _folderPoster(Directory dir) {
    try {
      final pictures = {
        for (final entry in dir.listSync(followLinks: false))
          if (entry is File) p.basename(entry.path).toLowerCase(): entry.path,
      };
      return _poster(pictures);
    } on FileSystemException {
      return null;
    }
  }

  /// docs/09: the video's own name, then an optional language and flags
  /// (`Movie.en.srt`, `Movie.eng.forced.srt`).
  static List<ExternalSubtitle> _subtitlesFor(String stem, List<String> files) {
    final lower = stem.toLowerCase();
    return [
      for (final file in files)
        if (file.toLowerCase().startsWith('$lower.'))
          ?_subtitle(file, file.substring(stem.length + 1)),
    ]..sort((a, b) => a.fileName.compareTo(b.fileName));
  }

  static ExternalSubtitle? _subtitle(String file, String rest) {
    final parts = rest.split('.');
    final format = parts.removeLast().toLowerCase();
    if (!subtitleExtensions.contains(format)) return null;
    String? language;
    var forced = false;
    for (final part in parts) {
      final word = part.toLowerCase();
      if (word == 'forced') {
        forced = true;
      } else if (word == 'sdh' || word == 'cc' || word == 'hi') {
        continue;
      } else if (language == null &&
          RegExp(r'^[a-z]{2,3}(-[a-z]{2})?$').hasMatch(word)) {
        language = word;
      } else if (language == null && _languageNames.containsKey(word)) {
        language = _languageNames[word];
      }
    }
    return ExternalSubtitle(
      fileName: file,
      format: format,
      language: language,
      forced: forced,
    );
  }

  static const _languageNames = {
    'english': 'en', 'french': 'fr', 'german': 'de', 'spanish': 'es', //
    'italian': 'it', 'portuguese': 'pt', 'arabic': 'ar', 'dutch': 'nl',
    'swedish': 'sv', 'norwegian': 'no', 'danish': 'da', 'finnish': 'fi',
    'polish': 'pl', 'turkish': 'tr', 'russian': 'ru', 'greek': 'el',
  };

  static String? _subtitlesJson(List<ExternalSubtitle> subtitles) =>
      subtitles.isEmpty
      ? null
      : jsonEncode([
          for (final s in subtitles)
            {
              'file': s.fileName,
              'format': s.format,
              'language': ?s.language,
              if (s.forced) 'forced': true,
            },
        ]);

  // ---- Pass 2.

  Future<void> _probe(LibraryFolderRow fresh) async {
    final folder = await db.libraryDao.folderById(fresh.id);
    if (folder == null || !folder.isAvailable) return;
    final waiting = (await db.libraryDao.itemsIn(folder.id))
        .where((row) => row.probeJson == null)
        .toList();
    if (waiting.isEmpty) return;
    final log = AppLog(output: _Quiet(), secrets: SecretRegistry());
    final processes = work.processFolder;
    final supervisor = ProcessSupervisor(
      folder: Directory(
        processes ??
            p.join(Directory.systemTemp.path, 'iptv_player', 'processes'),
      ),
      log: log,
    );
    var next = 0;
    final results = <(LibraryItemRow, LibraryMedia)>[];
    var done = 0;

    Future<void> flush() async {
      if (results.isEmpty) return;
      final batch = [...results];
      results.clear();
      await db.transaction(() async {
        for (final (row, media) in batch) {
          await db.libraryDao.changeItem(row.id, _probed(row, media));
        }
      });
      report?.call(
        LibraryScanProgress(
          folderId: folder.id,
          found: waiting.length,
          written: waiting.length,
          probed: done,
          probing: true,
        ),
      );
    }

    Future<void> worker() async {
      while (next < waiting.length && !(cancellation?.isRequested ?? false)) {
        final row = waiting[next++];
        final media = await probeLibraryFile(
          supervisor,
          work.ffprobe!,
          p.joinAll([folder.path, ...row.relPath.split('/')]),
        );
        done++;
        media.failed ? unreadable++ : probed++;
        results.add((row, media));
        if (results.length >= 50) await flush();
      }
    }

    await Future.wait([for (var i = 0; i < work.probeAtOnce; i++) worker()]);
    await flush();
    await supervisor.stopAll();
  }

  /// An unsorted video without the user's edit takes its file's own
  /// title (docs/09: titles come from names and embedded tags).
  LibraryItemsCompanion _probed(LibraryItemRow row, LibraryMedia media) {
    final tagged = media.title;
    return LibraryItemsCompanion(
      probeJson: Value(jsonEncode(media.toJson())),
      durationMs: Value(media.duration?.inMilliseconds ?? row.durationMs),
      title:
          tagged != null &&
              row.userEditsJson == null &&
              row.kind == LibraryKind.unsorted
          ? Value(tagged)
          : const Value.absent(),
    );
  }
}

/// A video the walk found.
final class _Found {
  const new({
    required this.path,
    required this.size,
    required this.mtime,
    required this.subtitles,
    this.artwork,
  });

  final String path;
  final int size;
  final int mtime;
  final List<ExternalSubtitle> subtitles;
  final String? artwork;
}

final class _Quiet extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
