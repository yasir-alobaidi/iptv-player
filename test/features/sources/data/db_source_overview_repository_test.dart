import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/features/sources/data/db_source_overview_repository.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';

final _now = DateTime.utc(2026, 9, 18, 9);

void main() {
  late AppDatabase db;
  late DbSourceOverviewRepository repository;

  setUp(() async {
    db = AppDatabase.memory();
    repository = DbSourceOverviewRepository(db);
    await db.sourcesDao.upsert(
      SourcesCompanion.insert(
        id: 's1',
        type: SourceType.xtream,
        name: 'Northwind',
        url: 'http://line.test',
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  });
  tearDown(() => db.close());

  test('a source never synced has no counts, account or run', () async {
    final overview = await repository.watch('s1').first;

    expect(overview, isNotNull);
    expect(overview!.account, isNull);
    expect(overview.counts.isEmpty, isTrue);
    expect(overview.lastSync, isNull);
  });

  test('an unknown source is null', () async {
    expect(await repository.watch('nope').first, isNull);
  });

  test('counts, the account and the latest run', () async {
    await db.channelsDao.upsertAll([
      for (var i = 0; i < 3; i++)
        ChannelsCompanion.insert(
          sourceId: 's1',
          remoteKey: 'c$i',
          name: 'Channel $i',
        ),
    ]);
    await db.moviesDao.upsertAll([
      MoviesCompanion.insert(sourceId: 's1', remoteKey: 'm1', name: 'Film'),
    ]);
    await db.sourcesDao.saveAccount(
      's1',
      accountJson: jsonEncode({
        'status': 'Active',
        'expires_at': '2026-11-03T12:00:00.000Z',
        'is_trial': false,
        'active_connections': '1',
        'max_connections': 2,
        'allowed_output_formats': ['TS', 'm3u8'],
        'server_timezone': 'Europe/London',
      }),
      expiresAt: DateTime.utc(2026, 11, 3, 12),
    );
    final first = await db.syncRunsDao.start('s1', _now);
    await db.syncRunsDao.finish(
      first,
      outcome: SyncOutcome.succeeded,
      at: _now.add(const Duration(seconds: 6)),
    );
    final second = await db.syncRunsDao.start('s1', _now.add(_hour));
    await db.syncRunsDao.finish(
      second,
      outcome: SyncOutcome.failed,
      at: _now.add(_hour),
      failure: 'network',
    );

    final overview = (await repository.watch('s1').first)!;

    expect(overview.counts.channels, 3);
    expect(overview.counts.movies, 1);
    expect(overview.counts.series, 0);
    final account = overview.account!;
    expect(account.status, 'Active');
    expect(account.expiresAt, DateTime.utc(2026, 11, 3, 12));
    expect(account.activeConnections, 1);
    expect(account.maxConnections, 2);
    expect(account.allowedFormats, ['ts', 'm3u8']);
    expect(account.serverTimezone, 'Europe/London');
    final last = overview.lastSync!;
    expect(last.outcome, LastSyncOutcome.failed);
    expect(last.failureCode, 'network');
    expect(last.startedAt, _now.add(_hour));
  });

  test('a run starting and ending shows up; removal ends in null', () async {
    final seen = <LastSyncOutcome?>[];
    final done = Completer<void>();
    final sub = repository.watch('s1').listen((overview) {
      if (overview == null) {
        done.complete();
        return;
      }
      seen.add(overview.lastSync?.outcome);
    });
    await pumpEventQueue();

    final run = await db.syncRunsDao.start('s1', _now);
    await pumpEventQueue();
    await db.syncRunsDao.finish(
      run,
      outcome: SyncOutcome.succeeded,
      at: _now,
      countsJson: '{}',
    );
    await pumpEventQueue();
    await db.sourcesDao.remove('s1');
    await done.future.timeout(const Duration(seconds: 5));
    await sub.cancel();

    expect(seen, [null, LastSyncOutcome.running, LastSyncOutcome.succeeded]);
  });

  test('item writes during a sync do not re-run the overview', () async {
    var emitted = 0;
    final sub = repository.watch('s1').listen((_) => emitted++);
    await pumpEventQueue();
    expect(emitted, 1);

    for (var batch = 0; batch < 3; batch++) {
      await db.channelsDao.upsertAll([
        ChannelsCompanion.insert(
          sourceId: 's1',
          remoteKey: 'c$batch',
          name: 'Channel $batch',
          position: Value(batch),
        ),
      ]);
    }
    await pumpEventQueue();
    await sub.cancel();

    expect(emitted, 1);
  });

  group('parseStoredAccount', () {
    test('tolerates damage', () {
      expect(parseStoredAccount(null), isNull);
      expect(parseStoredAccount('not json'), isNull);
      expect(parseStoredAccount('[1, 2]'), isNull);
      final sparse = parseStoredAccount(
        '{"status": "", "expires_at": "soon", "max_connections": "x", '
        '"allowed_output_formats": [1, "HLS"]}',
      )!;
      expect(sparse.status, isNull);
      expect(sparse.expiresAt, isNull);
      expect(sparse.maxConnections, isNull);
      expect(sparse.allowedFormats, ['hls']);
    });
  });
}

const _hour = Duration(hours: 1);
