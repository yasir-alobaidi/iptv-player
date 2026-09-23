import 'dart:async';

import 'package:drift/isolate.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_reader.dart';
import 'package:iptv_player/data/sync/epg_import_work.dart';
import 'package:iptv_player/data/sync/epg_match_service.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

/// Where a source's guide was found. Logged instead of the URL.
enum GuideLocationKind {
  /// The EPG URL the user typed for the source.
  override,

  /// The Xtream panel's own `xmltv.php`.
  panel,

  /// The first `url-tvg` the playlist's header names.
  playlist,
}

/// A source's guide: a URL (credentials and all) or a file path.
final class GuideLocation {
  const new(this.value, this.kind);

  final String value;
  final GuideLocationKind kind;

  /// True for a value with no `http(s)://` in front: a local file.
  bool get isFile => !_isWeb(value);

  /// What the import isolate opens.
  XmltvInput input({String? userAgent}) => isFile
      ? XmltvFileInput(_filePath(value))
      : XmltvUrlInput(value, userAgent: userAgent);

  /// Never the value: it can carry a password or a token.
  @override
  String toString() =>
      'GuideLocation(${kind.name}, ${isFile ? 'file' : 'url'})';
}

/// Where the guide for a source of [type] comes from: the user's EPG URL
/// wins; else an Xtream panel's `{server}/xmltv.php?username=…&password=…`;
/// else the first EPG URL the playlist's header named. A playlist with
/// none is a `NotFoundFailure`: the source simply has no guide. Pure, so
/// every branch is tested without a server.
Result<GuideLocation> resolveGuideLocation(
  SourceType type,
  SourceCredentials credentials,
) {
  final override = credentials.epgUrl?.trim() ?? '';
  if (override.isNotEmpty) {
    return Ok(GuideLocation(override, GuideLocationKind.override));
  }
  switch (type) {
    case SourceType.xtream:
      final url = xtreamGuideUrl(
        server: credentials.url,
        username: credentials.username ?? '',
        password: credentials.password ?? '',
      );
      if (url == null) {
        return Err(InvalidInputFailure('guide: the server is not a URL'));
      }
      return Ok(GuideLocation(url, GuideLocationKind.panel));
    case SourceType.m3uUrl:
    case SourceType.m3uFile:
      for (final url in credentials.advertisedEpgUrls) {
        if (url.trim().isNotEmpty) {
          return Ok(GuideLocation(url.trim(), GuideLocationKind.playlist));
        }
      }
      return Err(NotFoundFailure('the source has no guide URL'));
  }
}

