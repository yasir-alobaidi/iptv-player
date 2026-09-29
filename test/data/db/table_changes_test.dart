import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/table_changes.dart';
import 'package:iptv_player/data/db/tables.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  test('once at once, then on each change to its tables only', () async {
    var sources = 0;
    var channels = 0;
    // Two sets watched at the same time: with the same SQL, drift would
    // share one stream between them, watching the first one's tables.
    final a = tableChanges(db, {db.sources}).listen((_) => sources++);
    final b = tableChanges(db, {db.channels}).listen((_) => channels++);
    await pumpEventQueue();
    expect((sources, channels), (1, 1));

    await db.sourcesDao.upsert(
      SourcesCompanion.insert(
        id: 's1',
        type: SourceType.m3uFile,
        name: 'List',
        url: '/list.m3u',
        createdAt: DateTime.utc(2026, 9, 29),
        updatedAt: DateTime.utc(2026, 9, 29),
      ),
    );
    await pumpEventQueue();
    expect((sources, channels), (2, 1));

    await db.channelsDao.upsertAll([
      ChannelsCompanion.insert(sourceId: 's1', remoteKey: 'a', name: 'A'),
    ]);
    await pumpEventQueue();
    expect((sources, channels), (2, 2));

    await a.cancel();
    await b.cancel();
  });

  test('a change while paused comes once the listener resumes', () async {
    var heard = 0;
    final subscription = tableChanges(db, {db.sources}).listen((_) => heard++);
    await pumpEventQueue();
    subscription.pause();

    await db.sourcesDao.upsert(
      SourcesCompanion.insert(
        id: 's1',
        type: SourceType.m3uFile,
        name: 'List',
        url: '/list.m3u',
        createdAt: DateTime.utc(2026, 9, 29),
        updatedAt: DateTime.utc(2026, 9, 29),
      ),
    );
    await pumpEventQueue();
    expect(heard, 1);

    subscription.resume();
    await pumpEventQueue();
    expect(heard, 2);
    await subscription.cancel();
  });
}
