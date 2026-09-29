import 'dart:async';
import 'dart:io';

// `isNull` and `isNotNull` exist in both drift and matcher; the matcher's
// are the ones these tests mean.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/data/sync/channel_name_fill.dart';
import 'package:iptv_player/data/sync/channel_name_work.dart';
import 'package:iptv_player/features/live_tv/domain/channel_names.dart';
import 'package:logger/logger.dart';

final _now = DateTime.utc(2026, 9, 29, 12);

/// The fill over a real file database, opened the way the app opens it,
/// so the job connects to it as it does in the app.
final class _Env {
  new _(this.directory, this.db);

  static Future<_Env> open() async {
    final directory = await Directory.systemTemp.createTemp('channel_names');
    final db = AppDatabase(await openAppDatabase(directory));
    final env = _Env._(directory, db);
    addTearDown(env.close);
    await db.sourcesDao.upsert(
      SourcesCompanion.insert(
        id: 's1',
        type: SourceType.xtream,
        name: 'Provider',
        url: 'http://s1.test:8080',
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    return env;
  }

  final Directory directory;
  final AppDatabase db;

  /// Channels as a catalogue synced before schema v7 holds them: a name,
  /// and no cleaned name.
  Future<void> unnamed(List<String> names) => db.batch(
    (b) => b.insertAll(db.channels, [
      for (final (i, name) in names.indexed)
        ChannelsCompanion.insert(
          sourceId: 's1',
          remoteKey: 'k$i',
          name: name,
          position: Value(i),
        ),
    ]),
  );

  Future<List<ChannelRow>> rows() => (db.select(
    db.channels,
  )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

  Future<ChannelNameWork> work({int batchSize = 5000}) async => ChannelNameWork(
    connection: await db.serializableConnection(),
    batchSize: batchSize,
  );

  Future<void> checkIndex() => db.customStatement(
    'INSERT INTO channels_fts(channels_fts, rank) '
    "VALUES ('integrity-check', 1)",
  );

  Future<void> close() async {
    await db.close();
    await directory.delete(recursive: true);
  }
}

/// A job's result: the run's own, or the job's failure (a stop, the
/// timeout) when it never returned one.
Result<int> _unwrapped(Result<Result<int>> job) => switch (job) {
  Ok(:final value) => value,
  Err(:final failure) => Err(failure),
};

List<String> _names(int count) => [
  for (var i = 0; i < count; i++)
    switch (i % 4) {
      0 => 'UK: Channel $i HD',
      1 => '|EN| Channel $i',
      2 => 'Channel $i ᶠᴴᴰ',
      _ => 'Channel $i',
    },
];

void main() {
  group('runChannelNameWork', () {
    test('names every channel that has no cleaned name, a batch at a '
        'time, and the index finds them', () async {
      final env = await _Env.open();
      await env.unnamed(_names(23));
      final reports = <int>[];

      final result = await runChannelNameWork(
        await env.work(batchSize: 5),
        reports.add,
      );

      expect(result.valueOrNull, 23);
      expect(reports, [5, 10, 15, 20, 23]);
      for (final row in await env.rows()) {
        final cleaned = cleanChannelName(row.name);
        expect(row.cleanName, cleaned.name, reason: row.name);
        expect(row.quality, cleaned.quality?.name, reason: row.name);
      }
      expect((await env.rows()).first.cleanName, 'Channel 0');
      expect((await env.rows()).first.quality, 'hd');
      final hits = await env.db
          .customSelect(
            "SELECT rowid FROM channels_fts WHERE channels_fts MATCH 'uk'",
          )
          .get();
      expect(hits, isEmpty, reason: 'the tags are not what is indexed');
      await env.checkIndex();
    });

    test('leaves channels that already have a name, and has nothing to do '
        'a second time', () async {
      final env = await _Env.open();
      await env.unnamed(['UK: One HD', 'UK: Two HD']);
      await (env.db.update(env.db.channels)
            ..where((t) => t.remoteKey.equals('k1')))
          .write(const ChannelsCompanion(cleanName: Value('Synced since')));

      expect((await runChannelNameWork(await env.work(), null)).valueOrNull, 1);
      final rows = await env.rows();
      expect(rows.first.cleanName, 'One');
      expect(rows.last.cleanName, 'Synced since');
      expect(rows.last.quality, isNull);

      expect((await runChannelNameWork(await env.work(), null)).valueOrNull, 0);
    });

    test('an empty catalogue, and odd names, never fail', () async {
      final env = await _Env.open();
      expect((await runChannelNameWork(await env.work(), null)).valueOrNull, 0);

      await env.unnamed([
        '',
        '|UK| HD',
        '\ufffd',
        'AR | الجزيرة HD',
        'Q&amp;amp;A',
        'x' * 500,
      ]);
      expect((await runChannelNameWork(await env.work(), null)).valueOrNull, 6);
      expect(
        [for (final row in await env.rows()) row.cleanName],
        ['', '|UK| HD', '\ufffd', 'الجزيرة', 'Q&A', 'x' * 500],
      );
      await env.checkIndex();
    });

    test('stopped between batches: whole batches only, the database usable, '
        'and the next run finishes the rest', () async {
      final env = await _Env.open();
      const count = 20000;
      const batch = 1000;
      await env.unnamed(_names(count));

      for (var round = 0; round < 3; round++) {
        final job = startChannelNameJob(
          await env.work(batchSize: batch),
          timeout: const Duration(seconds: 60),
        );
        await job.progress.first;
        job.cancel();
        final result = _unwrapped(await job.result);

        final named = await env.db
            .customSelect(
              'SELECT COUNT(*) AS n FROM channels WHERE clean_name IS NOT NULL',
            )
            .getSingle()
            .timeout(const Duration(seconds: 10))
            .then((row) => row.read<int>('n'));
        if (result.isOk) {
          // It finished before the stop landed.
          expect(named, count);
          break;
        }
        expect(result.failureOrNull, isA<CancelledFailure>());
        expect(named % batch, 0, reason: 'a batch lands whole or not');
        await env.db
            .customStatement("UPDATE sources SET name = 'still usable'")
            .timeout(const Duration(seconds: 10));
      }

      final rest = await runChannelNameWork(await env.work(), null);
      expect(rest.isOk, isTrue);
      final rows = await env.rows();
      expect(rows.where((r) => r.cleanName == null), isEmpty);
      await env.checkIndex();
    });

    test('benchmark: 50,000 names', () async {
      final env = await _Env.open();
      await env.unnamed(_names(50000));
      final clock = Stopwatch()..start();
      final job = startChannelNameJob(await env.work());
      final result = _unwrapped(await job.result);
      final elapsed = clock.elapsedMilliseconds;
      // The benchmark's output is its result, read by whoever runs it.
      // ignore: avoid_print
      print('fill: ${result.valueOrNull} names in $elapsed ms');
      expect(result.valueOrNull, 50000);
    }, tags: 'benchmark');
  });

  group('ChannelNameFill', () {
    late MemoryOutput output;
    late AppLog log;

    setUp(() {
      output = MemoryOutput();
      log = AppLog(output: output, secrets: SecretRegistry());
      addTearDown(log.close);
    });

    test('starts nothing when every channel has its name', () async {
      final env = await _Env.open();
      await env.unnamed(['UK: One HD']);
      await runChannelNameWork(await env.work(), null);
      var runs = 0;
      final fill = ChannelNameFill(
        database: env.db,
        log: log,
        runner: (_, _) async {
          runs++;
          return const Ok(0);
        },
      );
      addTearDown(fill.dispose);

      expect((await fill.run()).valueOrNull, 0);
      expect(runs, 0);
    });

    test('runs the job once for calls made while it runs, and logs how it '
        'went', () async {
      final env = await _Env.open();
      await env.unnamed(_names(3));
      final fill = ChannelNameFill(database: env.db, log: log);
      addTearDown(fill.dispose);

      final first = fill.run();
      final second = fill.run();
      expect(identical(first, second), isTrue);
      expect((await first).valueOrNull, 3);
      expect((await fill.run()).valueOrNull, 0);
      final lines = [for (final e in output.buffer) ...e.lines];
      expect(
        lines.where((l) => l.contains('Channel names: 3 cleaned')),
        hasLength(1),
      );
      expect(lines.join('\n'), isNot(contains('Channel 0')));
    });

    test('dispose stops a run, and a later run says the app is '
        'closing', () async {
      final env = await _Env.open();
      await env.unnamed(_names(3));
      final started = Completer<void>();
      final fill = ChannelNameFill(
        database: env.db,
        log: log,
        runner: (_, stop) async {
          started.complete();
          await stop;
          return Err(CancelledFailure('channel-names cancelled'));
        },
      );

      final run = fill.run();
      await started.future;
      await fill.dispose();

      expect((await run).failureOrNull, isA<CancelledFailure>());
      expect((await fill.run()).failureOrNull, isA<CancelledFailure>());
    });
  });
}
