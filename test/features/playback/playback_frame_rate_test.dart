// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/playback/domain/frame_rate_match.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import 'support/display_fakes.dart';
import 'support/playback_fakes.dart';

/// A TV's Match frame rate on the coordinator (decisions 2–4): the
/// switch is part of a film's open, and the display goes back to the
/// TV's own mode when nothing needs it any more.
void main() {
  const film = Duration(minutes: 100);
  const ms = Duration(milliseconds: 1);

  /// A coordinator on a TV whose display is [display].
  Rig tv(
    FakeAsync async,
    FakeDisplayModes display, {
    PlaybackSettings settings = const PlaybackSettings(matchFrameRate: true),
    WatchdogTimings timings = const WatchdogTimings(),
    Duration settle = const Duration(milliseconds: 1500),
  }) => Rig(
    frameRate: (log) => FrameRateMatcher(
      display: display,
      log: log,
      clock: () => DateTime(2026, 10, 18).add(async.elapsed),
      settle: settle,
    ),
    settings: () => settings,
    timings: timings,
  );

  /// Opens [item] and brings it to its first frame: a file of [length]
  /// at [fps].
  void toFirstFrame(
    FakeAsync async,
    Rig rig,
    Playable item, {
    double? fps = 23.976,
    Duration? length = film,
  }) {
    switch (item) {
      case PlayableChannel(:final channel):
        rig.coordinator.playLive(channel);
      case _:
        rig.coordinator.playVod(item);
    }
    async.flushMicrotasks();
    rig.engine.info = StreamInfo(width: 1920, height: 1080, fps: fps);
    if (length != null && !item.live) rig.engine.duration(length);
    rig.engine.firstFrame();
    async.flushMicrotasks();
  }

  /// [item] played through its switch, to playing at its rate.
  void playedThrough(FakeAsync async, Rig rig, Playable item, {double? fps}) {
    toFirstFrame(async, rig, item, fps: fps ?? 23.976);
    async.elapse(const Duration(seconds: 4));
    expect(rig.state, isA<PlaybackPlaying>());
  }

  Matcher logged(String text) => anyElement(contains(text));

  final film1 = PlayableMovie(movie(1));
  final film2 = PlayableMovie(movie(2));

  group('the switch, part of the open (decision 3)', () {
    test('a 23.976 fps film: paused, the mode asked for, and played 1.5 s '
        'after the display changes; "Preparing…" meanwhile', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1);
        expect(rig.engine.calls, ['paused:true']);
        expect(display.requests, [uhd23976.id]);
        expect(rig.state, isA<PlaybackOpening>());

        async.elapse(const Duration(milliseconds: 1800));
        expect(display.current, uhd23976);
        expect(rig.state, isA<PlaybackOpening>(), reason: 'settling');
        async.elapse(const Duration(milliseconds: 1499));
        expect(rig.state, isA<PlaybackOpening>());
        expect(rig.engine.calls, ['paused:true']);

        async.elapse(ms);
        expect(rig.engine.calls, ['paused:true', 'paused:false']);
        expect(rig.state, isA<PlaybackPlaying>());
        expect(
          rig.timelines.where((t) => t.paused),
          isEmpty,
          reason: "the switch's pause is no pause of the user's",
        );
        expect(
          rig.logLines,
          logged('Display mode now 3840x2160 23.976 Hz, 1.8 s after asking'),
        );
      });
    });

    test('a 24 fps episode takes the 24 Hz mode', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(
          async,
          rig,
          PlayableEpisode(series, episode(1, 1)),
          fps: 24,
        );
        async.elapse(const Duration(seconds: 4));

        expect(display.requests, [uhd24.id]);
        expect(rig.state, isA<PlaybackPlaying>());
      });
    });

    test('neither the open timeout nor the stall watchdog counts the '
        'switch; the watchdog starts after it', () {
      fakeAsync((async) {
        final display = FakeDisplayModes()
          ..switchAfter = const Duration(seconds: 4);
        final rig = tv(
          async,
          display,
          // The open's timeout 8 s, a stall 8 s; the switch takes 14 s.
          settings: const PlaybackSettings(
            preset: BufferPreset.lowLatency,
            matchFrameRate: true,
          ),
          timings: const WatchdogTimings(fileOpen: Duration(seconds: 3)),
          settle: const Duration(seconds: 10),
        );

        toFirstFrame(async, rig, film1);
        async.elapse(const Duration(seconds: 14) - ms);
        expect(rig.state, isA<PlaybackOpening>());
        expect(rig.states.whereType<PlaybackReconnecting>(), isEmpty);

        async.elapse(ms);
        expect(rig.state, isA<PlaybackPlaying>());
        // Now the position has to move.
        async.elapse(const Duration(seconds: 8));
        expect(rig.state, isA<PlaybackReconnecting>());
      });
    });

    test('a display that never changes: it plays on at its mode after 5 s', () {
      fakeAsync((async) {
        final display = FakeDisplayModes()..switches = false;
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1);
        async.elapse(const Duration(seconds: 5) - ms);
        expect(rig.state, isA<PlaybackOpening>());

        async.elapse(ms);
        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.engine.calls, ['paused:true', 'paused:false']);
        expect(rig.logLines, logged('no change within 5 s, playing on'));
      });
    });

    test('a stop during the switch ends it and clears the request; '
        'nothing plays after', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1);
        async.elapse(const Duration(seconds: 1));
        rig.coordinator.stop();
        async.flushMicrotasks();

        expect(display.requests, [uhd23976.id, 0]);
        async.elapse(const Duration(seconds: 10));
        expect(rig.state, isA<PlaybackIdle>());
        expect(rig.engine.calls, ['paused:true', 'stop']);
        expect(display.current, uhd5994);
      });
    });

    test('a stream lost during the switch reconnects; its next first '
        'frame finds the mode and plays at once', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1);
        async.elapse(const Duration(milliseconds: 500));
        rig.engine.fail();
        async.flushMicrotasks();
        expect(rig.state, isA<PlaybackReconnecting>());
        async.elapse(const Duration(milliseconds: 1500));
        expect(rig.engine.opened, hasLength(2));
        expect(display.current, uhd23976);

        rig.engine
          ..duration(film)
          ..firstFrame();
        async.flushMicrotasks();
        expect(rig.state, isA<PlaybackPlaying>());
        expect(display.requests, [uhd23976.id]);
        expect(rig.engine.calls.where((c) => c.startsWith('paused')), [
          'paused:true',
        ], reason: 'the new open plays by itself');
        async.elapse(const Duration(seconds: 5));
        expect(rig.state, isA<PlaybackPlaying>());
      });
    });
  });

  // From the review before dev went to main (2026-10-18).
  group('the switch and the film around it', () {
    test('a film whose length comes late is held from its first frame '
        '(no sound under "Preparing…"), then switched and played', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1, length: null);
        expect(rig.engine.calls, ['paused:true']);
        expect(rig.state, isA<PlaybackOpening>());
        async.elapse(const Duration(milliseconds: 300));
        rig.engine.duration(film);
        async.flushMicrotasks();
        expect(display.requests, [uhd23976.id]);
        expect(rig.engine.calls, [
          'paused:true',
        ], reason: 'held once, not paused again for the switch');
        async.elapse(const Duration(seconds: 4));
        expect(rig.engine.calls, ['paused:true', 'paused:false']);
        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.timelines.where((t) => t.paused), isEmpty);
      });
    });

    test('a short film whose length comes late plays as soon as it does', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1, length: null);
        async.elapse(const Duration(milliseconds: 200));
        rig.engine.duration(const Duration(minutes: 10));
        async.flushMicrotasks();
        expect(rig.engine.calls, ['paused:true', 'paused:false']);
        expect(rig.state, isA<PlaybackPlaying>());
        expect(display.requests, isEmpty);
      });
    });

    test('a film left while its length is awaited switches nothing for '
        'it; the next film switches for itself', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1, length: null);
        async.elapse(const Duration(milliseconds: 300));
        rig.coordinator.playVod(film2);
        async.flushMicrotasks();
        // The next film's length, before its first frame.
        rig.engine.duration(film);
        async.flushMicrotasks();
        expect(display.requests, isEmpty, reason: 'nothing for film 1');
        expect(rig.engine.calls.where((c) => c.startsWith('paused')), [
          'paused:true',
        ], reason: "film 1's hold only");

        rig.engine.firstFrame();
        async.flushMicrotasks();
        expect(display.requests, [uhd23976.id]);
        async.elapse(const Duration(seconds: 4));
        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.state.item, film2);
      });
    });

    test('a film that ends during the switch is lost at once: it '
        'reconnects, and its next first frame plays at the mode', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1);
        async.elapse(const Duration(milliseconds: 500));
        rig.engine.end();
        async.flushMicrotasks();
        expect(rig.state, isA<PlaybackReconnecting>());
        async.elapse(const Duration(milliseconds: 1500));
        expect(rig.engine.opened, hasLength(2));

        rig.engine
          ..duration(film)
          ..firstFrame();
        async.elapse(const Duration(seconds: 4));
        expect(rig.state, isA<PlaybackPlaying>());
        expect(display.current, uhd23976);
      });
    });
  });

  group('when it switches (decisions 1 and 2)', () {
    /// [item]'s first frame plays at once, with no pause and no request.
    void playsAsItIs(
      Playable item, {
      FakeDisplayModes? display,
      PlaybackSettings settings = const PlaybackSettings(matchFrameRate: true),
      double? fps = 23.976,
      Duration? length = film,
      String? why,
    }) {
      fakeAsync((async) {
        final screen = display ?? FakeDisplayModes();
        final rig = tv(async, screen, settings: settings);

        toFirstFrame(async, rig, item, fps: fps, length: length);

        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.engine.calls, isEmpty);
        expect(screen.requests, isEmpty);
        if (why != null) expect(rig.logLines, logged(why));
        async.elapse(const Duration(seconds: 10));
        expect(screen.requests, isEmpty);
      });
    }

    test("never a live channel at a film's rate", () {
      playsAsItIs(
        PlayableChannel(channel(1)),
        fps: 24,
        why: '24 fps is not 25 or 50',
      );
    });

    test('never a file under 15 minutes', () {
      playsAsItIs(
        film1,
        length: const Duration(minutes: 14, seconds: 59),
        why: 'Display mode left as it is: shorter than 15 minutes',
      );
    });

    test("the provider's length counts when the player has none", () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(
          async,
          rig,
          PlayableMovie(movie(3, runtime: const Duration(minutes: 90))),
          length: null,
        );
        expect(display.requests, [uhd23976.id]);
      });
      // No length at all: a second for the player to say, then it plays.
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1, length: null);
        expect(rig.state, isA<PlaybackOpening>());
        async.elapse(const Duration(seconds: 1));
        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.engine.calls, [
          'paused:true',
          'paused:false',
        ], reason: 'held while its length might come, then played');
        expect(display.requests, isEmpty);
        expect(
          rig.logLines,
          logged("Display mode left as it is: the film's length isn't known"),
        );
      });
    });

    test("the player's length a moment after the first frame counts (the "
        "Bedroom TV's order; a provider's film list has no length)", () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1, length: null);
        async.elapse(const Duration(milliseconds: 300));
        expect(display.requests, isEmpty);
        expect(rig.state, isA<PlaybackOpening>());
        rig.engine.duration(film);
        async.flushMicrotasks();
        expect(display.requests, [uhd23976.id]);
        async.elapse(const Duration(seconds: 4));
        expect(rig.state, isA<PlaybackPlaying>());
      });
    });

    test('never with the switch off, as it is by default (ADR-042)', () {
      playsAsItIs(
        film1,
        settings: const PlaybackSettings(),
        why: 'Display mode left as it is: Match frame rate is off',
      );
    });

    test('never at any rate but 23.976 or 24', () {
      for (final fps in [25.0, 29.97, 50.0, 59.94]) {
        playsAsItIs(film1, fps: fps, why: 'is not 23.976 or 24');
      }
      playsAsItIs(film1, fps: null, why: "frame rate isn't known");
    });

    test("never when the TV's own setting is Never; Seamless only, "
        "Google TV's own default, doesn't stop it (ADR-044)", () {
      playsAsItIs(
        film1,
        display: FakeDisplayModes(preference: MatchContentFrameRate.never),
        why: 'Match content frame rate is Never',
      );
      fakeAsync((async) {
        final display = FakeDisplayModes(
          preference: MatchContentFrameRate.seamlessOnly,
        );
        final rig = tv(async, display);
        toFirstFrame(async, rig, film1);
        expect(display.requests, [uhd23976.id]);
      });
    });

    test('never with no mode at that rate at the current size', () {
      playsAsItIs(
        film1,
        display: FakeDisplayModes(current: tvMode(13)),
        why: 'no 23.976 Hz mode at 1280x720',
      );
    });

    test('nothing to do when the display is there already', () {
      playsAsItIs(
        film1,
        display: FakeDisplayModes(current: uhd23976),
        why: 'Display mode already 3840x2160 23.976 Hz',
      );
    });

    test('never on the desktop: its first frame plays at once, as before', () {
      fakeAsync((async) {
        final desktop = Rig(
          frameRate: (log) =>
              FrameRateMatcher(display: const NoDisplayModes(), log: log),
        );
        desktop.coordinator.playVod(film1);
        async.flushMicrotasks();
        desktop.engine
          ..info = const StreamInfo(fps: 23.976)
          ..duration(film)
          ..firstFrame();

        expect(desktop.state, isA<PlaybackPlaying>());
        expect(desktop.engine.calls, isEmpty);
        expect(desktop.logLines, isNot(logged('Display mode')));
      });
    });
  });

  group("back to the TV's own mode (decision 4)", () {
    test('2 s after the player closes', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, film1);

        rig.coordinator.stop();
        async.elapse(const Duration(seconds: 2) - ms);
        expect(display.requests, [uhd23976.id]);
        async.elapse(ms);
        expect(display.requests, [uhd23976.id, 0]);
        expect(
          rig.logLines,
          logged(
            "Display mode asked: back to the TV's own, 3840x2160 59.94 Hz: "
            'the player closed',
          ),
        );
        async.elapse(const Duration(seconds: 2));
        expect(display.current, uhd5994);
      });
    });

    test('a next episode at the same rate keeps the mode, with no pause', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, PlayableEpisode(series, episode(1, 1)));
        rig.engine.calls.clear();

        toFirstFrame(async, rig, PlayableEpisode(series, episode(1, 2)));

        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.engine.calls.where((c) => c.startsWith('paused')), isEmpty);
        expect(display.requests, [uhd23976.id]);
        expect(
          rig.logLines,
          logged('Display mode kept at 3840x2160 23.976 Hz for a 23.976 fps'),
        );
        async.elapse(const Duration(seconds: 10));
        expect(display.requests, [uhd23976.id]);
      });
    });

    test('a film opened within the grace keeps it too', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, film1);

        rig.coordinator.stop();
        async.elapse(const Duration(seconds: 1));
        rig.engine.calls.clear();
        toFirstFrame(async, rig, film2);

        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.engine.calls.where((c) => c.startsWith('paused')), isEmpty);
        async.elapse(const Duration(seconds: 10));
        expect(display.requests, [uhd23976.id]);
      });
    });

    test('a film at 24 after one at 23.976 switches again', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, film1);

        toFirstFrame(async, rig, film2, fps: 24);
        expect(rig.state, isA<PlaybackOpening>());
        async.elapse(const Duration(seconds: 4));

        expect(display.requests, [uhd23976.id, uhd24.id]);
        expect(display.current, uhd24);
        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.logLines, logged('3840x2160 23.976 → 24 Hz'));
      });
    });

    test("a file that isn't matched after one that was goes back as part "
        'of its open', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, film1);
        rig.engine.calls.clear();

        toFirstFrame(async, rig, film2, fps: 25);
        expect(rig.engine.calls.where((c) => c.startsWith('paused')), [
          'paused:true',
        ]);
        expect(display.requests, [uhd23976.id, 0]);
        expect(rig.state, isA<PlaybackOpening>());

        async.elapse(const Duration(milliseconds: 3300));
        expect(display.current, uhd5994);
        expect(rig.state, isA<PlaybackPlaying>());
        expect(
          rig.logLines,
          logged(
            'Display mode asked: 3840x2160 23.976 → 59.94 Hz, back to the '
            "TV's own: 25 fps is not 23.976 or 24",
          ),
        );
        expect(
          rig.logLines,
          logged(
            "Display mode back to the TV's own, 3840x2160 59.94 Hz, 1.8 s "
            'after asking',
          ),
        );
      });
    });

    test('a channel takes it back at once', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, film1);

        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        expect(display.requests, [uhd23976.id, 0]);
        expect(rig.logLines, logged('a channel plays'));

        rig.engine.firstFrame();
        expect(rig.state, isA<PlaybackPlaying>());
      });
    });

    test('the app leaving the screen takes it back at once, even with '
        'nothing playing', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, film1);

        rig.coordinator.stopWhileAway();
        async.flushMicrotasks();
        expect(display.requests, [uhd23976.id, 0]);
        expect(rig.logLines, logged('the app left the screen'));
      });
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, film1);
        // The end card: nothing plays, the mode is kept for the next one.
        rig.engine.progress(film);
        rig.engine.end();
        async.flushMicrotasks();
        expect(rig.state, isA<PlaybackEnded>());
        async.elapse(const Duration(seconds: 5));
        expect(display.requests, [uhd23976.id]);

        rig.coordinator.stopWhileAway();
        async.flushMicrotasks();
        expect(display.requests, [uhd23976.id, 0]);
      });
    });
  });

  group('the log (the TV tells what it did)', () {
    test("a switch: asked, with the film's rate and the TV's own setting; "
        'then when the display shows it', () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1);
        expect(
          rig.logLines,
          logged(
            'Display mode asked: 3840x2160 59.94 → 23.976 Hz for a 23.976 '
            "fps film; the TV's Match content frame rate: Always (API 34)",
          ),
        );
        expect(rig.logLines, isNot(logged('Display mode now')));

        async.elapse(const Duration(milliseconds: 1800));
        expect(
          rig.logLines,
          logged('Display mode now 3840x2160 23.976 Hz, 1.8 s after asking'),
        );
      });
      fakeAsync((async) {
        final display = FakeDisplayModes(
          preference: MatchContentFrameRate.unknown,
        );
        final rig = tv(async, display);

        toFirstFrame(async, rig, film1);
        expect(
          rig.logLines,
          logged("the TV's Match content frame rate: not known (API 34)"),
        );
      });
    });

    test("the TV's own mode back: asked, then when the display shows it", () {
      fakeAsync((async) {
        final display = FakeDisplayModes();
        final rig = tv(async, display);
        playedThrough(async, rig, film1);

        rig.coordinator.stop();
        async.elapse(const Duration(seconds: 2));
        expect(
          rig.logLines,
          logged(
            "Display mode asked: back to the TV's own, 3840x2160 59.94 Hz: "
            'the player closed',
          ),
        );
        expect(rig.logLines, isNot(logged("Display mode back to the TV's")));

        async.elapse(const Duration(milliseconds: 1800));
        expect(
          rig.logLines,
          logged(
            "Display mode back to the TV's own, 3840x2160 59.94 Hz, 1.8 s "
            'after asking',
          ),
        );
      });
    });

    test("a display already at the TV's own mode logs no return later", () {
      fakeAsync((async) {
        // The display never switched: nothing comes back.
        final display = FakeDisplayModes()..switches = false;
        final rig = tv(async, display);
        toFirstFrame(async, rig, film1);
        async.elapse(const Duration(seconds: 6));
        rig.coordinator.stop();
        async.elapse(const Duration(seconds: 3));

        display
          ..show(uhd23976)
          ..show(uhd5994);
        expect(rig.logLines, isNot(logged("Display mode back to the TV's")));
      });
    });
  });

  test('a display that reports the mode under another id has still '
      'switched to it: the film plays after the settle, not after 5 s', () {
    fakeAsync((async) {
      final display = FakeDisplayModes()..switches = false;
      final rig = tv(async, display);

      toFirstFrame(async, rig, film1);
      async.elapse(const Duration(seconds: 1));
      display.show(
        const DisplayMode(
          id: 99,
          width: 3840,
          height: 2160,
          refreshRate: 23.976025,
        ),
      );
      async.elapse(const Duration(milliseconds: 1500));

      expect(rig.state, isA<PlaybackPlaying>());
      expect(rig.logLines, isNot(logged('no change within')));
    });
  });

  group('a channel at 25 or 50 fps (ADR-044)', () {
    final one = PlayableChannel(channel(1));
    final two = PlayableChannel(channel(2));
    final three = PlayableChannel(channel(3));

    test('plays at once, and the display is asked for 50 Hz meanwhile, '
        'with no pause', () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung();
        final rig = tv(async, display, settings: const PlaybackSettings());

        toFirstFrame(async, rig, one, fps: 50);
        expect(rig.state, isA<PlaybackPlaying>(), reason: 'nothing waits');
        expect(rig.engine.calls, isEmpty, reason: 'no pause');
        expect(display.requests, [samsung50.id]);
        expect(
          rig.logLines,
          logged(
            'Display mode asked: 3840x2160 59.94 Hz → 50 Hz for a 50 fps '
            "channel; the TV's Match content frame rate: Seamless only",
          ),
        );

        async.elapse(const Duration(milliseconds: 1800));
        expect(display.current, samsung50);
        expect(
          rig.logLines,
          logged('Display mode now 3840x2160 50 Hz, 1.8 s after asking'),
        );
      });
    });

    test('the next channel at 25 or 50 keeps it: no request, no dark '
        'screen between channels', () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung();
        final rig = tv(async, display, settings: const PlaybackSettings());
        toFirstFrame(async, rig, one, fps: 50);
        async.elapse(const Duration(seconds: 3));

        toFirstFrame(async, rig, two, fps: 25);
        async.elapse(const Duration(seconds: 3));
        // A stop between two channels, as a one-connection source has.
        rig.coordinator.stop();
        async.elapse(const Duration(milliseconds: 500));
        toFirstFrame(async, rig, one, fps: 50);
        async.elapse(const Duration(seconds: 10));

        expect(display.requests, [samsung50.id]);
        expect(display.current, samsung50);
        final kept = rig.logLines
            .where((l) => l.contains('Display mode kept at'))
            .map((l) => l.substring(l.indexOf('Display')))
            .toList();
        expect(kept, [
          'Display mode kept at 3840x2160 50 Hz for a 25 fps channel',
          'Display mode kept at 3840x2160 50 Hz for a 50 fps channel',
        ], reason: 'a zap through channels at one rate logs it once');
      });
    });

    test("a channel at another rate takes the TV's own back", () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung();
        final rig = tv(async, display, settings: const PlaybackSettings());
        toFirstFrame(async, rig, one, fps: 50);
        async.elapse(const Duration(seconds: 3));

        toFirstFrame(async, rig, three, fps: 29.97);
        expect(rig.state, isA<PlaybackPlaying>());
        expect(display.requests, [samsung50.id, 0]);
        async.elapse(const Duration(seconds: 3));
        expect(display.current, samsung5994);
        expect(rig.logLines, logged('29.97 fps is not 25 or 50'));
      });
    });

    test("Live TV closing lets it go after the grace, as a film's", () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung();
        final rig = tv(async, display, settings: const PlaybackSettings());
        toFirstFrame(async, rig, one, fps: 25);
        async.elapse(const Duration(seconds: 3));

        rig.coordinator.stop();
        async.elapse(const Duration(milliseconds: 1900));
        expect(display.requests, [samsung50.id]);
        async.elapse(const Duration(milliseconds: 200));
        expect(display.requests, [samsung50.id, 0]);
        expect(rig.logLines, logged('the player closed'));
      });
    });

    test("a film after it goes back to the TV's own as part of its open "
        '(films unmatched by default)', () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung();
        final rig = tv(async, display, settings: const PlaybackSettings());
        toFirstFrame(async, rig, one, fps: 50);
        async.elapse(const Duration(seconds: 3));

        toFirstFrame(async, rig, film1);
        expect(rig.state, isA<PlaybackOpening>(), reason: 'Preparing…');
        expect(display.requests, [samsung50.id, 0]);
        async.elapse(const Duration(seconds: 4));
        expect(display.current, samsung5994);
        expect(rig.state, isA<PlaybackPlaying>());
      });
    });

    test('a film matched after it moves from 50 Hz to its own rate, and '
        "back to the TV's own after", () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung();
        final rig = tv(async, display);
        toFirstFrame(async, rig, one, fps: 50);
        async.elapse(const Duration(seconds: 3));

        toFirstFrame(async, rig, film1);
        async.elapse(const Duration(seconds: 4));
        expect(display.current, samsung23976);
        rig.coordinator.stop();
        async.elapse(const Duration(seconds: 5));
        expect(display.requests, [samsung50.id, samsung23976.id, 0]);
        expect(display.current, samsung5994);
      });
    });

    test("never with the switch off, on a TV with no 50 Hz, or the TV's "
        'own set to Never', () {
      void plainly(
        FakeDisplayModes display,
        PlaybackSettings settings,
        String why,
      ) {
        fakeAsync((async) {
          final rig = tv(async, display, settings: settings);
          toFirstFrame(async, rig, one, fps: 50);
          expect(rig.state, isA<PlaybackPlaying>());
          async.elapse(const Duration(seconds: 6));
          expect(display.requests, isEmpty, reason: why);
          expect(rig.logLines, logged(why));
        });
      }

      plainly(
        FakeDisplayModes.samsung(),
        const PlaybackSettings(matchChannelRate: false),
        'Match frame rate for channels is off',
      );
      plainly(
        FakeDisplayModes(),
        const PlaybackSettings(),
        'no 50 Hz mode at 3840x2160',
      );
      plainly(
        FakeDisplayModes.samsung(preference: MatchContentFrameRate.never),
        const PlaybackSettings(),
        "the TV's Match content frame rate is Never",
      );
    });

    test('a rate mpv knows only a moment after the first frame', () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung();
        final rig = tv(async, display, settings: const PlaybackSettings());
        toFirstFrame(async, rig, one, fps: null);
        async.elapse(const Duration(milliseconds: 300));
        rig.engine.info = const StreamInfo(width: 1920, height: 1080, fps: 25);
        async.elapse(const Duration(milliseconds: 500));
        expect(display.requests, [samsung50.id]);
      });
    });

    test("a display that doesn't switch is warned of once and not asked "
        'again', () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung()..switches = false;
        final rig = tv(async, display, settings: const PlaybackSettings());
        toFirstFrame(async, rig, one, fps: 50);
        async.elapse(const Duration(seconds: 6));
        expect(
          rig.logLines,
          logged(
            'Display mode 3840x2160 50 Hz: no change within 5 s, the '
            'channel plays on as it is',
          ),
        );
        toFirstFrame(async, rig, two, fps: 50);
        async.elapse(const Duration(seconds: 6));
        expect(display.requests, [samsung50.id]);
        expect(rig.state, isA<PlaybackPlaying>());
      });
    });

    test('the app leaving the screen takes it back at once', () {
      fakeAsync((async) {
        final display = FakeDisplayModes.samsung();
        final rig = tv(async, display, settings: const PlaybackSettings());
        toFirstFrame(async, rig, one, fps: 50);
        async.elapse(const Duration(seconds: 3));
        rig.coordinator.stopWhileAway();
        async.flushMicrotasks();
        expect(display.requests, [samsung50.id, 0]);
      });
    });
  });
}
