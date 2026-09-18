import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/daos/channels_dao.dart';
import 'package:iptv_player/data/db/tables.dart';

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
