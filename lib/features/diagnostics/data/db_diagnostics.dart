import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/core/platform/run_logs.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/core/player/decoder_notes.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_version.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/ffmpeg_encoder_detector.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/diagnostics/domain/diagnostics_report.dart';
import 'package:iptv_player/features/diagnostics/domain/diagnostics_service.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/sources/data/db_source_overview_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

/// [DiagnosticsService] on the app's database and what the running app
/// knows. It reads; it starts nothing (no encoder test, no sign-in).
final class DbDiagnostics implements DiagnosticsService {
  new({
    required this._db,
    required this._version,
    required this._system,
    required this._decoders,
    required this._log,
    required this._secrets,
    this._player,
    this._castFolder,
    this._exits = const NoLastExits(),
    this._runLogs = const NoRunLogs(),
    this.homeFolder,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Future<AppVersion> Function() _version;
  final SystemFactsReader _system;
  final DecoderNotes _decoders;
  final LogReader _log;
  final SecretRegistry _secrets;
  final PlayerEngine? _player;
  final Directory? _castFolder;
  final LastExitsSource _exits;
  final RunLogsSource _runLogs;

  /// Written `~` in the report.
  final String? homeFolder;
  final DateTime Function() _clock;

  /// How many of the log's newest warnings and errors the report ends
  /// with.
  static const problemLines = 50;

  /// Each run's own log in [shareReport], at most: a phone's quick
  /// download, and the newest part is where a run ended.
  static const int runLogBytes = 256 * 1024;

  @override
  Future<Result<String>> report() => Result.guard(
    () async => buildDiagnosticsReport(await facts(), secrets: _secrets.values),
  );

  @override
  Future<Result<String>> shareReport() => Result.guard(
    () async => buildDiagnosticsReport(
      await facts(withRunLogs: true),
      secrets: _secrets.values,
    ),
  );

  /// Everything the report is written from; each run's own log too with
  /// [withRunLogs]. Each part that can't be read is left out rather than
  /// failing the report: it is for the day something is broken.
  Future<DiagnosticsFacts> facts({bool withRunLogs = false}) async {
    final remembered = await _try(() async {
      final folder = _castFolder;
      return folder == null ? null : await _rememberedInIsolate(folder.path);
    });
    final problems = await _try(
      () async => (await _log.page(
        const LogQuery(problemsOnly: true),
        limit: problemLines,
      )).valueOrNull,
    );
    final rows = problems?.rows ?? const <LogRow>[];
    final last = _exits.available ? await _try(_exits.read) : null;
    final runLogs = withRunLogs && _runLogs.available
        ? await _try(() => _runLogs.read(maxBytes: runLogBytes))
        : null;
    return DiagnosticsFacts(
      now: _clock(),
      appVersion: (await _try(_version))?.short ?? 'unknown',
      system: await _try(_system.read) ?? const SystemFacts(),
      player: await _try(
        () async => switch (_player) {
          final PlayerVersion player => await player.playerVersion(),
          _ => null,
        },
      ),
      decoders: await _try(_decoders.recent) ?? const [],
      ffmpeg: remembered?.ffmpeg,
      encoders: remembered?.encoders,
      sources: await _try(_sources) ?? const [],
      settings: await _try(_settings) ?? const {},
      libraryFolders: await _count('library_folders'),
      libraryItems: await _count('library_items'),
      downloadsWaiting: await _downloads(finished: false),
      downloadsFinished: await _downloads(finished: true),
      // The newest [problemLines] lines, whole records where they fit.
      problems: [
        for (final row
            in rows.length > problemLines
                ? rows.sublist(rows.length - problemLines)
                : rows)
          row.raw,
      ],
      homeFolder: homeFolder,
      named: await _try(_named) ?? const {},
      drawing: last?.drawing,
      exits: last?.exits,
      runLogs: runLogs,
    );
  }

  /// What a log line may say and the report may not: each source's
  /// server and its name.
  Future<Map<String, String>> _named() async {
    final named = <String, String>{};
    for (final (index, source) in (await _db.sourcesDao.all()).indexed) {
      for (final url in [source.url, ?source.epgUrl]) {
        final host = Uri.tryParse(url)?.host ?? '';
        if (host.isNotEmpty) named[host] = '<server>';
      }
      named[source.name] = 'Source ${index + 1}';
    }
    return named;
  }

  static Future<T?> _try<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } on Object {
      return null;
    }
  }

  Future<int> _count(
    String table, [
    String where = '',
    List<Object> args = const [],
  ]) async {
    try {
      final row = await _db
          .customSelect(
            'SELECT COUNT(*) AS n FROM $table $where',
            variables: [for (final arg in args) Variable<Object>(arg)],
          )
          .getSingle();
      return row.read<int>('n');
    } on Object {
      return 0;
    }
  }

