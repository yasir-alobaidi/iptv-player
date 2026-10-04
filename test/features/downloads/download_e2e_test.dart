import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/quick_hash.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:path/path.dart' as p;

import '../../data/cast/relay/relay_rig.dart' show relayBinaries;
import 'support/download_e2e_rig.dart';

void main() {
  final binaries = relayBinaries();
  if (binaries == null || Platform.isWindows) {
    test('downloads end to end', () {}, skip: 'needs FFmpeg (Linux)');
    return;
  }
  late Directory temp;
  late DownloadE2E rig;

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('download_e2e_');
    rig = await DownloadE2E.start(binaries, temp: temp);
  });

  tearDown(() async {
    await rig.close();
    temp.deleteSync(recursive: true);
  });

  List<int> sample() =>
      File(p.join(temp.path, 'samples', 'vod_h264_aac_10min.mp4'))
          .readAsBytesSync();

  test('a movie downloads into the library, linked to its title', () async {
    await rig.queue.enqueue([DownloadE2E.movie('100000')]);
    final id = rig.queue.current.single.id;
    final done = await rig.until(id, {DownloadTaskState.completed});

    final file = File(done.targetPath);
    expect(
      done.targetPath,
      p.join(
        rig.downloads,
        'Movies',
        'Copper Hollow (2025)',
        'Copper Hollow (2025).mp4',
      ),
    );
    expect(file.readAsBytesSync(), sample());
    expect(File('${done.targetPath}.part').existsSync(), isFalse);
    expect(File(p.join(file.parent.path, 'poster.jpg')).existsSync(), isTrue);

    final item = (await rig.db.libraryDao.itemById(done.libraryItemId!))!;
    expect(item.kind, LibraryKind.movie);
    expect(item.title, 'Copper Hollow');
    expect(item.year, 2025);
    expect(
      item.relPath,
      'Movies/Copper Hollow (2025)/Copper Hollow (2025).mp4',
    );
    expect(item.providerSourceId, 'src');
    expect(item.providerItemType, VodType.movie);
    expect(item.providerRemoteKey, '100000');
    expect(item.durationMs, closeTo(6000, 300));
    expect(item.quickHash, await quickHash(file));
    expect(item.sizeBytes, file.lengthSync());
    final folder = (await rig.db.libraryDao.folderById(item.folderId))!;
    expect(folder.path, rig.downloads);
    expect(folder.isDownloadFolder, isTrue);

    final row = (await rig.db.downloadsDao.byId(id))!;
    expect(row.state, DownloadTaskState.completed);
    expect(row.libraryItemId, item.id);
    expect(row.downloadedBytes, file.lengthSync());
  });

  test(
    'a dropped connection: tried again, resumed with Range, whole',
    () async {
      final size = sample().length;
      rig.titles.queries['100000'] = 'drop_after_bytes=${size ~/ 2}';
      await rig.queue.enqueue([DownloadE2E.movie('100000')]);
      final id = rig.queue.current.single.id;
      final retrying = await rig.until(id, {DownloadTaskState.retrying});
      expect(retrying.problem, DownloadProblem.network);
      expect(retrying.downloadedBytes, size ~/ 2);
      final done = await rig.until(id, {DownloadTaskState.completed});
      expect(File(done.targetPath).readAsBytesSync(), sample());
      expect(rig.titles.asked, greaterThanOrEqualTo(2));
    },
  );

  test('a damaged file never takes its final name', () async {
    await rig.queue.enqueue([DownloadE2E.movie('100001', title: 'Broken')]);
    final id = rig.queue.current.single.id;
    final failed = await rig.until(id, {DownloadTaskState.failed});
    expect(failed.problem, DownloadProblem.damaged);
    expect(File(failed.targetPath).existsSync(), isFalse);
    expect(File('${failed.targetPath}.part').existsSync(), isFalse);
    expect(await rig.db.libraryDao.folders(), hasLength(1));
    expect(await rig.db.select(rig.db.libraryItems).get(), isEmpty);
  });

  test('the player needs the connection: the download gives way at once, '
      'and finishes after the player is done', () async {
    rig.titles.queries['100000'] = 'throttle_kbps=1500';
    await rig.queue.enqueue([DownloadE2E.movie('100000')]);
    final id = rig.queue.current.single.id;
    await rig.until(id, {DownloadTaskState.downloading});
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final clock = Stopwatch()..start();
    final room = await rig.connections.room(
      'src',
      limit: 1,
      holder: StreamHolder.player,
    );
    expect(room, isTrue);
    expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    rig.connections.set('src', StreamHolder.player, 1);
    final waiting = await rig.until(id, {
      DownloadTaskState.waitingForConnection,
    });
    expect(waiting.downloadedBytes, greaterThan(0));
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(rig.panel.state.activeStreams, 0, reason: 'its connection closed');

    rig.titles.queries.remove('100000');
    rig.connections.set('src', StreamHolder.player, 0);
    final done = await rig.until(id, {DownloadTaskState.completed});
    expect(File(done.targetPath).readAsBytesSync(), sample());
  });

  test("a download keeps a copy of its title's details", () async {
    final movie = await rig.db
        .into(rig.db.movies)
        .insert(
          MoviesCompanion.insert(
            sourceId: 'src',
            remoteKey: '100000',
            name: 'Copper Hollow',
            year: const Value(2025),
            rating: const Value(7.4),
          ),
        );
    await rig.db
        .into(rig.db.movieDetails)
        .insert(
          MovieDetailsCompanion.insert(
            movieId: Value(movie),
            plot: const Value('A quiet town, a copper mine.'),
            fetchedAt: DateTime.utc(2026, 10, 4),
          ),
        );
    await rig.queue.enqueue([DownloadE2E.movie('100000')]);
    final id = rig.queue.current.single.id;
    final done = await rig.until(id, {DownloadTaskState.completed});
    final item = (await rig.db.libraryDao.itemById(done.libraryItemId!))!;
    expect(jsonDecode(item.detailsJson!), {
      'name': 'Copper Hollow',
      'year': 2025,
      'rating': 7.4,
      'plot': 'A quiet town, a copper mine.',
    });
  });
}
