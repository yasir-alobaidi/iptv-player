import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/downloads/db_download_store.dart';
import 'package:iptv_player/data/downloads/file_download_finisher.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/features/downloads/data/catalogue_download_titles.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../playback/support/playback_fakes.dart' show FakeResolver;

void main() {
  late AppDatabase db;
  late Directory temp;
  final t0 = DateTime.utc(2026, 10, 4);

  setUp(() async {
    db = AppDatabase.memory();
    temp = Directory.systemTemp.createTempSync('download_data_');
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: 'src',
            type: SourceType.xtream,
            name: 'Northwind',
            url: 'http://n.test',
            createdAt: t0,
            updatedAt: t0,
          ),
        );
  });
  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<int> series() => db
      .into(db.series)
      .insert(
        SeriesCompanion.insert(
          sourceId: 'src',
          remoteKey: 's1',
          name: 'Glass Tide',
          posterUrl: const Value('http://art.test/glass-tide.jpg'),
          plot: const Value('A harbour town.'),
        ),
      );

  Future<void> episode(int seriesId) => db
      .into(db.episodes)
      .insert(
        EpisodesCompanion.insert(
          seriesId: seriesId,
          remoteKey: 'e5',
          season: 2,
          episode: 5,
          title: 'Northbound',
          ext: const Value('mkv'),
          plot: const Value('They sail.'),
        ),
      );

  DownloadTask task({
    VodType type = VodType.movie,
    String key = 'm1',
    String? seriesKey,
    String? target,
    int? total,
  }) => DownloadTask(
    id: 1,
    sourceId: 'src',
    type: type,
    remoteKey: key,
    title: type == VodType.movie ? 'Copper Hollow' : 'Northbound',
    showTitle: type == VodType.episode ? 'Glass Tide' : null,
    season: type == VodType.episode ? 2 : null,
    episode: type == VodType.episode ? 5 : null,
    seriesKey: seriesKey,
    year: 2025,
    targetPath:
        target ??
        p.join(
          temp.path,
          'IPTV Player',
          'Movies',
          'Copper Hollow (2025)',
          'Copper Hollow (2025).mkv',
        ),
    state: DownloadTaskState.verifying,
    downloadedBytes: 0,
    sortOrder: 0,
    createdAt: t0,
    totalBytes: total,
    artworkUrl: 'http://art.test/copper.jpg',
  );

  group('catalogue titles', () {
    late FakeResolver resolver;
    late CatalogueDownloadTitles titles;
    setUp(() {
      resolver = FakeResolver()..maxConnections = 2;
      titles = CatalogueDownloadTitles(
        db,
        resolver,
        folder: () async => '/v/IPTV Player',
      );
    });

    test(
      "a movie's URL from its row, built now, with the source's limit",
      () async {
        await db
            .into(db.movies)
            .insert(
              MoviesCompanion.insert(
                sourceId: 'src',
                remoteKey: 'm1',
                name: 'Copper Hollow',
                ext: const Value('mkv'),
              ),
            );
        final answer = await titles.source(task()) as DownloadSource;
        expect(answer.upstream.url, 'http://fake/movie/u/p/m1.mkv');
        expect(answer.maxConnections, 2);
        expect(await titles.folder(), '/v/IPTV Player');
      },
    );

    test("an episode's from its series' episode cache", () async {
      await episode(await series());
      final answer = await titles.source(
        task(type: VodType.episode, key: 'e5', seriesKey: 's1'),
      ) as DownloadSource;
      expect(answer.upstream.url, 'http://fake/series/u/p/e5.mkv');
    });

    test('a title gone is gone; a locked keyring may pass', () async {
      expect(await titles.source(task()), isA<DownloadSourceGone>());
      expect(
        await titles.source(task(type: VodType.episode, key: 'x')),
        isA<DownloadSourceGone>(),
      );
      await db
          .into(db.movies)
          .insert(
            MoviesCompanion.insert(sourceId: 'src', remoteKey: 'm1', name: 'A'),
          );
      resolver.failure = SecureStorageFailure('locked');
      expect(await titles.source(task()), isA<DownloadSourceUnavailable>());
      resolver.failure = NotFoundFailure('source src');
      expect(await titles.source(task()), isA<DownloadSourceGone>());
    });

    test(
      'downloaded: a library file of the title that is still there',
      () async {
        final folder = await db.libraryDao.addFolder(
          path: temp.path,
          label: 'Downloads',
          at: t0,
        );
        const request = DownloadRequest(
          sourceId: 'src',
          type: VodType.movie,
          remoteKey: 'm1',
          title: 'A',
        );
        expect(await titles.downloaded(request), isFalse);
        await db.libraryDao.insertItem(
          LibraryItemsCompanion.insert(
            folderId: folder,
            relPath: 'Movies/A/A.mkv',
            sizeBytes: 1,
            mtime: 0,
            quickHash: 'h',
            kind: LibraryKind.movie,
            title: 'A',
            providerSourceId: const Value('src'),
            providerItemType: const Value(VodType.movie),
            providerRemoteKey: const Value('m1'),
            addedAt: t0,
          ),
        );
        expect(await titles.downloaded(request), isFalse, reason: 'no file');
        File(p.join(temp.path, 'Movies', 'A', 'A.mkv'))
          ..createSync(recursive: true)
          ..writeAsStringSync('x');
        expect(await titles.downloaded(request), isTrue);
      },
    );
  });

  test('the store keeps everything the queue saves', () async {
    final store = DbDownloadStore(db);
    final added = (await store.add(
      const DownloadRequest(
        sourceId: 'src',
        type: VodType.episode,
        remoteKey: 'e5',
        title: 'Northbound',
        seriesKey: 's1',
        showTitle: 'Glass Tide',
        season: 2,
        episode: 5,
        artworkUrl: 'http://art.test/x.jpg',
      ),
      targetPath: '/v/x.mkv',
      at: t0,
    ))!;
    expect(added.state, DownloadTaskState.queued);
    expect(
      (added.showTitle, added.season, added.episode),
      ('Glass Tide', 2, 5),
    );
    final saved = added.copyWith(
      state: DownloadTaskState.failed,
      downloadedBytes: 500,
      totalBytes: 1000,
      etag: '"e"',
      lastModified: 'Sat, 04 Oct 2026 12:00:00 GMT',
      problem: DownloadProblem.network,
      problemDetail: 'GET http://n.test/series/user/secretpass/e5.mkv failed',
      attempts: 3,
    );
    await store.save(saved);
    final read = (await store.all()).single;
    expect(
      read.copyWith(problemDetail: null),
      saved.copyWith(problemDetail: null),
    );
    expect(read.problemDetail, isNot(contains('secretpass')));
    expect(
      await store.add(
        const DownloadRequest(
          sourceId: 'src',
          type: VodType.episode,
          remoteKey: 'e5',
          title: 'again',
        ),
        targetPath: '/v/y.mkv',
        at: t0,
      ),
      isNull,
    );
  });

  group('the finisher', () {
    late _Probe probe;
    late FileDownloadFinisher finisher;
    late File poster;

    setUp(() async {
      probe = _Probe();
      poster = File(p.join(temp.path, 'cached.jpg'))..writeAsBytesSync([1, 2]);
      finisher = FileDownloadFinisher(
        db: db,
        probe: probe,
        pictureFile: (url) async =>
            url.contains('glass-tide') || url.contains('copper')
            ? poster.path
            : null,
        log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
        now: () => t0,
      );
      await registerDownloadFolder(
        db.libraryDao,
        p.join(temp.path, 'IPTV Player'),
        now: t0,
      );
    });

    File part(DownloadTask task, [int size = 1000]) =>
        File('${task.targetPath}.part')
          ..createSync(recursive: true)
          ..writeAsBytesSync(List.filled(size, 7));

    test('a size other than the provider said is damaged, and its .part '
        'goes', () async {
      final t = task(total: 2000);
      part(t);
      final finish = await finisher.finish(t);
      expect(finish, isA<DownloadDamaged>());
      expect(File('${t.targetPath}.part').existsSync(), isFalse);
      expect(File(t.targetPath).existsSync(), isFalse);
      expect(probe.asked, isEmpty);
    });

    test('ffprobe that reads nothing: damaged; ffprobe that cannot run: the '
        'size stands alone', () async {
      final t = task(total: 1000);
      part(t);
      probe.next = const StreamProbeFailed(StreamProbeFailure.unreadable, 'x');
      expect(await finisher.finish(t), isA<DownloadDamaged>());

      part(t);
      probe.next = const StreamProbeFailed(StreamProbeFailure.couldNotStart);
      final finish = await finisher.finish(t) as DownloadFinished;
      final item = (await db.libraryDao.itemById(finish.libraryItemId))!;
      expect(item.durationMs, isNull);
      expect(File(t.targetPath).existsSync(), isTrue);
    });

    test(
      'a name taken meanwhile gets a number; the poster sits beside it',
      () async {
        final t = task();
        part(t);
        File(t.targetPath).writeAsStringSync('someone else');
        final finish = await finisher.finish(t) as DownloadFinished;
        final item = (await db.libraryDao.itemById(finish.libraryItemId))!;
        expect(
          item.relPath,
          'Movies/Copper Hollow (2025)/Copper Hollow (2025) (2).mkv',
        );
        expect(File(t.targetPath).readAsStringSync(), 'someone else');
        expect(
          File(p.join(p.dirname(t.targetPath), 'poster.jpg')).readAsBytesSync(),
          [1, 2],
        );
        expect(item.artworkPath, p.join(p.dirname(t.targetPath), 'poster.jpg'));
      },
    );

    test("an episode: the show's poster in the show's folder, and the "
        "episode's and its series' details", () async {
      await episode(await series());
      final target = p.join(
        temp.path,
        'IPTV Player',
        'Series',
        'Glass Tide',
        'Season 02',
        'Glass Tide - S02E05 - Northbound.mkv',
      );
      final t = task(
        type: VodType.episode,
        key: 'e5',
        seriesKey: 's1',
        target: target,
      );
      part(t);
      final finish = await finisher.finish(t) as DownloadFinished;
      final item = (await db.libraryDao.itemById(finish.libraryItemId))!;
      expect(item.kind, LibraryKind.episode);
      expect(item.showTitle, 'Glass Tide');
      expect((item.season, item.episode), (2, 5));
      expect(item.providerSeriesKey, 's1');
      expect(
        File(
          p.join(
            temp.path,
            'IPTV Player',
            'Series',
            'Glass Tide',
            'poster.jpg',
          ),
        ).existsSync(),
        isTrue,
      );
      final details = jsonDecode(item.detailsJson!) as Map;
      expect(details['series_name'], 'Glass Tide');
      expect(details['title'], 'Northbound');
      expect(details['plot'], 'They sail.');
      final folder = (await db.libraryDao.folderById(item.folderId))!;
      expect(folder.isDownloadFolder, isTrue);
    });

    test('after a crash between the rename and the database: finished from '
        'the final file', () async {
      final t = task(total: 1000);
      File(t.targetPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(1000, 7));
      final finish = await finisher.finish(t);
      expect(finish, isA<DownloadFinished>());
      expect(File(t.targetPath).existsSync(), isTrue);
    });

    test("discard and the .part's size", () async {
      final t = task();
      expect(await finisher.partSize(t), 0);
      part(t, 4096);
      expect(await finisher.partSize(t), 4096);
      await finisher.discard(t);
      expect(File('${t.targetPath}.part').existsSync(), isFalse);
      await finisher.discard(t);
    });
  });
}

final class _Probe implements StreamProbe {
  StreamProbeResult next = const StreamProbed(
    StreamFacts(
      origin: StreamFactsOrigin.probe,
      duration: Duration(minutes: 42),
    ),
  );
  final asked = <String>[];

  @override
  Future<StreamProbeResult> probe(String input, {String? userAgent}) async {
    asked.add(input);
    return next;
  }
}
