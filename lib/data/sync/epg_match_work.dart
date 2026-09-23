import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/job_database.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_match_summary.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';

/// Everything the match isolate needs, as plain sendable values: the
/// source, and the database as a [DriftIsolate] to connect to. It lives
/// only as long as the run.
final class EpgMatchWork {
  const new({
    required this.sourceId,
    required this.connection,
    this.pageSize = 5000,
  });

  final String sourceId;
  final DriftIsolate connection;

  /// Rows per read. The source's channels are read a page at a time
  /// rather than 50,000 in one answer: each page is one message out of the
  /// database isolate, which other queries wait behind, and the run holds
  /// one page and the matches rather than every row.
  final int pageSize;

  @override
  String toString() => 'EpgMatchWork($sourceId)';
}

/// Starts [work] in a new isolate. Top level, so the closure sent to the
/// isolate captures [work] and nothing else. Guarded: cancel and the
/// timeout never kill it inside its one write (`startGuardedJob`).
BackgroundJob<int, Result<EpgMatchSummary>> startEpgMatchJob(
  EpgMatchWork work, {
  Duration? timeout,
}) => startGuardedJob<int, Result<EpgMatchSummary>>(
  (report, cancellation) =>
      runEpgMatchWork(work, report, cancellation: cancellation),
  timeout: timeout,
  debugName: 'epg-match',
);

/// The match isolate's body: reads the source's live guide channels, the
/// user's mappings and the source's channels, runs [EpgMatcher] over
/// them, and replaces the source's `epg_matches` with what it found.
/// [report] hears how many channels have been read, after each page.
///
/// **The write is one batch**: the source's matches deleted and every
/// new one inserted, in the one transaction a batch is. Readers see the
/// old matches or the new ones, never a source half matched, and the
/// guard ([openJobDatabase] marks the batch on [cancellation]) means the
/// isolate is never killed inside it (ADR-011 step 3). The reads before
/// it are plain queries, so a stop lands at once while they run.
///
/// A source with no guide and no mappings still has its matches
/// replaced, by nothing. A channel removed while this runs (a sync's
/// sweep) is left out of the write rather than failing it.
///
/// Never throws. Nothing it returns names a channel.
Future<Result<EpgMatchSummary>> runEpgMatchWork(
  EpgMatchWork work,
  void Function(int channelsRead)? report, {
  JobCancellation? cancellation,
}) async {
  AppDatabase? db;
  try {
    final connected = db = await openJobDatabase(work.connection, cancellation);
    final guide = [
      await for (final page in _pages(
        connected,
        table: 'epg_channels',
        columns: 'xmltv_id, display_name',
        sourceId: work.sourceId,
        size: work.pageSize,
      ))
        for (final row in page) ?_guideChannel(row),
    ];
    final mappings = {
      for (final row in await connected.epgDao.mappingsFor(work.sourceId))
        row.channelRemoteKey: row.xmltvId,
    };
    final matcher = EpgMatcher(guide, mappings: mappings);

    final matches = <ChannelMatch>[];
    final byRule = <GuideMatchRule, int>{};
    var channels = 0;
    var skipped = 0;
    await for (final page in _pages(
      connected,
      table: 'channels',
      columns: 'remote_key, name, epg_key',
      sourceId: work.sourceId,
      size: work.pageSize,
    )) {
      for (final row in page) {
        channels++;
        final candidate = _candidate(row);
        if (candidate == null) {
          skipped++;
          continue;
        }
        final ChannelMatch? match;
        try {
          match = matcher.match(candidate);
        } on Object {
          // Hard rule 1: a name the matcher chokes on costs that channel
          // its guide, not the whole source's. Counted, and logged.
          skipped++;
          continue;
        }
        if (match == null) continue;
        matches.add(match);
        byRule.update(match.rule, (n) => n + 1, ifAbsent: () => 1);
      }
      report?.call(channels);
    }

    await _replace(connected, work.sourceId, matches);
    return Ok(
      EpgMatchSummary(
        channels: channels,
        byRule: byRule,
        guideChannels: guide.length,
        skipped: skipped,
      ),
    );
  } on Object catch (error) {
    return Err(epgMatchFailure(error));
  } finally {
    await db?.close();
  }
}