  Future<int> _downloads({required bool finished}) => _count(
    'downloads',
    finished ? 'WHERE state = ?' : 'WHERE state NOT IN (?, ?, ?)',
    finished
        ? [DownloadTaskState.completed.name]
        : [
            DownloadTaskState.completed.name,
            DownloadTaskState.failed.name,
            DownloadTaskState.canceled.name,
          ],
  );

  Future<List<SourceFacts>> _sources() async {
    final sources = await _db.sourcesDao.all();
    final facts = <SourceFacts>[];
    for (final source in sources) {
      final id = source.id;
      final account = parseStoredAccount(source.accountJson);
      final sync = await _db.syncRunsDao.latest(id);
      final import = await _db.epgDao.latestImport(id);
      facts.add(
        SourceFacts(
          type: switch (source.type) {
            SourceType.xtream => 'Xtream',
            SourceType.m3uUrl => 'M3U URL',
            SourceType.m3uFile => 'M3U file',
          },
          accountStatus: account?.status,
          maxConnections:
              source.maxConnectionsOverride ?? account?.maxConnections,
          channels: await _count('channels', 'WHERE source_id = ?', [id]),
          movies: await _count('movies', 'WHERE source_id = ?', [id]),
          series: await _count('series', 'WHERE source_id = ?', [id]),
          sync: sync == null
              ? null
              : RunFacts(
                  outcome: sync.outcome.name,
                  startedAt: sync.startedAt,
                  duration: _syncDuration(sync),
                  skipped: _syncSkipped(sync.countsJson),
                  failure: sync.failure,
                  failureStatus: sync.failureStatus,
                ),
          guide: import == null
              ? null
              : RunFacts(
                  outcome: import.outcome.name,
                  startedAt: import.startedAt,
                  duration: import.finishedAt?.difference(import.startedAt),
                  skipped: EpgImportCounts.fromJson(import.countsJson)
                      .skipped
                      .values
                      .fold(0, (sum, n) => sum + n),
                  failure: import.failure,
                  failureStatus: import.failureStatus,
                ),
          guideProgrammes: await _count('epg_programs', 'WHERE source_id = ?', [
            id,
          ]),
        ),
      );
    }
    return facts;
  }

  static Duration? _syncDuration(SyncRunRow run) {
    try {
      if (jsonDecode(run.countsJson ?? '') case {'duration_ms': final int ms}) {
        return Duration(milliseconds: ms);
      }
    } on FormatException {
      // The run's own times, below.
    }
    return run.finishedAt?.difference(run.startedAt);
  }

  static int _syncSkipped(String? countsJson) {
    try {
      if (jsonDecode(countsJson ?? '') case {'skipped': final int skipped}) {
        return skipped;
      }
    } on FormatException {
      // None recorded.
    }
    return 0;
  }

  /// The settings that change how the app behaves, as the report names
  /// them. Paths and languages stay out: a path names the user, and
  /// neither helps to fix a decoder.
  Future<Map<String, String>> _settings() async {
    final stored = await _db.settingsDao.readAll();
    Map<Object?, Object?> page(String key) {
      try {
        final value = jsonDecode(stored[key] ?? '');
        return value is Map ? value : const {};
      } on FormatException {
        return const {};
      }
    }

    final playback = page(SettingsKeys.playback);
    final appearance = page(SettingsKeys.appearance);
    final guide = page(SettingsKeys.guide);
    final cast = page(SettingsKeys.cast);
    final downloads = page(SettingsKeys.downloads);
    String text(Object? value, String fallback) => switch (value) {
      final String v when v.isNotEmpty => v,
      final num v => '$v',
      final bool v => v ? 'on' : 'off',
      _ => fallback,
    };

    return {
      'buffering': text(playback['preset'], 'balanced'),
      'hardware decoding': text(playback['hwdec'], 'auto'),
      'deinterlace': text(playback['deinterlace'], 'auto'),
      'text size': text(appearance['text_size'], 'system'),
      'density': text(appearance['density'], 'comfortable'),
      'reduce motion': text(appearance['reduce_motion'], 'system'),
      'guide days': text(guide['keep_days'], 'default'),
      'Dolby passthrough': text(cast['dolby_passthrough'], 'default'),
      'low latency': text(cast['low_latency'], 'default'),
      'smooth interlaced': text(cast['smooth_interlaced'], 'default'),
      'downloads at a time': text(downloads['at_a_time'], 'default'),
    };
  }

  @override
  Future<Result<void>> save(String path, String text) =>
      Result.guard(() => _writeInIsolate(path, text));
}

// Built at the top level, so the closures sent to the isolates carry
// their arguments and nothing of their caller.
Future<({String? ffmpeg, List<String> encoders})?> _rememberedInIsolate(
  String folder,
) => Isolate.run(() => FfmpegEncoderDetector.remembered(Directory(folder)));

Future<void> _writeInIsolate(String path, String text) => Isolate.run(() {
  File('$path.part')
    ..writeAsStringSync('$text\n', flush: true)
    ..renameSync(path);
});
