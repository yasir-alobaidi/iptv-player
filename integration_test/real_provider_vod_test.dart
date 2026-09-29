// Phase 5's look at the user's real VOD (plan step 8): opt-in, local
// only, and only after the user freed the account's one connection and
// said so. Skipped unless the login file also says "play": true
// (support/real_provider.dart).
//
// It syncs the provider into a throwaway database, then for the newest
// movie and the first episode of the newest series: asks for two small
// byte ranges (does it honour Range? what container is it?), plays it on
// the real player (codecs, picture, time to the first frame), seeks to the
// middle and back — each seek is a new request while the old one closes,
// so this shows whether a one-connection panel lets it in — and stops,
// checking the connection is let go. Findings, masked, in
// build/real_provider_run/vod_report.md.
//
// Run: flutter test integration_test/real_provider_vod_test.dart -d linux

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/playback/data/db_playback_history.dart';
import 'package:iptv_player/features/playback/data/db_stream_resolver.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/vod/data/db_movie_repository.dart';
import 'package:iptv_player/features/vod/data/db_series_repository.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/data/title_details_source.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:logger/logger.dart';

import 'support/real_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final login = readPlayLogin();

  testWidgets(
    'plays a movie and an episode from the real provider, seeks, and lets '
    'go of its connection',
    (tester) async {
      HttpOverrides.global = null;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      final (server, username, password) = login!;
      final lines = <String>[
        '# Real provider VOD — ${DateTime.now().toIso8601String()}',
        '',
      ];
      String scrub(String text) => redact(text, secrets: [password, username]);
      void note(String text) => lines.add(scrub(text));
      Future<void> write() =>
          File('build/real_provider_run/vod_report.md')
              .writeAsString('${lines.join('\n')}\n');
      Future<void> wait(int ms) => tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );

      Directory('build/real_provider_run').createSync(recursive: true);
      final db = AppDatabase.memory();
      final secrets = SecretRegistry()
        ..add(password)
        ..add(username);
      final log = AppLog(
        output: LogFileOutput(File('build/real_provider_run/vod_app.log')),
        secrets: secrets,
        level: Level.debug,
      );
      final sources = DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: secrets,
        log: log,
      );
      final engine = (await tester.runAsync(
        () => MediaKitPlayerEngine.create(log: log, secrets: secrets),
      ))!;
      final resolver = DbStreamResolver(db, sources);
      final coordinator = PlaybackCoordinator(
        engine: engine,
        resolver: resolver,
        prober: HttpStreamProber(sources),
        history: DbPlaybackHistory(db),
        channels: DbChannelRepository(db),
        progress: DbWatchProgress(db),
        log: log,
      );
      final details = XtreamTitleDetails(sources);
      final movies = DbMovieRepository(db, details);
      final series = DbSeriesRepository(db, details);
      addTearDown(
        () => tester.runAsync(() async {
          await coordinator.stop();
          await coordinator.dispose();
          await engine.dispose();
          await db.close();
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: engine.videoView(background: const Color(0xFF000000)),
        ),
      );
      final account = XtreamClient(
        server: server,
        username: username,
        password: password,
      );
      Future<String> connections() async {
        final info = (await tester.runAsync(account.account))!.valueOrNull;
        return '${info?.activeConnections ?? '?'} of '
            '${info?.maxConnections ?? '?'}';
      }

      /// Two small ranges of [url], one connection at a time: the start
      /// (the container's first bytes) and the middle.
      Future<void> probe(String url) async {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 15);
        try {
          for (final (label, range) in [
            ('the first 4 KB', 'bytes=0-4095'),
            ('4 KB from the middle', null),
          ]) {
            var asked = range;
            if (asked == null) {
              final length = await _lengthOf(client, url);
              if (length == null) {
                note('  - $label: no length to find the middle by');
                continue;
              }
              asked = 'bytes=${length ~/ 2}-${length ~/ 2 + 4095}';
            }
            final request = await client.getUrl(Uri.parse(url));
            request.headers.set(HttpHeaders.rangeHeader, asked);
            final response = await request.close();
            final head = <int>[];
            await for (final chunk in response) {
              head.addAll(chunk);
              if (head.length >= 4096) break;
            }
            final h = response.headers;
            final status = response.statusCode;
            final contentRange = h.value(HttpHeaders.contentRangeHeader);
            final acceptRanges = h.value(HttpHeaders.acceptRangesHeader);
            final start = range == null
                ? ''
                : ', starts like ${_container(head)}';
            note(
              '  - $label: $status${status == 206 ? ' (honoured)' : ''}, '
              'Content-Range ${contentRange ?? '—'}, '
              'Accept-Ranges ${acceptRanges ?? '—'}, '
              'type ${h.contentType?.mimeType ?? '—'}$start',
            );
            // Let the connection go before the next one.
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        } finally {
          client.close(force: true);
        }
      }

      Future<(PlaybackState, Duration)> until(
        bool Function(PlaybackState state) done, {
        int seconds = 60,
      }) async {
        final watch = Stopwatch()..start();
        final deadline = DateTime.now().add(Duration(seconds: seconds));
        while (DateTime.now().isBefore(deadline)) {
          final state = coordinator.state;
          if (done(state) || state is PlaybackFailed) {
            return (state, watch.elapsed);
          }
          await wait(100);
          await tester.pump();
        }
        return (coordinator.state, watch.elapsed);
      }

      String outcome(PlaybackState state) => switch (state) {
        PlaybackPlaying() => 'playing',
        PlaybackFailed(:final problem) =>
          'failed: ${problem.kind.name} ${problem.failure ?? ''} '
              '${problem.detail ?? ''}',
        _ => '${state.runtimeType}',
      };

      /// Plays [item], seeks to the middle and back, stops.
      Future<bool> watch(String what, Playable item, String url) async {
        note('\n## $what\n');
        note('- **Its address ends** `…${url.substring(url.length - 12)}`');
        note('- **Range** (connections before: ${await connections()}):');
        await tester.runAsync(() => probe(url));
        await wait(3000);

        final watch = Stopwatch()..start();
        final trail = coordinator.states.listen((state) {
          if (state is PlaybackReconnecting || state is PlaybackFailed) {
            note('  - ${watch.elapsedMilliseconds} ms: ${outcome(state)}');
          }
        });
        try {
          await tester.runAsync(() => coordinator.playVod(item));
          final (opened, first) = await until((s) => s is PlaybackPlaying);
          note(
            '- **Play:** ${outcome(opened)} after ${first.inMilliseconds} ms',
          );
          if (opened is! PlaybackPlaying) return false;
          await wait(10000);
          final info = (await tester.runAsync(engine.streamInfo))!;
          final length = coordinator.timeline.duration;
          note(
            '- **Stream:** ${info.width}×${info.height}, ${info.videoCodec}, '
            '${info.hardwareDecoder ?? 'software'} decoding; audio '
            '${info.audioCodec} ${info.audioChannels ?? '?'} ch; length '
            '${length ?? 'unknown'}; while playing: ${await connections()} '
            'connections',
          );
          for (final (label, fraction) in [('the middle', .5), ('10 %', .1)]) {
            if (length == null) break;
            final target = length * fraction;
            final seek = Stopwatch()..start();
            await tester.runAsync(() => coordinator.seek(target));
            // The coordinator takes the new position at once; the player
            // playing 2 s past it is the seek done.
            const past = Duration(seconds: 2);
            final (after, _) = await until(
              (s) =>
                  s is PlaybackPlaying &&
                  coordinator.timeline.position >= target + past &&
                  coordinator.timeline.position <
                      target + const Duration(seconds: 20),
              seconds: 40,
            );
            note(
              '- **Seek to $label:** ${outcome(after)}, 2 s past it '
              '${seek.elapsedMilliseconds} ms after the seek (at '
              '${coordinator.timeline.position})',
            );
            await wait(8000);
          }
          return coordinator.state is PlaybackPlaying;
        } finally {
          await trail.cancel();
          await tester.runAsync(coordinator.stop);
          await wait(5000);
          note('- **5 s after stopping:** ${await connections()} connections');
        }
      }

      try {
        note('- **Before:** ${await connections()} connections in use');
        final sourceId = (await tester.runAsync(
          () => sources.add(
            SourceDraft(
              type: SourceType.xtream,
              name: 'Real provider',
              url: server,
              username: username,
              password: password,
            ),
          ),
        ))!.valueOrNull!.id;
        final synced = (await tester.runAsync(
          () => SyncEngine(
            database: db,
            sources: sources,
            log: log,
          ).sync(sourceId),
        ))!;
        note('- **Sync:** ${synced.isOk ? 'done' : '${synced.failureOrNull}'}');
        final query = TitleQuery(sourceId: sourceId);

        final movie = (await tester.runAsync(() => movies.range(query, 0, 1)))!
            .valueOrNull!
            .first;
        final movieUrl = (await tester.runAsync(() => resolver.movie(movie)))!
            .valueOrNull!
            .url;
        final movieOk = await watch(
          'Movie: ${movie.name}',
          PlayableMovie(movie),
          movieUrl,
        );

        final show = (await tester.runAsync(() => series.range(query, 0, 1)))!
            .valueOrNull!
            .first;
        final fetched = (await tester.runAsync(
          () => series
              .details(show)
              .firstWhere((d) => d is! DetailsLoading<SeriesDetails>),
        ))!;
        if (fetched is! DetailsReady<SeriesDetails>) {
          note('\n**The series ${show.name} gave no episodes:** $fetched');
          await tester.runAsync(write);
          fail('no episodes');
        }
        final episode = fetched.value.seasons.first.episodes.first;
        final episodeUrl = (await tester.runAsync(
          () => resolver.episode(episode),
        ))!.valueOrNull!.url;
        final episodeOk = await watch(
          'Episode: ${show.name} S${episode.season} · E${episode.episode}',
          PlayableEpisode(show, episode),
          episodeUrl,
        );

        await tester.runAsync(write);
        expect(movieOk, isTrue, reason: 'the movie played through its seeks');
        expect(episodeOk, isTrue, reason: 'the episode did');
      } on TestFailure {
        rethrow;
      } on Object catch (error) {
        note('\n**Stopped:** $error');
        await tester.runAsync(write);
        fail(scrub('$error'));
      }
    },
    skip: login == null,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

