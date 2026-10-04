// `isNull` exists in both drift and matcher; the matcher is the one
// these tests mean.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_media.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/library_scan.dart';
import 'package:path/path.dart' as p;

import '../cast/relay/relay_rig.dart' show relayBinaries;

/// The scanner on a `library_tree.sh` tree (docs/06), against the
/// manifest of what each file is.
void main() {
  final binaries = relayBinaries();
  if (binaries == null || !Platform.isLinux) {
    test('the library scan', () {}, skip: 'needs FFmpeg and bash (Linux)');
    return;
  }
  late Directory temp;
  late Directory tree;
  late AppDatabase db;
  late int folderId;
  var clock = DateTime.utc(2026, 10, 4, 12);

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('library_scan_');
    tree = Directory(p.join(temp.path, 'Movies HDD'));
    final made = await Process.run(
      'tools/media_samples/library_tree.sh',
      [tree.path, '60'],
      environment: {'FFMPEG': binaries.ffmpeg},
    );
    expect(made.exitCode, 0, reason: '${made.stderr}');
    db = AppDatabase.memory();
    folderId = await db.libraryDao.addFolder(
      path: tree.path,
      label: 'Movies HDD',
      at: clock,
    );
    clock = DateTime.utc(2026, 10, 4, 12);
  });

  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<LibraryScanResult> scan({
    bool probe = false,
    List<int>? folders,
  }) async {
    final result = await runLibraryScan(
      LibraryScanWork(
        now: clock,
        folderIds: folders,
        minBytes: 10 * 1024,
        ffprobe: probe ? binaries.ffprobe : null,
        processFolder: p.join(temp.path, 'processes'),
        batchSize: 7,
      ),
      null,
      database: db,
    );
    return result.valueOrNull!;
  }

  List<Map<String, String>> manifest() {
    final lines = File(p.join(tree.path, '.manifest.tsv')).readAsLinesSync();
    final header = lines.first.split('\t');
    return [
      for (final line in lines.skip(1))
        {for (final (i, value) in line.split('\t').indexed) header[i]: value},
    ];
  }

  Future<Map<String, LibraryItemRow>> items() async => {
    for (final row in await db.libraryDao.itemsIn(folderId)) row.relPath: row,
  };

  /// Every name, size and time in the tree: hard rule 11 says a scan
  /// changes none of them.
  Map<String, (int, int)> snapshot() => {
    for (final entity in tree.listSync(recursive: true))
      if (entity is File)
        p.relative(entity.path, from: tree.path): (
          entity.lengthSync(),
          entity.lastModifiedSync().millisecondsSinceEpoch,
        ),
  };

  test('every video read as the manifest says; the junk left out; nothing '
      'on disk touched', () async {
    final before = snapshot();
    final result = await scan(probe: true);
    expect(snapshot(), before);

    final rows = await items();
    final expected = manifest().where((m) => m['kind'] != 'skip').toList();
    expect(result.added, expected.length);
    expect(rows.keys.toSet(), {for (final m in expected) m['path']});
    for (final m in expected) {
      final row = rows[m['path']]!;
      final why = m['path'];
      expect(row.kind.name, m['kind'], reason: why);
      switch (row.kind) {
        case LibraryKind.movie:
          expect(row.title, m['title'], reason: why);
          expect('${row.year}', m['year'], reason: why);
        case LibraryKind.episode:
          expect(row.showTitle, m['show'], reason: why);
          expect('${row.season}', m['season'], reason: why);
          expect('${row.episode}', m['episode'], reason: why);
          expect(row.title, m['title'], reason: why);
          expect(
            row.episodeEnd?.toString() ?? '',
            m['episode_end'],
            reason: why,
          );
        case LibraryKind.unsorted:
          break;
      }
      // The probe pass: every clip is 2 s with a picture and a sound.
      final media = LibraryMedia.fromJson(jsonDecode(row.probeJson!));
      expect(media.failed, isFalse, reason: why);
      expect(row.durationMs, closeTo(2000, 300), reason: why);
      expect(media.video?.height, 90, reason: why);
      expect(media.audio, hasLength(1), reason: why);
    }

    // Subtitles and posters beside a movie (the tree puts them by the
    // first movie folder of every eight).
    final withPoster = rows.values.firstWhere(
      (r) => r.relPath.startsWith('Movies/Copper Harbor (1975)/'),
    );
    expect(withPoster.artworkPath, endsWith('Copper Harbor (1975)/poster.jpg'));
    expect(jsonDecode(withPoster.subtitlesJson!), [
      {
        'file': 'Copper Harbor (1975).en.srt',
        'format': 'srt',
        'language': 'en',
      },
    ]);
    final forced = rows.values.firstWhere(
      (r) => r.subtitlesJson != null && r.subtitlesJson!.contains('forced'),
    );
    expect(forced.kind, LibraryKind.episode);
    expect(forced.episode, 3);

    // An unsorted video with an embedded title takes it.
    final tagged = rows.values.where((r) => r.title == 'Tagged video 0');
    expect(tagged, hasLength(1));
    expect(tagged.single.kind, LibraryKind.unsorted);
  });

  test(
    'a rescan of an unchanged tree writes nothing and reads no file',
    () async {
      await scan();
      final first = await items();
      final again = await scan();
      expect(
        (again.added, again.changed, again.moved, again.removed),
        (0, 0, 0, 0),
      );
      expect(await items(), first);
    },
  );

  test('renamed, moved to another folder, or gone: by its quick hash it '
      'keeps its id, edits and hiding', () async {
    final other = Directory(p.join(temp.path, 'Other'))..createSync();
    final otherId = await db.libraryDao.addFolder(
      path: other.path,
      label: 'Other',
      at: clock,
    );
    await scan();
    final rows = await items();
    final renamed = rows['Movies/Glass.Tide.1982.1080p.BluRay.x264-GRP.mkv']!;
    final crossing = rows.values.firstWhere(
      (r) => r.relPath.startsWith('Home videos/'),
    );
    final dropped = rows.values.firstWhere(
      (r) => r.relPath.startsWith('Camera/'),
    );
    await db.libraryDao.changeItem(
      renamed.id,
      const LibraryItemsCompanion(
        title: Value('My own title'),
        userEditsJson: Value('{"kind":"movie","title":"My own title"}'),
        isHidden: Value(true),
      ),
    );

    File(p.join(tree.path, renamed.relPath))
        .renameSync(p.join(tree.path, 'Movies', 'renamed by me.mkv'));
    File(p.join(tree.path, crossing.relPath))
        .renameSync(p.join(other.path, 'carried over.mp4'));
    File(p.join(tree.path, dropped.relPath)).deleteSync();

    // The folder the file left is scanned first: the move still holds.
    final result = await scan(folders: [folderId, otherId]);
    expect(result.moved, 2);
    expect(result.removed, 1);
    final after = await items();
    final moved = after['Movies/renamed by me.mkv']!;
    expect(moved.id, renamed.id);
    expect(moved.title, 'My own title', reason: 'the edit stays');
    expect(moved.isHidden, isTrue);
    final carried = (await db.libraryDao.itemsIn(otherId)).single;
    expect(carried.id, crossing.id);
    expect(carried.relPath, 'carried over.mp4');
    expect(await db.libraryDao.itemById(dropped.id), isNull);
  });

  test('a changed file is read again and probed again; edits stay', () async {
    await scan(probe: true);
    final row = (await items()).values.firstWhere(
      (r) => r.kind == LibraryKind.movie,
    );
    await db.libraryDao.changeItem(
      row.id,
      const LibraryItemsCompanion(
        title: Value('Kept'),
        userEditsJson: Value('{"kind":"movie","title":"Kept"}'),
      ),
    );
    final file = File(p.join(tree.path, row.relPath));
    file.writeAsBytesSync([...file.readAsBytesSync(), 1, 2, 3]);
    final result = await scan();
    expect(result.changed, 1);
    final after = (await db.libraryDao.itemById(row.id))!;
    expect(after.title, 'Kept');
    expect(after.sizeBytes, row.sizeBytes + 3);
    expect(after.quickHash, isNot(row.quickHash));
    expect(after.probeJson, isNull, reason: 'to be probed again');
  });

  test(
    'a drive unplugged: its items stay, as not connected, for 30 days',
    () async {
      await scan();
      final count = (await items()).length;
      final away = Directory(p.join(temp.path, 'unplugged'));
      tree.renameSync(away.path);

      await scan();
      var folder = (await db.libraryDao.folderById(folderId))!;
      expect(folder.isAvailable, isFalse);
      var rows = await items();
      expect(rows, hasLength(count));
      expect(rows.values.every((r) => r.unavailableSince == clock), isTrue);

      // Back after a week: as before.
      clock = clock.add(const Duration(days: 7));
      away.renameSync(tree.path);
      await scan();
      folder = (await db.libraryDao.folderById(folderId))!;
      expect(folder.isAvailable, isTrue);
      rows = await items();
      expect(rows.values.every((r) => r.unavailableSince == null), isTrue);

      // Away for 31 days: gone.
      tree.renameSync(away.path);
      await scan();
      clock = clock.add(const Duration(days: 31));
      await scan();
      expect(await items(), isEmpty);
    },
  );
}
