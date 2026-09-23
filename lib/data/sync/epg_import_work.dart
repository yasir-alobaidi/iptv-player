import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/job_database.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_reader.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';

/// Everything the guide import isolate needs, as plain sendable values:
/// the database travels as a [DriftIsolate] to connect to, the guide as
/// the real URL or a file path. It lives only as long as the import.
final class EpgImportWork {
  const new({
    required this.sourceId,
    required this.importRun,
    required this.connection,
    required this.input,
    required this.windowStartMs,
    required this.windowEndMs,
    this.offsetMinutes = 0,
    this.batchSize = 5000,
    this.idleTimeout = const Duration(seconds: 60),
  });

  final String sourceId;

  /// The import the staged rows carry (`EpgRepository.startImport`).
  final int importRun;
  final DriftIsolate connection;

  /// The guide, credentials and all when it is a URL.
  final XmltvInput input;

  /// The retention window, epoch ms UTC: programmes outside it are never
  /// staged (ADR-011 decision 4).
  final int windowStartMs;
  final int windowEndMs;

  /// The source's EPG offset (`sources.epg_offset_minutes`), applied to
  /// every time the guide gives.
  final int offsetMinutes;

  /// Rows per staged batch. The parser waits for each write, so this is
  /// also what the import holds in memory.
  final int batchSize;

  /// A body silent this long between bytes has stalled.
  final Duration idleTimeout;

  @override
  String toString() => 'EpgImportWork($sourceId, import $importRun, $input)';
}

/// What the isolate hands back for the importer to finish the import
/// with. Counts only, and warnings that hold no URL and no credential.
final class EpgImportWorkResult {
  const new({
    required this.channels,
    required this.programmes,
    this.outsideWindow = 0,
    this.skipped = const {},
    this.truncated = false,
    this.declaredEncoding,
    this.unknownEncoding = false,
    this.warnings = const [],
  });

  /// Rows staged.
  final int channels;
  final int programmes;

  /// Well-formed programmes left out by the retention window.
  final int outsideWindow;

  /// Rows the parser left out, by `XmltvSkip` code.
  final Map<String, int> skipped;

  /// The guide stopped mid-element: what came before is staged.
  final bool truncated;

  final String? declaredEncoding;

  /// [declaredEncoding] named an encoding the parser doesn't know, so the
  /// guide was read as UTF-8.
  final bool unknownEncoding;

  /// For the importer to log; the isolate has no log of its own. The
  /// parser's examples of skipped rows. Never holds a URL or a credential.
  final List<String> warnings;
}

/// Starts [work] in a new isolate. Top level, so the closure sent to the
/// isolate captures [work] and nothing else. Guarded: cancel and the
/// timeout never kill it inside a batch (`startGuardedJob`).
BackgroundJob<EpgImportProgress, Result<EpgImportWorkResult>> startEpgImportJob(
  EpgImportWork work, {
  Duration? timeout,
}) => startGuardedJob<EpgImportProgress, Result<EpgImportWorkResult>>(
  (report, cancellation) =>
      runEpgImportWork(work, report, cancellation: cancellation),
  timeout: timeout,
  debugName: 'epg-import',
);

/// The guide import isolate's body: connects to the app's database, opens
/// the guide, parses it, and stages what it reads in batches, reporting
/// progress as it goes.
///
/// **Every write is a single batch, never a longer transaction.** The
/// importer stops this isolate at any moment (cancel, timeout), and a
/// killed isolate's open transaction blocks the database for everyone
/// (hard rule 2, the Phase 2 spike). A batch is a transaction too, which
/// [openJobDatabase] marks on [cancellation], so the isolate is only ever
/// killed between batches. The live guide is never touched here: the swap
/// happens on the importer's side, in one transaction, once this returns.
///
/// Never throws, and nothing it returns carries the guide's URL
/// ([failureWithoutUrl]).
Future<Result<EpgImportWorkResult>> runEpgImportWork(
  EpgImportWork work,
  void Function(EpgImportProgress progress) report, {
  JobCancellation? cancellation,
}) async {
  final result = await _run(work, report, cancellation);
  final url = switch (work.input) {
    XmltvUrlInput(:final url) => url,
    XmltvFileInput() => null,
  };
  if (url == null) return result;
  return switch (result) {
    Ok(:final value) => Ok(
      EpgImportWorkResult(
        channels: value.channels,
        programmes: value.programmes,
        outsideWindow: value.outsideWindow,
        skipped: value.skipped,
        truncated: value.truncated,
        declaredEncoding: value.declaredEncoding,
        unknownEncoding: value.unknownEncoding,
        warnings: [for (final line in value.warnings) hideUrl(line, url)],
      ),
    ),
    Err(:final failure) => Err(failureWithoutUrl(failure, url)),
  };
}

