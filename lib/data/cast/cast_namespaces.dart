import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/data/cast/cast_channel.dart';
import 'package:iptv_player/data/cast/cast_status_json.dart';

/// The device's receiver namespace on a [CastChannel] (docs/04): what
/// runs, LAUNCH, STOP and the volume. Each call opens the virtual
/// connection to `receiver-0` first if needed.
final class ReceiverChannel {
  const new(this._channel);

  final CastChannel _channel;

  /// What runs on the device now; null when it didn't answer.
  Future<CastReceiverStatus?> status({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final reply = await _request({'type': 'GET_STATUS'}, timeout);
    return reply?.type == 'RECEIVER_STATUS'
        ? CastReceiverStatus.tryRead(reply!.payload)
        : null;
  }

  /// Starts [appId]. The device answers once it runs (RECEIVER_STATUS),
  /// or with LAUNCH_ERROR; it sends a LAUNCH_STATUS before either, which
  /// is not the answer. Null when nothing answered in [timeout].
  Future<CastMessageIn?> launch(String appId, {required Duration timeout}) =>
      _request({'type': 'LAUNCH', 'appId': appId}, timeout);

  /// Closes the app session [sessionId]; the TV returns to its home screen.
  Future<CastMessageIn?> stop(
    String sessionId, {
    Duration timeout = const Duration(seconds: 5),
  }) => _request({'type': 'STOP', 'sessionId': sessionId}, timeout);

  /// Sets the device's volume [level] (0–1), or mutes it.
  Future<CastMessageIn?> setVolume({
    double? level,
    bool? muted,
    Duration timeout = const Duration(seconds: 5),
  }) => _request({
    'type': 'SET_VOLUME',
    'volume': {'level': ?level?.clamp(0, 1), 'muted': ?muted},
  }, timeout);

  Future<CastMessageIn?> _request(
    Map<String, Object?> payload,
    Duration timeout,
  ) {
    _channel.connectTo(castReceiverId);
    return _channel.request(
      castReceiverId,
      CastNamespace.receiver,
      payload,
      timeout: timeout,
    );
  }
}

/// The media namespace of the app at [transportId] (docs/04): LOAD and
/// the commands on a media session.
final class MediaChannel {
  const new(this._channel, this.transportId);

  final CastChannel _channel;
  final String transportId;

  /// The device answers a LOAD it took with a MEDIA_STATUS at once
  /// (playerState IDLE, "LOADING"), and a LOAD it can't play with
  /// LOAD_FAILED, as a second answer to the same request when it already
  /// sent the first (seen on Living Room TV: 1.6 s later).
  Future<CastMessageIn?> load(
    CastLoad load, {
    Duration timeout = const Duration(seconds: 10),
  }) => _request(loadPayload(load), timeout);

  /// PLAY, PAUSE, STOP or SEEK on [mediaSessionId].
  Future<CastMessageIn?> command(
    String type,
    int mediaSessionId, {
    Map<String, Object?> extra = const {},
    Duration timeout = const Duration(seconds: 10),
  }) => _request({
    'type': type,
    'mediaSessionId': mediaSessionId,
    ...extra,
  }, timeout);

  /// The media session's status (`status: []` when there is none).
  Future<CastMessageIn?> status({
    Duration timeout = const Duration(seconds: 5),
  }) => _request({'type': 'GET_STATUS'}, timeout);

  Future<CastMessageIn?> _request(
    Map<String, Object?> payload,
    Duration timeout,
  ) {
    _channel.connectTo(transportId);
    return _channel.request(
      transportId,
      CastNamespace.media,
      payload,
      timeout: timeout,
    );
  }
}

/// LOAD with the fields verified on the device (ADR-004): no segment
/// format fields, `autoplay`, and `currentTime` where a file starts.
Map<String, Object?> loadPayload(CastLoad load) => {
  'type': 'LOAD',
  'media': {
    'contentId': load.url,
    'contentType': load.contentType,
    'streamType': load.live ? 'LIVE' : 'BUFFERED',
    if (load.duration case final duration? when !load.live)
      'duration': duration.inMilliseconds / 1000,
    'metadata': {
      'metadataType': 0,
      'title': load.title,
      'subtitle': ?load.subtitle,
      if (load.imageUrl case final url?)
        'images': [
          {'url': url},
        ],
    },
  },
  'autoplay': true,
  'currentTime': load.start.inMilliseconds / 1000,
};

/// What an answer to a command means. [open] says whether the channel was
/// still up, which tells a timeout from a lost connection.
CastCommandResult castCommandResult(
  CastMessageIn? reply, {
  required bool open,
  CastMediaStatus? previous,
}) {
  if (reply == null) {
    return open ? const CastUnanswered() : const CastDisconnected();
  }
  final type = reply.type?.toUpperCase();
  final reason = reply.payload['reason']?.toString();
  return switch (type) {
    'MEDIA_STATUS' => CastDone(
      readMediaStatus(reply.payload, previous: previous).media,
    ),
    'RECEIVER_STATUS' => CastDone(previous),
    'LOAD_FAILED' => CastRefused(CastRefusal.loadFailed, type),
    'LOAD_CANCELLED' => CastRefused(CastRefusal.loadCancelled, type),
    'INVALID_PLAYER_STATE' => CastRefused(CastRefusal.invalidState, type),
    'INVALID_REQUEST'
        when reason?.toUpperCase() == 'INVALID_MEDIA_SESSION_ID' =>
      CastRefused(CastRefusal.noMedia, '$type $reason'),
    _ => CastRefused(
      CastRefusal.invalidRequest,
      reason == null ? '$type' : '$type $reason',
    ),
  };
}
