import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/daos/channels_dao.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:path/path.dart' as p;

/// How the app opens its database decides whether the sync isolate can
/// reach it directly (ADR-009, step 5 spike): behind a `LazyDatabase`,
/// drift hides the database isolate and relays every write from another
/// isolate through a proxy on the UI isolate.
void main() {
  late Directory directory;
  late AppDatabase db;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('app_database_open');
    db = AppDatabase(await openAppDatabase(directory));
    await db.sourcesDao.upsert(
      SourcesCompanion.insert(
        id: 's1',
        type: SourceType.m3uFile,
        name: 'List',
        url: '/list.m3u',
        createdAt: DateTime.utc(2026, 9, 18),
        updatedAt: DateTime.utc(2026, 9, 18),
      ),
    );
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test('the file is kept with write-ahead logging, synced normally', () async {
    Future<Object?> pragma(String name) async =>
        (await db.customSelect('PRAGMA $name').getSingle()).data.values.single;

    expect(await pragma('journal_mode'), 'wal');
    expect(await pragma('synchronous'), 1); // NORMAL
    expect(await pragma('journal_size_limit'), 64 * 1024 * 1024);
    expect(await pragma('foreign_keys'), 1);
  });

  test("a screen's read doesn't wait for a write under way: reads have "
      "connections of their own (Live TV's list waited ~10 s behind a "
      "50,000-channel sync's batches)", () async {
    final release = Completer<void>();
    final started = Completer<void>();
    final writing = db.transaction(() async {
      await db.channelsDao.upsertAll([
        ChannelsCompanion.insert(sourceId: 's1', remoteKey: 'a', name: 'A'),
      ]);
      started.complete();
      await release.future;
    });
    await started.future;

    final count = await db.channelsDao
        .countFor('s1')
        .timeout(const Duration(seconds: 2));
    // What was committed: the write under way isn't.
    expect(count, 0);

    release.complete();
    await writing;
    expect(await db.channelsDao.countFor('s1'), 1);
  });

  test(
    "the log's checkpoint runs where the writes are: a write under way "
    'makes it wait rather than give up (the review of the read pool)',
    () async {
      final release = Completer<void>();
      final started = Completer<void>();
      final writing = db.transaction(() async {
        await db.channelsDao.upsertAll([
          ChannelsCompanion.insert(sourceId: 's1', remoteKey: 'a', name: 'A'),
        ]);
        started.complete();
        await release.future;
      });
      await started.future;

      var done = false;
      final truncating = db.maintenanceDao.truncateLog().whenComplete(
        () => done = true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(done, isFalse, reason: 'it waits for the write under way');

      release.complete();
      await writing;
      expect(await truncating, isTrue, reason: 'and then cuts the log');
      expect(
        File(p.join(directory.path, '$appDatabaseFileName-wal')).lengthSync(),
        0,
      );
    },
  );

  test('every connection waits a while for a lock rather than failing at '
      'once ("database is locked")', () async {
    Future<Object?> busyTimeout() async =>
        (await db.customSelect('PRAGMA busy_timeout').getSingle())
            .data
            .values
            .single;

    // A reader's, and the writer's.
    expect(await busyTimeout(), 5000);
    expect(await db.exclusively(busyTimeout), 5000);
  });

  test('other isolates connect straight to the database isolate', () async {
    final first = await db.serializableConnection();
    final second = await db.serializableConnection();

    // A proxy would be a new, single-use server each time.
    expect(first.connectPort, second.connectPort);
  });

  test('a write from another isolate reaches a query stream here', () async {
    final seen = db.channelsDao
        .watchCountFor('s1')
        .firstWhere((count) => count == 2);
    final connection = await db.serializableConnection();

    final written = await _writeTwoChannels(connection);

    expect(written.valueOrNull, isTrue);
    expect(await seen, 2);
  });
}

/// Top level, so the closure sent to the isolate captures [connection]
/// and not the test's database.
Future<Result<bool>> _writeTwoChannels(DriftIsolate connection) =>
    runInBackground(() async {
      final other = AppDatabase(await connection.connect());
      try {
        await other.channelsDao.upsertAll([
          ChannelsCompanion.insert(sourceId: 's1', remoteKey: 'a', name: 'A'),
          ChannelsCompanion.insert(sourceId: 's1', remoteKey: 'b', name: 'B'),
        ]);
        return true;
      } finally {
        await other.close();
      }
    }, timeout: const Duration(seconds: 30));

extension on ChannelsDao {
  Stream<int> watchCountFor(String sourceId) {
    final total = channels.id.count();
    return (selectOnly(channels)
          ..addColumns([total])
          ..where(channels.sourceId.equals(sourceId)))
        .map((row) => row.read(total) ?? 0)
        .watchSingle();
  }
}