Future<Result<EpgImportWorkResult>> _run(
  EpgImportWork work,
  void Function(EpgImportProgress progress) report,
  JobCancellation? cancellation,
) async {
  AppDatabase? db;
  XmltvBody? body;
  _Stager? stager;
  try {
    db = await openJobDatabase(work.connection, cancellation);
    final opened = await openXmltv(work.input, idleTimeout: work.idleTimeout);
    switch (opened) {
      case Ok(:final value):
        body = value;
      case Err(:final failure):
        return Err(failure);
    }
    final staging = stager = _Stager(db, work, body, report);
    final summary = await parseXmltv(
      body.bytes,
      onChannel: staging.channel,
      onProgramme: staging.programme,
      window: XmltvWindow(startMs: work.windowStartMs, endMs: work.windowEndMs),
      offsetMinutes: work.offsetMinutes,
    );
    await staging.flush();

    if (staging.programmes == 0) {
      // Nothing to show: a panel's empty answer, or a guide wholly outside
      // the window. The old guide stays rather than being swapped for this.
      return Err(
        ParseFailure(
          'the guide has no programmes to keep '
          '(${staging.channels} channels, '
          '${summary.outsideWindow} programmes outside the window, '
          '${summary.skippedTotal} skipped)',
        ),
      );
    }
    return Ok(
      EpgImportWorkResult(
        channels: staging.channels,
        programmes: staging.programmes,
        outsideWindow: summary.outsideWindow,
        skipped: summary.skipped,
        truncated: summary.truncated,
        declaredEncoding: summary.declaredEncoding,
        unknownEncoding: summary.unknownEncoding,
        warnings: summary.samples,
      ),
    );
  } on FormatException catch (error) {
    // The body is not XMLTV at all: an HTML error page, JSON, nothing.
    return Err(ParseFailure(error.message));
  } on Object catch (error) {
    return Err(epgWriteFailure(error));
  } finally {
    stager?.stop();
    body?.close();
    await db?.close();
  }
}

/// The reader and the parser return or throw what they mean; what else
/// is thrown during an import comes from writing to the database, or is a
/// broken body.
AppFailure epgWriteFailure(Object error) => switch (error) {
  DriftRemoteException() ||
  SqliteException() ||
  InvalidDataException() => StorageFailure('guide write: $error'),
  // dart:io's zlib filter reports a damaged gzip body this way.
  FileSystemException(:final message) when message.startsWith('Filter') =>
    ParseFailure('the guide is not valid gzip'),
  _ => AppFailure.fromError(error),
};

/// Collects rows into batches and writes each as one batch. A full batch
/// returns the write's future to the parser, which stops reading until it
/// completes: the import holds one batch, never the guide.
final class _Stager {
  new(this._db, this._work, this._body, this._report) {
    _ticker = Timer.periodic(_reportEvery, (_) => _progress());
  }

  /// Progress between batch writes, at most this often: bytes arrive far
  /// faster than a listener needs to hear about them.
  static const _reportEvery = Duration(milliseconds: 250);

  final AppDatabase _db;
  final EpgImportWork _work;
  final XmltvBody _body;
  final void Function(EpgImportProgress progress) _report;
  late final Timer _ticker;

  var _channelRows = <EpgChannelsStagingCompanion>[];
  var _programmeRows = <EpgProgramsStagingCompanion>[];
  EpgImportProgress? _last;

  /// Rows written so far.
  int channels = 0;
  int programmes = 0;

  FutureOr<void> channel(XmltvChannel channel) {
    _channelRows.add(
      EpgChannelsStagingCompanion.insert(
        importRun: _work.importRun,
        xmltvId: channel.id,
        displayName: Value(channel.displayName),
        iconUrl: Value(channel.iconUrl),
      ),
    );
    if (_channelRows.length >= _work.batchSize) return _writeChannels();
  }

  FutureOr<void> programme(XmltvProgramme programme) {
    _programmeRows.add(
      EpgProgramsStagingCompanion.insert(
        importRun: _work.importRun,
        epgChannelId: programme.channelId,
        startUtc: programme.startMs,
        endUtc: programme.endMs,
        title: programme.title,
        subtitle: Value(programme.subtitle),
        description: Value(programme.description),
        category: Value(programme.category),
      ),
    );
    if (_programmeRows.length >= _work.batchSize) return _writeProgrammes();
  }

  /// Writes what is left of both batches.
  Future<void> flush() async {
    if (_channelRows.isNotEmpty) await _writeChannels();
    if (_programmeRows.isNotEmpty) await _writeProgrammes();
    _progress();
  }

  void stop() => _ticker.cancel();

  Future<void> _writeChannels() async {
    final rows = _channelRows;
    _channelRows = [];
    await _db.epgDao.stageChannels(rows);
    channels += rows.length;
    _progress();
  }

  Future<void> _writeProgrammes() async {
    final rows = _programmeRows;
    _programmeRows = [];
    await _db.epgDao.stagePrograms(rows);
    programmes += rows.length;
    _progress();
  }

  /// Reports where the import is, unless nothing moved since last time.
  void _progress() {
    final now = EpgImportProgress(
      bytesRead: _body.bytesRead,
      totalBytes: _body.length,
      channels: channels,
      programmes: programmes,
    );
    if (now == _last) return;
    _last = now;
    _report(now);
  }
}
