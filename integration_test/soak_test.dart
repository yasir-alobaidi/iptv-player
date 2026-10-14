// The soak (docs/06; Phase 3 exit: 1 hour; Phase 9 decision 15: the app as
// it is used now). The whole app is open on the fake panel — its database
// and guide, the player, casting with the relay and FFmpeg, the download
// queue — and plays a live channel full screen for IPTV_SOAK_MINUTES.
//
// Every [_actionEvery] something happens to playback: a zap, or a fault
// (drop, stall, a 500, a codec switch) that is cleared once the watchdog
// has reacted. And every IPTV_SOAK_ROUND_MINUTES (20) a round of the rest:
//
//   1. the channel is cast to the fake TV (tools/fake_receiver, which
//      fetches what it is sent as a TV does) for two minutes, then Stop
//      casting: no FFmpeg may be left;
//   2. with nothing playing (the source has one connection, and a
//      download yields to playback), a movie is downloaded from the panel
//      while the Guide and Movies are opened and scrolled and Search is
//      typed into; the file is checked and deleted again;
//   3. the channel plays again.
//
// Once a minute the memory, the CPU and what is going on go to
// build/soak/soak.csv.
//
// It passes when every fault recovered (the picture back within a
// minute), every round did all of its parts, nothing threw, and memory
// stopped growing: the last five minutes' RSS within [_growthBudget] of
// the five after [_warmUpMinutes] (a run too short to have both is a
// trial of the soak itself, and memory isn't judged). The first round
// comes before those (two fifths of the way to the second), so the
// relay, the downloads isolate and the picture cache have all run once
// before the baseline; no round starts that close to the end either, so
// both ends of the comparison are plain playback.
//
// Warm-up is 20 minutes, not 5: the player settles for about 40 minutes
// (a debug build, three codecs, the video output) and then holds flat, so
// a baseline at minute 5 reads the ramp as a leak — the 2026-09-19 hour
// grew 101 MB measured from minute 5 and 34 MB measured from minute 20,
// with the last two 10-minute medians flat (678, 674 MB). Medians, not
// averages: a reconnect spikes RSS by ~85 MB for a sample or two.
//
// Run with tools/soak/run.sh (on the real display, for real CPU numbers).
// Skipped unless IPTV_SOAK_MINUTES is set. Only the fake panel and the
// fake TV: nothing of a real provider, no real TV.

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/cast_shell_slots.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/presentation/download_actions.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/presentation/guide_grid.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart';

import 'support/cast_tv.dart';
import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

const _actionEvery = Duration(seconds: 90);
const _recoveryLimit = Duration(minutes: 1);
const _growthBudget = 50; // MB, docs/06 (8 h); held to over any run.

/// Memory is measured from after this many minutes (see the note above).
/// A run too short for it falls back to the first minutes it has.
const _warmUpMinutes = 20;

/// How long the TV plays in a round of the usual length, and in a trial's
/// shorter ones.
const _castFor = Duration(minutes: 2);
const _trialCastFor = Duration(seconds: 30);

