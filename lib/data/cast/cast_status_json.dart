/// Readers for what a Cast device reports (docs/04). Tolerant, as for a
/// provider's data (hard rule 1): numbers as strings, a `status` that is a
/// string rather than an object, missing fields. None of them throw.
library;

import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/data/cast/cast_txt.dart';
import 'package:iptv_player/data/providers/xtream/tolerant_json.dart';

/// An app running on the device (RECEIVER_STATUS `applications`).
final class CastRunningApp {
  const new({
    required this.appId,
    required this.sessionId,
    required this.transportId,
    this.displayName,
    this.idleScreen = false,
  });

  final String appId;
  final String sessionId;

  /// Where its messages go; a virtual connection is opened to it first.
  final String transportId;

  /// "Default Media Receiver", "YouTube", …
  final String? displayName;

  /// The device's own backdrop, shown when nothing is cast.
  final bool idleScreen;
}

/// RECEIVER_STATUS: the apps running, and the device's volume.
final class CastReceiverStatus {
  const new({required this.apps, required this.volume});

  /// Reads a RECEIVER_STATUS payload; null when its `status` isn't an
  /// object, which says nothing about what runs. A status without
  /// `applications` is a device running nothing.
  static CastReceiverStatus? tryRead(Map<String, Object?> payload) {
    final status = payload['status'];
    if (status is! Map<String, Object?>) return null;
    final apps = <CastRunningApp>[];
    for (final row in readRows(status['applications'])) {
      final app = readMap(row);
      final appId = readString(app['appId']);
      final sessionId = readString(app['sessionId']);
      final transportId = readString(app['transportId']) ?? sessionId;
      if (appId == null || sessionId == null || transportId == null) continue;
      apps.add(
        CastRunningApp(
          appId: appId,
          sessionId: sessionId,
          transportId: transportId,
          displayName: cleanCastText(readString(app['displayName'])),
          idleScreen: readBool(app['isIdleScreen']) ?? false,
        ),
      );
    }
    return CastReceiverStatus(
      apps: apps,
      volume: readCastVolume(status['volume']),
    );
  }

  final List<CastRunningApp> apps;
  final CastVolume volume;

  /// The running app with [appId], if any.
  CastRunningApp? app(String appId) =>
      apps.where((a) => a.appId == appId).firstOrNull;

  /// The app with [sessionId], if it still runs.
  CastRunningApp? session(String sessionId) =>
      apps.where((a) => a.sessionId == sessionId).firstOrNull;

  /// What the device shows other than its backdrop, if anything.
  CastRunningApp? get foreground =>
      apps.where((a) => !a.idleScreen).firstOrNull;
}

/// A `volume` object: `level` 0–1, `muted`, `controlType` (`fixed` when
/// the TV's own remote sets it).
CastVolume readCastVolume(Object? value) {
  final volume = readMap(value);
  final level = readDouble(volume['level']);
  return CastVolume(
    level: level == null ? 1 : level.clamp(0, 1).toDouble(),
    muted: readBool(volume['muted']) ?? false,
    fixed: readString(volume['controlType'])?.toLowerCase() == 'fixed',
  );
}

/// The media session in a MEDIA_STATUS payload: `present` is false when
/// it lists none (`status: []`). A status without a session id of its own
/// takes [previous]'s; one that leaves out `media` (the device sends it
/// only when it changes) keeps [previous]'s URL and length.
({bool present, CastMediaStatus? media}) readMediaStatus(
  Map<String, Object?> payload, {
  CastMediaStatus? previous,
}) {
  final rows = readRows(payload['status']);
  if (rows.isEmpty) return (present: false, media: null);
  final status = readMap(rows.first);
  final sessionId = readInt(status['mediaSessionId']) ?? previous?.sessionId;
  if (sessionId == null) return (present: false, media: null);
  final same = previous?.sessionId == sessionId ? previous : null;
  final extended = readMap(status['extendedStatus']);
  final media = readMap(status['media']).isNotEmpty
      ? readMap(status['media'])
      : readMap(extended['media']);
  final state = _playerState(
    readString(status['playerState']),
    extended: readString(extended['playerState']),
  );
  final duration = _seconds(media['duration']);
  final video = readMap(status['videoInfo']);
  return (
    present: true,
    media: CastMediaStatus(
      sessionId: sessionId,
      playerState: state,
      idleReason: state == CastPlayerState.idle
          ? _idleReason(readString(status['idleReason']))
          : null,
      position: _seconds(status['currentTime']) ?? Duration.zero,
      duration: duration != null && duration > Duration.zero
          ? duration
          : same?.duration,
      rate: readDouble(status['playbackRate']) ?? 1,
      contentId: readString(media['contentId']) ?? same?.contentId,
      videoWidth: readInt(video['width']) ?? same?.videoWidth,
      videoHeight: readInt(video['height']) ?? same?.videoHeight,
    ),
  );
}

/// IDLE while the device fetches what a LOAD named is "loading": its
/// `extendedStatus` says so. A state the app doesn't know is buffering —
/// neither an end nor an error.
CastPlayerState _playerState(String? state, {String? extended}) => switch (state
    ?.toUpperCase()) {
  'IDLE' when extended?.toUpperCase() == 'LOADING' => CastPlayerState.loading,
  'IDLE' => CastPlayerState.idle,
  'LOADING' => CastPlayerState.loading,
  'PLAYING' => CastPlayerState.playing,
  'PAUSED' => CastPlayerState.paused,
  _ => CastPlayerState.buffering,
};

CastIdleReason? _idleReason(String? reason) => switch (reason?.toUpperCase()) {
  'FINISHED' => CastIdleReason.finished,
  'CANCELLED' => CastIdleReason.cancelled,
  'INTERRUPTED' => CastIdleReason.interrupted,
  'ERROR' => CastIdleReason.error,
  _ => null,
};

/// Seconds as a [Duration], to the millisecond; null for none, negative
/// or not a number.
Duration? _seconds(Object? value) {
  final seconds = readDouble(value);
  if (seconds == null || seconds < 0 || seconds > 1e9) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

/// A device in MULTIZONE_STATUS: the device itself, for one that isn't
/// part of a group. Cast devices send it with their name and id, which
/// RECEIVER_STATUS lacks.
final class CastZoneDevice {
  const new({required this.id, required this.name, this.capabilities});

  /// The device id as discovery's TXT `id` has it: 32 lower-case hex
  /// digits, from the UUID's form here.
  final String id;
  final String name;
  final int? capabilities;
}

/// The devices a MULTIZONE_STATUS payload lists; any without an id or a
/// name are left out.
List<CastZoneDevice> readZoneDevices(Map<String, Object?> payload) {
  final devices = <CastZoneDevice>[];
  for (final row in readRows(readMap(payload['status'])['devices'])) {
    final device = readMap(row);
    final id = readString(device['deviceId'])?.toLowerCase();
    final name = cleanCastText(readString(device['name']));
    if (id == null || id.isEmpty || name == null) continue;
    final hex = id.replaceAll('-', '');
    devices.add(
      CastZoneDevice(
        id: RegExp(r'^[0-9a-f]{32}$').hasMatch(hex) ? hex : id,
        name: name,
        capabilities: readInt(device['capabilities']),
      ),
    );
  }
  return devices;
}
