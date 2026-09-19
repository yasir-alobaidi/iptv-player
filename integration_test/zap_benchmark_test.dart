// The zap benchmark (docs/03: p50 ≤ 1.5 s, p95 ≤ 3 s on the fake
// provider): 50 zaps between two H.264 channels on the real player and
// coordinator, the source limited to one connection, so every zap closes
// the old stream before opening the new one. Each is timed from the key
// press: the 350 ms debounce, the close, the open, the first frame.
//
// Timings on a shared CI runner are noise, so this runs only when asked:
//   IPTV_BENCHMARK=1 flutter test integration_test/zap_benchmark_test.dart -d linux
// It writes build/benchmarks/zap.txt as well.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/db_playback_history.dart';
import 'package:iptv_player/features/playback/data/db_stream_resolver.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

const _zaps = 50;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final asked = Platform.environment['IPTV_BENCHMARK'] == '1';
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'benchmark: zapping on a one-connection source',
    (tester) async {
      HttpOverrides.global = null;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      final panel = (await tester.runAsync(
        () => FakePanel.start(streams: true),
      ))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final db = AppDatabase.memory();
      final secrets = SecretRegistry();
      final log = AppLog(output: SilentOutput(), secrets: secrets);
      final sources = DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: secrets,
        log: log,
      );
      final engine = (await tester.runAsync(
        () => MediaKitPlayerEngine.create(
          log: log,
          secrets: secrets,
          video: video,
        ),
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
        }),
      );
      final sourceId = (await tester.runAsync(
        () => sources.add(
          SourceDraft(
            type: SourceType.xtream,
            name: 'Fake',
            url: panel.url,
            username: 'test',
            password: 'test',
            maxConnectionsOverride: 1,
          ),
        ),
      ))!.valueOrNull!.id;
      await tester.runAsync(
        () => db.channelsDao.upsertAll([
          // Channels 1 and 2: h264_1080p50_aac and h264_1080p25_ac3.
          for (final key in ['1', '2'])
            ChannelsCompanion.insert(
              sourceId: sourceId,
              remoteKey: key,
              name: 'Channel $key',
            ),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: engine.videoView(background: const Color(0xFF000000)),
        ),
      );
      final both = [
        for (final key in ['1', '2'])
          (await tester.runAsync(() => channels.byRemoteKey(sourceId, key)))!
              .valueOrNull!,
      ];

      Future<Duration> zap(ChannelItem channel) async {
        final watch = Stopwatch()..start();
        // The key press: the banner at once, the stream after the debounce.
        await tester.runAsync(
          () => Future<void>.delayed(PlayerScreen.zapDebounce),
        );
        await tester.runAsync(() => coordinator.playLive(channel));
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (DateTime.now().isBefore(deadline)) {
          if (coordinator.state is PlaybackPlaying) return watch.elapsed;
          if (coordinator.state is PlaybackFailed) {
            fail('zap failed: ${coordinator.state}');
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump();
        }
        fail('no picture within 20 s');
      }

      // Warm up (the fake panel remuxes each sample once).
      await zap(both[0]);
      await zap(both[1]);
      final times = <Duration>[];
      for (var i = 0; i < _zaps; i++) {
        times.add(await zap(both[i.isEven ? 0 : 1]));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
      }
      final sorted = [...times]..sort();
      Duration pct(double p) => sorted[((sorted.length - 1) * p).round()];
      final p50 = pct(0.5);
      final p95 = pct(0.95);
      final line =
          'zap on a one-connection source, $_zaps zaps, video '
          '${video ? 'on' : 'off'}: p50 ${p50.inMilliseconds} ms, p95 '
          '${p95.inMilliseconds} ms, worst ${sorted.last.inMilliseconds} ms '
          '(includes the ${PlayerScreen.zapDebounce.inMilliseconds} ms '
          'debounce)';
      // The measurement is this test's output.
      // ignore: avoid_print
      print(line);
      await tester.runAsync(() async {
        final dir = Directory('build/benchmarks')..createSync(recursive: true);
        await File('${dir.path}/zap.txt').writeAsString('$line\n');
      });
      expect(p50, lessThanOrEqualTo(const Duration(milliseconds: 1500)));
      expect(p95, lessThanOrEqualTo(const Duration(seconds: 3)));
    },
    skip: !asked || !streamsAvailable,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
