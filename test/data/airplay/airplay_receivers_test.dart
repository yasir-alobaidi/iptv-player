import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_pairing.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/airplay/airplay_browser.dart';
import 'package:iptv_player/data/airplay/airplay_receivers.dart';
import 'package:iptv_player/data/airplay/airplay_session.dart';
import 'package:iptv_player/data/airplay/hap_pairing.dart';

/// The Hisense Roku TV's record (test/data/airplay/airplay_features_test).
const _roku = {
  'pi': 'D1:3C:2C:48:B5:B5',
  'manufacturer': 'Hisense',
  'model': 'G204X',
  'flags': '0x244',
  'features': '0x7F8AD0,0x38BCF46',
  'deviceid': 'D1:3C:2C:48:B5:B5',
  'acl': '0',
};

final class _FakePlayback implements AirPlayPlayback {
  final calls = <String>[];
  final stateEvents = StreamController<String>.broadcast();
  AirPlayResult<void> answer = const AirPlayOk(null);

  @override
  String get localAddress => '192.168.1.254';

  @override
  Stream<String> get states => stateEvents.stream;

  @override
  Future<AirPlayResult<void>> play(String url, {double position = 0}) async {
    calls.add('play $url @$position');
    return answer;
  }

  @override
  Future<AirPlayResult<void>> setRate(double rate) async {
    calls.add('rate $rate');
    return answer;
  }

  @override
  Future<void> close() async {
    calls.add('close');
    await stateEvents.close();
  }
}

final _credentials = HapCredentials(
  deviceLtpk: Uint8List.fromList(List.filled(32, 1)),
  ltsk: Uint8List.fromList(List.filled(32, 2)),
  deviceId: Uint8List.fromList(utf8.encode('D1:3C:2C:48:B5:B5')),
  pairingId: Uint8List.fromList(
    utf8.encode('b0b0b0b0-0000-4000-8000-000000000000'),
  ),
);

