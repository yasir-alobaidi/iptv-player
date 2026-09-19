// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import 'support/playback_fakes.dart';

void main() {
  /// Plays channel 1 up to its first frame.
  Rig playing(FakeAsync async) {
    final rig = Rig();
    rig.coordinator.playLive(channel(1));
    async.flushMicrotasks();
    rig.engine.firstFrame();
    return rig;
  }

  /// Advances [seconds] with the position moving every second.
  void advancing(FakeAsync async, Rig rig, int seconds, {int from = 0}) {
    for (var s = 1; s <= seconds; s++) {
      rig.engine.progress(Duration(seconds: from + s));
      async.elapse(const Duration(seconds: 1));
    }
  }

  test('no picture within the open timeout → reconnect; the URL is built '
      'again; a first frame resets the count', () {
    fakeAsync((async) {
      final rig = Rig();
      rig.coordinator.playLive(channel(1));
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 12));
      final reconnecting = rig.state as PlaybackReconnecting;
      expect(reconnecting.attempt, 1);
      expect(reconnecting.maxAttempts, 6);
      expect(reconnecting.problem.kind, PlaybackProblemKind.network);

      async.elapse(const Duration(seconds: 1));
      expect(rig.resolver.resolved, hasLength(2));
      expect(rig.engine.opened, hasLength(2));
      rig.engine.firstFrame();
      expect(rig.state, isA<PlaybackPlaying>());
      // History once, not per reconnect.
      expect(rig.history.recorded, ['k1']);
    });
  });

  test('a picture that stops moving for 8 s is a stall', () {
    fakeAsync((async) {
      final rig = playing(async);
      advancing(async, rig, 20);
      expect(rig.state, isA<PlaybackPlaying>());

      async.elapse(const Duration(seconds: 7));
      expect(rig.state, isA<PlaybackPlaying>());
      async.elapse(const Duration(seconds: 1));
      expect(rig.state, isA<PlaybackReconnecting>());
      expect(
        (rig.state as PlaybackReconnecting).problem.detail,
        contains('stalled'),
      );
    });
  });

  test('buffering is given 15 s; resuming in time is fine', () {
    fakeAsync((async) {
      final rig = playing(async);
      rig.engine.buffering(on: true);
      async.elapse(const Duration(seconds: 10));
      rig.engine.buffering(on: false);
      advancing(async, rig, 10);
      expect(rig.state, isA<PlaybackPlaying>());

      rig.engine.buffering(on: true);
      async.elapse(const Duration(seconds: 15));
      expect(rig.state, isA<PlaybackReconnecting>());
    });
  });

  test('a live stream that ends is a drop: reconnect', () {
    fakeAsync((async) {
      final rig = playing(async);
      rig.engine.end();
      expect(rig.state, isA<PlaybackReconnecting>());
    });
  });

  test('backoff 1, 2, 4, 8, 15, 30 s, then failed after 6 attempts', () {
    fakeAsync((async) {
      final rig = Rig();
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      final opens = <Duration>[];
      var last = rig.engine.opened.length;
      final start = async.elapsed;
      // Every open fails at once.
      for (var i = 0; i < 7; i++) {
        rig.engine.fail();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 31));
        if (rig.engine.opened.length > last) {
          last = rig.engine.opened.length;
          opens.add(async.elapsed - start);
        }
      }
      final failed = rig.state as PlaybackFailed;
      expect(failed.attempts, 6);
      expect(rig.engine.opened, hasLength(7));
      expect(rig.prober.details.first, 'Failed to open');
      expect(rig.engine.playing, isFalse);
    });
  });

  test('the waits between attempts follow docs/03', () {
    fakeAsync((async) {
      final rig = Rig();
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      final waits = <int>[];
      for (var i = 0; i < 6; i++) {
        final before = rig.engine.opened.length;
        rig.engine.fail();
        async.flushMicrotasks();
        var waited = 0;
        while (rig.engine.opened.length == before && waited < 40) {
          async.elapse(const Duration(seconds: 1));
          waited++;
        }
        waits.add(waited);
      }
      expect(waits, [1, 2, 4, 8, 15, 30]);
    });
  });

  test('a refusal that retrying cannot fix fails at once', () {
    for (final kind in [
      PlaybackProblemKind.auth,
      PlaybackProblemKind.offline,
      PlaybackProblemKind.unsupported,
    ]) {
      fakeAsync((async) {
        final rig = Rig()
          ..prober.next = PlaybackProblem(
            kind,
            failure: NotFoundFailure('stream: HTTP 404', 404),
          );
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.engine.fail();
        async.flushMicrotasks();

        final failed = rig.state as PlaybackFailed;
        expect(failed.problem.kind, kind);
        expect(failed.attempts, 0);
        async.elapse(const Duration(minutes: 1));
        expect(rig.engine.opened, hasLength(1), reason: kind.name);
      });
    }
  });

  test('a full account is tried three times, not six', () {
    fakeAsync((async) {
      final rig = Rig()
        ..prober.next = const PlaybackProblem(
          PlaybackProblemKind.connectionLimit,
        );
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      for (var i = 0; i < 4; i++) {
        rig.engine.fail();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 31));
      }

      final failed = rig.state as PlaybackFailed;
      expect(failed.problem.kind, PlaybackProblemKind.connectionLimit);
      expect(failed.attempts, 3);
    });
  });

  test('zapping away mid-backoff drops the old retry', () {
    fakeAsync((async) {
      final rig = playing(async);
      rig.engine.end();
      expect(rig.state, isA<PlaybackReconnecting>());

      rig.coordinator.playLive(channel(2));
      async.flushMicrotasks();
      rig.engine.firstFrame();
      async.elapse(const Duration(seconds: 40));

      // Channel 1 was never tried again after the zap (channel 2, which
      // never moves here, is retried as a stall: that's its own watchdog).
      expect(rig.resolver.resolved.where((c) => c.id == 1), hasLength(1));
      expect(rig.state.channel?.id, 2);
    });
  });

  test('Retry after a failure starts over', () {
    fakeAsync((async) {
      final rig = Rig()
        ..prober.next = const PlaybackProblem(PlaybackProblemKind.offline);
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      rig.engine.fail();
      async.flushMicrotasks();
      expect(rig.state, isA<PlaybackFailed>());

      rig.coordinator.retry();
      async.flushMicrotasks();
      expect(rig.state, isA<PlaybackOpening>());
      rig.engine.firstFrame();
      expect(rig.state, isA<PlaybackPlaying>());
    });
  });
}
