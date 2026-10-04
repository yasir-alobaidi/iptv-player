// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import 'support/playback_fakes.dart';

/// What each play tells "You're offline" (Phase 8 decision 11).
void main() {
  final item = PlayableChannel(channel(1));

  PlaybackFailed failed(AppFailure? failure) => PlaybackFailed(
    item,
    PlaybackProblem(PlaybackProblemKind.network, failure: failure),
  );

  test("a source's picture, or any HTTP answer, is an answer; the prober "
      'reaching nothing is none', () {
    expect(sourceAnswered(PlaybackPlaying(item), local: false), isTrue);
    expect(
      sourceAnswered(failed(NetworkFailure('stream: no answer')), local: false),
      isFalse,
    );
    expect(
      sourceAnswered(
        PlaybackReconnecting(
          item,
          attempt: 1,
          maxAttempts: 6,
          problem: PlaybackProblem(
            PlaybackProblemKind.network,
            failure: NetworkFailure('stream: no answer'),
          ),
        ),
        local: false,
      ),
      isFalse,
    );
    expect(
      sourceAnswered(
        failed(NetworkFailure('stream: HTTP 503', 503)),
        local: false,
      ),
      isTrue,
    );
    expect(
      sourceAnswered(
        PlaybackFailed(
          item,
          PlaybackProblem(
            PlaybackProblemKind.auth,
            failure: AuthFailure('stream: HTTP 401', 401),
          ),
        ),
        local: false,
      ),
      isTrue,
    );
  });

  test('a stall, an open, and a file on this computer say nothing', () {
    expect(sourceAnswered(failed(null), local: false), isNull);
    expect(sourceAnswered(PlaybackOpening(item), local: false), isNull);
    expect(sourceAnswered(const PlaybackIdle(), local: false), isNull);
    expect(sourceAnswered(PlaybackPlaying(item), local: true), isNull);
    expect(
      sourceAnswered(failed(NetworkFailure('no answer')), local: true),
      isNull,
    );
  });

  test('wired up: where the system says nothing, a channel no one answers '
      'makes the app offline, and its picture online again', () {
    fakeAsync((async) {
      final rig = Rig();
      final container = ProviderContainer(
        overrides: [
          playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
          systemNetworkProvider.overrideWithValue(const NoSystemNetwork()),
        ],
      );
      final status = container.read(networkStatusProvider);
      container.read(playbackReachabilityProvider);
      async.flushMicrotasks();

      rig.prober.next = PlaybackProblem(
        PlaybackProblemKind.network,
        failure: NetworkFailure('stream: no answer'),
      );
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      rig.engine.fail();
      async.flushMicrotasks();
      expect(rig.state, isA<PlaybackReconnecting>());
      async.elapse(const Duration(seconds: 3));
      expect(status.offline, isTrue);

      // The retry gets through.
      async.elapse(const Duration(seconds: 2));
      rig.engine.firstFrame();
      async.flushMicrotasks();
      expect(rig.state, isA<PlaybackPlaying>());
      expect(status.offline, isFalse);

      rig.coordinator.stop();
      async.flushMicrotasks();
      container.dispose();
      async.flushMicrotasks();
    });
  });
}
