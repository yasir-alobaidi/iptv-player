// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

import 'support/playback_fakes.dart';

/// Phase 5 decision 1: a movie or an episode on the one coordinator.
void main() {
  const minute = Duration(minutes: 1);
  const length = Duration(minutes: 10);

  /// Plays movie 1 (from [from]) up to its first frame, with the player
  /// reporting a length of [length].
  Rig playing(FakeAsync async, {Duration? from, Rig? rig}) {
    final r = rig ?? Rig();
    r.coordinator.playVod(PlayableMovie(movie(1)), from: from);
    async.flushMicrotasks();
    r.engine
      ..duration(length)
      ..firstFrame();
    return r;
  }

  /// [seconds] of playing, the position moving with the clock.
  void advancing(FakeAsync async, Rig rig, int seconds, {required int from}) {
    for (var s = 1; s <= seconds; s++) {
      rig.engine.progress(Duration(seconds: from + s));
      async.elapse(const Duration(seconds: 1));
    }
  }

  group('opening', () {
    test('a movie opens as a file, from where it was left', () {
      fakeAsync((async) {
        final rig = playing(async, from: const Duration(minutes: 3));

        final request = rig.engine.opened.single;
        expect(request.live, isFalse);
        expect(request.start, const Duration(minutes: 3));
        expect(request.url, 'http://fake/movie/u/p/m1.mkv');
        expect(rig.state, isA<PlaybackPlaying>());
        expect(rig.state.item, PlayableMovie(movie(1)));
        expect(rig.state.channel, isNull, reason: 'Live TV sees no channel');
        expect(rig.coordinator.current, isNull);
        expect(rig.coordinator.startedFrom, const Duration(minutes: 3));
        expect(rig.coordinator.timeline.position, const Duration(minutes: 3));
        expect(rig.coordinator.timeline.duration, length);
        // Live history is for channels.
        expect(rig.history.recorded, isEmpty);
      });
    });

    test('from nothing or zero is the start', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playVod(PlayableMovie(movie(1)));
        async.flushMicrotasks();
        rig.coordinator.playVod(PlayableMovie(movie(1)), from: Duration.zero);
        async.flushMicrotasks();

        expect(rig.engine.opened.map((r) => r.start), [null, null]);
        expect(rig.coordinator.startedFrom, isNull);
      });
    });

    test('an episode opens its own file; the length falls back to the '
        "provider's until the player knows it", () {
      fakeAsync((async) {
        final rig = Rig();
        final e = episode(2, 4, duration: const Duration(minutes: 49));
        rig.coordinator.playVod(PlayableEpisode(series, e));
        async.flushMicrotasks();

        expect(rig.engine.opened.single.url, 'http://fake/series/u/p/e24.mp4');
        expect(rig.coordinator.timeline.duration, const Duration(minutes: 49));
        rig.engine.duration(const Duration(minutes: 48, seconds: 30));
        expect(
          rig.coordinator.timeline.duration,
          const Duration(minutes: 48, seconds: 30),
        );
      });
    });

    test('a live preview on a one-connection source is closed before the '
        'movie opens', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.engine.firstFrame();
        rig.engine.sequence.clear();

        rig.coordinator.playVod(PlayableMovie(movie(1)));
        async.flushMicrotasks();

        expect(rig.engine.sequence, ['stop', 'open']);
      });
    });

    test('a source allowing two streams opens the movie over the preview', () {
      fakeAsync((async) {
        final rig = Rig()..resolver.maxConnections = 2;
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.engine.firstFrame();
        rig.engine.sequence.clear();

        rig.coordinator.playVod(PlayableMovie(movie(1)));
        async.flushMicrotasks();

        expect(rig.engine.sequence, ['open']);
      });
    });
  });

  group('saving where it was left', () {
    test('every 10 s while playing', () {
      fakeAsync((async) {
        final rig = playing(async);
        advancing(async, rig, 25, from: 0);

        expect(rig.progress.saves.map((s) => s.position.inSeconds), [10, 20]);
        expect(rig.progress.saves.first.ref, movie(1).ref);
        expect(rig.progress.saves.first.duration, length);
      });
    });

    test('on pause at once, and not again while paused', () {
      fakeAsync((async) {
        final rig = playing(async);
        advancing(async, rig, 4, from: 0);
        rig.coordinator.setPaused(paused: true);
        async.flushMicrotasks();

        expect(rig.progress.saves.map((s) => s.position.inSeconds), [4]);
        expect(rig.coordinator.timeline.paused, isTrue);
        async.elapse(const Duration(minutes: 1));
        expect(rig.progress.saves, hasLength(1));

        rig.coordinator.setPaused(paused: false);
        async.flushMicrotasks();
        expect(rig.coordinator.timeline.paused, isFalse);
        // The count goes on from before the pause: 6 s more makes 10.
        advancing(async, rig, 6, from: 4);
        expect(rig.progress.saves.map((s) => s.position.inSeconds), [4, 10]);
      });
    });

    test('after a seek, at the new position', () {
      fakeAsync((async) {
        final rig = playing(async);
        advancing(async, rig, 3, from: 0);
        rig.coordinator.seek(const Duration(minutes: 5));
        async.flushMicrotasks();

        expect(rig.engine.calls, contains('seek:300000'));
        expect(rig.progress.lastPosition, const Duration(minutes: 5));
        expect(rig.coordinator.timeline.position, const Duration(minutes: 5));
      });
    });

    test('on leaving, before the stop completes', () {
      fakeAsync((async) {
        final rig = playing(async);
        advancing(async, rig, 7, from: 60);
        var stopped = false;
        rig.coordinator.stop().then((_) => stopped = true);
        async.flushMicrotasks();

        expect(stopped, isTrue);
        expect(rig.progress.lastPosition, const Duration(seconds: 67));
        expect(rig.state, isA<PlaybackIdle>());
      });
    });

    test('when something else starts', () {
      fakeAsync((async) {
        final rig = playing(async);
        advancing(async, rig, 7, from: 60);
        rig.coordinator.playVod(PlayableMovie(movie(2)));
        async.flushMicrotasks();

        expect(rig.progress.saves.single.ref, movie(1).ref);
        expect(rig.progress.lastPosition, const Duration(seconds: 67));
      });
    });

    test('not when it never showed a picture', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playVod(
          PlayableMovie(movie(1)),
          from: const Duration(minutes: 3),
        );
        async.flushMicrotasks();
        rig.coordinator.stop();
        async.flushMicrotasks();

        expect(rig.progress.saves, isEmpty);
      });
    });
  });

  group('the end', () {
    test('at the end of the file: ended, saved at its length, and the '
        'connection let go', () {
      fakeAsync((async) {
        final rig = playing(async);
        rig.coordinator.seek(length - const Duration(seconds: 3));
        async.flushMicrotasks();
        advancing(async, rig, 3, from: length.inSeconds - 3);
        rig.engine.sequence.clear();
        rig.engine.end();
        async.flushMicrotasks();

        expect(rig.state, isA<PlaybackEnded>());
        expect(rig.progress.lastPosition, length);
        expect(rig.progress.saves.last.duration, length);
        expect(isComplete(length, length), isTrue);
        expect(rig.engine.sequence, ['stop']);
        // Leaving the end card saves nothing more.
        final saves = rig.progress.saves.length;
        rig.coordinator.stop();
        async.flushMicrotasks();
        expect(rig.progress.saves, hasLength(saves));
      });
    });

    test('an end well before the length is a drop: back where it was, with '
        'the URL built again', () {
      fakeAsync((async) {
        final rig = playing(async);
        advancing(async, rig, 30, from: 120);
        rig.engine.end();

        final reconnecting = rig.state as PlaybackReconnecting;
        expect(reconnecting.problem.detail, contains('ended'));
        async.elapse(const Duration(seconds: 1));
        expect(rig.resolver.resolvedFiles, ['m1', 'm1']);
        expect(rig.engine.opened.last.start, const Duration(seconds: 150));
        rig.engine.firstFrame();
        expect(rig.state, isA<PlaybackPlaying>());
        // Not "Resumed from": the player came back on its own.
        expect(rig.coordinator.startedFrom, isNull);
      });
    });

    test('an end with no length known is the end', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playVod(PlayableMovie(movie(1)));
        async.flushMicrotasks();
        rig.engine.firstFrame();
        advancing(async, rig, 5, from: 0);
        rig.engine.end();

        expect(rig.state, isA<PlaybackEnded>());
        expect(rig.progress.lastPosition, const Duration(seconds: 5));
      });
    });
  });

  group('the watchdog', () {
    test('a paused file is never a stall', () {
      fakeAsync((async) {
        final rig = playing(async);
        advancing(async, rig, 3, from: 0);
        rig.coordinator.setPaused(paused: true);
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 5));
        expect(rig.state, isA<PlaybackPlaying>());

        // Playing again, it is watched again.
        rig.coordinator.setPaused(paused: false);
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 8));
        expect(rig.state, isA<PlaybackReconnecting>());
        expect(rig.engine.opened.last.start, isNull, reason: 'not yet');
        async.elapse(const Duration(seconds: 1));
        expect(rig.engine.opened.last.start, const Duration(seconds: 3));
      });
    });

    test('a file that stalls reconnects where it was', () {
      fakeAsync((async) {
        final rig = playing(async, from: const Duration(minutes: 2));
        advancing(async, rig, 5, from: 120);
        async.elapse(const Duration(seconds: 9));

        expect(rig.state, isA<PlaybackReconnecting>());
        expect(rig.engine.opened.last.start, const Duration(seconds: 125));
      });
    });

    test('a refusal that retrying cannot fix fails; where it was is kept, '
        'and Retry goes back there', () {
      fakeAsync((async) {
        final rig = Rig()
          ..prober.next = PlaybackProblem(
            PlaybackProblemKind.offline,
            failure: NotFoundFailure('stream: HTTP 404', 404),
          );
        playing(async, rig: rig);
        advancing(async, rig, 12, from: 30);
        rig.engine.fail();
        async.flushMicrotasks();

        final failed = rig.state as PlaybackFailed;
        expect(failed.item, PlayableMovie(movie(1)));
        expect(failed.problem.kind, PlaybackProblemKind.offline);
        expect(rig.progress.lastPosition, const Duration(seconds: 42));

        rig.coordinator.retry();
        async.flushMicrotasks();
        expect(rig.engine.opened.last.start, const Duration(seconds: 42));
      });
    });
  });

  group('seeking', () {
    test('stays within the file', () {
      fakeAsync((async) {
        final rig = playing(async);
        rig.coordinator.seek(const Duration(seconds: -30));
        async.flushMicrotasks();
        rig.coordinator.seek(const Duration(hours: 2));
        async.flushMicrotasks();

        expect(rig.engine.calls.where((c) => c.startsWith('seek')), [
          'seek:0',
          'seek:${length.inMilliseconds}',
        ]);
      });
    });

    test("a report from before the seek landed doesn't move the bar back", () {
      fakeAsync((async) {
        final rig = playing(async);
        advancing(async, rig, 2, from: 0);
        rig.coordinator.seek(const Duration(minutes: 5));
        async.flushMicrotasks();
        rig.engine.progress(const Duration(seconds: 3));
        expect(rig.coordinator.timeline.position, const Duration(minutes: 5));

        rig.engine.progress(const Duration(minutes: 5, seconds: 1));
        expect(
          rig.coordinator.timeline.position,
          const Duration(minutes: 5, seconds: 1),
        );
      });
    });

    test('does nothing to live, or before the picture', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playVod(PlayableMovie(movie(1)));
        async.flushMicrotasks();
        rig.coordinator
          ..seek(minute)
          ..setPaused(paused: true);
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.engine.firstFrame();
        rig.coordinator
          ..seek(minute)
          ..setPaused(paused: true);
        async.flushMicrotasks();

        expect(
          rig.engine.calls.where(
            (c) => c.startsWith('seek') || c.startsWith('paused'),
          ),
          isEmpty,
        );
      });
    });
  });
}
