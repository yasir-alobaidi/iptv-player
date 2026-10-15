// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/tv_away.dart';

import 'support/playback_fakes.dart';

/// docs/07 "Lifecycle": on a TV, what plays stops while the app is off
/// the screen and plays again when it is back. The Bedroom TV showed why:
/// after the remote's Home the stream went on at 2 MB/s behind the
/// launcher, holding a one-connection source.
void main() {
  void films(FakeAsync async, Rig rig, {required int seconds}) {
    rig.engine
      ..duration(const Duration(minutes: 10))
      ..firstFrame();
    for (var s = 1; s <= seconds; s++) {
      rig.engine.progress(Duration(seconds: s));
      async.elapse(const Duration(seconds: 1));
    }
  }

  test('a channel stops while away and plays again on return', () {
    fakeAsync((async) {
      final rig = Rig();
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      rig.engine.firstFrame();

      rig.coordinator.stopWhileAway();
      async.flushMicrotasks();
      expect(rig.engine.calls, ['stop']);
      expect(rig.state, isA<PlaybackIdle>());

      rig.coordinator.resumeAfterAway();
      async.flushMicrotasks();
      expect(rig.engine.opened.map((r) => r.url), [
        'http://fake/live/u/p/k1.ts',
        'http://fake/live/u/p/k1.ts',
      ]);
      expect(rig.state.item, PlayableChannel(channel(1)));
    });
  });

  test('a film plays again from where it was', () {
    fakeAsync((async) {
      final rig = Rig();
      rig.coordinator.playVod(PlayableMovie(movie(1)));
      async.flushMicrotasks();
      films(async, rig, seconds: 30);

      rig.coordinator.stopWhileAway();
      async.flushMicrotasks();
      rig.coordinator.resumeAfterAway();
      async.flushMicrotasks();

      expect(rig.engine.opened.last.start, const Duration(seconds: 30));
      expect(rig.engine.calls, isNot(contains('paused:true')));
    });
  });

  test('a paused film comes back paused', () {
    fakeAsync((async) {
      final rig = Rig();
      rig.coordinator.playVod(PlayableMovie(movie(1)));
      async.flushMicrotasks();
      films(async, rig, seconds: 30);
      rig.coordinator.setPaused(paused: true);
      async.flushMicrotasks();
      rig.engine.calls.clear();

      rig.coordinator.stopWhileAway();
      async.flushMicrotasks();
      rig.coordinator.resumeAfterAway();
      async.flushMicrotasks();
      expect(rig.engine.calls, ['stop']);

      rig.engine.firstFrame();
      async.flushMicrotasks();
      expect(rig.engine.calls, ['stop', 'paused:true']);
      expect(rig.engine.opened.last.start, const Duration(seconds: 30));
    });
  });

  test('a failure stays as it was, and nothing plays on return', () {
    fakeAsync((async) {
      final rig = Rig()..resolver.failure = NetworkFailure('down');
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      expect(rig.state, isA<PlaybackFailed>());

      rig.coordinator.stopWhileAway();
      rig.coordinator.resumeAfterAway();
      async.flushMicrotasks();
      expect(rig.engine.calls, isEmpty);
      expect(rig.state, isA<PlaybackFailed>());
    });
  });

  test('something else started meanwhile is left playing', () {
    fakeAsync((async) {
      final rig = Rig();
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      rig.engine.firstFrame();
      rig.coordinator.stopWhileAway();
      async.flushMicrotasks();

      rig.coordinator.playLive(channel(2));
      async.flushMicrotasks();
      rig.coordinator.resumeAfterAway();
      async.flushMicrotasks();

      expect(rig.engine.opened.last.url, 'http://fake/live/u/p/k2.ts');
      expect(rig.state.item, PlayableChannel(channel(2)));
    });
  });

  group('the TV observer', () {
    test('hidden is away, resumed is back; a system dialog over the app '
        '(inactive) changes nothing', () {
      fakeAsync((async) {
        final rig = Rig();
        final observer = TvAwayObserver(rig.coordinator);
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.engine.firstFrame();

        observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
        async.flushMicrotasks();
        expect(rig.engine.calls, isEmpty);

        // Home on the remote: inactive, hidden, paused.
        observer
          ..didChangeAppLifecycleState(AppLifecycleState.hidden)
          ..didChangeAppLifecycleState(AppLifecycleState.paused);
        async.flushMicrotasks();
        expect(rig.engine.calls, ['stop']);

        // And back: hidden, inactive, resumed.
        observer
          ..didChangeAppLifecycleState(AppLifecycleState.hidden)
          ..didChangeAppLifecycleState(AppLifecycleState.inactive)
          ..didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(rig.engine.opened, hasLength(2));
        expect(rig.state.item, PlayableChannel(channel(1)));
      });
    });
  });
}
