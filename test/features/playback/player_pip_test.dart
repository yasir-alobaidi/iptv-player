import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/platform/picture_in_picture.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_surface.dart';
import 'package:iptv_player/features/playback/presentation/player_system_ui.dart';
import 'package:iptv_player/features/playback/presentation/vod_osd.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';
import '../vod/vod_fakes.dart';
import 'support/system_ui_fakes.dart';
import 'support/vod_player_rig.dart';

/// What the player told the system, and the system's word back.
final class RecordedPictureInPicture implements PictureInPicture {
  final wishes = <PictureInPictureWish?>[];
  final _events = StreamController<PictureInPictureEvent>.broadcast();

  void say(PictureInPictureEvent event) => _events.add(event);

  @override
  Future<void> allow(PictureInPictureWish? wish) async => wishes.add(wish);

  @override
  Stream<PictureInPictureEvent> get events => _events.stream;
}

/// ADR-069: on a phone, a tablet or a Chromebook, the full-screen player
/// shrinks to a corner of the screen as the app is left, the picture
/// alone in it; its Play/Pause pauses a film, and closing it ends what
/// played. The desktop and a TV are never asked.
void main() {
  late RecordedPictureInPicture pip;

  setUp(() => pip = RecordedPictureInPicture());

  final finishers = <Future<void> Function()>[];

  void pipTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final finish in finishers.reversed) {
        await finish();
      }
      finishers.clear();
    }
  });

  List<Override> on(FormFactor formFactor) => [
    formFactorProvider.overrideWithValue(formFactor),
    playerSystemUiProvider.overrideWithValue(RecordedPlayerSystemUi()),
    pictureInPictureProvider.overrideWithValue(pip),
  ];

  /// A film playing 5 minutes in, its picture 1920 × 800.
  Future<VodPlayerRig> playFilm(
    WidgetTester tester, {
    FormFactor formFactor = FormFactor.mobile,
  }) async {
    final t = VodPlayerRig();
    finishers.add(() => t.finish(tester));
    await t.open(
      tester,
      '/movies/src-1/501',
      size: const Size(780, 360),
      extra: on(formFactor),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    await t.firstFrame(tester);
    t.rig.engine
      ..emit(const PlayerVideoChanged(width: 1920, height: 800))
      ..progress(const Duration(minutes: 5));
    await settle(tester);
    return t;
  }

  Future<void> intoCorner(WidgetTester tester) async {
    pip.say(const PictureInPictureEntered());
    tester.view.physicalSize = const Size(240, 100);
    await settle(tester);
  }

  pipTest("a film on a phone: leaving shrinks it to its picture's shape, "
      'with Play/Pause; a pause is told too; Back takes it back', (
    tester,
  ) async {
    final t = await playFilm(tester);
    expect(
      pip.wishes.last,
      const PictureInPictureWish(size: (1920, 800), pauseButton: true),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(t.rig.engine.calls, contains('paused:true'));
    expect(
      pip.wishes.last,
      const PictureInPictureWish(
        size: (1920, 800),
        pauseButton: true,
        paused: true,
      ),
    );

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(t.app.location, isNot(playerRoutePath));
    expect(pip.wishes.last, isNull);
  });

  pipTest('in the corner: the picture alone, nothing cut; expanded, the '
      'controls again', (tester) async {
    await playFilm(tester);
    await intoCorner(tester);

    expect(
      tester.widget<PlayerSurface>(find.byType(PlayerSurface)).pictureOnly,
      isTrue,
    );
    expect(find.byType(VodOsdBottom), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(tester.takeException(), isNull);

    pip.say(const PictureInPictureExpanded());
    tester.view.physicalSize = const Size(780, 360);
    await settle(tester);
    expect(find.byType(VodOsdBottom), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  pipTest("the small window's Play/Pause pauses the film and plays it "
      'again', (tester) async {
    final t = await playFilm(tester);
    await intoCorner(tester);

    pip.say(const PictureInPicturePlayPause());
    await settle(tester);
    expect(t.rig.engine.calls, contains('paused:true'));
    expect(pip.wishes.last?.paused, isTrue);

    pip.say(const PictureInPicturePlayPause());
    await settle(tester);
    expect(t.rig.engine.calls.last, 'paused:false');
    expect(pip.wishes.last?.paused, isFalse);
  });

  pipTest('closing the small window ends the film where it was and leaves '
      'the player; coming back plays nothing', (tester) async {
    final t = await playFilm(tester);
    await intoCorner(tester);
    // The system says the app left the screen as the window goes.
    await t.rig.coordinator.stopWhileAway();
    pip.say(const PictureInPictureClosed());
    tester.view.physicalSize = const Size(780, 360);
    await settle(tester);

    expect(t.app.location, isNot(playerRoutePath));
    expect(t.rig.state, isA<PlaybackIdle>());
    final opened = t.rig.engine.opened.length;
    await t.rig.coordinator.resumeAfterAway();
    await settle(tester);
    expect(t.rig.engine.opened, hasLength(opened));
    expect(t.rig.state, isA<PlaybackIdle>());
  });

  pipTest('a failure leaves the app as ever: the small window is not '
      'asked', (tester) async {
    final t = await playFilm(tester);
    expect(pip.wishes.last, isNotNull);

    // A refusal no retry fixes: the failure card at once.
    t.rig.prober.next = PlaybackProblem(
      PlaybackProblemKind.offline,
      failure: NotFoundFailure('stream: HTTP 404', 404),
    );
    t.rig.engine.fail();
    await settle(tester);
    expect(find.byType(PlaybackFailureCard), findsOneWidget);
    expect(pip.wishes.last, isNull);
  });

  pipTest('a channel on a phone: its shape, no Play/Pause', (tester) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      size: const Size(1280, 800),
      overrides: [...live.overrides, ...on(FormFactor.mobile)],
    );
    await settle(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    live.rig.engine
      ..firstFrame()
      ..emit(const PlayerVideoChanged(width: 1280, height: 720));
    await settle(tester);
    finishers.add(() async {
      await tester.pump(const Duration(seconds: 4));
      await live.rig.coordinator.stop();
      await settle(tester);
    });

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(pip.wishes.last, const PictureInPictureWish(size: (1280, 720)));
  });

  for (final formFactor in [FormFactor.desktop, FormFactor.tv]) {
    pipTest('${formFactor.name}: never asked', (tester) async {
      await playFilm(tester, formFactor: formFactor);
      expect(pip.wishes, isEmpty);
    });
  }
}
