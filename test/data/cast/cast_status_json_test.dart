import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/data/cast/cast_status_json.dart';

/// Payloads as Living Room TV sent them in Phase 0
/// (spike/cast_spike/results), with made-up ids.
Map<String, Object?> _json(String text) =>
    jsonDecode(text) as Map<String, Object?>;

final Map<String, Object?> _idle = _json('''
{"requestId":1,"status":{"isActiveInput":true,"isStandBy":false,"userEq":{},
"volume":{"controlType":"fixed","level":1.0,"muted":false,
"stepInterval":0.03999999910593033}},"type":"RECEIVER_STATUS"}''');

final Map<String, Object?> _running = _json('''
{"requestId":2,"status":{"applications":[{"appId":"CC1AD845","appType":"WEB",
"displayName":"Default Media Receiver","iconUrl":"","isIdleScreen":false,
"launchedFromCloud":false,"namespaces":[{"name":"urn:x-cast:com.google.cast.media"}],
"senderConnected":false,"sessionId":"11111111-2222-4333-a444-555555555555",
"statusText":"Default Media Receiver",
"transportId":"11111111-2222-4333-a444-555555555555","universalAppId":"CC1AD845"}],
"isActiveInput":true,"isStandBy":false,"userEq":{},"volume":{"controlType":"fixed",
"level":1.0,"muted":false,"stepInterval":0.04}},"type":"RECEIVER_STATUS"}''');

final Map<String, Object?> _loadReply = _json('''
{"type":"MEDIA_STATUS","status":[{"mediaSessionId":1,"playbackRate":1,
"playerState":"IDLE","currentTime":0,"supportedMediaCommands":274447,
"volume":{"level":1,"muted":false},"media":{"contentId":"http://192.168.1.254:38400/f/t/media.mp4",
"contentType":"video/mp4","streamType":"BUFFERED","metadata":{"metadataType":0,
"title":"Spike B"},"mediaCategory":"VIDEO"},"currentItemId":1,
"extendedStatus":{"playerState":"LOADING","media":{"contentId":"http://192.168.1.254:38400/f/t/media.mp4"},
"mediaSessionId":1},"repeatMode":"REPEAT_OFF"}],"requestId":3}''');

final Map<String, Object?> _failed = _json('''
{"type":"MEDIA_STATUS","status":[{"mediaSessionId":1,"playbackRate":1,
"playerState":"IDLE","currentTime":0,"supportedMediaCommands":274447,
"volume":{"level":1,"muted":false},"currentItemId":1,"idleReason":"ERROR"}],
"requestId":0}''');

final Map<String, Object?> _cancelled = _json(
  '''
{"type":"MEDIA_STATUS","status":[{"mediaSessionId":1,"playbackRate":0,
"playerState":"IDLE","currentTime":0,"supportedMediaCommands":274447,
"volume":{"level":1,"muted":false},"videoInfo":{"width":3840,"height":2160,
"hdrType":"sdr"},"currentItemId":1,"idleReason":"CANCELLED"}],"requestId":9}''',
);

final Map<String, Object?> _zone = _json('''
{"requestId":0,"status":{"devices":[{"capabilities":458757,
"deviceId":"0A1B2C3D-4E5F-6071-8293-A4B5C6D7E8F9","name":"Living Room TV",
"volume":{"level":1.0,"muted":false}}],"isMultichannel":false,
"playbackSession":{"appAllowsGrouping":true,"isVideoContent":false,
"streamTransferSupported":true}},"type":"MULTIZONE_STATUS"}''');

Map<String, Object?> _media(Map<String, Object?> status) => {
  'type': 'MEDIA_STATUS',
  'status': [status],
};

