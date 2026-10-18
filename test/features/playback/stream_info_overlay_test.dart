// The coordinator's futures run on the test's clock; pumps drive them.
// ignore_for_file: unawaited_futures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/presentation/playback_text.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';

import '../../design/design_harness.dart';
import 'support/display_fakes.dart';
import 'support/playback_fakes.dart';

/// Stream info (I): the video's frame rate as it is (23.976 is not 24),
/// and on a TV the display's mode, and whether it is the film's rate.
void main() {
  group('the Display row (ADR-035)', () {
    test("the display's size and rate", () {
      expect(displayInfoText(uhd5994), '3840×2160 · 59.94 Hz');
      expect(displayInfoText(uhd24, fps: 50), '3840×2160 · 24 Hz');
    });

    test('a film at 23.976 or 24 fps: whether the display is at its rate', () {
      expect(
        displayInfoText(uhd23976, fps: 23.976, film: true),
        '3840×2160 · 23.976 Hz · matched',
      );
      expect(
        displayInfoText(uhd24, fps: 24, film: true),
        '3840×2160 · 24 Hz · matched',
      );
      expect(
        displayInfoText(uhd5994, fps: 23.976, film: true),
        '3840×2160 · 59.94 Hz · not matched',
      );
      expect(
        displayInfoText(uhd24, fps: 23.976, film: true),
        '3840×2160 · 24 Hz · not matched',
        reason: '23.976 and 24 are different modes',
      );
    });

    test('nothing said of any other rate, or of a channel', () {
      expect(
        displayInfoText(uhd5994, fps: 25, film: true),
        '3840×2160 · 59.94 Hz',
      );
      expect(displayInfoText(uhd5994, film: true), '3840×2160 · 59.94 Hz');
      expect(displayInfoText(uhd5994, fps: 23.976), '3840×2160 · 59.94 Hz');
    });
  });

  group('the overlay', () {
    Future<Rig> pumpOverlay(
      WidgetTester tester, {
      required DisplayModes display,
      required StreamInfo info,
      bool film = true,
    }) async {
      final rig = Rig();
      rig.engine.info = info;
      if (film) {
        rig.coordinator.playVod(PlayableMovie(movie(1)));
      } else {
        rig.coordinator.playLive(channel(1));
      }
      await pumpDesign(
        tester,
        ProviderScope(
          overrides: [
            playerEngineProvider.overrideWithValue(rig.engine),
            playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
            displayModesProvider.overrideWithValue(display),
          ],
          child: const StreamInfoOverlay(),
        ),
      );
      await tester.pump();
      await tester.pump();
      return rig;
    }

    /// Nothing left running: the player stopped, the overlay (which reads
    /// again every second) gone.
    Future<void> done(WidgetTester tester, Rig rig) async {
      rig.coordinator.stop();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    }

    const film = StreamInfo(
      width: 1920,
      height: 1080,
      fps: 23.976023976,
      videoCodec: 'hevc',
    );

    testWidgets('the frame rate as it is: 23.976 fps, not 24', (tester) async {
      final rig = await pumpOverlay(
        tester,
        display: const NoDisplayModes(),
        info: film,
      );
      expect(find.text('1920×1080 · 23.976 fps · hevc'), findsOneWidget);
      await done(tester, rig);
    });

    testWidgets('29.97 fps too', (tester) async {
      final rig = await pumpOverlay(
        tester,
        display: const NoDisplayModes(),
        info: const StreamInfo(width: 1920, height: 1080, fps: 29.97003),
      );
      expect(find.text('1920×1080 · 29.97 fps'), findsOneWidget);
      await done(tester, rig);
    });

    testWidgets("on a TV, the display's mode, matched to the film", (
      tester,
    ) async {
      final rig = await pumpOverlay(
        tester,
        display: FakeDisplayModes(current: uhd23976),
        info: film,
      );
      expect(find.text('Display'), findsOneWidget);
      expect(find.text('3840×2160 · 23.976 Hz · matched'), findsOneWidget);
      await done(tester, rig);
    });

    testWidgets("on a TV, a film the display isn't matched to says so", (
      tester,
    ) async {
      final rig = await pumpOverlay(
        tester,
        display: FakeDisplayModes(),
        info: film,
      );
      expect(find.text('3840×2160 · 59.94 Hz · not matched'), findsOneWidget);
      await done(tester, rig);
    });

    testWidgets("on a TV, a channel: the display's mode alone", (tester) async {
      final rig = await pumpOverlay(
        tester,
        display: FakeDisplayModes(),
        info: const StreamInfo(width: 1920, height: 1080, fps: 50),
        film: false,
      );
      expect(find.text('3840×2160 · 59.94 Hz'), findsOneWidget);
      await done(tester, rig);
    });

    testWidgets('the desktop: no Display row', (tester) async {
      final rig = await pumpOverlay(
        tester,
        display: const NoDisplayModes(),
        info: film,
      );
      expect(find.text('Display'), findsNothing);
      expect(find.textContaining(' Hz'), findsNothing);
      await done(tester, rig);
    });

    testWidgets("a display that can't be read: no Display row", (tester) async {
      final rig = await pumpOverlay(tester, display: _Unreadable(), info: film);
      expect(find.text('Display'), findsNothing);
      await done(tester, rig);
    });
  });
}

/// A TV whose display answers nothing.
final class _Unreadable implements DisplayModes {
  @override
  bool get available => true;

  @override
  Future<DisplayFacts?> read() async => null;

  @override
  Future<bool> request(int id) async => false;

  @override
  Stream<DisplayMode> get changes => const Stream.empty();
}