/// An Xtream panel's full guide: `xmltv.php` beside `player_api.php`,
/// built the way `XtreamClient` builds its requests (the server's own
/// path kept, the credentials query-encoded). Null when [server] is not
/// an http(s) URL.
String? xtreamGuideUrl({
  required String server,
  required String username,
  required String password,
}) {
  final uri = Uri.tryParse(server.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  final base = uri.path.replaceAll(RegExp(r'/+$'), '');
  return uri
      .replace(
        path: '$base/xmltv.php',
        queryParameters: {'username': username, 'password': password},
      )
      .removeFragment()
      .toString();
}

bool _isWeb(String value) {
  final lower = value.trimLeft().toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

/// A `file://` URI as a path; anything else is taken as a path already
/// (`C:\guide.xml` parses as a URI with the scheme `c`).
String _filePath(String value) {
  if (value.toLowerCase().startsWith('file://')) {
    try {
      return Uri.parse(value).toFilePath();
    } on Object {
      return value;
    }
  }
  return value;
}

/// Imports a source's XMLTV guide in a background isolate and swaps it in.
///
/// Shaped like the sync engine: this side (the UI isolate) does only what
/// is small and must not be interrupted — it reads the credentials (the
/// keyring answers on this isolate only), opens the import, starts the
/// isolate, relays its progress, and then either swaps the staged rows in
/// (`EpgRepository.commitImport`, one transaction) or abandons them. The
/// isolate fetches, parses and stages in single batches, and is stopped
/// on cancel or timeout between two of them (`startGuardedJob`). A failed
/// or cancelled import leaves the live guide as it was (decision 5).
///
/// After a swap, the source's channels are matched to the new guide
/// ([EpgMatchService]) before the import reports back, so its result
/// means "the guide is in, and attached". A match that fails is logged
/// and leaves the import as it is: the guide is in either way.
///
/// When to import (daily, after a sync, one source at a time) is the
/// scheduler's business, not this class's.
final class EpgImporter {
  new({
    required AppDatabase database,
    required this._guide,
    required this._sources,
    required this._log,
    this._matches,
    DateTime Function()? clock,
    this.timeout = const Duration(minutes: 30),
    this.batchSize = 5000,
    this.keepBehind = const Duration(days: 1),
    this.keepAhead = const Duration(days: 7),
    this.idleTimeout = const Duration(seconds: 60),
  }) : _db = database,
       _clock = clock ?? _utcNow;

  final AppDatabase _db;
  final EpgRepository _guide;
  final SourceRepository _sources;
  final AppLog _log;

  /// Rematches a source after its swap; none in tests that don't care.
  final EpgMatchService? _matches;
  final DateTime Function() _clock;

  /// An import still going after this is killed and fails with a
  /// `TimeoutFailure`. A stalled body is caught far sooner by the
  /// reader's idle watchdog; this is the backstop.
  final Duration timeout;

  /// Staged rows per batch write.
  final int batchSize;

  /// The retention window around now (ADR-011 decision 4): a programme
  /// is kept when it overlaps it. The days ahead become a setting in
  /// Settings → Guide.
  final Duration keepBehind;
  final Duration keepAhead;

  /// How long the guide's server may go silent.
  final Duration idleTimeout;

  static const _tag = 'epg';

  final _running = <String, _Import>{};
  final _progress = StreamController<(String, EpgImportProgress)>.broadcast();
  var _disposed = false;

  /// Every running import's progress, by source id.
  Stream<(String, EpgImportProgress)> get progress => _progress.stream;

  bool isImporting(String sourceId) => _running.containsKey(sourceId);

  /// Imports [sourceId]'s guide and returns what the swap put in place.
  /// Asking again while an import for the source runs joins it.
  Future<Result<EpgImportCounts>> importGuide(String sourceId) {
    if (_disposed) {
      return Future.value(Err(CancelledFailure('the app is closing')));
    }
    final running = _running[sourceId];
    if (running != null) return running.result.future;

    final run = _running[sourceId] = _Import();
    unawaited(
      _import(sourceId, run)
          .catchError(
            // _import guards every step; this is the last line of defence.
            (Object error) => Err<EpgImportCounts>(AppFailure.fromError(error)),
          )
          .then((result) {
            _running.remove(sourceId);
            run.result.complete(result);
          }),
    );
    return run.result.future;
  }

  /// Stops [sourceId]'s import, if one runs, and waits until it has been
  /// recorded. A cancelled import leaves the live guide untouched; one
  /// already swapping in finishes.
  Future<void> cancel(String sourceId) async {
    final run = _running[sourceId];
    if (run == null) return;
    run.cancelled = true;
    run.job?.cancel();
    await run.result.future;
  }

  /// Cancels every import; for when the app closes.
  Future<void> dispose() async {
    _disposed = true;
    await Future.wait([for (final id in _running.keys.toList()) cancel(id)]);
    await _progress.close();
  }

  Future<Result<EpgImportCounts>> _import(String sourceId, _Import run) async {
    final clock = Stopwatch()..start();
    final Source source;
    switch (await _sources.byId(sourceId)) {
      case Ok(value: final found?):
        source = found;
      case Ok():
        return Err(NotFoundFailure('source $sourceId'));
      case Err(:final failure):
        return Err(failure);
    }
    final GuideLocation location;
    switch (await _sources.credentialsFor(sourceId)) {
      case Ok(:final value):
        switch (resolveGuideLocation(source.type, value)) {
          case Ok(:final value):
            location = value;
          case Err(:final failure):
            return Err(failure);
        }
      case Err(:final failure):
        return Err(failure);
    }
    if (run.cancelled) return Err(CancelledFailure('guide $sourceId'));

    final int importRun;
    switch (await _guide.startImport(sourceId)) {
      case Ok(:final value):
        importRun = value;
      case Err(:final failure):
        return Err(failure);
    }
    _log.info(
      _tag,
      'Guide import $sourceId started (import $importRun, from the '
      '${_from(location)}, offset ${source.epgOffsetMinutes} min)',
    );

    final outcome = await _work(source, location, importRun, run);
    final finished = switch (outcome) {
      Ok(:final value) => await _commit(sourceId, importRun, value, clock),
      Err(:final failure) => Err<EpgImportCounts>(failure),
    };
    if (finished case Err(:final failure)) {
      // The isolate already keeps the URL out of what it returns; this
      // covers what went wrong on this side of it.
      final clean = location.isFile
          ? failure
          : failureWithoutUrl(failure, location.value);
      await _abandon(sourceId, importRun, clean, run.last, clock.elapsed);
      return Err(clean);
    }
    await _rematch(sourceId);
    return finished;
  }

  /// Attaches the source's channels to the guide just swapped in. The
  /// service logs how it went; a failure costs the matches, never the
  /// import.
  Future<void> _rematch(String sourceId) async {
    final matches = _matches;
    if (matches == null) return;
    final matched = await matches.rematch(sourceId);
    if (matched case Err(:final failure) when failure is! CancelledFailure) {
      _log.warning(
        _tag,
        'Guide import $sourceId: the guide is in, but its channels were not '
        'matched to it (${failure.code})',
      );
    }
  }

  /// The isolate, from start to its result. Every failure comes back as a
  /// result.
  Future<Result<EpgImportWorkResult>> _work(
    Source source,
    GuideLocation location,
    int importRun,
    _Import run,
  ) async {
    if (run.cancelled) return Err(CancelledFailure('guide ${source.id}'));
    final window = XmltvWindow.around(
      _clock(),
      behind: keepBehind,
      ahead: keepAhead,
    );
    final job = startEpgImportJob(
      EpgImportWork(
        sourceId: source.id,
        importRun: importRun,
        connection: await _db.serializableConnection(),
        input: location.input(userAgent: source.userAgent),
        windowStartMs: window.startMs,
        windowEndMs: window.endMs,
        offsetMinutes: source.epgOffsetMinutes,
        batchSize: batchSize,
        idleTimeout: idleTimeout,
      ),
      timeout: timeout,
    );
    run.job = job;
    // A cancel that landed while the connection was being set up.
    if (run.cancelled) job.cancel();
    final progress = job.progress.listen((event) {
      run.last = event;
      if (!_progress.isClosed) _progress.add((source.id, event));
    });
    final result = await job.result;
    await progress.cancel();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => Err(failure),
    };
  }

  /// The swap: the staged rows become the source's guide, in one
  /// transaction on this isolate.
  Future<Result<EpgImportCounts>> _commit(
    String sourceId,
    int importRun,
    EpgImportWorkResult work,
    Stopwatch clock,
  ) async {
    final committed = await _guide.commitImport(
      sourceId: sourceId,
      importRun: importRun,
      counts: EpgImportCounts(skipped: work.skipped, truncated: work.truncated),
    );
    if (committed case Ok(value: final counts)) {
      for (final warning in work.warnings) {
        _log.warning(_tag, 'Guide import $sourceId: $warning');
      }
      if (work.unknownEncoding) {
        _log.warning(
          _tag,
          'Guide import $sourceId: the guide declares the encoding '
          '"${work.declaredEncoding}", which is not one we know; read as '
          'UTF-8',
        );
      }
      if (work.truncated) {
        _log.warning(
          _tag,
          'Guide import $sourceId: the guide ended mid-file; kept what was '
          'read',
        );
      }
      _log.info(
        _tag,
        'Guide import $sourceId succeeded in '
        '${clock.elapsed.inMilliseconds} ms: ${counts.channels} channels, '
        '${counts.programmes} programmes, ${work.outsideWindow} outside the '
        'window; ${_skipped(counts.skipped)}',
      );
    }
    return committed;
  }

  /// Records the import as failed or cancelled, with what it had staged,
  /// and drops its staged rows now rather than at the next launch. The
  /// sweep leaves running imports alone, so another source's import is
  /// safe; a batch the killed isolate still had in flight lands after it
  /// and goes at the next launch (`recoverInterrupted`).
  Future<void> _abandon(
    String sourceId,
    int importRun,
    AppFailure failure,
    EpgImportProgress? last,
    Duration elapsed,
  ) async {
    final cancelled = failure is CancelledFailure;
    final recorded = await _guide.abandonImport(
      importRun,
      outcome: cancelled
          ? GuideImportOutcome.cancelled
          : GuideImportOutcome.failed,
      failure: cancelled ? null : failure,
      counts: EpgImportCounts(
        channels: last?.channels ?? 0,
        programmes: last?.programmes ?? 0,
      ),
    );
    if (recorded case Err(failure: final problem)) {
      _log.error(
        _tag,
        'Could not record the end of guide import $importRun: $problem',
      );
    }
    try {
      await _db.epgDao.sweepStaging();
    } on Object catch (error) {
      // Swept again at the next launch.
      _log.warning(_tag, 'Could not drop the staged guide rows: $error');
    }
    // `failure` is already redacted, and has no URL in it.
    if (cancelled) {
      _log.info(_tag, 'Guide import $sourceId cancelled');
    } else {
      _log.warning(
        _tag,
        'Guide import $sourceId failed after ${elapsed.inMilliseconds} ms: '
        '$failure',
      );
    }
  }

  static String _from(GuideLocation location) {
    final from = switch (location.kind) {
      GuideLocationKind.override => "source's EPG URL",
      GuideLocationKind.panel => 'panel',
      GuideLocationKind.playlist => "playlist's EPG URL",
    };
    return location.isFile ? '$from (a file)' : from;
  }

  static String _skipped(Map<String, int> skipped) {
    if (skipped.isEmpty) return 'nothing skipped';
    final total = skipped.values.fold(0, (sum, n) => sum + n);
    final reasons =
        (skipped.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => '${e.key} ${e.value}')
            .join(', ');
    return '$total skipped ($reasons)';
  }
}

final class _Import {
  final Completer<Result<EpgImportCounts>> result = Completer();
  BackgroundJob<EpgImportProgress, Result<EpgImportWorkResult>>? job;
  EpgImportProgress? last;
  bool cancelled = false;
}

DateTime _utcNow() => DateTime.now().toUtc();