void main() {
  group('RECEIVER_STATUS', () {
    test('a device running nothing: no apps, its fixed volume', () {
      final status = CastReceiverStatus.tryRead(_idle)!;
      expect(status.apps, isEmpty);
      expect(status.foreground, isNull);
      expect(status.volume, const CastVolume(fixed: true));
    });

    test('the Default Media Receiver running', () {
      final status = CastReceiverStatus.tryRead(_running)!;
      final app = status.app(defaultMediaReceiverAppId)!;
      expect(app.sessionId, '11111111-2222-4333-a444-555555555555');
      expect(app.transportId, app.sessionId);
      expect(app.displayName, 'Default Media Receiver');
      expect(status.session(app.sessionId), same(app));
      expect(status.foreground, same(app));
      expect(status.session('other'), isNull);
    });

    test('a status that is a string says nothing: null', () {
      expect(
        CastReceiverStatus.tryRead({
          'type': 'LAUNCH_STATUS',
          'status': 'USER_ALLOWED',
        }),
        isNull,
      );
      expect(CastReceiverStatus.tryRead({'type': 'RECEIVER_STATUS'}), isNull);
    });

    test('apps without an id or a session are left out; odd values read', () {
      final status = CastReceiverStatus.tryRead({
        'status': {
          'applications': [
            {'appId': 'A'},
            'not an app',
            {'appId': 'B', 'sessionId': 42, 'isIdleScreen': 'true'},
            {
              'appId': 'C',
              'sessionId': 's',
              'transportId': 't',
              'displayName': 'You\u0000Tube',
            },
          ],
          'volume': {'level': '1.7', 'muted': 1, 'controlType': 'attenuation'},
        },
      })!;
      expect([for (final a in status.apps) a.appId], ['B', 'C']);
      expect(status.apps.first.sessionId, '42');
      expect(status.apps.first.transportId, '42');
      expect(status.apps.first.idleScreen, isTrue);
      expect(status.foreground?.appId, 'C');
      expect(status.apps.last.displayName, 'You Tube');
      expect(status.volume, const CastVolume(muted: true));
    });

    test('applications as an object of rows, and a volume of nonsense', () {
      final status = CastReceiverStatus.tryRead({
        'status': {
          'applications': {
            'x': {'appId': 'A', 'sessionId': 's'},
          },
          'volume': 'loud',
        },
      })!;
      expect(status.apps.single.appId, 'A');
      expect(status.volume, const CastVolume());
    });
  });

  group('MEDIA_STATUS', () {
    test("a LOAD's first answer is loading, with the URL", () {
      final read = readMediaStatus(_loadReply);
      expect(read.present, isTrue);
      expect(
        read.media,
        const CastMediaStatus(
          sessionId: 1,
          playerState: CastPlayerState.loading,
          contentId: 'http://192.168.1.254:38400/f/t/media.mp4',
        ),
      );
    });

    test('IDLE/ERROR after a LOAD_FAILED; IDLE/CANCELLED after STOP', () {
      expect(
        readMediaStatus(_failed).media,
        const CastMediaStatus(
          sessionId: 1,
          playerState: CastPlayerState.idle,
          idleReason: CastIdleReason.error,
        ),
      );
      final cancelled = readMediaStatus(_cancelled).media!;
      expect(cancelled.idleReason, CastIdleReason.cancelled);
      expect(cancelled.rate, 0);
      expect((cancelled.videoWidth, cancelled.videoHeight), (3840, 2160));
    });

    test("an update without media keeps the session's URL and length", () {
      const previous = CastMediaStatus(
        sessionId: 4,
        playerState: CastPlayerState.buffering,
        contentId: 'http://relay/x',
        duration: Duration(minutes: 10),
        videoWidth: 1920,
        videoHeight: 1080,
      );
      final next = readMediaStatus(
        _media({
          'mediaSessionId': 4,
          'playerState': 'PLAYING',
          'currentTime': 12.3456,
        }),
        previous: previous,
      ).media!;
      expect(next.playerState, CastPlayerState.playing);
      expect(next.position, const Duration(milliseconds: 12346));
      expect(next.contentId, 'http://relay/x');
      expect(next.duration, const Duration(minutes: 10));
      expect(next.videoHeight, 1080);
      // Another session keeps nothing of it.
      final other = readMediaStatus(
        _media({'mediaSessionId': 5, 'playerState': 'PLAYING'}),
        previous: previous,
      ).media!;
      expect(other.contentId, isNull);
      expect(other.duration, isNull);
    });

    test('no media session: status [] or no status at all', () {
      for (final payload in [
        {'type': 'MEDIA_STATUS', 'status': <Object?>[]},
        {'type': 'MEDIA_STATUS'},
        {'type': 'MEDIA_STATUS', 'status': 'none'},
      ]) {
        final read = readMediaStatus(payload);
        expect(read.present, isFalse, reason: '$payload');
        expect(read.media, isNull);
      }
    });

    test('a status without a session id takes the previous one', () {
      const previous = CastMediaStatus(
        sessionId: 7,
        playerState: CastPlayerState.playing,
      );
      expect(
        readMediaStatus(
          _media({'playerState': 'PAUSED'}),
          previous: previous,
        ).media?.sessionId,
        7,
      );
      expect(
        readMediaStatus(_media({'playerState': 'PAUSED'})).present,
        isFalse,
      );
    });

    test('numbers as strings; nonsense times; unknown states', () {
      final media = readMediaStatus(
        _media({
          'mediaSessionId': '3',
          'playerState': 'playing',
          'currentTime': '61.5',
          'playbackRate': '1.0',
          'media': {'contentId': 'u', 'duration': '120.25'},
        }),
      ).media!;
      expect(media.sessionId, 3);
      expect(media.playerState, CastPlayerState.playing);
      expect(media.position, const Duration(milliseconds: 61500));
      expect(media.duration, const Duration(milliseconds: 120250));
      for (final time in [-1, 'NaN', 1e12, null, <Object?>[]]) {
        expect(
          readMediaStatus(_media({'mediaSessionId': 1, 'currentTime': time}))
              .media!
              .position,
          Duration.zero,
          reason: '$time',
        );
      }
      // An unknown state is neither an end nor an error.
      expect(
        readMediaStatus(
          _media({'mediaSessionId': 1, 'playerState': 'WARMING_UP'}),
        ).media!.playerState,
        CastPlayerState.buffering,
      );
      // An idle reason only means something while idle.
      expect(
        readMediaStatus(
          _media({
            'mediaSessionId': 1,
            'playerState': 'PLAYING',
            'idleReason': 'ERROR',
          }),
        ).media!.idleReason,
        isNull,
      );
    });

    test('a live stream has no length (-1, 0 or none)', () {
      for (final duration in [-1, 0, null]) {
        expect(
          readMediaStatus(
            _media({
              'mediaSessionId': 1,
              'media': {'streamType': 'LIVE', 'duration': duration},
            }),
          ).media!.duration,
          isNull,
        );
      }
    });
  });

  group('MULTIZONE_STATUS', () {
    test("the device's name and its id as TXT has it", () {
      final device = readZoneDevices(_zone).single;
      expect(device.id, '0a1b2c3d4e5f60718293a4b5c6d7e8f9');
      expect(device.name, 'Living Room TV');
      expect(device.capabilities, 458757);
    });

    test('ids that are not UUIDs are kept; rows without a name are not', () {
      final devices = readZoneDevices({
        'status': {
          'devices': [
            {'deviceId': 'Some-Id', 'name': 'Bedroom'},
            {'deviceId': 'x'},
            {'name': 'No id'},
            'junk',
          ],
        },
      });
      expect(devices.single.id, 'some-id');
      expect(devices.single.name, 'Bedroom');
      expect(devices.single.capabilities, isNull);
      expect(readZoneDevices({'status': 'none'}), isEmpty);
    });
  });
}
