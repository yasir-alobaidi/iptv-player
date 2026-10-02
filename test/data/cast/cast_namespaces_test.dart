import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/data/cast/cast_channel.dart';
import 'package:iptv_player/data/cast/cast_namespaces.dart';

CastMessageIn _reply(Map<String, Object?> payload) => CastMessageIn(
  source: 'app',
  namespace: CastNamespace.media,
  payload: payload,
);

void main() {
  group('LOAD', () {
    test('a live HLS stream: the fields ADR-004 verified, nothing more', () {
      final payload = loadPayload(
        const CastLoad(
          url: 'http://192.168.1.254:38400/r/token/index.m3u8',
          contentType: 'application/x-mpegurl',
          live: true,
          title: 'Arena Sports 1',
          duration: Duration(hours: 1),
        ),
      );
      expect(payload, {
        'type': 'LOAD',
        'media': {
          'contentId': 'http://192.168.1.254:38400/r/token/index.m3u8',
          'contentType': 'application/x-mpegurl',
          'streamType': 'LIVE',
          'metadata': {'metadataType': 0, 'title': 'Arena Sports 1'},
        },
        'autoplay': true,
        'currentTime': 0,
      });
    });

    test(
      'a file: BUFFERED, its start and length, the subtitle and picture',
      () {
        final payload = loadPayload(
          const CastLoad(
            url: 'http://192.168.1.254:38400/f/token/media.mp4',
            contentType: 'video/mp4',
            live: false,
            title: 'Blue Water',
            subtitle: '2024 · Drama',
            imageUrl: 'http://192.168.1.254:38400/i/token/poster.jpg',
            start: Duration(minutes: 42, seconds: 10, milliseconds: 500),
            duration: Duration(hours: 1, minutes: 58),
          ),
        );
        final media = payload['media']! as Map<String, Object?>;
        expect(media['streamType'], 'BUFFERED');
        expect(media['duration'], 7080);
        expect(media['metadata'], {
          'metadataType': 0,
          'title': 'Blue Water',
          'subtitle': '2024 · Drama',
          'images': [
            {'url': 'http://192.168.1.254:38400/i/token/poster.jpg'},
          ],
        });
        expect(payload['currentTime'], 2530.5);
        expect(media.keys, isNot(contains('hlsSegmentFormat')));
      },
    );
  });

  group('answers', () {
    CastCommandResult result(
      Map<String, Object?>? payload, {
      bool open = true,
    }) =>
        castCommandResult(payload == null ? null : _reply(payload), open: open);

    test('none: unanswered while connected, disconnected otherwise', () {
      expect(result(null), isA<CastUnanswered>());
      expect(result(null, open: false), isA<CastDisconnected>());
    });

    test('a MEDIA_STATUS is done, with the status', () {
      final done = result({
        'type': 'MEDIA_STATUS',
        'status': [
          {'mediaSessionId': 2, 'playerState': 'PAUSED'},
        ],
      });
      expect(
        (done as CastDone).media,
        const CastMediaStatus(
          sessionId: 2,
          playerState: CastPlayerState.paused,
        ),
      );
    });

    test('a RECEIVER_STATUS is done, keeping what plays', () {
      const playing = CastMediaStatus(
        sessionId: 1,
        playerState: CastPlayerState.playing,
      );
      final done = castCommandResult(
        _reply({'type': 'RECEIVER_STATUS', 'status': <String, Object?>{}}),
        open: true,
        previous: playing,
      );
      expect((done as CastDone).media, playing);
    });

    test('each refusal by its name', () {
      CastRefusal? refusal(Map<String, Object?> payload) =>
          (result(payload) as CastRefused).reason;
      expect(
        refusal({'type': 'LOAD_FAILED', 'severity': 2, 'itemId': 1}),
        CastRefusal.loadFailed,
      );
      expect(refusal({'type': 'LOAD_CANCELLED'}), CastRefusal.loadCancelled);
      expect(
        refusal({
          'type': 'INVALID_REQUEST',
          'reason': 'INVALID_MEDIA_SESSION_ID',
        }),
        CastRefusal.noMedia,
      );
      expect(
        refusal({'type': 'INVALID_PLAYER_STATE'}),
        CastRefusal.invalidState,
      );
      expect(
        refusal({'type': 'INVALID_REQUEST', 'reason': 'INVALID_COMMAND'}),
        CastRefusal.invalidRequest,
      );
      expect(refusal({'type': 'SOMETHING_NEW'}), CastRefusal.invalidRequest);
      expect(refusal({'requestId': 3}), CastRefusal.invalidRequest);
    });

    test("a refusal keeps the device's words for the log", () {
      final refused = result({
        'type': 'INVALID_REQUEST',
        'reason': 'INVALID_PARAMS',
      }) as CastRefused;
      expect(refused.detail, 'INVALID_REQUEST INVALID_PARAMS');
    });
  });
}
