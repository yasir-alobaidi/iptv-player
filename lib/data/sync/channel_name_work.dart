import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/job_database.dart';
import 'package:iptv_player/features/live_tv/domain/channel_names.dart';

/// Everything the fill isolate needs, as plain sendable values: the
/// database as a [DriftIsolate] to connect to, and the batch size.
final class ChannelNameWork {
  const new({required this.connection, this.batchSize = 5000});

  final DriftIsolate connection;

  /// Channels read, cleaned and written back per batch: each batch is one
  /// transaction, which every other query waits behind while it commits.
  final int batchSize;

  @override
  String toString() => 'ChannelNameWork($batchSize)';
}

/// Starts [work] in a new isolate. Top level, so the closure sent to the
/// isolate captures [work] and nothing else. Guarded: cancel and the
/// timeout never kill it inside a batch (`startGuardedJob`).
BackgroundJob<int, Result<int>> startChannelNameJob(
  ChannelNameWork work, {
  Duration? timeout,
}) => startGuardedJob<int, Result<int>>(
  (report, cancellation) =>
      runChannelNameWork(work, report, cancellation: cancellation),
  timeout: timeout,
  debugName: 'channel-names',
);

/// The fill isolate's body: gives every channel that has no cleaned name
/// yet (a catalogue synced before schema v7) the name the screens show
/// and its badge (`cleanChannelName`), [ChannelNameWork.batchSize] at a
/// time in row id order, until none is left. Returns how many it wrote;
/// [report] hears the running total after each batch.
///
/// **Each batch is one transaction**, and the guard ([openJobDatabase]
/// marks it on [cancellation]) means the isolate is never killed inside
/// one: a stop between two leaves every row written whole or untouched,
/// and the next launch carries on from the rows still without a name.
///
/// A row is written only if its name is still the one read and it still
/// has no cleaned name, so a sync that lands between the read and the
/// write keeps what it wrote. Such a row is not read again: the pages
/// move on by id, so the loop always ends.
///
/// Never throws. Nothing it returns names a channel.
Future<Result<int>> runChannelNameWork(
  ChannelNameWork work,
  void Function(int filled)? report, {
  JobCancellation? cancellation,
}) async {
  AppDatabase? db;
  try {
    final connected = db = await openJobDatabase(work.connection, cancellation);
    final limit = work.batchSize < 1 ? 1 : work.batchSize;
    var filled = 0;
    var after = 0;
    while (true) {
      final rows = await connected
          .customSelect(
            'SELECT id, name FROM channels '
            'WHERE clean_name IS NULL AND id > ?1 ORDER BY id LIMIT ?2',
            variables: [Variable.withInt(after), Variable.withInt(limit)],
          )
          .get();
      if (rows.isEmpty) break;
      await connected.batch((batch) {
        for (final row in rows) {
          final name = row.read<String>('name');
          final cleaned = cleanChannelName(name);
          batch.customStatement(
            'UPDATE channels SET clean_name = ?1, quality = ?2 '
            'WHERE id = ?3 AND name = ?4 AND clean_name IS NULL',
            [cleaned.name, cleaned.quality?.name, row.read<int>('id'), name],
          );
        }
      });
      filled += rows.length;
      report?.call(filled);
      if (rows.length < limit) break;
      after = rows.last.read<int>('id');
    }
    return Ok(filled);
  } on Object catch (error) {
    return Err(channelNameFailure(error));
  } finally {
    await db?.close();
  }
}

/// What a failed run returns, as the guide's match job does: the job's
/// own failure (a stop), a storage failure for what the database refused,
/// or an unexpected one. Only the first line of what was thrown: SQLite's
/// next line quotes the statement and its values.
AppFailure channelNameFailure(Object error) {
  final text = 'channel names: ${'$error'.split('\n').first}';
  return switch (error) {
    AppFailure() => error,
    DriftRemoteException() ||
    SqliteException() ||
    InvalidDataException() => StorageFailure(text),
    _ => UnexpectedFailure(text),
  };
}