/// What Search is asked in a round.
const _searchText = 'the';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final environment = Platform.environment;
  final minutes = int.tryParse(environment['IPTV_SOAK_MINUTES'] ?? '');
  final roundMinutes =
      int.tryParse(environment['IPTV_SOAK_ROUND_MINUTES'] ?? '') ?? 20;
  final video = environment['IPTV_PLAYER_VIDEO'] != '0';
  // A heap snapshot of every isolate before the first round and after
  // each, to build/soak/heap.txt: what a round leaves behind, by class.
  final heap = environment['IPTV_SOAK_HEAP'] == '1';
  final binaries = castBinaries();

  testWidgets(
    'soak: the app as it is used, with faults, for IPTV_SOAK_MINUTES',
    (tester) async {
      HttpOverrides.global = null;
      // The window as it is, not the walks' fixed 1440 × 900: with the
      // test window's size overridden Flutter never asks the player for
      // its picture (mpv drops every frame), and a soak of a player that
      // draws nothing proves little.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      final folder = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('iptv_soak'),
      ))!;
      addTearDown(() => tester.runAsync(() => folder.delete(recursive: true)));
      final panel = (await tester.runAsync(
        () => FakePanel.start(streams: true),
      ))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final app = (await tester.runAsync(
        () => PanelApp.open(
          panel,
          video: video,
          maxConnections: 1,
          overrides: [
            ...castOverrides(binaries!, folder),
            ...downloadShellOverrides,
            // Never the user's own Videos folder.
            systemVideosProvider.overrideWith(
              (ref) async => p.join(folder.path, 'Videos'),
            ),
            libraryThumbnailFolderProvider.overrideWithValue(
              Directory(p.join(folder.path, 'thumbnails')),
            ),
          ],
        ),
      ))!;
      addTearDown(() => tester.runAsync(app.close));
      // As `bootstrap()` does: the cast's notices as toasts.
      final container = app.container..read(castNoticeToastsProvider);
      final imported = (await tester.runAsync(
        () => container
            .read(guideImportServiceProvider)
            .importGuide(app.sourceId),
      ))!;
      expect(imported.isOk, isTrue, reason: '${imported.failureOrNull}');

      // H.264 1080p50, H.264 1080p25 AC-3, HEVC 1080p50.
      final lineup = <ChannelItem>[
        for (final key in ['1', '2', '3'])
          (await tester.runAsync(
            () => container
                .read(channelRepositoryProvider)
                .byRemoteKey(app.sourceId, key),
          ))!.valueOrNull!,
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IptvPlayerApp(),
        ),
      );
      // The app stays "in front" whatever the desktop does with the
      // window, as in the walks.
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      Keys(tester).resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // What `bootstrap()` does after launch: the download folder is a
      // library folder, the queue's news are toasts, the queue starts.
      await tester.runAsync(() async {
        final downloadFolder = await container.read(
          downloadFolderProvider.future,
        );
        await registerDownloadFolder(
          app.db.libraryDao,
          downloadFolder,
          now: DateTime.now().toUtc(),
        );
        container.read(downloadToastsProvider);
        await container.read(downloadQueueProvider).startUp();
      });
      final coordinator = container.read(playbackCoordinatorProvider);
      final cast = container.read(castCoordinatorProvider);
      final downloads = container.read(downloadServiceProvider);
      final router = container.read(routerProvider);
      final queue = container.listen(downloadTasksProvider, (_, _) {});
      addTearDown(queue.close);

      if (heap) {
        File('build/soak/heap.txt')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('');
      }
      final csv = File('build/soak/soak.csv')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          'minute,rss_mb,cpu_pct_one_core,state,reconnects,failures,'
          'active_cons,last_action,casts,downloads,walks,troubles\n',
        );
      final random = Random(7);
      final rss = <int>[];
      // What a round, or the app itself, got wrong: each fails the soak.
      final troubles = <String>[];
      var reconnects = 0;
      var failures = 0;
      var rounds = 0;
      var casts = 0;
      var downloaded = 0;
      var walks = 0;
      var lastAction = 'start';
      DateTime? downSince;
      var worstDown = Duration.zero;
      final watching = coordinator.states.listen((state) {
        if (state is PlaybackReconnecting) reconnects++;
        if (state is PlaybackFailed) failures++;
      });
      addTearDown(watching.cancel);

      await tester.runAsync(() => coordinator.playLive(lineup[0]));
      unawaited(router.push<void>(playerRoutePath));
      final start = DateTime.now();
      final end = start.add(Duration(minutes: minutes!));
      final roundEvery = Duration(minutes: roundMinutes);
      // No round this close to either end (8 minutes of the usual 20).
      final apart = roundEvery * 0.4;
      final castFor = roundMinutes >= 20 ? _castFor : _trialCastFor;
      var nextAction = start.add(_actionEvery);
      var nextRound = start.add(apart);
      var nextSample = start.add(const Duration(minutes: 1));
      var clearFaultsAt = DateTime(0);
      var cpu = _cpuTicks();
      var cpuAt = DateTime.now();
      var minute = 0;
      int? tvPort;

      void trouble(String what) {
        final line = 'minute ${minute + 1}: $what';
        troubles.add(line);
        // Said at once: an hour is long to wait for it.
        // ignore: avoid_print
        print('SOAK TROUBLE $line');
      }

      /// A quarter of a second of the app running, and the minute's row
      /// when it is due.
      Future<void> tick() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
        final now = DateTime.now();
        if (!now.isAfter(nextSample)) return;
        nextSample = nextSample.add(const Duration(minutes: 1));
        minute++;
        final mb = ProcessInfo.currentRss ~/ (1024 * 1024);
        rss.add(mb);
        final ticks = _cpuTicks();
        final seconds = now.difference(cpuAt).inMilliseconds / 1000;
        final pct = (ticks - cpu) / 100 / seconds * 100;
        cpu = ticks;
        cpuAt = now;
        // Anything a frame threw (an overflow, an assertion) since the
        // last row.
        final thrown = tester.takeException();
        if (thrown != null) {
          trouble('the app threw: ${'$thrown'.split('\n').first}');
        }
        final active = await tester.runAsync(panel.activeConnections);
        csv.writeAsStringSync(
          '$minute,$mb,${pct.toStringAsFixed(1)},'
          '${coordinator.state.runtimeType},$reconnects,$failures,$active,'
          '"$lastAction",$casts,$downloaded,$walks,${troubles.length}\n',
          mode: FileMode.append,
        );
      }

      /// Whether [done] came true within [limit], the app running.
      Future<bool> until(bool Function() done, Duration limit) async {
        final by = DateTime.now().add(limit);
        while (!done()) {
          if (DateTime.now().isAfter(by)) return false;
          await tick();
        }
        return true;
      }

      Future<void> hold(Duration time) => until(() => false, time);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      Future<void> wheel(int notches) async {
        // A little under the middle of the window: in the Guide's grid,
        // and in Movies' posters.
        final window = tester.view.physicalSize / tester.view.devicePixelRatio;
        final at = Offset(window.width / 2, window.height * 0.58);
        for (var i = 0; i < notches; i++) {
          await tester.sendEventToBinding(pointer.hover(at));
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, 240)));
          await hold(const Duration(milliseconds: 250));
        }
      }

      /// The channel on the fake TV for [castFor], then Stop casting.
      Future<void> castRound() async {
        lastAction = 'round $rounds: cast to the TV';
        // A TV of its own each round, at the same address: what it keeps
        // of a session (every message, every fetch) goes with it.
        final tv = (await tester.runAsync(
          () => _startTv(binaries!.ffprobe, tvPort),
        ))!;
        tvPort = tv.port;
        try {
          final device = CastDevice(
            id: 'soak-fake-tv',
            name: tv.device.name,
            host: tv.host,
            port: tv.port,
            model: 'Chromecast',
            manual: true,
          );
          await tester.runAsync(() => cast.connect(device));
          bool onTv() =>
              cast.state.phase == CastPhase.playing &&
              tv.playerState == 'PLAYING';
          if (!await until(onTv, const Duration(seconds: 90))) {
            trouble(
              'the TV never played (the cast is ${cast.state.phase.name}, '
              'the TV ${tv.playerState ?? 'has nothing loaded'})',
            );
          } else {
            await hold(castFor);
            if (onTv()) {
              casts++;
            } else {
              trouble(
                'the cast did not last (the cast is ${cast.state.phase.name}, '
                'the TV ${tv.playerState ?? 'has nothing loaded'})',
              );
            }
          }
          await tester.runAsync(cast.disconnect);
          if (!await until(
            () => runningProcesses(folder).isEmpty,
            const Duration(seconds: 20),
          )) {
            trouble('an FFmpeg was left after Stop casting');
          }
        } finally {
          await tester.runAsync(tv.close);
        }
      }

      /// A movie downloaded while the Guide, Movies and Search are used.
      Future<void> downloadAndWalk() async {
        lastAction = 'round $rounds: a download, and a walk';
        await tester.runAsync(coordinator.stop);
        final movie = (await tester.runAsync(
          () => container
              .read(movieRepositoryProvider)
              .byRemoteKey(app.sourceId, '${firstMovieId + rounds - 1}'),
        ))?.valueOrNull;
        DownloadTask? task() => (queue.read().value ?? const <DownloadTask>[])
            .where((task) => task.remoteKey == movie?.remoteKey)
            .firstOrNull;
        if (movie == null) {
          trouble('no movie ${firstMovieId + rounds - 1} to download');
        } else {
          await tester.runAsync(
            () => downloads.enqueue([movieDownloadRequest(movie)]),
          );
        }

        var walked = true;
        router.go(AppDestination.guide.path);
        if (await until(
          () => find.byType(GuideGrid).evaluate().isNotEmpty,
          const Duration(seconds: 30),
        )) {
          await wheel(8);
        } else {
          walked = false;
          trouble('the Guide did not open');
        }
        router.go(AppDestination.movies.path);
        if (await until(
          () => find
              .byWidgetPredicate((widget) => widget is TitleGrid)
              .evaluate()
              .isNotEmpty,
          const Duration(seconds: 30),
        )) {
          await wheel(8);
        } else {
          walked = false;
          trouble('Movies did not open');
        }
        unawaited(router.push<void>(searchRoutePath));
        final overlay = find.byType(SearchOverlay);
        final field = find.descendant(
          of: overlay,
          matching: find.byType(EditableText),
        );
        if (await until(
          () => field.evaluate().isNotEmpty,
          const Duration(seconds: 15),
        )) {
          for (var i = 1; i <= _searchText.length; i++) {
            await tester.enterText(field, _searchText.substring(0, i));
            await hold(const Duration(milliseconds: 150));
          }
          bool answered() =>
              ['CHANNELS', 'ON TV NOW & UPCOMING', 'MOVIES', 'SERIES'].any(
                (heading) => find
                    .descendant(of: overlay, matching: find.text(heading))
                    .evaluate()
                    .isNotEmpty,
              );
          if (!await until(answered, const Duration(seconds: 15))) {
            walked = false;
            trouble('Search answered nothing for "$_searchText"');
          }
          await hold(const Duration(seconds: 1));
        } else {
          walked = false;
          trouble('Search did not open');
        }
        if (isSearchOpen(router)) router.pop();
        if (walked) walks++;

        if (movie != null) {
          if (await until(
            () => task()?.state == DownloadTaskState.completed,
            const Duration(minutes: 3),
          )) {
            // The file is whole, and then leaves again (this test's own
            // folder): a night of them would fill the disk.
            final file = await tester.runAsync(
              () => container
                  .read(libraryRepositoryProvider)
                  .downloadOf(VodType.movie, app.sourceId, movie.remoteKey),
            );
            final onDisk = switch (file?.path) {
              final path? => File(path),
              null => null,
            };
            final size = task()?.totalBytes;
            if (file == null || onDisk == null || !onDisk.existsSync()) {
              trouble('the download finished with no file in the library');
            } else if (size == null || onDisk.lengthSync() != size) {
              trouble(
                'the downloaded file has ${onDisk.lengthSync()} bytes of '
                '${size ?? '?'}',
              );
            } else {
              downloaded++;
            }
            await tester.runAsync(() async {
              if (task() case final done?) await downloads.remove(done.id);
              if (onDisk != null && onDisk.existsSync()) onDisk.deleteSync();
              if (file != null) await app.db.libraryDao.removeItem(file.id);
            });
          } else {
            trouble(
              'the download did not finish (${task()?.state.name}, '
              '${task()?.problem?.name})',
            );
            if (task() case final stuck?) {
              await tester.runAsync(() => downloads.cancel(stuck.id));
            }
          }
        }
        var active = await tester.runAsync(panel.activeConnections);
        for (var i = 0; i < 40 && active != 0; i++) {
          await tick();
          active = await tester.runAsync(panel.activeConnections);
        }
        if (active != 0) trouble('the panel still has $active connection(s)');
      }

      /// Whether the player's picture is drawn at the stream's size, not
      /// only counted as playing.
      bool pictureDrawn() {
        final picture = find.byType(Texture);
        return picture.evaluate().isNotEmpty &&
            tester.getSize(picture.first).width > 1;
      }

      if (video) {
        expect(
          await until(pictureDrawn, const Duration(seconds: 30)),
          isTrue,
          reason: "the player's picture is drawn",
        );
      }

      while (DateTime.now().isBefore(end)) {
        await tick();
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

        // A round, from plain playback: no fault on, the picture there.
        if (now.isAfter(nextRound) &&
            state is PlaybackPlaying &&
            clearFaultsAt.year < 2000) {
          nextRound = nextRound.add(roundEvery);
          if (end.difference(now) < apart) continue;
          rounds++;
          final channel = coordinator.current ?? lineup[0];
          if (heap && rounds == 1) {
            await tester.runAsync(() => _heapSnapshot('before round 1'));
          }
          await castRound();
          await downloadAndWalk();
          lastAction = 'round $rounds: playing again';
          await tester.runAsync(() => coordinator.playLive(channel));
          unawaited(router.push<void>(playerRoutePath));
          if (!await until(
            () => coordinator.state is PlaybackPlaying,
            const Duration(seconds: 30),
          )) {
            trouble('the channel did not play again after the round');
          } else if (video &&
              !await until(pictureDrawn, const Duration(seconds: 30))) {
            trouble('the picture was not drawn again after the round');
          }
          if (heap) {
            await tester.runAsync(() => _heapSnapshot('after round $rounds'));
          }
          downSince = null;
          nextAction = DateTime.now().add(_actionEvery);
          continue;
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
      // A run that ends inside the warm-up has measured the warm-up (the
      // pictures' cache filling, the player settling): a trial of the
      // soak itself, with nothing to say about memory.
      final judged = rss.length > _warmUpMinutes + 5;
      final summary =
          'soak ${minutes}min video ${video ? 'on' : 'off'}: '
          '${rss.isEmpty ? '?' : rss.first}→${rss.isEmpty ? '?' : rss.last} MB '
          '(growth from minute ${from + 1}: $growth MB'
          '${judged ? '' : ', too short a run to judge it'}), '
          '$reconnects reconnects, '
          '$failures failures, longest without a picture '
          '${worstDown.inSeconds} s; $rounds rounds: $casts casts, '
          '$downloaded downloads, $walks walks'
          '${troubles.isEmpty ? '' : '; TROUBLE: ${troubles.join(' | ')}'}';
      File('build/soak/summary.txt').writeAsStringSync('$summary\n');
      // The summary is this test's output.
      // ignore: avoid_print
      print(summary);
      expect(
        worstDown,
        lessThan(_recoveryLimit),
        reason: 'every fault recovered',
      );
      expect(troubles, isEmpty, reason: 'every round did all of its parts');
      if (judged) expect(growth, lessThanOrEqualTo(_growthBudget));
    },
    skip: minutes == null || !streamsAvailable || binaries == null,
    timeout: Timeout(Duration(minutes: (minutes ?? 0) + 10)),
  );
}

