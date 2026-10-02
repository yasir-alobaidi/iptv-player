import 'dart:io';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/data/cast/cast_v2_receivers.dart';

/// Every wait short, so a lost connection shows in a few hundred ms.
const _timings = CastTimings(
  connect: Duration(seconds: 2),
  answer: Duration(milliseconds: 500),
  launch: Duration(seconds: 2),
  command: Duration(seconds: 1),
  heartbeat: Duration(milliseconds: 100),
  reconnectFor: Duration(seconds: 2),
  firstRetry: Duration(milliseconds: 50),
  longestRetry: Duration(milliseconds: 200),
);

const _mp4 = CastLoad(
  url: 'http://127.0.0.1:1/f/token/media.mp4',
  contentType: 'video/mp4',
  live: false,
  title: 'Sample',
  start: Duration(seconds: 30),
);

/// The session's state once [test] holds, within [within].
Future<CastSessionState> _until(
  CastReceiverSession session,
  bool Function(CastSessionState state) test, {
  Duration within = const Duration(seconds: 4),
}) async {
  if (test(session.state)) return session.state;
  return await session.states.firstWhere(test).timeout(within);
}

/// Waits until [test] holds, polling; fails after [within].
Future<void> _eventually(
  bool Function() test, {
  Duration within = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(within);
  while (!test()) {
    if (DateTime.now().isAfter(deadline)) fail('not within $within');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

bool _playing(CastSessionState s) =>
    s.media?.playerState == CastPlayerState.playing;

void main() {
  late FakeReceiver fake;
  late CastV2Receivers receivers;
  CastReceiverSession? session;

  Future<void> startFake({
    FakeDevice device = const FakeDevice(),
    Duration launchDelay = const Duration(milliseconds: 50),
    bool receiverRunning = false,
  }) async {
    fake = await FakeReceiver.start(
      device: device,
      launchDelay: launchDelay,
      loadDelay: const Duration(milliseconds: 50),
      pingEvery: null,
      receiverRunning: receiverRunning,
    );
  }

  CastAddress address() => CastAddress(fake.host, fake.port);

  Future<CastReceiverSession> join() async {
    final result = await receivers.join(address());
    expect(result, isA<CastJoined>());
    return session = (result as CastJoined).session;
  }

  /// Joined, with the sample loaded and playing.
  Future<CastReceiverSession> playing() async {
    final joined = await join();
    expect(await joined.load(_mp4), isA<CastDone>());
    await _until(joined, _playing);
    return joined;
  }

  setUp(() {
    receivers = CastV2Receivers(timings: _timings);
    session = null;
  });

  tearDown(() async {
    if (session != null && session!.state.link != CastLink.ended) {
      await session!.leave();
    }
    await fake.close();
  });

  group('joining', () {
    test('launches the receiver when nothing runs', () async {
      await startFake();
      final result = await receivers.join(address());
      expect(result, isA<CastJoined>());
      final joined = result as CastJoined;
      session = joined.session;
      expect(joined.launched, isTrue);
      expect(fake.app?.appId, defaultMediaReceiverAppId);
      expect(fake.requests('LAUNCH'), hasLength(1));
      expect(session!.state.link, CastLink.connected);
      expect(session!.state.media, isNull);
      expect(session!.state.volume.fixed, isTrue);
      expect(session!.localAddress, '127.0.0.1');
    });

    test('joins a receiver already running, without LAUNCH', () async {
      await startFake(receiverRunning: true);
      final result = await receivers.join(address()) as CastJoined;
      session = result.session;
      expect(result.launched, isFalse);
      expect(fake.requests('LAUNCH'), isEmpty);
    });

    test("waits out a slow launch, like the TV's 3–6 s", () async {
      await startFake(launchDelay: const Duration(milliseconds: 800));
      final result = await receivers.join(address());
      expect(result, isA<CastJoined>());
      session = (result as CastJoined).session;
    });

    test('a launch past its time is launchTimedOut', () async {
      await startFake(launchDelay: const Duration(seconds: 5));
      final result = await receivers.join(address()) as CastJoinFailed;
      expect(result.reason, CastJoinFailure.launchTimedOut);
    });

    test('a refused launch is launchRefused, with the reason', () async {
      await startFake();
      fake.refuseLaunch = true;
      final result = await receivers.join(address()) as CastJoinFailed;
      expect(result.reason, CastJoinFailure.launchRefused);
      expect(result.detail, contains('NOT_ALLOWED'));
    });

    test('a device that takes the connection but says nothing', () async {
      await startFake();
      fake.silent = true;
      final result = await receivers.join(address()) as CastJoinFailed;
      expect(result.reason, CastJoinFailure.noAnswer);
    });

    test('nothing listening is unreachable', () async {
      await startFake();
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      final result = await receivers.join(
        CastAddress('127.0.0.1', port),
      ) as CastJoinFailed;
      expect(result.reason, CastJoinFailure.unreachable);
      expect(result.detail, isNotNull);
    });
  });

  group('media', () {
    test('LOAD: taken at once, then playing from where it starts', () async {
      await startFake();
      final joined = await join();
      final taken = await joined.load(_mp4) as CastDone;
      expect(taken.media?.playerState, CastPlayerState.loading);
      expect(taken.media?.contentId, _mp4.url);
      final state = await _until(joined, _playing);
      expect(state.media?.contentId, _mp4.url);
      expect(state.media!.position, greaterThanOrEqualTo(_mp4.start));
      final load = fake.requests('LOAD').single.payload;
      expect(load['currentTime'], 30);
      expect((load['media']! as Map)['streamType'], 'BUFFERED');
    });

    test('pause, seek, play and stop, each answered with the status', () async {
      await startFake();
      final joined = await playing();
      final paused = await joined.pause() as CastDone;
      expect(paused.media?.playerState, CastPlayerState.paused);
      final seeked =
          await joined.seek(const Duration(seconds: 100)) as CastDone;
      expect(seeked.media?.position, const Duration(seconds: 100));
      expect(seeked.media?.playerState, CastPlayerState.paused);
      final played = await joined.play() as CastDone;
      expect(played.media?.playerState, CastPlayerState.playing);
      final stopped = await joined.stopMedia() as CastDone;
      expect(stopped.media?.idleReason, CastIdleReason.cancelled);
      // The session is gone on the device now.
      final after = await joined.play() as CastRefused;
      expect(after.reason, CastRefusal.noMedia);
      expect(joined.state.link, CastLink.connected);
    });

    test('a LOAD the TV cannot play: taken, then IDLE with an error', () async {
      await startFake();
      fake.refuseLoads((_) => true);
      final joined = await join();
      expect(await joined.load(_mp4), isA<CastDone>());
      final state = await _until(
        joined,
        (s) => s.media?.idleReason == CastIdleReason.error,
      );
      expect(state.media?.playerState, CastPlayerState.idle);
    });

    test('commands with nothing loaded are refused without asking', () async {
      await startFake();
      final joined = await join();
      final asked = fake.received.length;
      expect((await joined.pause() as CastRefused).reason, CastRefusal.noMedia);
      expect(fake.received.length, asked);
    });

    test('a status of an older media session is out of date', () async {
      await startFake();
      final joined = await playing();
      expect(await joined.load(_mp4), isA<CastDone>());
      await _until(joined, (s) => _playing(s) && s.media!.sessionId == 2);
      fake.sendJson(nsMedia, {
        'type': 'MEDIA_STATUS',
        'status': [
          {
            'mediaSessionId': 1,
            'playerState': 'IDLE',
            'idleReason': 'INTERRUPTED',
          },
        ],
      }, source: fake.app!.transportId);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(joined.state.media?.sessionId, 2);
      expect(_playing(joined.state), isTrue);
    });
  });

  group('volume', () {
    test('a fixed volume stays as the TV has it', () async {
      await startFake();
      final joined = await join();
      expect(await joined.setVolume(0.3), isA<CastDone>());
      expect(joined.state.volume, const CastVolume(fixed: true));
    });

    test('a device that takes it: level and mute', () async {
      await startFake(device: const FakeDevice(fixedVolume: false));
      final joined = await join();
      expect(await joined.setVolume(0.3), isA<CastDone>());
      await _until(joined, (s) => s.volume.level == 0.3);
      expect(await joined.setMuted(muted: true), isA<CastDone>());
      await _until(joined, (s) => s.volume.muted);
      final sent = fake.requests('SET_VOLUME');
      expect(sent.first.payload['volume'], {'level': 0.3});
      expect(sent.last.payload['volume'], {'muted': true});
    });
  });

  group('following the TV', () {
    test('its remote pausing and playing', () async {
      await startFake();
      final joined = await playing();
      fake.remotePause();
      await _until(
        joined,
        (s) => s.media?.playerState == CastPlayerState.paused,
      );
      fake.remotePlay();
      await _until(joined, _playing);
    });

    test('its remote going Back closes the session', () async {
      await startFake();
      final joined = await playing();
      fake.remoteBack();
      final ended = await _until(joined, (s) => s.link == CastLink.ended);
      expect(ended.end, CastEnd.closedOnDevice);
    });

    test('another app taking the TV ends the session with its name', () async {
      await startFake();
      final joined = await playing();
      fake.startOtherApp();
      final ended = await _until(joined, (s) => s.link == CastLink.ended);
      expect(ended.end, CastEnd.otherApp);
      expect(ended.otherApp, 'YouTube');
      expect(await joined.play(), isA<CastDisconnected>());
    });

    test('junk from the device changes nothing', () async {
      await startFake();
      final joined = await playing();
      final before = joined.state;
      fake
        ..sendRaw([0, 0, 0, 3, 0xff, 0xff, 0xff])
        ..sendJson('urn:x-cast:com.example.unknown', {'type': 'HELLO'})
        ..sendJson(nsReceiver, {'type': 'RECEIVER_STATUS', 'status': 'odd'})
        ..sendJson(nsMedia, {
          'type': 'MEDIA_STATUS',
          'status': 'odd',
        }, source: 'someone-else');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(joined.state, before);
      expect(
        (await joined.pause() as CastDone).media?.playerState,
        CastPlayerState.paused,
      );
    });
  });

  group('reconnecting', () {
    test(
      'a dropped connection: back on the same receiver, still playing',
      () async {
        await startFake();
        final joined = await playing();
        final app = fake.app;
        final links = <CastLink>[];
        joined.states.listen((s) => links.add(s.link));
        fake.dropConnections();
        await _until(joined, (s) => s.link == CastLink.reconnecting);
        final back = await _until(joined, (s) => s.link == CastLink.connected);
        expect(
          links,
          containsAllInOrder([CastLink.reconnecting, CastLink.connected]),
        );
        expect(fake.app, same(app));
        expect(fake.requests('LAUNCH'), hasLength(1));
        expect(_playing(back), isTrue);
        expect(await joined.pause(), isA<CastDone>());
      },
    );

    test('a silent heartbeat loses the connection; it comes back', () async {
      await startFake();
      final joined = await playing();
      fake.heartbeat = false;
      await _until(joined, (s) => s.link == CastLink.reconnecting);
      fake.heartbeat = true;
      await _until(joined, (s) => s.link == CastLink.connected);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(joined.state.link, CastLink.connected);
      expect(fake.app?.appId, defaultMediaReceiverAppId);
    });

    test('a message over 64 KiB breaks the framing; it reconnects', () async {
      await startFake();
      final joined = await playing();
      fake.sendRaw([0x00, 0x01, 0x00, 0x01]);
      await _until(joined, (s) => s.link == CastLink.reconnecting);
      await _until(joined, (s) => s.link == CastLink.connected);
    });

    test('commands while reconnecting are not sent', () async {
      await startFake();
      final joined = await playing();
      fake
        ..refuseConnections = true
        ..dropConnections();
      await _until(joined, (s) => s.link == CastLink.reconnecting);
      expect(await joined.pause(), isA<CastDisconnected>());
      expect(await joined.load(_mp4), isA<CastDisconnected>());
      fake.refuseConnections = false;
      await _until(joined, (s) => s.link == CastLink.connected);
    });

    test('the receiver closed while away: the session ends', () async {
      await startFake();
      final joined = await playing();
      fake
        ..refuseConnections = true
        ..dropConnections();
      await _until(joined, (s) => s.link == CastLink.reconnecting);
      fake
        ..remoteBack()
        ..refuseConnections = false;
      final ended = await _until(joined, (s) => s.link == CastLink.ended);
      expect(ended.end, CastEnd.closedOnDevice);
    });

    test('no way back within the time: lost', () async {
      await startFake();
      final joined = await playing();
      fake
        ..refuseConnections = true
        ..dropConnections();
      final ended = await _until(
        joined,
        (s) => s.link == CastLink.ended,
        within: const Duration(seconds: 6),
      );
      expect(ended.end, CastEnd.lost);
    });
  });

  group('ending', () {
    test('stop closes the receiver: the TV goes home', () async {
      await startFake();
      final joined = await playing();
      final sessionId = fake.app!.sessionId;
      await joined.stop();
      expect(joined.state.link, CastLink.ended);
      expect(joined.state.end, CastEnd.stopped);
      expect(fake.app, isNull);
      final stop = fake.received.lastWhere(
        (m) => m.namespace == nsReceiver && m.type == 'STOP',
      );
      expect(stop.payload['sessionId'], sessionId);
    });

    test('leave lets go and leaves it playing', () async {
      await startFake();
      final joined = await playing();
      await joined.leave();
      expect(joined.state.end, CastEnd.left);
      expect(fake.app?.appId, defaultMediaReceiverAppId);
      expect(fake.playerState, 'PLAYING');
      List<String> closes() => [
        for (final m in fake.received)
          if (m.namespace == nsConnection && m.type == 'CLOSE') m.destination,
      ];
      await _eventually(() => closes().length == 2);
      expect(closes(), [fake.app!.transportId, receiverId]);
    });

    test('stop while reconnecting ends it at once', () async {
      await startFake();
      final joined = await playing();
      fake
        ..refuseConnections = true
        ..dropConnections();
      await _until(joined, (s) => s.link == CastLink.reconnecting);
      await joined.stop();
      expect(joined.state.end, CastEnd.stopped);
      fake.refuseConnections = false;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(fake.connections, 0);
    });
  });
}
