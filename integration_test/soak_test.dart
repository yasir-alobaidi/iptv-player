// The soak (docs/06, Phase 3 exit: 1 hour; 8 hours before a release):
// the real player and coordinator play the fake provider's live channels
// for IPTV_SOAK_MINUTES, and every [_actionEvery] something happens — a
// zap, or a fault (drop, stall, a 500, a codec switch) that is cleared
// once the watchdog has reacted. Once a minute the memory, the CPU and the
// playback state go to build/soak/soak.csv.
//
// It passes when every fault recovered (the picture back within a
// minute), nothing crashed, and memory stopped growing: the last five
// minutes' RSS within [_growthBudget] of the five after [_warmUpMinutes].
//
// Warm-up is 20 minutes, not 5: the player settles for about 40 minutes
// (a debug build, three codecs, the video output) and then holds flat, so
// a baseline at minute 5 reads the ramp as a leak — the 2026-09-19 hour
// grew 101 MB measured from minute 5 and 34 MB measured from minute 20,
// with the last two 10-minute medians flat (678, 674 MB). Medians, not
// averages: a reconnect spikes RSS by ~85 MB for a sample or two.
//
// Run with tools/soak/run.sh (on the real display, for real CPU numbers).
// Skipped unless IPTV_SOAK_MINUTES is set.

import 'dart:io';
import 'dart:math';

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
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

const _actionEvery = Duration(seconds: 90);
const _recoveryLimit = Duration(minutes: 1);
const _growthBudget = 50; // MB, docs/06 (8 h); held to over any run.