/// What a failed run returns: the job's own failure (a stop), a storage
/// failure for what the database refused, or an unexpected one. Only the
/// first line of what was thrown: SQLite's next line quotes the
/// statement and its values.
AppFailure epgMatchFailure(Object error) {
  final text = 'guide match: ${'$error'.split('\n').first}';
  return switch (error) {
    AppFailure() => error,
    DriftRemoteException() ||
    SqliteException() ||
    InvalidDataException() => StorageFailure(text),
    _ => UnexpectedFailure(text),
  };
}

/// The rows of [table] for a source, [size] at a time, in row id order:
/// each page starts after the last id of the one before, so no row is
/// read twice and the loop always ends (the id is an integer key, where
/// a text key could hold a value that sorts oddly). Pages are separate
/// reads, not one snapshot; a sync that lands between two is caught by
/// the rematch that follows it.
Stream<List<QueryRow>> _pages(
  AppDatabase db, {
  required String table,
  required String columns,
  required String sourceId,
  required int size,
}) async* {
  final limit = size < 1 ? 1 : size;
  int? after;
  while (true) {
    final rows = await db
        .customSelect(
          'SELECT id, $columns FROM $table WHERE source_id = ?1'
          '${after == null ? '' : ' AND id > ?3'} ORDER BY id LIMIT ?2',
          variables: [
            Variable.withString(sourceId),
            Variable.withInt(limit),
            if (after != null) Variable.withInt(after),
          ],
        )
        .get();
    if (rows.isNotEmpty) yield rows;
    if (rows.length < limit) return;
    after = rows.last.read<int>('id');
  }
}

/// A channel row as the matcher sees it, or null when it can't be read.
MatchCandidate? _candidate(QueryRow row) {
  try {
    final id = row.readNullable<int>('id');
    final remoteKey = row.readNullable<String>('remote_key');
    if (id == null || remoteKey == null) return null;
    return MatchCandidate(
      channelId: id,
      remoteKey: remoteKey,
      name: row.readNullable<String>('name') ?? '',
      epgKey: row.readNullable<String>('epg_key'),
    );
  } on Object {
    return null;
  }
}

GuideChannel? _guideChannel(QueryRow row) {
  try {
    final id = row.readNullable<String>('xmltv_id');
    if (id == null) return null;
    return GuideChannel(
      xmltvId: id,
      displayName: row.readNullable<String>('display_name'),
    );
  } on Object {
    return null;
  }
}

/// Only matches for the source's own channels that still exist go in:
/// the key is the channel's row id, and a sync's sweep may have removed
/// one since it was read. `OR IGNORE` keeps the first match if a channel
/// were ever matched twice.
const _insertMatch =
    'INSERT OR IGNORE INTO epg_matches (channel_id, source_id, xmltv_id, '
    'rule) SELECT ?1, ?2, ?3, ?4 WHERE EXISTS '
    '(SELECT 1 FROM channels WHERE id = ?1 AND source_id = ?2)';

/// The source's matches, replaced whole in one batch.
Future<void> _replace(
  AppDatabase db,
  String sourceId,
  List<ChannelMatch> matches,
) {
  final inserted = {
    TableUpdate.onTable(db.epgMatches, kind: UpdateKind.insert),
  };
  return db.batch((batch) {
    batch.deleteWhere(db.epgMatches, (t) => t.sourceId.equals(sourceId));
    for (final match in matches) {
      batch.customStatement(_insertMatch, [
        match.channelId,
        sourceId,
        match.xmltvId,
        _stored(match.rule).name,
      ], inserted);
    }
  });
}

/// The rule as `epg_matches.rule` stores it. The two enums share their
/// names; the switch makes a rule added to one fail to compile until the
/// other has it too.
EpgMatchRule _stored(GuideMatchRule rule) => switch (rule) {
  GuideMatchRule.manual => EpgMatchRule.manual,
  GuideMatchRule.exactId => EpgMatchRule.exactId,
  GuideMatchRule.caseInsensitiveId => EpgMatchRule.caseInsensitiveId,
  GuideMatchRule.normalizedName => EpgMatchRule.normalizedName,
};
