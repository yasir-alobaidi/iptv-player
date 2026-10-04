// `isNull` and `isNotNull` exist in both drift and matcher; the matcher's
// are the ones these tests mean.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/library_tables.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

void main() {
  late AppDatabase db;
  final t0 = DateTime.utc(2026, 10, 4, 12);

  setUp(() async {
    db = AppDatabase.memory();
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: 'src-1',
            type: SourceType.xtream,
            name: 'Northwind',
            url: 'http://n.test',
            createdAt: t0,
            updatedAt: t0,
          ),
        );
  });
  tearDown(() => db.close());

  LibraryItemsCompanion item(
    int folderId,
    String relPath, {
    String title = 'Paper Kites',
    LibraryKind kind = LibraryKind.movie,
    String hash = 'hash-1',
    String? show,
    int? season,
    int? episode,
    bool hidden = false,
  }) => LibraryItemsCompanion.insert(
    folderId: folderId,
    relPath: relPath,
    sizeBytes: 2100000000,
    mtime: 1759564800000,
    quickHash: hash,
    kind: kind,
    title: title,
    showTitle: Value(show),
    season: Value(season),
    episode: Value(episode),
    isHidden: Value(hidden),
    addedAt: t0,
  );

  group('folders', () {
    test('the download folder is one at a time; the one before stays as an '
        'ordinary folder', () async {
      final dao = db.libraryDao;
      final first = await dao.makeDownloadFolder(
        '/home/me/Videos/IPTV Player',
        label: 'IPTV Player',
        at: t0,
      );
      expect(first.isDownloadFolder, isTrue);
      expect(first.isAvailable, isTrue);

      // Again: nothing changes.
      final same = await dao.makeDownloadFolder(
        '/home/me/Videos/IPTV Player',
        label: 'other',
        at: t0,
      );
      expect(same.id, first.id);
      expect(same.label, 'IPTV Player');

      final second = await dao.makeDownloadFolder(
        '/media/data/Downloads',
        label: 'Downloads',
        at: t0,
      );
      final folders = await dao.folders();
      expect(
        [for (final f in folders) (f.path, f.isDownloadFolder)],
        [
          ('/media/data/Downloads', true),
          ('/home/me/Videos/IPTV Player', false),
        ],
      );
      expect(second.isDownloadFolder, isTrue);

      // A folder the user added can become the download folder.
      final added = await dao.addFolder(
        path: '/media/usb/Films',
        label: 'Films',
        at: t0,
      );
      await dao.makeDownloadFolder('/media/usb/Films', label: 'x', at: t0);
      expect((await dao.folderById(added))!.isDownloadFolder, isTrue);
      expect(
        [for (final f in await dao.folders()) f.isDownloadFolder],
        [true, false, false],
      );
    });

    test('a path is added once', () async {
      await db.libraryDao.addFolder(path: '/m', label: 'm', at: t0);
      await expectLater(
        db.libraryDao.addFolder(path: '/m', label: 'm', at: t0),
        throwsA(isA<SqliteException>()),
      );
    });

    test("totals count each folder's videos and bytes; removing a folder "
        'takes its items with it', () async {
      final dao = db.libraryDao;
      final a = await dao.addFolder(path: '/a', label: 'A', at: t0);
      final b = await dao.addFolder(path: '/b', label: 'B', at: t0);
      await dao.insertItem(item(a, 'one.mkv'));
      await dao.insertItem(item(a, 'two.mkv', hash: 'hash-2'));
      await dao.insertItem(item(b, 'three.mkv', hash: 'hash-3'));

      final totals = await dao.watchFolderTotals().first;
      expect(totals[a], (items: 2, bytes: 4200000000));
      expect(totals[b], (items: 1, bytes: 2100000000));

      await dao.removeFolder(a);
      expect(await dao.itemsIn(a), isEmpty);
      expect(await dao.itemsIn(b), hasLength(1));
    });
  });

  group('items', () {
    late int folder;
    setUp(() async {
      folder = await db.libraryDao.addFolder(path: '/m', label: 'M', at: t0);
    });

    test('a path is one item per folder', () async {
      await db.libraryDao.insertItem(item(folder, 'a.mkv'));
      await expectLater(
        db.libraryDao.insertItem(item(folder, 'a.mkv', hash: 'other')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('found by hash, and by the title it was downloaded from', () async {
      final dao = db.libraryDao;
      final id = await dao.insertItem(
        item(folder, 'a.mkv').copyWith(
          providerSourceId: const Value('src-1'),
          providerItemType: const Value(VodType.movie),
          providerRemoteKey: const Value('100000'),
        ),
      );
      expect([for (final r in await dao.itemsWithHash('hash-1')) r.id], [id]);
      expect(
        (await dao.itemForTitle('src-1', VodType.movie, '100000'))!.id,
        id,
      );
      expect(await dao.itemForTitle('src-1', VodType.episode, '100000'), null);
    });

    test('removing the source unlinks a download but keeps it', () async {
      final dao = db.libraryDao;
      final id = await dao.insertItem(
        item(folder, 'a.mkv').copyWith(
          providerSourceId: const Value('src-1'),
          providerItemType: const Value(VodType.movie),
          providerRemoteKey: const Value('100000'),
        ),
      );
      await (db.delete(db.sources)..where((t) => t.id.equals('src-1'))).go();
      final row = (await dao.itemById(id))!;
      expect(row.providerSourceId, isNull);
      expect(row.providerRemoteKey, '100000');
    });

    test('lists by kind: episodes by show, season and episode; hidden ones '
        'apart', () async {
      final dao = db.libraryDao;
      await dao.insertItem(
        item(
          folder,
          'b2.mkv',
          kind: LibraryKind.episode,
          title: 'Undertow',
          show: 'Glass Tide',
          season: 2,
          episode: 4,
          hash: 'h1',
        ),
      );
      await dao.insertItem(
        item(
          folder,
          'b1.mkv',
          kind: LibraryKind.episode,
          title: 'Low Water',
          show: 'Glass Tide',
          season: 1,
          episode: 1,
          hash: 'h2',
        ),
      );
      await dao.insertItem(
        item(
          folder,
          'a.mkv',
          kind: LibraryKind.episode,
          title: 'Pilot',
          show: 'Arbor',
          season: 1,
          episode: 1,
          hash: 'h3',
        ),
      );
      await dao.insertItem(
        item(folder, 'm.mkv', title: 'Ember Road', hash: 'h4', hidden: true),
      );

      final episodes = await dao.watchItems(kind: LibraryKind.episode).first;
      expect(
        [for (final r in episodes) r.title],
        ['Pilot', 'Low Water', 'Undertow'],
      );
      expect(await dao.watchItems(kind: LibraryKind.movie).first, isEmpty);
      expect(
        [
          for (final r
              in await dao
                  .watchItems(kind: LibraryKind.movie, hidden: true)
                  .first)
            r.title,
        ],
        ['Ember Road'],
      );
    });

    test('search finds titles and shows by their words, follows edits, and '
        'leaves hidden items out', () async {
      final dao = db.libraryDao;
      final id = await dao.insertItem(
        item(
          folder,
          'e.mkv',
          kind: LibraryKind.episode,
          title: 'Undertow',
          show: 'Glass Tide',
          season: 2,
          episode: 4,
        ),
      );
      await dao.insertItem(
        item(folder, 'h.mkv', title: 'Harbor Walk', hash: 'h2', hidden: true),
      );
      Future<List<String>> titles(String match) async => [
        for (final r in await dao.search(match)) r.title,
      ];

      expect(await titles('gla*'), ['Undertow']);
      expect(await titles('under*'), ['Undertow']);
      expect(await titles('harb*'), isEmpty);

      await dao.changeItem(
        id,
        const LibraryItemsCompanion(title: Value('The Long Tide')),
      );
      expect(await titles('under*'), isEmpty);
      expect(await titles('long*'), ['The Long Tide']);

      await dao.removeItem(id);
      expect(await titles('gla*'), isEmpty);
    });
  });

  group('downloads', () {
    DownloadsCompanion download(String key, {VodType type = VodType.movie}) =>
        DownloadsCompanion.insert(
          sourceId: 'src-1',
          itemType: type,
          remoteKey: key,
          title: 'Title $key',
          targetPath: '/v/Movies/Title $key.mkv',
          state: DownloadTaskState.queued,
          sortOrder: 0,
          createdAt: t0,
        );

    test('enqueued at the end, once per title', () async {
      final dao = db.downloadsDao;
      final a = await dao.enqueue(download('1'));
      final b = await dao.enqueue(download('2'));
      final again = await dao.enqueue(download('1'));
      final episode = await dao.enqueue(download('1', type: VodType.episode));

      expect(again, isNull);
      expect(a, isNotNull);
      expect(episode, isNotNull);
      expect(
        [for (final r in await dao.all()) (r.id, r.sortOrder)],
        [(a, 0), (b, 1), (episode, 2)],
      );
    });

    test('moved to any place, the order numbered again', () async {
      final dao = db.downloadsDao;
      final ids = [
        for (final key in ['1', '2', '3', '4'])
          (await dao.enqueue(download(key)))!,
      ];
      await dao.move(ids[3], 0);
      expect(
        [for (final r in await dao.all()) r.id],
        [ids[3], ids[0], ids[1], ids[2]],
      );
      await dao.move(ids[3], 99);
      expect([for (final r in await dao.all()) r.sortOrder], [0, 1, 2, 3]);
      expect((await dao.all()).last.id, ids[3]);
    });

    test('Clear list takes the completed off; removing the source takes its '
        'queue', () async {
      final dao = db.downloadsDao;
      final a = (await dao.enqueue(download('1')))!;
      await dao.enqueue(download('2'));
      await dao.change(
        a,
        const DownloadsCompanion(state: Value(DownloadTaskState.completed)),
      );
      await dao.removeCompleted();
      expect([for (final r in await dao.all()) r.remoteKey], ['2']);

      await (db.delete(db.sources)..where((t) => t.id.equals('src-1'))).go();
      expect(await dao.all(), isEmpty);
    });

    test(
      'a finished download points at its library item until that goes',
      () async {
        final folder = await db.libraryDao.addFolder(
          path: '/v',
          label: 'IPTV Player',
          at: t0,
        );
        final itemId = await db.libraryDao.insertItem(item(folder, 'a.mkv'));
        final id = (await db.downloadsDao.enqueue(download('1')))!;
        await db.downloadsDao.change(
          id,
          DownloadsCompanion(libraryItemId: Value(itemId)),
        );
        await db.libraryDao.removeItem(itemId);
        expect((await db.downloadsDao.byId(id))!.libraryItemId, isNull);
      },
    );
  });

  test('a local file has one favorite and one history row', () async {
    Future<void> favorite() => db
        .into(db.favorites)
        .insert(
          FavoritesCompanion.insert(
            itemType: UserItemType.local,
            remoteKey: 'hash-1',
            addedAt: t0,
          ),
        );
    Future<void> watched() => db
        .into(db.watchHistory)
        .insert(
          WatchHistoryCompanion.insert(
            itemType: UserItemType.local,
            remoteKey: 'hash-1',
            updatedAt: t0,
          ),
        );
    await favorite();
    await watched();
    await expectLater(favorite(), throwsA(isA<SqliteException>()));
    await expectLater(watched(), throwsA(isA<SqliteException>()));

    // A source's rows are keyed as before.
    await db.favoritesDao.add(UserItemType.movie, 'src-1', 'hash-1', t0);
    await db.watchHistoryDao.touch(UserItemType.movie, 'src-1', 'hash-1', t0);
    expect(await db.select(db.favorites).get(), hasLength(2));
    expect(await db.select(db.watchHistory).get(), hasLength(2));
  });
}
