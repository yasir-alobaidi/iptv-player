import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/streams/idle_timeout.dart';
import 'package:iptv_player/data/providers/m3u/m3u_credentials.dart';
import 'package:iptv_player/data/providers/m3u/m3u_models.dart';
import 'package:iptv_player/data/providers/m3u/m3u_parser.dart';
import 'package:iptv_player/data/providers/provider_http.dart';

/// Where a playlist comes from. Plain values, so an input can be sent to
/// the isolate that reads it: the bytes never cross isolates.
sealed class M3uInput {
  const new();
}

final class M3uFileInput extends M3uInput {
  const new(this.path);

  final String path;
}

final class M3uUrlInput extends M3uInput {
  const new(this.url, {this.userAgent});

  /// The real playlist URL, credentials and all (from the secure store).
  final String url;
  final String? userAgent;
}

/// Reads and parses [input] in the calling isolate, handing each entry to
/// [onEntry]. The sync engine calls this inside its own isolate; the UI
/// uses [readM3uInBackground].
///
/// The credentials in a playlist URL's query become placeholders in every
/// stream URL (`playlistSecrets`, `templateUrl`). Never throws: a missing
/// file is `NotFoundFailure`, 401/403 `AuthFailure`, a body that isn't a
/// playlist `ParseFailure`, a server silent for [idleTimeout]
/// `TimeoutFailure`, and so on.
Future<Result<M3uSummary>> readM3u(
  M3uInput input,
  void Function(M3uEntry entry) onEntry, {
  Duration idleTimeout = const Duration(seconds: 30),
}) async {
  HttpClient? client;
  try {
    final Stream<List<int>> bytes;
    final Map<String, String> secrets;
    switch (input) {
      case M3uFileInput(:final path):
        final file = File(path);
        if (!file.existsSync()) {
          return Err(NotFoundFailure('playlist file does not exist'));
        }
        bytes = file.openRead();
        secrets = const {};
      case M3uUrlInput(:final url, :final userAgent):
        client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 15)
          ..userAgent = userAgent ?? defaultUserAgent;
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        final status = response.statusCode;
        if (status < 200 || status >= 300) {
          await response.drain<void>().catchError((_) {});
          return Err(switch (status) {
            401 || 403 => AuthFailure('playlist: HTTP $status'),
            404 => NotFoundFailure('playlist: HTTP 404'),
            _ => NetworkFailure('playlist: HTTP $status', status),
          });
        }
        bytes = response.idleTimeout(idleTimeout);
        secrets = playlistSecrets(url);
    }
    return Ok(await parseM3u(bytes, onEntry, secrets: secrets));
  } on FormatException catch (error) {
    return Err(ParseFailure(error.message));
  } on Object catch (error) {
    // Socket, TLS and HTTP errors quote the URL; AppFailure redacts it.
    return Err(AppFailure.fromError(error));
  } finally {
    client?.close(force: true);
  }
}

/// A playlist being read in a background isolate (hard rule 2): entries
/// arrive on [batches] a few thousand at a time, then [result] completes.
final class M3uBackgroundRead {
  new _(this._job);

  final BackgroundJob<List<M3uEntry>, Result<M3uSummary>> _job;

  Stream<List<M3uEntry>> get batches => _job.progress;

  Future<Result<M3uSummary>> get result async => switch (await _job.result) {
    Ok(:final value) => value,
    Err(:final failure) => Err(failure),
  };

  /// Stops reading; [result] completes with a `CancelledFailure`.
  void cancel() => _job.cancel();
}

/// Reads [input] in a new isolate, sending entries back in batches of
/// [batchSize] so the UI isolate only ever receives, never parses.
M3uBackgroundRead readM3uInBackground(
  M3uInput input, {
  int batchSize = 5000,
  Duration idleTimeout = const Duration(seconds: 30),
}) => M3uBackgroundRead._(
  startBackgroundJob<List<M3uEntry>, Result<M3uSummary>>(
    (report) => _readInBatches(input, report, batchSize, idleTimeout),
    debugName: 'm3u-read',
  ),
);

/// Top level, so the closure sent to the isolate captures only sendable
/// values.
Future<Result<M3uSummary>> _readInBatches(
  M3uInput input,
  void Function(List<M3uEntry>) report,
  int batchSize,
  Duration idleTimeout,
) async {
  var batch = <M3uEntry>[];
  final result = await readM3u(input, (entry) {
    batch.add(entry);
    if (batch.length >= batchSize) {
      report(batch);
      batch = <M3uEntry>[];
    }
  }, idleTimeout: idleTimeout);
  if (batch.isNotEmpty) report(batch);
  return result;
}
