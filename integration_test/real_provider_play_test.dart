// Playing from the user's real provider (ADR-010 decision 1): opt-in,
// local only, and only after the user freed the account's one connection
// and said so. Skipped unless the login file
// (~/.config/iptv-player-dev/real_provider.json or $IPTV_REAL_PROVIDER)
// also says "play": true.
//
// It syncs the provider into a throwaway database, plays the first
// channel (by number) for 20 s, zaps to the second, stops, and checks the
// provider sees the connection let go. Findings, masked, in
// build/real_provider_run/play_report.md.
//
// Run: flutter test integration_test/real_provider_play_test.dart -d linux

import 'dart:convert';
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
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/db_playback_history.dart';
import 'package:iptv_player/features/playback/data/db_stream_resolver.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final login = _readLogin();

  testWidgets(
    'plays from the real provider and lets go of its connection',
    (tester) async {
      HttpOverrides.global = null;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      final (server, username, password) = login!;
      final lines = <String>[
        '# Real provider playback — ${DateTime.now().toIso8601String()}',
        '',
      ];
      String scrub(String text) => redact(text, secrets: [password, username]);
      void note(String text) => lines.add(scrub(text));
      Future<void> write() async {
        final dir = Directory('build/real_provider_run')
          ..createSync(recursive: true);
        await File('${dir.path}/play_report.md')
            .writeAsString('${lines.join('\n')}\n');
      }

      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('iptv_real_play'),
      ))!;
      final db = AppDatabase.memory();
      final secrets = SecretRegistry()
        ..add(password)
        ..add(username);
      Directory('build/real_provider_run').createSync(recursive: true);
      final log = AppLog(
        output: _FileOutput(File('build/real_provider_run/play_app.log')),
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
      final channels = DbChannelRepository(db);
      final coordinator = PlaybackCoordinator(
        engine: engine,
        resolver: DbStreamResolver(db, sources),
        prober: HttpStreamProber(sources),
        history: DbPlaybackHistory(db),
        channels: channels,
        log: log,
      );
      addTearDown(
        () => tester.runAsync(() async {
          await coordinator.stop();
          await coordinator.dispose();
          await engine.dispose();
          await db.close();
          await directory.delete(recursive: true);
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

      try {
        final before = (await tester.runAsync(account.account))!.valueOrNull;
        note(
          '- **Before:** ${before?.activeConnections ?? '?'} of '
          '${before?.maxConnections ?? '?'} connections in use',
        );

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
        final first = (await tester.runAsync(
          () => channels.range(ChannelQuery(sourceId: sourceId), 0, 2),
        ))!.valueOrNull!;

        Future<(PlaybackState, Duration)> play(ChannelItem channel) async {
          final watch = Stopwatch()..start();
          // Every state on the way, with its time, for the report.
          final trail = coordinator.states.listen((state) {
            final what = switch (state) {
              PlaybackReconnecting(:final attempt, :final problem) =>
                'reconnecting (attempt $attempt): ${problem.kind.name} '
                    '${problem.failure ?? ''}',
              PlaybackFailed(:final problem) =>
                'failed: ${problem.kind.name} ${problem.failure ?? ''}',
              _ => state.runtimeType.toString(),
            };
            note('  - ${watch.elapsedMilliseconds} ms: $what');
          });
          try {
            await tester.runAsync(() => coordinator.playLive(channel));
            final deadline = DateTime.now().add(const Duration(seconds: 40));
            while (DateTime.now().isBefore(deadline)) {
              final state = coordinator.state;
              if (state is PlaybackPlaying || state is PlaybackFailed) {
                return (state, watch.elapsed);
              }
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)),
              );
              await tester.pump();
            }
            return (coordinator.state, watch.elapsed);
          } finally {
            await trail.cancel();
          }
        }

        String outcome(PlaybackState state) => switch (state) {
          PlaybackPlaying() => 'playing',
          PlaybackFailed(:final problem) =>
            'failed: ${problem.kind.name} ${problem.failure ?? ''} '
                '${problem.detail ?? ''}',
          _ => '$state',
        };

        final (one, firstTime) = await play(first[0]);
        note(
          '- **Channel ${first[0].number} (${first[0].name}):** '
          '${outcome(one)} after ${firstTime.inMilliseconds} ms',
        );
        if (one is PlaybackPlaying) {
          final seen = <PlaybackState>[];
          final watching = coordinator.states.listen(seen.add);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 20)),
          );
          await watching.cancel();
          final info = (await tester.runAsync(engine.streamInfo))!;
          note(
            '- **20 s of playback:** '
            '${seen.whereType<PlaybackReconnecting>().length} reconnects; '
            '${info.width}×${info.height}, ${info.videoCodec}, '
            '${info.hardwareDecoder ?? 'software'} decoding, '
            '${info.droppedFrames ?? 0} dropped',
          );
        }

        // Back and forth, to tell a slow zap from a slow channel.
        final zaps = <(ChannelItem, PlaybackState, Duration)>[];
        for (final channel in [first[1], first[0], first[1]]) {
          final (state, time) = await play(channel);
          zaps.add((channel, state, time));
          note(
            '- **Zap to ${channel.number} (${channel.name}):** '
            '${outcome(state)} after ${time.inMilliseconds} ms',
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 3)),
          );
        }
        final two = zaps.first.$2;

        await tester.runAsync(coordinator.stop);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 5)),
        );
        final after = (await tester.runAsync(account.account))!.valueOrNull;
        note(
          '- **5 s after stopping:** ${after?.activeConnections ?? '?'} of '
          '${after?.maxConnections ?? '?'} connections in use',
        );
        await tester.runAsync(write);
        expect(one, isA<PlaybackPlaying>(), reason: outcome(one));
        expect(two, isA<PlaybackPlaying>(), reason: outcome(two));
        expect(
          after?.activeConnections ?? 0,
          lessThanOrEqualTo(before?.activeConnections ?? 0),
          reason: 'the connection was let go',
        );
      } on Object catch (error) {
        note('\n**Stopped:** $error');
        await tester.runAsync(write);
        fail(scrub('$error'));
      }
    },
    skip: login == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// (server, username, password) when the login file asks for playback.
(String, String, String)? _readLogin() {
  final home = Platform.environment['HOME'] ?? '';
  final file = File(
    Platform.environment['IPTV_REAL_PROVIDER'] ??
        '$home/.config/iptv-player-dev/real_provider.json',
  );
  if (!file.existsSync()) return null;
  final json = jsonDecode(file.readAsStringSync());
  if (json is! Map || json['play'] != true) return null;
  final server = '${json['server'] ?? ''}'.trim();
  final username = '${json['username'] ?? ''}'.trim();
  final password = '${json['password'] ?? ''}';
  if ([server, username, password].any((v) => v.isEmpty)) return null;
  return (server, username, password);
}

/// The app log, already masked by [AppLog], to a file.
final class _FileOutput extends LogOutput {
  new(this._file) {
    _file.writeAsStringSync('');
  }

  final File _file;

  @override
  void output(OutputEvent event) => _file.writeAsStringSync(
    '${event.lines.join('\n')}\n',
    mode: FileMode.append,
  );
}