/// The fake TV, at [port] when it is still free (the port it had in the
/// round before), else wherever there is room.
Future<FakeReceiver> _startTv(String ffprobe, int? port) async {
  FakePlayback playback() => FakePlayback(ffprobe: ffprobe);
  if (port != null) {
    try {
      return await FakeReceiver.start(port: port, playback: playback());
    } on SocketException {
      // Taken meanwhile.
    }
  }
  return await FakeReceiver.start(playback: playback());
}

/// Every isolate's heap after a full collection, and the main isolate's
/// classes by the bytes they hold, appended to build/soak/heap.txt.
Future<void> _heapSnapshot(String label) async {
  final info = await developer.Service.getInfo();
  final uri = info.serverWebSocketUri;
  if (uri == null) return;
  final service = await vmServiceConnectUri(uri.toString());
  try {
    final out = StringBuffer(
      '== $label, RSS ${ProcessInfo.currentRss ~/ (1024 * 1024)} MB\n',
    );
    final main = developer.Service.getIsolateId(Isolate.current);
    final machine = await service.getVM();
    for (final isolate in machine.isolates ?? const <vm.IsolateRef>[]) {
      final id = isolate.id;
      if (id == null) continue;
      final profile = await service.getAllocationProfile(id, gc: true);
      final usage = await service.getMemoryUsage(id);
      int mb(int? bytes) => (bytes ?? 0) ~/ (1024 * 1024);
      out.writeln(
        '${isolate.name}: heap ${mb(usage.heapUsage)} MB of '
        '${mb(usage.heapCapacity)}, external ${mb(usage.externalUsage)} MB',
      );
      if (id != main) continue;
      final members = [...?profile.members]
        ..sort((a, b) => (b.bytesCurrent ?? 0).compareTo(a.bytesCurrent ?? 0));
      for (final member in members.take(40)) {
        out.writeln(
          '  ${member.classRef?.name}: ${member.instancesCurrent} '
          'instances, ${(member.bytesCurrent ?? 0) ~/ 1024} KB',
        );
      }
    }
    File('build/soak/heap.txt')
        .writeAsStringSync('$out\n', mode: FileMode.append);
  } finally {
    await service.dispose();
  }
}

/// This process's CPU time so far, in clock ticks (100 a second on
/// Linux): user + system from /proc/self/stat.
int _cpuTicks() {
  final stat = File('/proc/self/stat').readAsStringSync();
  // Fields after the command name, which is in parentheses.
  final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
  return int.parse(fields[11]) + int.parse(fields[12]);
}
