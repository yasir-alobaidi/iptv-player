// `isNull` exists in both drift and matcher; the matcher is the one
// these tests mean.
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/library/library_scan.dart';
import 'package:iptv_player/data/library/library_thumbnails.dart';
import 'package:iptv_player/data/library/system_trash.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:iptv_player/features/library/data/db_library_repository.dart';
import 'package:iptv_player/features/library/data/library_scans.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../../data/cast/relay/relay_rig.dart' show relayBinaries;

void main() {
  final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());

  group('the scans', () {
    test(
      'one at a time; a whole scan waiting covers a folder asked for',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final asked = <List<int>?>[];
        final gate = Completer<void>();
        final scans = LibraryScans(
          db: db,
          log: log,
          run: (folders, report) async {
            asked.add(folders);
            report(
              const LibraryScanProgress(folderId: 1, found: 3, written: 1),
            );
            await gate.future;
            return const Ok(LibraryScanResult());
          },
        );
        final states = <bool>[];
        scans.states.listen((s) => states.add(s.scanning));
        final first = scans.scan(folderId: 1);
        unawaited(scans.scan(folderId: 2));
        unawaited(scans.scan());
        unawaited(scans.scan(folderId: 3));
        await pumpEventQueue();
        expect(asked, [
          [1],
        ]);
        gate.complete();
        await first;
        await scans.scan();
        await pumpEventQueue();
        expect(asked, [
          [1],
          null,
          null,
        ]);
        expect(states.first, isTrue);
        expect(states.last, isFalse);
        await scans.dispose();
      },
    );

    test("a watched folder's changes are scanned 3 s after the last; a "
        "download's .part never counts", () {
      fakeAsync((async) {
        final db = AppDatabase.memory();
        final temp = Directory.systemTemp.createTempSync('watch_');
        final events = StreamController<WatchEvent>.broadcast();
        final asked = <List<int>?>[];
        final scans = LibraryScans(
          db: db,
          log: log,
          run: (folders, report) async {
            asked.add(folders);
            return const Ok(LibraryScanResult());
          },
          watcher: (_) => _FakeWatcher(events.stream),
        );
        late int id;
        unawaited(
          db.libraryDao
              .addFolder(path: temp.path, label: 'T', at: DateTime.utc(2026))
              .then((v) => id = v),
        );
        async.flushMicrotasks();
        unawaited(scans.startUp());
        async.elapse(const Duration(milliseconds: 100));
        expect(asked, [null], reason: 'the launch scan');
        expect(scans.watched(id), isTrue);

        void change(String name) =>
            events.add(WatchEvent(ChangeType.MODIFY, p.join(temp.path, name)));
        change('a.mkv');
        async.elapse(const Duration(seconds: 2));
        change('b.mkv');
        async.elapse(const Duration(seconds: 2));
        expect(asked, hasLength(1), reason: 'still settling');
        async.elapse(const Duration(seconds: 2));
        expect(asked.last, [id]);

        change('Movie.mkv.part');
        change('.hidden.mkv');
        async.elapse(const Duration(seconds: 10));
        expect(asked, hasLength(2));

        // A watch that fails says so.
        events.addError(const FileSystemException('too many watches'));
        async.elapse(const Duration(milliseconds: 10));
        expect(scans.watched(id), isFalse);

        unawaited(scans.dispose());
        unawaited(db.close());
        async.flushMicrotasks();
        temp.deleteSync(recursive: true);
      });
    });
  });

  group('the repository', () {
    late Directory temp;
    late AppDatabase db;
    late DbLibraryRepository library;
    late List<int?> rescans;
    late String downloads;

    setUp(() async {
      temp = Directory.systemTemp.createTempSync('library_repo_');
      db = AppDatabase.memory();
      rescans = [];
      library = DbLibraryRepository(
        db,
        scans: LibraryScans(
          db: db,
          log: log,
          run: (folders, report) async {
            rescans.addAll(folders ?? [null]);
            return await runLibraryScan(
              LibraryScanWork(
                now: DateTime.utc(2026),
                folderIds: folders,
                minBytes: 1,
              ),
              report,
              database: db,
            );
          },
        ),
        trash: SystemTrash(
          environment: {'HOME': p.join(temp.path, 'home')},
          mountOf: (_) => temp.path,
        ),
      );
      downloads = p.join(temp.path, 'Videos', 'IPTV Player');
      await registerDownloadFolder(
        db.libraryDao,
        downloads,
        now: DateTime.utc(2026),
      );
    });
    tearDown(() async {
      await db.close();
      temp.deleteSync(recursive: true);
    });

    File make(String path) => File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('video ${path.hashCode}');

    test('folders: added once, never one inside another, renamed; the '
        'download folder stays', () async {
      final movies = Directory(p.join(temp.path, 'Movies'))..createSync();
      final added = (await library.addFolder(movies.path)).valueOrNull!;
      expect(added.label, 'Movies');
      expect(added.isDownloadFolder, isFalse);
      await pumpEventQueue();
      expect(rescans, [added.id], reason: 'scanned at once');

      for (final (path, words) in [
        (movies.path, 'already in the library'),
        (p.join(movies.path, 'Sub'), 'inside Movies'),
        (temp.path, 'inside it'),
        (p.join(temp.path, 'nowhere'), 'No folder'),
      ]) {
        Directory(path).createSync(recursive: true);
        if (path.endsWith('nowhere')) Directory(path).deleteSync();
        final result = await library.addFolder(path);
        expect(result.failureOrNull, isA<InvalidInputFailure>(), reason: path);
        expect('${result.failureOrNull}', contains(words), reason: path);
      }

      expect(
        (await library.renameFolder(added.id, ' Movies HDD ')).isOk,
        isTrue,
      );
      final folders = await library.watchFolders().first;
      expect([for (final f in folders) f.label], ['Downloads', 'Movies HDD']);

      final download = folders.first;
      expect(
        (await library.removeFolder(download.id)).failureOrNull,
        isA<InvalidInputFailure>(),
      );
      expect((await library.removeFolder(added.id)).isOk, isTrue);
      expect(await library.watchFolders().first, hasLength(1));
      expect(movies.existsSync(), isTrue, reason: 'the files stay');
    });

    Future<LibraryItem> scanOne(String rel) async {
      final folder = Directory(p.join(temp.path, 'Mine'))..createSync();
      make(p.join(folder.path, rel));
      final added = (await library.addFolder(folder.path)).valueOrNull!;
      await library.rescan(folderId: added.id);
      final items = await library.watch(const LibraryQuery()).first;
      return items.single;
    }

    test('edits: what the screens show, kept apart, and undone by the '
        "file's name", () async {
      final item = await scanOne('Glass.Tide.S01E03.mkv');
      expect(item.kind, LibraryKind.episode);
      expect(item.path, endsWith('Mine/Glass.Tide.S01E03.mkv'));
      await library.editItem(
        item.id,
        const LibraryItemEdit(
          kind: LibraryKind.movie,
          title: 'Tide',
          year: 1999,
        ),
      );
      var now = (await library.watch(const LibraryQuery()).first).single;
      expect(
        (now.kind, now.title, now.year, now.season),
        (LibraryKind.movie, 'Tide', 1999, null),
      );
      expect(now.edit?.title, 'Tide');
      await library.rescan();
      now = (await library.watch(const LibraryQuery()).first).single;
      expect(now.title, 'Tide', reason: 'a rescan keeps it');
      await library.editItem(item.id, null);
      now = (await library.watch(const LibraryQuery()).first).single;
      expect(
        (now.kind, now.showTitle, now.episode, now.edit),
        (LibraryKind.episode, 'Glass Tide', 3, null),
      );
    });

    test(
      'hidden, then shown again; removed stays out of every rescan',
      () async {
        final item = await scanOne('Paper Kites (2019).mkv');
        await library.setHidden(item.id, hidden: true);
        expect(await library.watch(const LibraryQuery()).first, isEmpty);
        expect(
          await library.watch(const LibraryQuery(hidden: true)).first,
          hasLength(1),
        );
        await library.setHidden(item.id, hidden: false);
        await library.removeItem(item.id);
        await library.rescan();
        expect(await library.watch(const LibraryQuery()).first, isEmpty);
        expect(
          await library.watch(const LibraryQuery(hidden: true)).first,
          isEmpty,
        );
        expect(File(item.path!).existsSync(), isTrue, reason: 'the file stays');
      },
    );

    test('Delete file: the video and its subtitles to the trash; no trash '
        'asks again; for good when told', () async {
      final folder = Directory(p.join(temp.path, 'Mine'))..createSync();
      make(p.join(folder.path, 'Ember Road (2011).mkv'));
      make(p.join(folder.path, 'Ember Road (2011).en.srt'));
      make(p.join(folder.path, 'Other (2012).mkv'));
      final added = (await library.addFolder(folder.path)).valueOrNull!;
      await library.rescan(folderId: added.id);
      final items = {
        for (final i in await library.watch(const LibraryQuery()).first)
          i.title: i,
      };
      final ember = items['Ember Road']!;
      expect(ember.subtitles.single.language, 'en');

      expect(
        (await library.deleteFile(ember.id)).valueOrNull,
        DeleteOutcome.trashed,
      );
      final trash = p.join(
        temp.path,
        'home',
        '.local',
        'share',
        'Trash',
        'files',
      );
      expect(File(p.join(trash, 'Ember Road (2011).mkv')).existsSync(), isTrue);
      expect(
        File(p.join(trash, 'Ember Road (2011).en.srt')).existsSync(),
        isTrue,
      );
      expect(await db.libraryDao.itemById(ember.id), isNull);

      // A drive with no trash: asked again, then deleted for good.
      final noTrash = DbLibraryRepository(
        db,
        scans: LibraryScans(
          db: db,
          log: log,
          run: (_, _) async => const Ok(LibraryScanResult()),
        ),
        trash: SystemTrash(environment: const {}, mountOf: (_) => null),
      );
      final other = items['Other']!;
      expect(
        (await noTrash.deleteFile(other.id)).valueOrNull,
        DeleteOutcome.noTrash,
      );
      expect(File(other.path!).existsSync(), isTrue);
      expect(
        (await noTrash.deleteFile(other.id, permanently: true)).valueOrNull,
        DeleteOutcome.deleted,
      );
      expect(File(other.path!).existsSync(), isFalse);
    });

    test("a download's file goes with its poster and the folders it "
        'leaves empty', () async {
      final movie = p.join(downloads, 'Movies', 'Copper Hollow (2025)');
      make(p.join(movie, 'Copper Hollow (2025).mp4'));
      make(p.join(movie, 'poster.jpg'));
      final folder = (await db.libraryDao.folderByPath(downloads))!;
      final id = await db.libraryDao.insertItem(
        LibraryItemsCompanion.insert(
          folderId: folder.id,
          relPath: 'Movies/Copper Hollow (2025)/Copper Hollow (2025).mp4',
          sizeBytes: 1,
          mtime: 0,
          quickHash: 'h',
          kind: LibraryKind.movie,
          title: 'Copper Hollow',
          providerRemoteKey: const Value('100000'),
          addedAt: DateTime.utc(2026),
        ),
      );
      final downloaded = await library
          .watch(const LibraryQuery(origin: LibraryOrigin.downloaded))
          .first;
      expect(downloaded.single.downloaded, isTrue);
      expect(
        await library
            .watch(const LibraryQuery(origin: LibraryOrigin.localFolders))
            .first,
        isEmpty,
      );
      expect((await library.deleteFile(id)).valueOrNull, DeleteOutcome.trashed);
      expect(Directory(movie).existsSync(), isFalse);
      expect(Directory(p.join(downloads, 'Movies')).existsSync(), isFalse);
      expect(Directory(downloads).existsSync(), isTrue);
    });
  });

  test('a frame for a video, made once, at 10 % of its length', () async {
    final binaries = relayBinaries();
    if (binaries == null) {
      markTestSkipped('needs FFmpeg');
      return;
    }
    final temp = Directory.systemTemp.createTempSync('thumbs_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final clip = p.join(temp.path, 'clip.mp4');
    final made = await Process.run(binaries.ffmpeg, [
      ...['-hide_banner', '-loglevel', 'error', '-y'],
      ...['-f', 'lavfi', '-i', 'testsrc2=size=640x360:rate=25:duration=4'],
      ...['-c:v', 'libx264', '-preset', 'ultrafast', clip],
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final folder = await db.libraryDao.addFolder(
      path: temp.path,
      label: 'T',
      at: DateTime.utc(2026),
    );
    final id = await db.libraryDao.insertItem(
      LibraryItemsCompanion.insert(
        folderId: folder,
        relPath: 'clip.mp4',
        sizeBytes: 1,
        mtime: 0,
        quickHash: 'abc',
        kind: LibraryKind.unsorted,
        title: 'clip',
        durationMs: const Value(4000),
        addedAt: DateTime.utc(2026),
      ),
    );
    final thumbnails = LibraryThumbnails(
      db: db,
      supervisor: ProcessSupervisor(
        folder: Directory(p.join(temp.path, 'pids')),
        log: log,
      ),
      ffmpeg: binaries.ffmpeg,
      folder: Directory(p.join(temp.path, 'thumbs')),
    );
    final both = await Future.wait([
      thumbnails.thumbnailFor(id),
      thumbnails.thumbnailFor(id),
    ]);
    expect(both[0], p.join(temp.path, 'thumbs', 'abc.jpg'));
    expect(both[1], both[0]);
    final bytes = File(both[0]!).readAsBytesSync();
    expect(bytes.take(2), [0xff, 0xd8], reason: 'a JPEG');
    expect((await db.libraryDao.itemById(id))!.thumbnailPath, both[0]);
    expect(await thumbnails.thumbnailFor(id), both[0]);
    expect(await thumbnails.thumbnailFor(9999), isNull);
  });
}

final class _FakeWatcher implements Watcher {
  new(this.events);

  @override
  final Stream<WatchEvent> events;

  @override
  String get path => '';

  @override
  bool get isReady => true;

  @override
  Future<void> get ready => Future.value();
}
