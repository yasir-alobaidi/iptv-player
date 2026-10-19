// The coordinator's futures run on the test's clock; pumps drive them.
// ignore_for_file: unawaited_futures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_surface.dart';

import '../../design/design_harness.dart';
import 'support/playback_fakes.dart';

void main() {
  final picture = find.byKey(const ValueKey('fake-video'));
  final spinner = find.byType(CircularProgressIndicator);

  Future<void> pumpSurface(
    WidgetTester tester,
    Rig rig, {
    FormFactor formFactor = FormFactor.desktop,
    PlaybackSettings stored = const PlaybackSettings(),
  }) => pumpDesign(
    tester,
    ProviderScope(
      overrides: [
        playerEngineProvider.overrideWithValue(rig.engine),
        playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
        playbackSettingsStoreProvider.overrideWithValue(_Stored(stored)),
        formFactorProvider.overrideWithValue(formFactor),
      ],
      child: const SizedBox(
        width: 640,
        height: 360,
        child: PlayerSurface(compact: true),
      ),
    ),
  );

  // The Bedroom TV (ADR-027): a film resumed after a channel showed the
  // channel's last picture under "Reconnecting" for about 30 s.
  testWidgets('a film reconnecting before its own picture shows none, never '
      "the channel's last one; after its own, that one", (tester) async {
    final rig = Rig();
    await pumpSurface(tester, rig);
    rig.coordinator.playLive(channel(1));
    await tester.pump();
    rig.engine.firstFrame();
    await tester.pump();
    expect(picture, findsOneWidget);

    rig.coordinator.playVod(
      PlayableMovie(movie(1)),
      from: const Duration(minutes: 3),
    );
    await tester.pump();
    expect(rig.state, isA<PlaybackOpening>());
    expect(picture, findsNothing);
    expect(spinner, findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(rig.state, isA<PlaybackReconnecting>());
    expect(picture, findsNothing);
    expect(find.byType(ReconnectingPill), findsOneWidget);

    // The next attempt shows the film; a stall then keeps its picture.
    await tester.pump(const Duration(seconds: 1));
    rig.engine.firstFrame();
    await tester.pump();
    expect(picture, findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    expect(rig.state, isA<PlaybackReconnecting>());
    expect(picture, findsOneWidget);
    expect(find.byType(ReconnectingPill), findsOneWidget);

    rig.coordinator.stop();
    await tester.pump();
  });

  group('a picture on its own layer behind the app (the TV trial)', () {
    Color backdrop(WidgetTester tester) => tester
        .widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(PlayerSurface),
                matching: find.byType(ColoredBox),
              )
              .first,
        )
        .color;

    Color video(WidgetTester tester) =>
        tester.element(find.byType(PlayerSurface)).tokens.colors.video;

    testWidgets('paints nothing over it once the film plays, and the video '
        'colour before, so no old frame shows', (tester) async {
      final rig = Rig();
      rig.engine.pictureBehindApp.value = true;
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(PlayableMovie(movie(1)));
      await tester.pump();
      expect(rig.state, isA<PlaybackOpening>());
      expect(backdrop(tester), video(tester));

      rig.engine.firstFrame();
      await tester.pump();
      expect(rig.state, isA<PlaybackPlaying>());
      expect(backdrop(tester), Colors.transparent);

      // Back on the texture (a channel): the video colour again.
      rig.engine.pictureBehindApp.value = false;
      await tester.pump();
      expect(backdrop(tester), video(tester));

      rig.coordinator.stop();
      await tester.pump();
    });

    testWidgets('a picture on the texture keeps the video colour behind it', (
      tester,
    ) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(PlayableMovie(movie(1)));
      await tester.pump();
      rig.engine.firstFrame();
      await tester.pump();
      expect(rig.state, isA<PlaybackPlaying>());
      expect(backdrop(tester), video(tester));

      rig.coordinator.stop();
      await tester.pump();
    });
  });
  group('Subtitle size (ADR-038): the picture draws them at the size '
      'Settings → Playback says, at once', () {
    double scale(WidgetTester tester) =>
        tester.widget<FakeVideoView>(picture).subtitleScale;

    Future<void> choose(WidgetTester tester, SubtitleSize size) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayerSurface)),
      );
      final controller = container.read(
        playbackSettingsControllerProvider.notifier,
      );
      await controller.update(
        container
            .read(playbackSettingsControllerProvider)
            .copyWith(subtitleSize: size),
      );
      await tester.pump();
    }

    Future<Rig> playing(
      WidgetTester tester, {
      FormFactor formFactor = FormFactor.desktop,
      PlaybackSettings stored = const PlaybackSettings(),
    }) async {
      final rig = Rig();
      await pumpSurface(tester, rig, formFactor: formFactor, stored: stored);
      rig.coordinator.playVod(PlayableMovie(movie(1)));
      await tester.pump();
      rig.engine.firstFrame();
      await tester.pump();
      expect(picture, findsOneWidget);
      return rig;
    }

    testWidgets("a desktop's Medium is the player's own size; a change "
        'reaches what plays without opening it again', (tester) async {
      final rig = await playing(tester);
      expect(scale(tester), 1);

      await choose(tester, SubtitleSize.large);
      expect(scale(tester), closeTo(1.3, 1e-9));
      await choose(tester, SubtitleSize.small);
      expect(scale(tester), closeTo(0.8, 1e-9));
      expect(rig.engine.opened, hasLength(1));
      expect(rig.engine.calls, isNot(contains('stop')));

      rig.coordinator.stop();
      await tester.pump();
    });

    testWidgets("a TV's Medium is 1.4 times it, read from a sofa; Small and "
        'Large are of that', (tester) async {
      final rig = await playing(tester, formFactor: FormFactor.tv);
      expect(scale(tester), closeTo(1.4, 1e-9));

      await choose(tester, SubtitleSize.small);
      expect(scale(tester), closeTo(1.12, 1e-9));
      await choose(tester, SubtitleSize.large);
      expect(scale(tester), closeTo(1.82, 1e-9));

      rig.coordinator.stop();
      await tester.pump();
    });

    testWidgets('the stored choice is the size from the first picture', (
      tester,
    ) async {
      final rig = await playing(
        tester,
        stored: const PlaybackSettings(subtitleSize: SubtitleSize.large),
      );
      expect(scale(tester), closeTo(1.3, 1e-9));

      rig.coordinator.stop();
      await tester.pump();
    });
  });
}

final class _Stored implements PlaybackSettingsStore {
  const new(this._settings);

  final PlaybackSettings _settings;

  @override
  Future<Result<PlaybackSettings>> load() async => Ok(_settings);

  @override
  Future<Result<void>> save(PlaybackSettings settings) async => const Ok(null);
}
