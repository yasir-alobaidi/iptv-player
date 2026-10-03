// Phase 7's casting walk (step 7), keys only, on the real app — its
// database and sync, the player, the cast coordinator, the relay with
// FFmpeg, our Cast client — against the fake panel (one connection) and
// the fake TV (tools/fake_receiver), which fetches and checks what it is
// sent as a TV does:
//
// Live TV → Enter: the first channel full screen → C: the picker, nothing
// found → Add device by IP address → the fake TV's address → Enter: kept
// and listed → Enter on it: the channel moves to the TV and the player
// hands over to the casting view → the TV plays it from the relay → ↓:
// the next channel on the TV → Esc: Live TV, its card for the cast and
// the bar → C: the picker says what is on → Esc → Ctrl+4: a movie's page →
// Play: on the TV, straight from the panel, which the TV can't read (no
// CORS), so through the relay from then on → → three times: on from 0:30
// → Stop casting in the view: the movie's place kept, the TV gone home,
// no FFmpeg left, the panel's connection closed, nothing plays here.
//
// The test reads state to check it; everything it does goes through the
// keyboard. Needs FFmpeg (bundled, else the system's), the stream samples
// and the movie's (CI makes them).

import 'dart:io';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/add_cast_device_dialog.dart';
import 'package:iptv_player/features/casting/presentation/cast_shell_slots.dart';
import 'package:iptv_player/features/casting/presentation/casting_view.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';

