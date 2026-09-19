// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import 'support/playback_fakes.dart';

void main() {
  group('connection policy', () {
    test('a one-connection source: the old stream closes before the new '
        'one opens', () {
      fakeAsync((async) {
        final rig = Rig(stopDelay: const Duration(milliseconds: 300));
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.engine.firstFrame();

        rig.coordinator.playLive(channel(2));
        async.flushMicrotasks();
        // Waiting for the close: not opened yet.
        expect(rig.engine.calls, ['stop']);
        expect(rig.engine.opened, hasLength(1));

        async.elapse(const Duration(milliseconds: 300));
        expect(rig.engine.opened.map((r) => r.url), [
          'http://fake/live/u/p/k1.ts',
          'http://fake/live/u/p/k2.ts',
        ]);
      });
    });

    test('a source with room for two just replaces the stream', () {
      fakeAsync((async) {
        final rig = Rig()..resolver.maxConnections = 2;
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.engine.firstFrame();

        rig.coordinator.playLive(channel(2));
        async.flushMicrotasks();

        expect(rig.engine.calls, isEmpty);
        expect(rig.engine.opened, hasLength(2));
      });
    });

    test('another source needs no close first, even at one connection', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.coordinator.playLive(channel(2, source: 'other'));
        async.flushMicrotasks();

        expect(rig.engine.calls, isEmpty);
        expect(rig.engine.opened, hasLength(2));
      });
    });
  });

  group('states and history', () {
    test('opening, then playing on the first frame; history once', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        expect(rig.state, isA<PlaybackOpening>());

        rig.engine.firstFrame();
        expect(rig.state, isA<PlaybackPlaying>());
        rig.engine
          ..buffering(on: true)
          ..buffering(on: false);
        expect(rig.history.recorded, ['k1']);
        expect(
          rig.states.whereType<PlaybackPlaying>().map((s) => s.buffering),
          [false, true, false],
        );
      });
    });

    test('a first frame from the previous open is ignored', () {
      fakeAsync((async) {
        final rig = Rig()..resolver.maxConnections = 2;
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        final old = rig.engine.generation;
        rig.coordinator.playLive(channel(2));
        async.flushMicrotasks();

        rig.engine.emit(PlayerFirstFrame(old));

        expect(rig.state, isA<PlaybackOpening>());
      });
    });

    test('the previous channel, then from history on a fresh start', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.engine.firstFrame();
        rig.coordinator.playLive(channel(2));
        async.flushMicrotasks();

        expect(rig.coordinator.previous?.id, 1);
        ChannelItem? last;
        rig.coordinator.lastChannel('src').then((c) => last = c);
        async.flushMicrotasks();
        expect(last?.id, 1);

        final fresh = Rig();
        fresh.history.recorded.addAll(['k7', 'k9']);
        fresh.channels.byKey['k7'] = channel(7);
        fresh.channels.byKey['k9'] = channel(9);
        fresh.coordinator.lastChannel('src').then((c) => last = c);
        async.flushMicrotasks();
        expect(last?.id, 9);
      });
    });

    test('a stream that cannot be built fails at once, with the reason', () {
      fakeAsync((async) {
        final rig = Rig()..resolver.failure = SecureStorageFailure('locked');
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();

        final failed = rig.state as PlaybackFailed;
        expect(failed.problem.kind, PlaybackProblemKind.unavailable);
        expect(failed.problem.failure, isA<SecureStorageFailure>());
        expect(rig.engine.opened, isEmpty);
      });
    });

    test('stop lets go and goes idle', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.coordinator.playLive(channel(1));
        async.flushMicrotasks();
        rig.coordinator.stop();
        async.flushMicrotasks();

        expect(rig.state, isA<PlaybackIdle>());
        expect(rig.engine.playing, isFalse);
      });
    });
  });
}