/// The file's length from a HEAD, or from a one-byte range's
/// Content-Range when HEAD isn't answered.
Future<int?> _lengthOf(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
  final response = await request.close();
  await response.drain<void>().timeout(
    const Duration(seconds: 5),
    onTimeout: () {},
  );
  final range = response.headers.value(HttpHeaders.contentRangeHeader);
  final total = range?.split('/').lastOrNull;
  await Future<void>.delayed(const Duration(seconds: 2));
  return int.tryParse(total ?? '') ??
      (response.statusCode == 200 ? response.contentLength : null);
}

/// What the first bytes say the file is.
String _container(List<int> head) {
  bool at(int offset, List<int> bytes) =>
      head.length >= offset + bytes.length &&
      [for (var i = 0; i < bytes.length; i++) head[offset + i]].join(',') ==
          bytes.join(',');
  if (at(4, 'ftyp'.codeUnits)) return 'MP4 (ftyp)';
  if (at(0, [0x1A, 0x45, 0xDF, 0xA3])) return 'Matroska/WebM';
  if (at(0, [0x47]) && at(188, [0x47])) return 'MPEG-TS';
  if (at(0, 'RIFF'.codeUnits)) return 'AVI (RIFF)';
  if (at(0, '#EXTM3U'.codeUnits)) return 'an HLS playlist';
  return 'unknown (${head.take(8).map((b) => b.toRadixString(16)).join(' ')})';
}