import 'support/cast_tv.dart';
import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';
  final binaries = castBinaries();

  testWidgets(
    'Cast while watching, a zap on the TV, back to Live TV, Stop casting',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      final folder = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('iptv_cast_walk'),
      ))!;
      addTearDown(() => tester.runAsync(() => folder.delete(recursive: true)));
      final panel = (await tester.runAsync(
        () => FakePanel.start(streams: true),
      ))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final tv = (await tester.runAsync(
        () => FakeReceiver.start(
          playback: FakePlayback(ffprobe: binaries!.ffprobe),
        ),
      ))!;
      addTearDown(() => tester.runAsync(tv.close));
      final app = (await tester.runAsync(
        () => PanelApp.open(
          panel,
          video: video,
          overrides: castOverrides(binaries!, folder),
        ),
      ))!;
      addTearDown(() => tester.runAsync(app.close));
      // As `bootstrap()` does: the cast's notices as toasts.
      final container = app.container..read(castNoticeToastsProvider);

      final [one, two] = (await tester.runAsync(
        () => container
            .read(channelRepositoryProvider)
            .range(ChannelQuery(sourceId: app.sourceId), 0, 2),
      ))!.valueOrNull!;
      final movie = (await tester.runAsync(
        () => container
            .read(movieRepositoryProvider)
            .byRemoteKey(app.sourceId, '$firstMovieId'),
      ))!.valueOrNull!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      final k = Keys(tester)..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final playback = container.read(playbackCoordinatorProvider);
      final cast = container.read(castCoordinatorProvider);
      int? onTv() => switch (cast.state.item) {
        PlayableChannel(:final channel) => channel.id,
        _ => null,
      };
      Future<bool> tvPlaying({int after = 0}) async =>
          cast.state.phase == CastPhase.playing &&
          tv.playerState == 'PLAYING' &&
          tv.checks.length > after;

      // ── Ctrl+2: Live TV → All channels → Enter: the first channel full
      // screen.
      await k.waitFor(find.text('Start watching'), seconds: 30);
      await k.chord(LogicalKeyboardKey.digit2);
      await k.waitFor(find.text('All channels'));
      await k.waitUntil(
        () => k.focusIsOn(find.text('Favorites').first),
        'the focus on Favorites',
      );
      await k.press(LogicalKeyboardKey.arrowDown);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => container.read(liveTvControllerProvider)?.selected?.id == one.id,
        'the first row focused (${k.focusedLabel()})',
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(PlayerScreen));
      await k.waitUntil(
        () => playback.state is PlaybackPlaying,
        'the channel playing here (${playback.state})',
        seconds: 30,
      );

      // ── C: the picker. Nothing on the network; Add device by IP
      // address, the fake TV's.
      await k.press(LogicalKeyboardKey.keyC);
      await k.waitFor(find.text('Cast to a device'));
      expect(find.textContaining(one.name), findsWidgets, reason: 'what');
      await k.tabTo(find.text('Add device by IP address'));
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text('Add a device by address'));
      await k.typeIn(
        find.descendant(
          of: find.byType(AddCastDeviceDialog),
          matching: find.byType(EditableText),
        ),
        '127.0.0.1:${tv.port}',
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => find.byType(AddCastDeviceDialog).evaluate().isEmpty,
        'the device added',
        seconds: 30,
      );
      final kept = (await tester.runAsync(
        () => container.read(castDeviceStoreProvider).watchAll().first,
      ))!;
      expect(kept.single.name, 'Fake TV');
      expect(kept.single.manual, isTrue);

      // ── Enter on it: the channel moves to the TV; the player hands
      // over to the casting view.
      final fakeTv = find.byWidgetPredicate(
        (widget) =>
            widget is FocusableSurface &&
            (widget.semanticLabel?.startsWith('Fake TV') ?? false),
        description: 'the Fake TV row',
      );
      await k.waitFor(fakeTv, seconds: 30);
      await k.tabTo(fakeTv, back: true);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(CastingView));
      await k.waitUntil(
        tvPlaying,
        'the TV playing (${cast.state}, ${tv.playerState})',
        seconds: 60,
      );
      expect(onTv(), one.id);
      expect(cast.state.plan!.delivery, CastDelivery.relayHls);
      expect(tv.checks.last.videoCodec, 'h264');
      expect(playback.state, isA<PlaybackCasting>());
      expect(app.location, isNot(playerRoutePath));
      expect(find.text('PLAYING ON FAKE TV'), findsOneWidget);
      expect(
        await tester.runAsync(panel.activeConnections),
        1,
        reason: "the laptop's stream closed before the TV's opened",
      );

      // ── ↓: the next channel, on the TV.
      final checked = tv.checks.length;
      await k.press(LogicalKeyboardKey.arrowDown);
      await k.waitUntil(
        () async => onTv() == two.id && await tvPlaying(after: checked),
        'the next channel playing on the TV (${cast.state})',
        seconds: 60,
      );
      expect(tv.checks.last.audioCodec, 'aac');
      expect(await tester.runAsync(panel.activeConnections), 1);

      // ── Esc: Live TV, its card for the cast, the bar; the cast goes on.
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => find.byType(CastingView).evaluate().isEmpty,
        'the casting view closed',
      );
      expect(find.text('Playing on Fake TV'), findsOneWidget);
      expect(find.textContaining('Casting to Fake TV'), findsOneWidget);
      expect(cast.state.phase, CastPhase.playing);

      // ── C: the picker says what is on; Esc closes it, the cast goes on.
      await k.press(LogicalKeyboardKey.keyC);
      await k.waitFor(find.text('Cast to a device'));
      expect(find.text('Casting to Fake TV'), findsOneWidget);
      await k.press(LogicalKeyboardKey.escape);
      await k.waitUntil(
        () => find.text('Cast to a device').evaluate().isEmpty,
        'the picker closed',
      );
      expect(cast.state.phase, CastPhase.playing);

      // ── Ctrl+4: Movies → a movie's page → Play: on the TV. The panel
      // sends no CORS headers, so the TV can't read the file itself: the
      // relay sends it from then on, and a toast says so.
      await k.chord(LogicalKeyboardKey.digit4);
      final filter = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SearchField && w.hint == 'Filter movies',
        ),
        matching: find.byType(EditableText),
      );
      await k.waitFor(filter);
      await k.tabTo(filter);
      await k.typeIn(filter, _typed(movie.name));
      await k.waitFor(byLabel(movie.name));
      await k.tabTo(find.byWidgetPredicate((w) => w is TitleGrid));
      for (var i = 0; i < 20 && k.focusedLabel() != movie.name; i++) {
        await k.press(LogicalKeyboardKey.arrowRight);
      }
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => app.location == movieDetailsPath(movie),
        'the movie page (${app.location})',
      );
      await k.waitUntil(
        () => k.focusedLabel() == 'Play',
        'the focus on Play (${focusPath()})',
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.byType(CastingView));
      await k.waitUntil(
        () async =>
            cast.state.item == PlayableMovie(movie) &&
            cast.state.plan?.delivery == CastDelivery.relayContinuous &&
            await tvPlaying(),
        'the movie playing on the TV, relayed (${cast.state})',
        seconds: 60,
      );
      expect(
        find.text(
          "Fake TV couldn't fetch it directly, so this computer "
          'sends it',
        ),
        findsOneWidget,
      );
      expect(find.text('PLAYING ON FAKE TV'), findsOneWidget);

      // ── → three times: 30 s on, the relay starts again from there.
      final loads = tv.requests('LOAD').length;
      for (var i = 0; i < 3; i++) {
        await k.press(LogicalKeyboardKey.arrowRight);
      }
      await k.waitUntil(
        () async =>
            tv.requests('LOAD').length > loads &&
            cast.timeline.position >= const Duration(seconds: 30) &&
            await tvPlaying(),
        'the movie playing on from 0:30 (${cast.timeline.position})',
        seconds: 30,
      );

      // ── Tab to Stop casting, in the view: the movie's place is kept.
      // (The view itself has the focus, for its keys, and holds the
      // button: Tab until the button has it.)
      for (var i = 0; i < 12 && k.focusedLabel() != 'Stop casting'; i++) {
        await k.press(LogicalKeyboardKey.tab);
      }
      expect(k.focusedLabel(), 'Stop casting');
      expect(
        find.descendant(
          of: find.byType(CastingView),
          matching: find.text('Stop casting'),
        ),
        findsOneWidget,
      );
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () => cast.state.phase == CastPhase.off,
        'casting stopped (${cast.state})',
      );
      final mark = (await tester.runAsync(
        () => container.read(watchProgressProvider).watch(movie.ref).first,
      ))!;
      expect(mark.position, greaterThanOrEqualTo(const Duration(seconds: 30)));
      expect(find.byType(CastingView), findsNothing);
      await k.waitUntil(() => tv.app == null, 'the TV gone home');
      await k.waitUntil(
        () => runningProcesses(folder).isEmpty,
        'no FFmpeg left (${runningProcesses(folder)})',
      );
      await k.waitUntil(
        () async => await panel.activeConnections() == 0,
        "the panel's connection closed",
      );
      expect(find.textContaining('Casting to Fake TV'), findsNothing);
      expect(playback.state, isA<PlaybackIdle>(), reason: 'nothing here');
    },
    skip: binaries == null || !streamsAvailable || !vodAvailable,
  );
}

/// The start of a title's name, as typed into a filter.
String _typed(String name) =>
    RegExp("^[A-Za-z' ]+").firstMatch(name)?[0]?.trim() ?? name;
