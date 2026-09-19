import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';

/// [SourceOverviewRepository] over `sources`, `sync_runs` and the
/// catalogue tables.
///
/// The query watches only `sources` and `sync_runs`, so it runs again when
/// a sync starts or finishes, not on each of a sync's thousands of item
/// writes; the counts are read once per change.
final class DbSourceOverviewRepository implements SourceOverviewRepository {
  new(AppDatabase database) : _db = database;

  final AppDatabase _db;

  @override
  Stream<SourceOverview?> watch(String sourceId) => _db
      .customSelect(
        'SELECT s.account_json, r.outcome, r.started_at, r.finished_at, '
        'r.failure, r.failure_status, r.id AS run_id '
        'FROM sources s '
        'LEFT JOIN sync_runs r ON r.id = '
        '(SELECT MAX(id) FROM sync_runs WHERE source_id = s.id) '
        'WHERE s.id = ?',
        variables: [Variable.withString(sourceId)],
        readsFrom: {_db.sources, _db.syncRuns},
      )
      .watchSingleOrNull()
      .asyncMap((row) async {
        if (row == null) return null;
        return SourceOverview(
          account: parseStoredAccount(row.read<String?>('account_json')),
          counts: await _counts(sourceId),
          lastSync: _lastSync(row),
        );
      })
      .handleError(
        (Object error) => throw StorageFailure('source overview: $error'),
        test: (error) => error is! AppFailure,
      );

  Future<SourceCounts> _counts(String sourceId) async {
    final row = await _db
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM channels WHERE source_id = ?1) AS channels, '
          '(SELECT COUNT(*) FROM movies WHERE source_id = ?1) AS movies, '
          '(SELECT COUNT(*) FROM series WHERE source_id = ?1) AS series',
          variables: [Variable.withString(sourceId)],
        )
        .getSingle();
    return SourceCounts(
      channels: row.read<int>('channels'),
      movies: row.read<int>('movies'),
      series: row.read<int>('series'),
    );
  }

  static LastSync? _lastSync(QueryRow row) {
    if (row.read<int?>('run_id') == null) return null;
    final startedAt = _time(row.read<String?>('started_at'));
    if (startedAt == null) return null;
    return LastSync(
      outcome: switch (row.read<String?>('outcome')) {
        'succeeded' => LastSyncOutcome.succeeded,
        'failed' => LastSyncOutcome.failed,
        'cancelled' => LastSyncOutcome.cancelled,
        _ => LastSyncOutcome.running,
      },
      startedAt: startedAt,
      finishedAt: _time(row.read<String?>('finished_at')),
      failureCode: row.read<String?>('failure'),
      failureStatus: row.read<int?>('failure_status'),
    );
  }

  static DateTime? _time(String? text) =>
      text == null ? null : DateTime.tryParse(text)?.toUtc();
}

/// Reads `sources.account_json` (written from `XtreamAccount.toStoredJson`)
/// back into the domain's account. Tolerant: a damaged or foreign value
/// reads as no account rather than failing the screen (hard rule 1).
ProviderAccount? parseStoredAccount(String? json) {
  if (json == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, Object?>) return null;
  final fields = decoded;
  String? text(String key) => switch (fields[key]) {
    final String value when value.isNotEmpty => value,
    _ => null,
  };
  int? number(String key) => switch (fields[key]) {
    final int value => value,
    final String value => int.tryParse(value),
    _ => null,
  };
  return ProviderAccount(
    status: text('status'),
    expiresAt: DateTime.tryParse(text('expires_at') ?? '')?.toUtc(),
    isTrial: fields['is_trial'] == true,
    activeConnections: number('active_connections'),
    maxConnections: number('max_connections'),
    allowedFormats: switch (fields['allowed_output_formats']) {
      final List<Object?> formats => [
        for (final f in formats)
          if (f is String) f.toLowerCase(),
      ],
      _ => const [],
    },
    serverTimezone: text('server_timezone'),
  );
}