void main() {
  group('the Roku as a device to cast to', () {
    test('found by its record: an AirPlay id, port 7000, its maker and '
        'model, and a code to pair with', () {
      final answer = readAirPlayService(
        instance: '58in Hisense Roku TV',
        txt: _roku,
        hosts: ['fe80::1', '192.168.1.162'],
        port: 7000,
      );
      final device = (answer! as CastDeviceAnswered).device;
      expect(device.id, 'airplay:D1:3C:2C:48:B5:B5');
      expect(device.protocol, CastProtocol.airPlay);
      expect(device.host, '192.168.1.162');
      expect(device.port, 7000);
      expect(device.model, 'Hisense G204X');
      expect(device.needsPairing, isTrue);
    });

    test('a speaker, a receiver with a password, or one with no id is '
        'left out', () {
      CastAddressAnswer? read(Map<String, String> txt) => readAirPlayService(
        instance: 'Kitchen',
        txt: txt,
        hosts: ['192.168.1.5'],
      );
      expect(read({..._roku, 'features': '0x200'}), isNull);
      expect(read({..._roku, 'flags': '0x80'}), isNull);
      expect(read({..._roku}..remove('deviceid')), isNull);
    });
  });

  group('AirPlayReceivers', () {
    late InMemoryCredentialStore store;
    late AirPlayCredentials credentials;
    setUp(() {
      store = InMemoryCredentialStore();
      credentials = AirPlayCredentials(store);
    });

    test('joins with the pairing kept for the device, and says where this '
        'computer is', () async {
      await credentials.write('airplay:TV', _credentials);
      HapCredentials? used;
      final receivers = AirPlayReceivers(
        credentials: credentials,
        connect: (host, port, {credentials}) async {
          used = credentials;
          return AirPlayOk(_FakePlayback());
        },
      );
      String? local;
      final result = await receivers.join(
        const CastAddress('192.168.1.162', 7000),
        deviceId: 'airplay:TV',
        onConnected: (address) => local = address,
      );
      expect(result, isA<CastJoined>());
      expect(used, _credentials);
      expect(local, '192.168.1.254');
    });

    test('a TV that wants pairing says so', () async {
      final receivers = AirPlayReceivers(
        credentials: credentials,
        connect: (host, port, {credentials}) async =>
            const AirPlayFailed(AirPlayNeedsPairing()),
      );
      final result = await receivers.join(
        const CastAddress('192.168.1.162', 7000),
        deviceId: 'airplay:TV',
      );
      expect((result as CastJoinFailed).reason, CastJoinFailure.needsPairing);
    });

    test('a TV that forgot this computer: the pairing is dropped, and it '
        'asks for a new one', () async {
      await credentials.write('airplay:TV', _credentials);
      final receivers = AirPlayReceivers(
        credentials: credentials,
        connect: (host, port, {credentials}) async => const AirPlayFailed(
          AirPlayPairingFailed(HapVerificationFailed('unknown')),
        ),
      );
      final result = await receivers.join(
        const CastAddress('192.168.1.162', 7000),
        deviceId: 'airplay:TV',
      );
      expect((result as CastJoinFailed).reason, CastJoinFailure.needsPairing);
      expect(await credentials.read('airplay:TV'), isNull);
    });

    test('nothing at the address is unreachable', () async {
      final receivers = AirPlayReceivers(
        credentials: credentials,
        connect: (host, port, {credentials}) async =>
            const AirPlayFailed(AirPlayUnreachable('no connection')),
      );
      final result = await receivers.join(
        const CastAddress('192.168.1.162', 7000),
      );
      expect((result as CastJoinFailed).reason, CastJoinFailure.unreachable);
    });
  });

  group('AirPlayCastSession', () {
    late _FakePlayback playback;
    late AirPlayCastSession session;
    setUp(() {
      playback = _FakePlayback();
      session = AirPlayCastSession(
        const CastAddress('192.168.1.162', 7000),
        playback,
      );
    });

    test('LOAD plays the URL from its start; play and pause are the rate; '
        "the volume is the TV's own", () async {
      expect(
        await session.load(
          const CastLoad(
            url: 'http://192.168.1.254:38400/t/index.m3u8',
            contentType: 'application/x-mpegurl',
            live: false,
            title: 'A film',
            start: Duration(seconds: 90),
          ),
        ),
        isA<CastDone>(),
      );
      expect(session.state.media?.playerState, CastPlayerState.loading);
      await session.pause();
      await session.play();
      expect(playback.calls, [
        'play http://192.168.1.254:38400/t/index.m3u8 @90.0',
        'rate 0.0',
        'rate 1.0',
      ]);
      expect(session.state.volume.fixed, isTrue);
      expect(await session.setVolume(0.5), isA<CastRefused>());
    });

    test("the TV's playback states, as Cast's", () async {
      await session.load(
        const CastLoad(
          url: 'http://x/index.m3u8',
          contentType: 'application/x-mpegurl',
          live: true,
          title: 'A channel',
        ),
      );
      final seen = <CastPlayerState?>[];
      session.states.listen((state) => seen.add(state.media?.playerState));
      playback.stateEvents
        ..add('playing')
        ..add('paused');
      await pumpEventQueue();
      expect(seen, [CastPlayerState.playing, CastPlayerState.paused]);
    });

    test(
      'a LOAD the TV refuses is a failed load, idle with an error',
      () async {
        playback.answer = const AirPlayFailed(
          AirPlayRefused('POST /command', 500),
        );
        final result = await session.load(
          const CastLoad(
            url: 'http://x/index.m3u8',
            contentType: 'application/x-mpegurl',
            live: true,
            title: 'A channel',
          ),
        );
        expect((result as CastRefused).reason, CastRefusal.loadFailed);
        expect(session.state.media?.idleReason, CastIdleReason.error);
      },
    );

    test('the connection closed on the TV ends the session; stop closes it '
        'here', () async {
      await playback.stateEvents.close();
      await pumpEventQueue();
      expect(session.state.link, CastLink.ended);
      expect(session.state.end, CastEnd.closedOnDevice);
      expect(await session.play(), isA<CastDisconnected>());
    });
  });

  test('ProtocolCastReceivers sends each join to its protocol', () async {
    final google = _Recording();
    final airPlay = _Recording();
    final receivers = ProtocolCastReceivers(
      googleCast: google,
      airPlay: airPlay,
    );
    await receivers.join(const CastAddress('a'));
    await receivers.join(
      const CastAddress('b', 7000),
      protocol: CastProtocol.airPlay,
      deviceId: 'airplay:B',
    );
    expect(google.joined, ['a']);
    expect(airPlay.joined, ['b:7000 airplay:B']);
  });

  group('AirPlayCastPairing', () {
    test("a TV out of reach can't pair; a paired one is known", () async {
      final credentials = AirPlayCredentials(InMemoryCredentialStore());
      final pairing = AirPlayCastPairing(
        credentials: credentials,
        startPairing: (host, port) async =>
            const AirPlayFailed(AirPlayUnreachable('no connection')),
      );
      const tv = CastDevice(
        id: 'airplay:TV',
        name: 'TV',
        host: '192.168.1.162',
        port: 7000,
      );
      final started = await pairing.start(tv);
      expect(
        (started as CastPairingUnavailable).reason,
        CastPairingProblem.unreachable,
      );
      expect(await pairing.isPaired(tv), isFalse);
      await credentials.write(tv.id, _credentials);
      expect(await pairing.isPaired(tv), isTrue);
      await pairing.forget(tv);
      expect(await pairing.isPaired(tv), isFalse);
    });
  });
}

final class _Recording implements CastReceivers {
  final joined = <String>[];

  @override
  Future<CastJoinResult> join(
    CastAddress address, {
    void Function(String localAddress)? onConnected,
    CastProtocol protocol = CastProtocol.googleCast,
    String? deviceId,
  }) async {
    joined.add('$address${deviceId == null ? '' : ' $deviceId'}');
    return const CastJoinFailed(CastJoinFailure.unreachable);
  }
}