/// Memory is measured from after this many minutes (see the note above).
/// A run too short for it falls back to the first minutes it has.
const _warmUpMinutes = 20;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final minutes = int.tryParse(Platform.environment['IPTV_SOAK_MINUTES'] ?? '');
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'soak: live playback with faults for IPTV_SOAK_MINUTES',
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
      // H.264 1080p50, H.264 1080p25 AC-3, HEVC 1080p50.
      await tester.runAsync(
        () => db.channelsDao.upsertAll([
          for (final key in ['1', '2', '3'])
            ChannelsCompanion.insert(
              sourceId: sourceId,
              remoteKey: key,
              name: 'Channel $key',
            ),
        ]),
      );
      final lineup = <ChannelItem>[
        for (final key in ['1', '2', '3'])
          (await tester.runAsync(() => channels.byRemoteKey(sourceId, key)))!
              .valueOrNull!,
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: engine.videoView(background: const Color(0xFF000000)),
        ),
      );

      final csv = File('build/soak/soak.csv')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          'minute,rss_mb,cpu_pct_one_core,state,reconnects,failures,'
          'active_cons,last_action\n',
        );
      final random = Random(7);
      final rss = <int>[];
      var reconnects = 0;
      var failures = 0;
      var lastAction = 'start';
      DateTime? downSince;
      var worstDown = Duration.zero;
      final watching = coordinator.states.listen((state) {
        if (state is PlaybackReconnecting) reconnects++;
        if (state is PlaybackFailed) failures++;
      });
      addTearDown(watching.cancel);

      await tester.runAsync(() => coordinator.playLive(lineup[0]));
      final start = DateTime.now();
      final end = start.add(Duration(minutes: minutes!));
      var nextAction = start.add(_actionEvery);
      var nextSample = start.add(const Duration(minutes: 1));
      var clearFaultsAt = DateTime(0);
      var cpu = _cpuTicks();
      var cpuAt = DateTime.now();
      var minute = 0;

      while (DateTime.now().isBefore(end)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
        final now = DateTime.now();
        final state = coordinator.state;

        // How long playback has been without a picture.
        if (state is PlaybackPlaying) {
          downSince = null;
        } else {
          downSince ??= now;
          final down = now.difference(downSince);
          if (down > worstDown) worstDown = down;
          // A failure the watchdog gave up on: try again, as a user would.
          if (state is PlaybackFailed && down > const Duration(seconds: 5)) {
            await tester.runAsync(coordinator.retry);
          }
        }

        if (now.isAfter(clearFaultsAt) && clearFaultsAt.year > 2000) {
          await tester.runAsync(() => panel.setFaults(const {}));
          clearFaultsAt = DateTime(0);
        }

        if (now.isAfter(nextAction)) {
          nextAction = now.add(_actionEvery);
          final current = coordinator.current ?? lineup[0];
          switch (random.nextInt(5)) {
            case 0:
              final others = lineup.where((c) => c.id != current.id).toList();
              final next = others[random.nextInt(others.length)];
              lastAction = 'zap to ${next.remoteKey}';
              await tester.runAsync(() => coordinator.playLive(next));
            case 1:
              lastAction = 'drop';
              await tester.runAsync(
                () => panel.setFaults(const {'drop_after_s': 2}),
              );
              await tester.runAsync(coordinator.retry);
              clearFaultsAt = now.add(const Duration(seconds: 10));
            case 2:
              lastAction = 'stall';
              await tester.runAsync(
                () => panel.setFaults(const {'stall_after_s': 2}),
              );
              await tester.runAsync(coordinator.retry);
              clearFaultsAt = now.add(const Duration(seconds: 20));
            case 3:
              lastAction = 'server error';
              await tester.runAsync(
                () => panel.setFaults(const {'http_status': 500}),
              );
              await tester.runAsync(coordinator.retry);
              clearFaultsAt = now.add(const Duration(seconds: 5));
            default:
              lastAction = 'codec switch';
              await tester.runAsync(
                () => panel.setFaults(const {'codec_switch_after_s': 3}),
              );
              await tester.runAsync(coordinator.retry);
              clearFaultsAt = now.add(const Duration(seconds: 15));
          }
        }

        if (now.isAfter(nextSample)) {
          nextSample = nextSample.add(const Duration(minutes: 1));
          minute++;
          final mb = ProcessInfo.currentRss ~/ (1024 * 1024);
          rss.add(mb);
          final ticks = _cpuTicks();
          final seconds = now.difference(cpuAt).inMilliseconds / 1000;
          final pct = (ticks - cpu) / 100 / seconds * 100;
          cpu = ticks;
          cpuAt = now;
          final active = await tester.runAsync(panel.activeConnections);
          csv.writeAsStringSync(
            '$minute,$mb,${pct.toStringAsFixed(1)},'
            '${state.runtimeType},$reconnects,$failures,$active,'
            '"$lastAction"\n',
            mode: FileMode.append,
          );
        }
      }

      // The five minutes after warm-up, or the best a short run can do.
      final from = rss.length > _warmUpMinutes + 5
          ? _warmUpMinutes
          : (rss.length > 10 ? 5 : 0);
      final early = rss.length > from + 5 ? rss.sublist(from, from + 5) : rss;
      final late = rss.length > 5 ? rss.sublist(rss.length - 5) : rss;
      int median(List<int> xs) {
        if (xs.isEmpty) return 0;
        final sorted = [...xs]..sort();
        return sorted[sorted.length ~/ 2];
      }

      final growth = median(late) - median(early);
      final summary =
          'soak ${minutes}min video ${video ? 'on' : 'off'}: '
          '${rss.isEmpty ? '?' : rss.first}→${rss.isEmpty ? '?' : rss.last} MB '
          '(growth from minute ${from + 1}: $growth MB), '
          '$reconnects reconnects, '
          '$failures failures, longest without a picture '
          '${worstDown.inSeconds} s';
      File('build/soak/summary.txt').writeAsStringSync('$summary\n');
      // The summary is this test's output.
      // ignore: avoid_print
      print(summary);
      expect(
        worstDown,
        lessThan(_recoveryLimit),
        reason: 'every fault recovered',
      );
      expect(growth, lessThanOrEqualTo(_growthBudget));
    },
    skip: minutes == null || !streamsAvailable,
    timeout: Timeout(Duration(minutes: (minutes ?? 0) + 5)),
  );
}

/// This process's CPU time so far, in clock ticks (100 a second on
/// Linux): user + system from /proc/self/stat.
int _cpuTicks() {
  final stat = File('/proc/self/stat').readAsStringSync();
  // Fields after the command name, which is in parentheses.
  final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
  return int.parse(fields[11]) + int.parse(fields[12]);
}
