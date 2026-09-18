import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/m3u/m3u_models.dart';
import 'package:iptv_player/data/providers/m3u/m3u_reader.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';
import 'package:iptv_player/data/sync/xtream_sync.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_check.dart';
import 'package:iptv_player/features/sources/domain/source_form.dart';

/// [SourceChecker] over the real clients.
///
/// An Xtream panel is asked for the account once, without retries: the
/// user is watching. A playlist is read in a background isolate until the
/// first [previewEntries] entries arrive, or to its end if it is smaller,
/// and never for longer than [timeout].
final class ProviderSourceChecker implements SourceChecker {
  new({this.timeout = const Duration(seconds: 30), this.previewEntries = 500});

  final Duration timeout;
  final int previewEntries;

  @override
  Future<Result<SourceCheck>> check(SourceDraft draft) async {
    // The name is the form's to fill in; everything else must be there.
    final problems = validateDraft(draft, requirePassword: true)
      ..remove(DraftField.name);
    if (problems.isNotEmpty) {
      return Err(InvalidInputFailure(problems.keys.first.name));
    }
    return switch (draft.type) {
      SourceType.xtream => await _xtream(draft),
      SourceType.m3uUrl => await _playlist(
        M3uUrlInput(draft.url.trim(), userAgent: _blankToNull(draft.userAgent)),
        where: Uri.parse(draft.url.trim()).host,
      ),
      SourceType.m3uFile => await _file(draft.url.trim()),
    };
  }

  Future<Result<SourceCheck>> _xtream(SourceDraft draft) async {
    final server = normalizeServerUrl(draft.url)!;
    final client = XtreamClient(
      server: server,
      username: draft.username!.trim(),
      password: draft.password!.trim(),
      userAgent: _blankToNull(draft.userAgent),
      idleTimeout: const Duration(seconds: 15),
    );
    final clock = Stopwatch()..start();
    try {
      final signedIn = await client
          .account(retry: false)
          .timeout(
            timeout,
            onTimeout: () {
              client.cancelAll();
              return Err(TimeoutFailure('account check'));
            },
          );
      return switch (signedIn) {
        Ok(:final value) => Ok(
          SourceCheck(
            where: Uri.parse(server).host,
            responseTime: clock.elapsed,
            account: value.toProviderAccount(),
          ),
        ),
        Err(:final failure) => Err(failure),
      };
    } finally {
      client.close();
    }
  }

  Future<Result<SourceCheck>> _file(String path) async {
    final file = File(path);
    final int bytes;
    try {
      bytes = await file.length();
    } on FileSystemException {
      return Err(NotFoundFailure('playlist file'));
    }
    final checked = await _playlist(
      M3uFileInput(path),
      where: file.uri.pathSegments.lastWhere(
        (segment) => segment.isNotEmpty,
        orElse: () => path,
      ),
    );
    return switch (checked) {
      Ok(:final value) => Ok(
        value.copyWith(playlist: value.playlist?.copyWith(bytes: bytes)),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  /// Reads until the first batch of entries or the end, whichever comes
  /// first. A playlist whose start holds no entry at all is read on, in
  /// the background isolate, until one turns up or it ends.
  Future<Result<SourceCheck>> _playlist(
    M3uInput input, {
    required String where,
  }) async {
    final clock = Stopwatch()..start();
    final read = readM3uInBackground(
      input,
      batchSize: previewEntries,
      idleTimeout: const Duration(seconds: 15),
    );
    final first = Completer<List<M3uEntry>>();
    final batches = read.batches.listen((batch) {
      // A short batch is the playlist's last: its result follows, whole.
      if (batch.length >= previewEntries && !first.isCompleted) {
        first.complete(batch);
      }
    });
    final timer = Timer(timeout, read.cancel);
    try {
      final outcome = await Future.any<Object>([first.future, read.result]);
      final elapsed = clock.elapsed;
      switch (outcome) {
        case final List<M3uEntry> batch:
          // A big playlist: its start is enough.
          read.cancel();
          return Ok(
            SourceCheck(
              where: where,
              responseTime: elapsed,
              playlist: _preview(batch),
            ),
          );
        case Ok<M3uSummary>(:final value):
          return Ok(
            SourceCheck(
              where: where,
              responseTime: elapsed,
              playlist: PlaylistPreview(
                complete: true,
                entries: value.entries,
                live: value.live,
                movies: value.movies,
                episodes: value.episodes,
              ),
            ),
          );
        case Err<M3uSummary>(failure: CancelledFailure()):
          return Err(TimeoutFailure('playlist check'));
        case Err<M3uSummary>(:final failure):
          return Err(failure);
        default:
          return Err(UnexpectedFailure('playlist check: $outcome'));
      }
    } finally {
      timer.cancel();
      await batches.cancel();
    }
  }

  static PlaylistPreview _preview(List<M3uEntry> batch) {
    var live = 0;
    var movies = 0;
    var episodes = 0;
    for (final entry in batch) {
      switch (entry.kind) {
        case M3uKind.live:
          live++;
        case M3uKind.movie:
          movies++;
        case M3uKind.episode:
          episodes++;
      }
    }
    return PlaylistPreview(
      complete: false,
      entries: batch.length,
      live: live,
      movies: movies,
      episodes: episodes,
    );
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
