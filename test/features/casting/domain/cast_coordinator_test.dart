import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/cast_subtitles.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';

import '../../playback/support/playback_fakes.dart';
import '../support/cast_fakes.dart';

/// From [low] to [high], both included.
Matcher _between(Duration low, Duration high) =>
    allOf(greaterThanOrEqualTo(low), lessThanOrEqualTo(high));

void main() {
  late CastRig rig;

  setUp(() => rig = CastRig());
  tearDown(() => rig.dispose());

  /// Casts [channel(1)] from nothing playing, until the TV plays it.
  Future<void> castChannel({int id = 1}) async {
    await rig.coordinator.connect(tvDevice);
    await rig.phase(CastPhase.idle);
    unawaited(rig.playback.coordinator.playLive(channel(id)));
    await rig.loaded(rig.tv.loads.length + 1);
    rig.tv.playing();
    await rig.phase(CastPhase.playing);
  }

  group('the session', () {
    test('nothing playing: connected and idle, the device kept', () async {
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      expect(rig.receivers.joins.single.host, '192.168.1.155');
      expect(rig.state.device, tvDevice);
      expect(rig.state.item, isNull);
      await rig.until(() => rig.devices.used.contains('tv1'));
      expect(rig.tv.loads, isEmpty);
      expect(rig.relay.sessions, isEmpty);
      expect(rig.sleep.held, isFalse, reason: 'nothing is cast yet');
      expect(rig.playback.coordinator.casting, isTrue);
      expect(rig.playback.state, isA<PlaybackIdle>());
    });

    test('a play goes to the TV: probed, relayed, loaded, playing', () async {
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1, number: 201)));
      await rig.loaded();
      expect(rig.playback.engine.opened, isEmpty, reason: 'not here');
      expect(rig.playback.state, isA<PlaybackCasting>());
      expect(rig.relay.log, ['input', 'input closed', 'start:cast-1']);
      final request = rig.relay.last.request;
      expect(request.localAddress, '192.168.1.20');
      expect(request.plan.delivery, CastDelivery.relayHls);
      expect(request.plan.video, isA<CastVideoCopy>());
      final load = rig.tv.loads.single;
      expect(load.url, rig.relay.last.url);
      expect(load.contentType, 'application/x-mpegurl');
      expect(load.live, isTrue);
      expect(load.title, '201 · Channel 1');
      expect(load.imageUrl, isNull, reason: 'Channel 1 has no logo');
      expect(rig.state.phase, CastPhase.preparing);
      expect(rig.sleep.held, isTrue);
      rig.tv.playing();
      await rig.phase(CastPhase.playing);
      expect(rig.state.plan, request.plan);
      await rig.until(() => rig.playback.history.recorded.contains('k1'));
    });

    test(
      'zapping: the old relay session goes before the new one starts',
      () async {
        await castChannel();
        unawaited(rig.playback.coordinator.playLive(channel(2)));
        await rig.loaded(2);
        expect(rig.relay.log, [
          'input',
          'input closed',
          'start:cast-1',
          'stop:cast-1',
          'input',
          'input closed',
          'start:cast-2',
        ]);
        expect(rig.tv.loads.last.url, rig.relay.sessions[1].url);
        expect(rig.state.item, PlayableChannel(channel(2)));
        expect(rig.state.phase, CastPhase.preparing);
        // The old media's news is ignored.
        rig.tv.emit(
          rig.tv.state.copyWith(
            media: CastMediaStatus(
              sessionId: rig.tv.mediaSession - 1,
              playerState: CastPlayerState.idle,
              idleReason: CastIdleReason.interrupted,
              contentId: rig.tv.loads.first.url,
            ),
          ),
        );
        rig.tv.playing();
        await rig.phase(CastPhase.playing);
      },
    );

    test('a channel zapped back to is not probed again', () async {
      await castChannel();
      unawaited(rig.playback.coordinator.playLive(channel(2)));
      await rig.loaded(2);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.loaded(3);
      expect(rig.probe.inputs, hasLength(2));
    });

    test('Cast while watching: the laptop lets go first, its facts '
        'and audio track come along', () async {
      final playback = rig.playback;
      await playback.coordinator.playLive(channel(1));
      playback.engine
        ..info = const StreamInfo(
          videoCodec: 'h264 (H.264 / AVC)',
          width: 1920,
          height: 1080,
          fps: 50,
          audioCodec: 'aac',
          audioChannels: 2,
        )
        ..firstFrame()
        ..emit(
          const PlayerTracks(
            audio: [
              MediaTrack(id: '1', language: 'en', codec: 'aac'),
              MediaTrack(id: '2', language: 'de', codec: 'aac'),
            ],
            subtitles: [],
            audioId: '2',
          ),
        );
      expect(playback.state, isA<PlaybackPlaying>());
      expect(playback.coordinator.connections.held('src'), 1);
      await rig.coordinator.connect(tvDevice);
      expect(playback.engine.calls, contains('stop'));
      expect(playback.coordinator.connections.held('src'), 0);
      await rig.loaded();
      expect(rig.probe.inputs, isEmpty, reason: "the player's facts");
      expect(rig.relay.log, ['start:cast-1']);
      final plan = rig.relay.last.request.plan;
      expect(plan.audio, const CastAudioCopy(1));
      expect(rig.state.item, PlayableChannel(channel(1)));
      expect(playback.state, isA<PlaybackCasting>());
    });

    test('the relay starts while the TV launches its receiver', () async {
      final launching = rig.receivers.launching = Completer<void>();
      await rig.coordinator.connect(tvDevice);
      expect(rig.state.phase, CastPhase.connecting);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.until(() => rig.relay.sessions.isNotEmpty);
      expect(rig.receivers.joined, isFalse);
      expect(rig.tv.loads, isEmpty, reason: 'LOAD waits for the receiver');
      expect(rig.state.phase, CastPhase.connecting);
      launching.complete();
      await rig.loaded();
      expect(rig.state.phase, CastPhase.preparing);
    });

    test('the device does not answer: failed; Try again joins again', () async {
      rig.receivers.answer = () =>
          const CastJoinFailed(CastJoinFailure.unreachable, 'refused');
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.deviceUnreachable);
      expect(rig.state.problem!.detail, 'refused');
      rig.receivers.answer = null;
      await rig.coordinator.retry();
      await rig.phase(CastPhase.idle);
      expect(rig.receivers.joins, hasLength(2));
    });

    test('a receiver that will not start says so', () async {
      rig.receivers.answer = () =>
          const CastJoinFailed(CastJoinFailure.launchRefused);
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.receiverRefused);
    });

    test('a play while the join fails: the relay is let go', () async {
      final launching = rig.receivers.launching = Completer<void>();
      rig.receivers.answer = () =>
          const CastJoinFailed(CastJoinFailure.launchTimedOut);
      await rig.coordinator.connect(tvDevice);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      // No connection: nothing to listen on.
      launching.complete();
      await rig.phase(CastPhase.failed);
      expect(rig.relay.sessions, isEmpty);
    });

    test('Stop casting: the TV goes home, the relay stops, nothing plays '
        'here', () async {
      await castChannel();
      await rig.coordinator.disconnect();
      expect(rig.tv.calls, contains('stop'));
      expect(rig.relay.last.stopped, isTrue);
      expect(rig.state, const CastingState());
      expect(rig.playback.coordinator.casting, isFalse);
      expect(rig.playback.state, isA<PlaybackIdle>());
      expect(rig.playback.engine.opened, isEmpty);
      await rig.until(() => !rig.sleep.held);
    });

    test('Play here: the session ends and the laptop plays it', () async {
      await castChannel();
      await rig.coordinator.playHere();
      expect(rig.tv.calls, contains('stop'));
      expect(rig.playback.engine.opened.single.url, contains('k1.ts'));
      expect(rig.playback.state, isA<PlaybackOpening>());
    });

    test("a screen's stop leaves the cast alone", () async {
      await castChannel();
      await rig.playback.coordinator.stop();
      expect(rig.relay.last.stopped, isFalse);
      expect(rig.tv.calls, isNot(contains('stopMedia')));
      expect(rig.state.phase, CastPhase.playing);
    });

    test('another app takes the TV: the session ends with its name', () async {
      await castChannel();
      rig.tv.emit(
        rig.tv.state.copyWith(
          link: CastLink.ended,
          end: CastEnd.otherApp,
          otherApp: 'YouTube',
        ),
      );
      await rig.phase(CastPhase.off);
      final notice = rig.notices.single as CastSessionClosed;
      expect(notice.end, CastEnd.otherApp);
      expect(notice.otherApp, 'YouTube');
      expect(notice.deviceName, 'Living Room TV');
      expect(rig.relay.last.stopped, isTrue);
      expect(rig.playback.coordinator.casting, isFalse);
      expect(rig.playback.state, isA<PlaybackIdle>());
    });

    test(
      'the connection breaks and comes back: the pill, then nothing',
      () async {
        await castChannel();
        rig.tv.emit(rig.tv.state.copyWith(link: CastLink.reconnecting));
        await rig.until(() => rig.state.reconnecting);
        expect(rig.state.phase, CastPhase.playing);
        rig.tv.emit(rig.tv.state.copyWith(link: CastLink.connected));
        await rig.until(() => !rig.state.reconnecting);
      },
    );

    test('lost: the session ends and says so', () async {
      await castChannel();
      rig.tv.emit(
        rig.tv.state.copyWith(link: CastLink.ended, end: CastEnd.lost),
      );
      await rig.phase(CastPhase.off);
      expect((rig.notices.single as CastSessionClosed).end, CastEnd.lost);
    });

    test("stopped with the TV's remote: idle, the relay stopped", () async {
      await castChannel();
      rig.tv.idle(CastIdleReason.cancelled);
      await rig.phase(CastPhase.idle);
      expect(rig.state.item, isNull);
      expect(rig.relay.last.stopped, isTrue);
      expect(rig.notices.single, isA<CastStoppedOnDevice>());
      expect(rig.playback.state, isA<PlaybackIdle>());
      expect(rig.playback.coordinator.casting, isTrue);
    });

    test('paused on the TV, and played again', () async {
      await castChannel();
      rig.tv.media(CastPlayerState.paused);
      await rig.until(() => rig.state.paused);
      rig.tv.playing();
      await rig.until(() => !rig.state.paused);
    });

    test('the volume follows the TV, and is set on it', () async {
      await castChannel();
      rig.tv.emit(rig.tv.state.copyWith(volume: const CastVolume(level: 0.3)));
      await rig.until(() => rig.state.volume.level == 0.3);
      await rig.coordinator.setVolume(0.6);
      await rig.coordinator.setMuted(muted: true);
      expect(rig.tv.calls, containsAll(['volume:0.6', 'muted:true']));
    });

    test("the picture: the cache's copy, served by the relay", () async {
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      const logo = 'http://panel/art/logo.png';
      unawaited(
        rig.playback.coordinator.playLive(
          const ChannelItem(
            id: 1,
            sourceId: 'src',
            remoteKey: 'k1',
            name: 'Channel 1',
            logoUrl: logo,
          ),
        ),
      );
      await rig.loaded();
      expect(rig.relay.pictures, ['/cache/${logo.hashCode}']);
      expect(
        rig.tv.loads.single.imageUrl,
        'http://192.168.1.20:38400/f/pic/media.png',
      );
      await rig.coordinator.disconnect();
      expect(rig.relay.unserved, hasLength(1));
    });

    test(
      'Windows: the firewall is explained once, before the first relay',
      () async {
        await rig.dispose();
        var explained = 0;
        rig = CastRig(
          beforeFirstRelay: () async {
            explained++;
            expect(rig.relay.sessions, isEmpty);
          },
        );
        await castChannel();
        unawaited(rig.playback.coordinator.playLive(channel(2)));
        await rig.loaded(2);
        expect(explained, 1);
      },
    );

    test('sleep is held while it plays, and let go when it ends', () async {
      await castChannel();
      expect(rig.sleep.held, isTrue);
      rig.tv.idle(CastIdleReason.cancelled);
      await rig.until(() => !rig.sleep.held);
      unawaited(rig.playback.coordinator.playLive(channel(2)));
      await rig.until(() => rig.sleep.held);
    });

    test('the relay and the TV count against the source', () async {
      await castChannel();
      rig.relay.connectionsNow('src', 1);
      await rig.until(
        () => rig.playback.coordinator.connections.held('src') == 1,
      );
      expect(
        rig.playback.coordinator.connections.held(
          'src',
          except: StreamHolder.cast,
        ),
        0,
      );
    });
  });

  group('the TV and the relay fail', () {
    test(
      'the TV never fetches the stream: it cannot reach this computer',
      () async {
        await rig.coordinator.connect(tvDevice);
        await rig.phase(CastPhase.idle);
        unawaited(rig.playback.coordinator.playLive(channel(1)));
        await rig.phase(CastPhase.failed);
        expect(rig.state.problem!.kind, CastProblemKind.computerUnreachable);
        expect(rig.tv.calls, contains('stopMedia'));
        expect(rig.relay.last.stopped, isTrue);
      },
    );

    test('a fetch in time is no failure', () async {
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.loaded();
      rig.relay.last.emit(const CastRelayFetched());
      await Future<void>.delayed(fastTimings.reach * 2);
      expect(rig.state.phase, CastPhase.preparing);
    });

    test("a provider's refusal: docs/03's words, the TV stopped", () async {
      await castChannel();
      rig.relay.last.fail(
        const CastRelayFailure(
          CastRelayFailureKind.providerRefused,
          status: 401,
          body: 'Unauthorized',
        ),
      );
      await rig.phase(CastPhase.failed);
      final problem = rig.state.problem!;
      expect(problem.kind, CastProblemKind.stream);
      expect(problem.stream!.kind, PlaybackProblemKind.auth);
      expect(rig.tv.calls, contains('stopMedia'));
    });

    test('every connection in use: the connection limit', () async {
      await castChannel();
      rig.relay.last.fail(
        const CastRelayFailure(CastRelayFailureKind.connectionsInUse),
      );
      await rig.phase(CastPhase.failed);
      expect(
        rig.state.problem!.stream!.kind,
        PlaybackProblemKind.connectionLimit,
      );
    });

    test('too many restarts: the relay failed', () async {
      await castChannel();
      rig.relay.last.fail(
        const CastRelayFailure(
          CastRelayFailureKind.restartBudget,
          detail: 'Stream ends prematurely',
        ),
      );
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.relay);
      expect(rig.state.problem!.detail, 'Stream ends prematurely');
    });

    test('a relay that does not start fails the cast', () async {
      rig.relay.notStarted = const CastRelayFailure(
        CastRelayFailureKind.couldNotStart,
      );
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.relay);
    });

    test('Try again after a failure casts it again', () async {
      await castChannel();
      rig.relay.last.fail(
        const CastRelayFailure(CastRelayFailureKind.providerUnreachable),
      );
      await rig.phase(CastPhase.failed);
      unawaited(rig.coordinator.retry());
      await rig.loaded(2);
      expect(rig.relay.sessions, hasLength(2));
      expect(rig.state.problem, isNull);
    });

    test('the stream cannot be built: unavailable', () async {
      rig.playback.resolver.failure = AuthFailure('locked');
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.stream!.kind, PlaybackProblemKind.unavailable);
    });

    test("the probe refused by the provider: the provider's words", () async {
      rig.probe.next = const StreamProbeFailed(StreamProbeFailure.unreadable);
      rig.relay.inputRefusal = const CastRelayFailure(
        CastRelayFailureKind.providerRefused,
        status: 404,
      );
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.stream!.kind, PlaybackProblemKind.offline);
      expect(rig.relay.log, ['input', 'input closed']);
    });

    test('a probe that times out is a network problem', () async {
      rig.probe.next = const StreamProbeFailed(StreamProbeFailure.timedOut);
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.stream!.kind, PlaybackProblemKind.network);
    });

    test('neither picture nor sound: nothing to play', () async {
      rig.probe.next = const StreamProbed(
        StreamFacts(origin: StreamFactsOrigin.probe),
      );
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.nothingToPlay);
    });

    test('a re-encode with no encoder: said, nothing relayed', () async {
      rig.encoders.found = CastEncoders.none;
      rig.probe.next = StreamProbed(
        h264Facts.copyWith(
          video: h264Facts.video!.copyWith(codec: 'mpeg2video'),
        ),
      );
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.cantReencode);
      expect(rig.relay.sessions, isEmpty);
    });

    test('a failed re-encode tries the next encoder', () async {
      rig.probe.next = StreamProbed(
        h264Facts.copyWith(
          video: h264Facts.video!.copyWith(codec: 'mpeg2video'),
        ),
      );
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.loaded();
      expect(rig.relay.last.request.encoder!.kind, CastEncoderKind.nvenc);
      rig.relay.last.fail(
        const CastRelayFailure(CastRelayFailureKind.encoderFailed),
      );
      await rig.loaded(2);
      expect(rig.encoders.detectedAgain, 1);
      expect(rig.relay.sessions, hasLength(2));
      expect(rig.relay.last.request.encoder!.kind, CastEncoderKind.x264);
      rig.relay.last.fail(
        const CastRelayFailure(CastRelayFailureKind.encoderFailed),
      );
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.cantReencode);
    });
  });

  group('learning (docs/04)', () {
    test('4K refused at once: 1080p learned, kept, and re-encoded', () async {
      rig
        ..probe.next = const StreamProbed(hevc4kFacts)
        ..refuseNextLoad();
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.until(() => rig.relay.sessions.length == 2);
      expect(rig.devices.devices['tv1']!.learned.maxHeight, 1080);
      final first = rig.relay.sessions[0].request.plan;
      final second = rig.relay.sessions[1].request.plan;
      expect(first.video, isA<CastVideoCopy>());
      expect(rig.relay.sessions[0].stopped, isTrue);
      final video = second.video as CastVideoTranscode;
      expect(video.height, 1080);
      expect(video.reasons.first, TranscodeReason.aboveLearnedHeight);
      final notice = rig.notices.single as CastPlanChanged;
      expect(notice.before, first);
      expect(notice.after, second);
      await rig.loaded(2);
      expect(rig.state.plan, second);
    });

    test('HEVC refused on an IDLE/ERROR: the codec learned', () async {
      rig.probe.next = StreamProbed(
        hevc4kFacts.copyWith(
          video: hevc4kFacts.video!.copyWith(height: 1080, width: 1920),
        ),
      );
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.loaded();
      rig.relay.last.emit(const CastRelayFetched());
      rig.tv.idle(CastIdleReason.error);
      await rig.until(() => rig.relay.sessions.length == 2);
      expect(rig.devices.devices['tv1']!.learned.refusedCodecs, {'hevc'});
      expect(rig.relay.last.request.plan.video, isA<CastVideoTranscode>());
      await rig.loaded(2);
    });

    test('learned once: the next cast plans with it from the start', () async {
      rig.devices.devices['tv1'] = const KnownCastDevice(
        id: 'tv1',
        name: 'Living Room TV',
        host: '192.168.1.155',
        port: 8009,
        manual: false,
        hevc: HevcSupport.auto,
        learned: CastLearned(maxHeight: 1080),
      );
      rig.probe.next = const StreamProbed(hevc4kFacts);
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.loaded();
      final video = rig.relay.last.request.plan.video as CastVideoTranscode;
      expect(video.height, 1080);
    });

    test('nothing to learn: the TV cannot play it', () async {
      rig.tv.onLoad = (_) => const CastRefused(CastRefusal.loadFailed);
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.deviceCantPlay);
      expect(rig.devices.devices['tv1']!.learned, const CastLearned());
      expect(rig.notices, isEmpty);
    });

    test('a LOAD_FAILED and its IDLE/ERROR are one refusal', () async {
      rig.probe.next = const StreamProbed(hevc4kFacts);
      var first = true;
      rig.tv.onLoad = (_) {
        if (!first) return null;
        first = false;
        scheduleMicrotask(() => rig.tv.idle(CastIdleReason.error));
        return const CastRefused(CastRefusal.loadFailed);
      };
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.loaded(2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(rig.relay.sessions, hasLength(2));
      expect(rig.devices.devices['tv1']!.learned.refusedCodecs, isEmpty);
    });

    test('an error after it played: loaded again, then given up', () async {
      await castChannel();
      for (var i = 0; i < 3; i++) {
        rig.tv.idle(CastIdleReason.error);
        await rig.loaded(i + 2);
        rig.tv.playing();
        await rig.phase(CastPhase.playing);
      }
      rig.tv.idle(CastIdleReason.error);
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.deviceCantPlay);
      expect(rig.devices.devices['tv1']!.learned, const CastLearned());
    });
  });

  group('direct plays (docs/04 rule 1)', () {
    setUp(() => rig.playback.resolver.hls = true);

    test('HLS with H.264 and AAC: the TV reads the provider itself', () async {
      await castChannel();
      expect(rig.relay.sessions, isEmpty);
      final load = rig.tv.loads.single;
      expect(load.url, 'http://fake/live/u/p/k1.m3u8');
      expect(load.contentType, 'application/x-mpegurl');
      expect(rig.state.plan!.delivery, CastDelivery.directHls);
      expect(rig.playback.coordinator.connections.held('src'), 1);
      await rig.coordinator.disconnect();
      expect(rig.playback.coordinator.connections.held('src'), 0);
    });

    test('an error soon after: the relay from then on, remembered', () async {
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.loaded();
      rig.tv.idle(CastIdleReason.error);
      await rig.loaded(2);
      expect(rig.devices.devices['tv1']!.learned.directRefusedSources, {'src'});
      expect(rig.tv.loads.last.url, rig.relay.last.url);
      expect(rig.relay.last.request.plan.delivery, CastDelivery.relayHls);
      expect(rig.notices.single, isA<CastPlanChanged>());
      expect(
        rig.playback.coordinator.connections.held('src'),
        0,
        reason: "the TV's direct connection is let go",
      );
    });

    test('a source with its own User-Agent never goes direct', () async {
      rig.playback.resolver.customUserAgent = true;
      await castChannel();
      expect(rig.relay.sessions, hasLength(1));
    });
  });

  group('live streams that end', () {
    test('a continuous stream that finishes is renewed and loaded '
        'again (ADR-004)', () async {
      rig.probe.next = const StreamProbed(hevc4kFacts);
      await castChannel();
      expect(rig.state.plan!.delivery, CastDelivery.relayContinuous);
      final first = rig.tv.loads.single.url;
      rig.tv.idle(CastIdleReason.finished);
      await rig.loaded(2);
      expect(rig.relay.last.renews.single.startAt, isNull);
      expect(rig.tv.loads.last.url, isNot(first));
      expect(rig.tv.loads.last.contentType, 'video/mp4');
    });

    test('a renew that fails fails the cast', () async {
      rig.probe.next = const StreamProbed(hevc4kFacts);
      await castChannel();
      rig.relay.last.renewFailure = const CastRelayFailure(
        CastRelayFailureKind.restartBudget,
      );
      rig.tv.idle(CastIdleReason.finished);
      await rig.phase(CastPhase.failed);
      expect(rig.state.problem!.kind, CastProblemKind.relay);
    });

    test('ending over and over: given up after the budget', () async {
      rig.probe.next = const StreamProbed(hevc4kFacts);
      await castChannel();
      for (var i = 0; i < 3; i++) {
        rig.tv.idle(CastIdleReason.finished);
        await rig.loaded(i + 2);
        rig.tv.playing();
        await rig.phase(CastPhase.playing);
      }
      rig.tv.idle(CastIdleReason.finished);
      await rig.phase(CastPhase.failed);
    });

    test('a codec change: probed again, planned again, loaded again', () async {
      await castChannel();
      rig.probe.next = const StreamProbed(hevc4kFacts);
      rig.relay.last.emit(const CastRelayStreamsChanged());
      await rig.loaded(2);
      expect(rig.probe.inputs, hasLength(2));
      expect(rig.relay.sessions.first.stopped, isTrue);
      expect(
        rig.relay.log.indexOf('stop:cast-1'),
        lessThan(rig.relay.log.lastIndexOf('input')),
      );
      expect(
        rig.relay.last.request.plan.delivery,
        CastDelivery.relayContinuous,
      );
    });

    test(
      "FFmpeg's facts: remembered; a plan they change is made again",
      () async {
        await castChannel();
        rig.relay.last.emit(
          const CastRelayOpened(
            StreamFacts(
              origin: StreamFactsOrigin.relay,
              video: VideoFacts(codec: 'h264', height: 1080, width: 1920),
              audio: [AudioFacts(index: 0, codec: 'aac', channels: 2)],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(rig.relay.sessions, hasLength(1), reason: 'the same plan');
        rig.relay.last.emit(
          const CastRelayOpened(
            StreamFacts(
              origin: StreamFactsOrigin.relay,
              video: VideoFacts(codec: 'h264', height: 1080, width: 1920),
              audio: [AudioFacts(index: 0, codec: 'ac3', channels: 6)],
            ),
          ),
        );
        await rig.loaded(2);
        expect(rig.relay.last.request.plan.audio, isA<CastAudioToAac>());
      },
    );
  });

  group('movies and episodes', () {
    Future<void> castMovie({
      Duration? from,
      StreamFacts facts = mkvFacts,
    }) async {
      rig.probe.next = StreamProbed(facts);
      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(
        rig.playback.coordinator.playVod(PlayableMovie(movie(7)), from: from),
      );
      await rig.loaded();
      rig.relay.sessions.lastOrNull?.emit(const CastRelayFetched());
    }

    test(
      'through the relay from its place: the TV time plus the start',
      () async {
        await castMovie(from: const Duration(minutes: 10));
        final request = rig.relay.last.request;
        expect(request.plan.delivery, CastDelivery.relayContinuous);
        expect(request.startAt, const Duration(minutes: 10));
        final load = rig.tv.loads.single;
        expect(load.live, isFalse);
        expect(load.start, Duration.zero);
        expect(load.duration, const Duration(minutes: 100));
        rig.tv.playing(position: const Duration(seconds: 5));
        await rig.phase(CastPhase.playing);
        expect(
          rig.coordinator.timeline.position,
          greaterThanOrEqualTo(const Duration(minutes: 10, seconds: 5)),
        );
        expect(rig.coordinator.timeline.duration, const Duration(minutes: 100));
      },
    );

    test('a seek starts the relay again there, with a new LOAD', () async {
      await castMovie();
      rig.tv.playing();
      await rig.phase(CastPhase.playing);
      await rig.playback.coordinator.seek(const Duration(minutes: 30));
      await rig.loaded(2);
      expect(rig.relay.last.renews.single.startAt, const Duration(minutes: 30));
      expect(rig.tv.loads.last.url, rig.relay.last.url);
      expect(rig.state.phase, CastPhase.preparing);
      expect(rig.playback.progress.lastPosition, const Duration(minutes: 30));
      rig.tv.playing(position: const Duration(seconds: 2));
      await rig.phase(CastPhase.playing);
      expect(
        rig.coordinator.timeline.position,
        greaterThanOrEqualTo(const Duration(minutes: 30, seconds: 2)),
      );
    });

    test('pause and play go to the TV; a pause saves the place', () async {
      await castMovie();
      rig.tv.playing(position: const Duration(minutes: 1));
      await rig.phase(CastPhase.playing);
      await rig.playback.coordinator.setPaused(paused: true);
      expect(rig.tv.calls, contains('pause'));
      expect(
        rig.playback.progress.lastPosition,
        greaterThanOrEqualTo(const Duration(minutes: 1)),
      );
      await rig.playback.coordinator.setPaused(paused: false);
      expect(rig.tv.calls, contains('play'));
    });

    test('its place is saved while it plays', () async {
      await castMovie();
      rig.tv.playing(position: const Duration(minutes: 2));
      await rig.phase(CastPhase.playing);
      await rig.until(
        () => rig.playback.progress.saves.isNotEmpty,
        within: const Duration(seconds: 3),
      );
      expect(rig.playback.progress.saves.last.ref, movie(7).ref);
    });

    test('played to its end: ended, saved at its length', () async {
      await castMovie();
      rig.tv.playing(position: const Duration(minutes: 99, seconds: 55));
      await rig.phase(CastPhase.playing);
      rig.tv.idle(
        CastIdleReason.finished,
        position: const Duration(minutes: 99, seconds: 58),
      );
      await rig.phase(CastPhase.ended);
      expect(rig.playback.progress.lastPosition, const Duration(minutes: 100));
      expect(rig.relay.last.stopped, isTrue);
    });

    test('cut short: it carries on where it was', () async {
      await castMovie();
      rig.tv.playing(position: const Duration(minutes: 40));
      await rig.phase(CastPhase.playing);
      rig.tv.idle(
        CastIdleReason.finished,
        position: const Duration(minutes: 40),
      );
      await rig.loaded(2);
      expect(rig.relay.last.renews.single.startAt, const Duration(minutes: 40));
    });

    test('an MP4 the TV plays goes direct; it seeks itself', () async {
      await castMovie(from: const Duration(minutes: 5), facts: mp4Facts);
      expect(rig.relay.sessions, isEmpty);
      final load = rig.tv.loads.single;
      expect(load.contentType, 'video/mp4');
      expect(load.start, const Duration(minutes: 5));
      expect(load.url, 'http://fake/movie/u/p/m7.mkv');
      rig.tv.playing(position: const Duration(minutes: 5));
      await rig.phase(CastPhase.playing);
      await rig.playback.coordinator.seek(const Duration(minutes: 20));
      expect(rig.tv.calls, contains('seek:1200000'));
      expect(rig.tv.loads, hasLength(1));
    });

    group('from a file on this computer (Phase 8 decision 12)', () {
      const file = '/downloads/Movies/Film (2025)/Film (2025).mp4';

      Future<void> castDownloaded({
        Duration? from,
        StreamFacts facts = mp4Facts,
      }) async {
        rig.playback.resolver.downloads['m7'] = file;
        rig.probe.next = StreamProbed(facts);
        await rig.coordinator.connect(tvDevice);
        await rig.phase(CastPhase.idle);
        unawaited(
          rig.playback.coordinator.playVod(PlayableMovie(movie(7)), from: from),
        );
        await rig.loaded();
        rig.relay.sessions.lastOrNull?.emit(const CastRelayFetched());
      }

      test('an MP4 the TV plays: served from this computer, sought by the '
          "TV itself, with none of the provider's connections", () async {
        await castDownloaded(from: const Duration(minutes: 5));
        // ffprobe read the file itself: no proxy, no room asked for.
        expect(rig.probe.inputs, [file]);
        expect(rig.relay.log, isNot(contains('input')));
        expect(rig.relay.files, [file]);
        expect(rig.relay.sessions, isEmpty);
        final load = rig.tv.loads.single;
        expect(load.url, 'http://192.168.1.20:38400/f/file1/media.mp4');
        expect(load.contentType, 'video/mp4');
        expect(load.start, const Duration(minutes: 5));
        expect(rig.playback.coordinator.connections.held('src'), 0);

        rig.tv.playing(position: const Duration(minutes: 5));
        await rig.phase(CastPhase.playing);
        await rig.playback.coordinator.seek(const Duration(minutes: 20));
        expect(rig.tv.calls, contains('seek:1200000'));
        expect(rig.tv.loads, hasLength(1));
        expect(rig.playback.coordinator.connections.held('src'), 0);

        // Its place is the title's; its URL goes with the cast.
        await rig.coordinator.disconnect();
        expect(rig.playback.progress.saves.last.ref, movie(7).ref);
        expect(rig.relay.unserved, contains(load.url));
      });

      test('anything else: the relay, whose FFmpeg reads the file', () async {
        await castDownloaded(facts: mkvFacts);
        final request = rig.relay.last.request;
        expect(request.plan.delivery, CastDelivery.relayContinuous);
        expect(request.source.file, file);
        expect(rig.relay.files, isEmpty);
        expect(rig.relay.log, isNot(contains('input')));
      });

      test("the file can't be served: said so, not left loading", () async {
        rig.relay.canServeFiles = false;
        rig.playback.resolver.downloads['m7'] = file;
        rig.probe.next = const StreamProbed(mp4Facts);
        await rig.coordinator.connect(tvDevice);
        await rig.phase(CastPhase.idle);
        unawaited(rig.playback.coordinator.playVod(PlayableMovie(movie(7))));
        await rig.until(() => rig.coordinator.state.problem != null);
        expect(rig.coordinator.state.problem!.kind, CastProblemKind.relay);
        expect(rig.tv.loads, isEmpty);
      });

      test('a TV that refuses the file as it is: the relay for this file, '
          'and nothing learned about the provider', () async {
        await castDownloaded();
        rig.tv.idle(CastIdleReason.error);
        await rig.until(() => rig.relay.sessions.isNotEmpty);
        expect(rig.relay.last.request.source.file, file);
        expect(rig.relay.unserved, hasLength(1), reason: 'its URL is gone');
        expect(rig.devices.devices.values.single.learned.directRefusedSources, {
          'file:$file',
        });
      });

      test('cut short while the TV reads it itself: it carries on there, '
          "and its place is still the TV's own time", () async {
        await castDownloaded();
        rig.tv.playing(position: const Duration(minutes: 40));
        await rig.phase(CastPhase.playing);
        rig.tv.idle(
          CastIdleReason.finished,
          position: const Duration(minutes: 40),
        );
        await rig.loaded(2);
        expect(rig.tv.loads.last.start, const Duration(minutes: 40));
        expect(rig.tv.loads.last.url, rig.tv.loads.first.url);
        rig.tv.playing(position: const Duration(minutes: 40, seconds: 5));
        await rig.phase(CastPhase.playing);
        expect(
          rig.coordinator.timeline.position,
          _between(
            const Duration(minutes: 40, seconds: 5),
            const Duration(minutes: 41),
          ),
        );
      });

      group('its subtitles (docs/04 "Subtitles")', () {
        const english = CastSubtitle(language: 'en', beside: true);
        const german = CastSubtitle(language: 'ger', title: 'SDH');
        const srt = '/downloads/Movies/Film (2025)/Film (2025).en.srt';

        Iterable<String> switches() =>
            rig.tv.calls.where((call) => call.startsWith('textTrack:'));

        test('the LOAD names each as a WebVTT file the relay serves; a '
            'file beside the video shows from the start', () async {
          rig.subtitles.ready = [english, german];
          rig.playback.resolver.downloadSubtitles['m7'] = [srt];
          await castDownloaded();
          expect(rig.subtitles.last.video, file);
          expect(rig.subtitles.last.beside, [srt]);
          final load = rig.tv.loads.single;
          expect(
            [for (final t in load.textTracks) (t.id, t.language, t.name)],
            [(1, 'en', 'English'), (2, 'de', 'German · SDH')],
          );
          // The first file served is the video.
          expect(
            [for (final t in load.textTracks) t.url],
            [
              'http://192.168.1.20:38400/f/file2/media.vtt',
              'http://192.168.1.20:38400/f/file3/media.vtt',
            ],
          );
          expect(load.activeTextTrack, 1);
          // The TV plays the file itself: the cues keep their times.
          expect(rig.subtitles.last.moves, [Duration.zero]);
          expect(rig.subtitles.starts, isEmpty);
          expect(rig.state.subtitles, [english, german]);
          expect(rig.state.subtitle, 1);
        });

        test('Preferred subtitles decide which shows first: the most '
            'wanted language that has one', () async {
          rig
            ..subtitleLanguages = ['fr', 'de', 'en']
            ..subtitles.ready = [english, german];
          await castDownloaded();
          expect(rig.tv.loads.single.activeTextTrack, 2);
          expect(rig.state.subtitle, 2);
        });

        test("only the file's own tracks, none preferred: listed, and "
            'off', () async {
          rig.subtitles.ready = [german];
          await castDownloaded();
          expect(rig.tv.loads.single.textTracks, hasLength(1));
          expect(rig.tv.loads.single.activeTextTrack, isNull);
          expect(rig.state.subtitles, [german]);
          expect(rig.state.subtitle, isNull);
        });

        test('a file with none, a channel, a movie from the provider: no '
            'tracks', () async {
          await castDownloaded();
          expect(rig.tv.loads.single.textTracks, isEmpty);
          expect(rig.state.subtitles, isEmpty);
          rig.subtitles.ready = [english];
          unawaited(rig.playback.coordinator.playVod(PlayableMovie(movie(8))));
          await rig.loaded(2);
          unawaited(rig.playback.coordinator.playLive(channel(1)));
          await rig.loaded(3);
          expect(rig.subtitles.sets, hasLength(1), reason: 'only the file');
          expect(rig.subtitles.sets.single.deleted, isTrue);
          expect(rig.tv.loads.last.textTracks, isEmpty);
          expect(rig.state.subtitles, isEmpty);
        });

        test('choosing one tells the TV, and so does none', () async {
          rig.subtitles.ready = [english, german];
          await castDownloaded();
          rig.tv.playing();
          await rig.phase(CastPhase.playing);
          await rig.coordinator.setSubtitle(2);
          expect(switches(), ['textTrack:2']);
          expect(rig.state.subtitle, 2);
          await rig.coordinator.setSubtitle(null);
          expect(switches(), ['textTrack:2', 'textTrack:none']);
          expect(rig.state.subtitle, isNull);
          // One that isn't there is no choice.
          await rig.coordinator.setSubtitle(3);
          expect(rig.state.subtitle, isNull);
          expect(switches(), hasLength(2));
          expect(rig.tv.loads, hasLength(1));
        });

        test('a TV that refuses the switch: what it shows is what is '
            'said', () async {
          rig.subtitles.ready = [english, german];
          await castDownloaded();
          rig.tv.playing();
          await rig.phase(CastPhase.playing);
          rig.tv.onTextTrack = (_) =>
              const CastRefused(CastRefusal.invalidRequest);
          await rig.coordinator.setSubtitle(2);
          expect(rig.state.subtitle, 1);
        });

        test('chosen while it loads: the TV is told once it plays', () async {
          rig.subtitles.ready = [english, german];
          await castDownloaded();
          await rig.coordinator.setSubtitle(2);
          expect(switches(), isEmpty);
          expect(rig.state.subtitle, 2);
          rig.tv.playing();
          await rig.until(() => switches().isNotEmpty);
          expect(switches(), ['textTrack:2']);
        });

        test("the file's own tracks read after the LOAD: listed when "
            'they are ready, and choosing one loads the file again where '
            'it is', () async {
          rig.subtitles.late = [german];
          await castDownloaded(from: const Duration(minutes: 5));
          final first = rig.tv.loads.single;
          expect(first.textTracks, isEmpty);
          rig.tv.playing(position: const Duration(minutes: 5));
          await rig.phase(CastPhase.playing);
          expect(rig.state.subtitles, isEmpty);

          rig.subtitles.last.finish();
          await rig.until(() => rig.state.subtitles.isNotEmpty);
          expect(rig.state.subtitles, [german]);
          expect(rig.state.subtitle, isNull);
          expect(rig.tv.loads, hasLength(1), reason: 'nothing was asked yet');

          rig.tv.playing(position: const Duration(minutes: 12));
          await rig.until(
            () =>
                rig.coordinator.timeline.position >=
                const Duration(minutes: 12),
          );
          unawaited(rig.coordinator.setSubtitle(1));
          await rig.loaded(2);
          final again = rig.tv.loads.last;
          expect(again.url, first.url);
          expect(
            again.start,
            _between(const Duration(minutes: 12), const Duration(minutes: 13)),
          );
          expect(again.textTracks.single.id, 1);
          expect(again.activeTextTrack, 1);
          expect(rig.state.phase, CastPhase.preparing);
          rig.tv.playing(position: const Duration(minutes: 12));
          await rig.phase(CastPhase.playing);
          expect(rig.state.subtitle, 1);
          expect(switches(), isEmpty, reason: 'the LOAD carried it');
          expect(rig.tv.loads, hasLength(2));
        });

        test('through the relay: the cues, the timeline and the saved '
            'place count from the key frame the stream really starts '
            'at, and again after a seek', () async {
          rig.subtitles
            ..ready = [english]
            ..keyFrameBefore = const Duration(seconds: 4);
          await castDownloaded(
            from: const Duration(minutes: 10),
            facts: mkvFacts,
          );
          expect(rig.relay.last.request.startAt, const Duration(minutes: 10));
          final asked = rig.subtitles.starts.single;
          expect(asked.at, const Duration(minutes: 10));
          expect(asked.copied, (video: true, audioTrack: null));
          const start = Duration(minutes: 9, seconds: 56);
          expect(rig.subtitles.last.moves, [start]);
          final load = rig.tv.loads.single;
          expect(load.textTracks.single.url, endsWith('/media.vtt'));
          expect(load.activeTextTrack, 1);

          rig.tv.playing(position: const Duration(seconds: 2));
          await rig.phase(CastPhase.playing);
          expect(
            rig.coordinator.timeline.position,
            _between(
              start + const Duration(seconds: 2),
              const Duration(minutes: 10),
            ),
          );

          await rig.playback.coordinator.seek(const Duration(minutes: 30));
          await rig.loaded(2);
          expect(
            rig.relay.last.renews.single.startAt,
            const Duration(minutes: 30),
          );
          expect(
            rig.subtitles.last.moves.last,
            const Duration(minutes: 29, seconds: 56),
          );
          final again = rig.tv.loads.last;
          expect(again.activeTextTrack, 1, reason: 'the choice is kept');
          expect(
            again.textTracks.single.url,
            isNot(load.textTracks.single.url),
          );
          expect(rig.relay.unserved, contains(load.textTracks.single.url));
        });

        test('the end of the cast stops serving them and deletes '
            'them', () async {
          rig.subtitles.ready = [english, german];
          await castDownloaded();
          rig.tv.playing();
          await rig.phase(CastPhase.playing);
          final urls = [for (final t in rig.tv.loads.single.textTracks) t.url];
          await rig.coordinator.disconnect();
          expect(rig.relay.unserved, containsAll(urls));
          expect(rig.subtitles.last.deleted, isTrue);
          expect(rig.state.subtitles, isEmpty);
        });

        Future<void> handOver({required String? showing}) async {
          final playback = rig.playback;
          playback.resolver.downloads['m7'] = file;
          rig.subtitles.ready = [english, german];
          await playback.coordinator.playVod(PlayableMovie(movie(7)));
          playback.engine
            ..info = const StreamInfo(
              videoCodec: 'h264 (H.264 / AVC)',
              width: 1920,
              height: 1080,
              fps: 24,
              audioCodec: 'aac',
              audioChannels: 2,
            )
            ..firstFrame()
            ..emit(
              PlayerTracks(
                audio: const [MediaTrack(id: '1', codec: 'aac')],
                subtitles: const [
                  MediaTrack(id: '2', language: 'deu'),
                  MediaTrack(id: '3', language: 'en'),
                ],
                subtitleId: showing,
              ),
            );
          await rig.coordinator.connect(tvDevice);
          await rig.loaded();
        }

        test("handed over from the laptop's player: the subtitle in the "
            'language it showed', () async {
          await handOver(showing: '2');
          expect(rig.tv.loads.single.activeTextTrack, 2);
        });

        test("handed over with the player's subtitles off: off, whatever "
            'is beside the file', () async {
          rig.subtitleLanguages = ['en'];
          await handOver(showing: null);
          expect(rig.tv.loads.single.textTracks, hasLength(2));
          expect(rig.tv.loads.single.activeTextTrack, isNull);
          expect(rig.state.subtitle, isNull);
        });
      });

      group('the MP4 made beside the relay (decision 12)', () {
        /// The Matroska file relayed and playing, a minute in.
        Future<void> relayed() async {
          await castDownloaded(facts: mkvFacts);
          rig.tv.playing(position: const Duration(minutes: 1));
          await rig.phase(CastPhase.playing);
        }

        test('made for a relayed file whose picture is copied; a seek '
            'before it is whole starts the relay again', () async {
          await relayed();
          final copy = rig.mp4s.copies.single;
          expect(copy.video, file);
          expect(copy.plan, rig.state.plan);
          expect(copy.plan.video, isA<CastVideoCopy>());
          await rig.playback.coordinator.seek(const Duration(minutes: 30));
          await rig.loaded(2);
          expect(
            rig.relay.last.renews.single.startAt,
            const Duration(minutes: 30),
          );
          expect(rig.tv.loads.last.url, rig.relay.last.url);
          expect(rig.mp4s.copies, hasLength(1), reason: 'made once');
        });

        test('none for a file the TV plays itself, a re-encode, or a '
            "provider's own file", () async {
          await castDownloaded();
          expect(rig.mp4s.copies, isEmpty);
          // MPEG-2, which no TV takes as it is: re-encoded.
          rig.probe.next = StreamProbed(
            mkvFacts.copyWith(
              video: mkvFacts.video!.copyWith(codec: 'mpeg2video'),
            ),
          );
          rig.playback.resolver.downloads['m8'] = '/downloads/Film 8.mkv';
          unawaited(rig.playback.coordinator.playVod(PlayableMovie(movie(8))));
          await rig.loaded(2);
          expect(rig.relay.last.request.source.file, '/downloads/Film 8.mkv');
          expect(rig.relay.last.request.plan.video, isA<CastVideoTranscode>());
          expect(rig.mp4s.copies, isEmpty);
          rig.probe.next = const StreamProbed(mkvFacts);
          unawaited(rig.playback.coordinator.playVod(PlayableMovie(movie(9))));
          await rig.loaded(3);
          expect(rig.relay.last.request.source.file, isNull);
          expect(rig.mp4s.copies, isEmpty);
        });

        test('once it is whole, the next seek loads it there: the relay '
            "stops, and every seek after is the TV's own", () async {
          rig.subtitles
            ..ready = [const CastSubtitle(language: 'en', beside: true)]
            ..keyFrameBefore = const Duration(seconds: 4);
          await relayed();
          await rig.mp4s.last.whole();
          expect(rig.tv.loads, hasLength(1), reason: 'nothing is interrupted');
          expect(rig.relay.last.stopped, isFalse);

          await rig.playback.coordinator.seek(const Duration(minutes: 30));
          await rig.loaded(2);
          expect(rig.relay.last.stopped, isTrue);
          expect(rig.relay.last.renews, isEmpty);
          expect(rig.relay.files, contains(FakeMp4Copy.path));
          final load = rig.tv.loads.last;
          expect(load.url, endsWith('/media.mp4'));
          expect(load.url, isNot(rig.relay.last.url));
          expect(load.contentType, 'video/mp4');
          expect(load.start, const Duration(minutes: 30));
          // Its subtitles keep the file's own times now.
          expect(rig.subtitles.last.moves.last, Duration.zero);
          expect(load.activeTextTrack, 1);
          expect(rig.state.phase, CastPhase.preparing);
          expect(rig.state.plan!.delivery, CastDelivery.relayContinuous);

          // The TV's time is the file's.
          rig.tv.playing(position: const Duration(minutes: 30, seconds: 3));
          await rig.phase(CastPhase.playing);
          expect(
            rig.coordinator.timeline.position,
            _between(
              const Duration(minutes: 30, seconds: 3),
              const Duration(minutes: 31),
            ),
          );
          await rig.playback.coordinator.seek(const Duration(minutes: 50));
          expect(rig.tv.calls, contains('seek:3000000'));
          expect(rig.tv.loads, hasLength(2), reason: 'no new LOAD');
          expect(rig.relay.sessions, hasLength(1), reason: 'no relay again');
          expect(rig.state.phase, CastPhase.playing);

          await rig.coordinator.disconnect();
          expect(rig.mp4s.last.deleted, isTrue);
          expect(rig.relay.unserved, contains(load.url));
        });

        test('a TV that refuses the MP4: the relay again where it was, no '
            'MP4 for this cast any more, and nothing learned', () async {
          await relayed();
          await rig.mp4s.last.whole();
          await rig.playback.coordinator.seek(const Duration(minutes: 30));
          await rig.loaded(2);
          final refused = rig.tv.loads.last.url;
          rig.tv.idle(CastIdleReason.error);
          await rig.loaded(3);
          expect(rig.relay.sessions, hasLength(2));
          expect(rig.relay.last.request.startAt, const Duration(minutes: 30));
          expect(rig.tv.loads.last.url, rig.relay.last.url);
          expect(rig.relay.unserved, contains(refused));
          expect(rig.mp4s.copies.single.deleted, isTrue);
          expect(
            rig.devices.devices.values.single.learned.directRefusedSources,
            isEmpty,
          );
          rig.relay.last.emit(const CastRelayFetched());
          rig.tv.playing(position: const Duration(seconds: 1));
          await rig.phase(CastPhase.playing);
          // Seeks are the relay's from here on.
          await rig.playback.coordinator.seek(const Duration(minutes: 40));
          await rig.loaded(4);
          expect(
            rig.relay.last.renews.single.startAt,
            const Duration(minutes: 40),
          );
          expect(rig.mp4s.copies, hasLength(1));
        });

        test('an MP4 that could not be made: the relay goes on as it '
            'was', () async {
          await relayed();
          await rig.mp4s.last.failed();
          await rig.playback.coordinator.seek(const Duration(minutes: 30));
          await rig.loaded(2);
          expect(rig.relay.last.renews, hasLength(1));
          expect(rig.relay.files, isEmpty);
        });

        test('the end of the cast stops its making and deletes it', () async {
          await relayed();
          expect(rig.mp4s.last.deleted, isFalse);
          unawaited(rig.playback.coordinator.playLive(channel(1)));
          await rig.loaded(2);
          expect(rig.mp4s.copies.single.deleted, isTrue);
        });
      });
    });

    test('Stop casting saves where the TV was', () async {
      await castMovie();
      rig.tv.playing(position: const Duration(minutes: 12));
      await rig.phase(CastPhase.playing);
      await rig.coordinator.disconnect();
      expect(
        rig.playback.progress.lastPosition,
        greaterThanOrEqualTo(const Duration(minutes: 12)),
      );
    });

    test('Play here continues it on the laptop from its place', () async {
      await castMovie();
      rig.tv.playing(position: const Duration(minutes: 12));
      await rig.phase(CastPhase.playing);
      await rig.coordinator.playHere();
      final opened = rig.playback.engine.opened.single;
      expect(opened.live, isFalse);
      expect(opened.start, greaterThanOrEqualTo(const Duration(minutes: 12)));
    });
  });
}
