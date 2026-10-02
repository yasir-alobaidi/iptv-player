import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';

part 'cast_receiver.freezed.dart';

/// Google's Default Media Receiver, which needs no registration (docs/04).
const defaultMediaReceiverAppId = 'CC1AD845';

/// Talks to Cast devices' receivers: our own Cast v2 client (docs/04).
abstract interface class CastReceivers {
  /// Connects to the device at [address] and joins the Default Media
  /// Receiver there: the one already running, or a new launch (3–6 s on
  /// Living Room TV, ADR-004). The TV shows the receiver from then on.
  Future<CastJoinResult> join(CastAddress address);
}

/// How [CastReceivers.join] went.
@immutable
sealed class CastJoinResult {
  const new();
}

final class CastJoined extends CastJoinResult {
  const new(this.session, {required this.launched});

  final CastReceiverSession session;

  /// False when the receiver was already running and was joined as it was.
  final bool launched;
}

final class CastJoinFailed extends CastJoinResult {
  const new(this.reason, [this.detail]);

  final CastJoinFailure reason;

  /// Technical text for the log and Details, never shown in front.
  final String? detail;
}

enum CastJoinFailure {
  /// No connection: the device is off, at another address, or a firewall
  /// is in the way.
  unreachable,

  /// Connected, but the device didn't answer.
  noAnswer,

  /// The device refused to start the receiver (LAUNCH_ERROR).
  launchRefused,

  /// The receiver didn't start in time.
  launchTimedOut,
}

/// One connection to a device's media receiver. It follows the receiver
/// through Wi-Fi blips — reconnects, and joins the receiver it left by its
/// transport id, while the TV carries on playing — until the session ends.
abstract interface class CastReceiverSession {
  /// The device, as joined.
  CastAddress get address;

  /// This computer's address on the connection to the device: one the
  /// device can reach it at, which the relay serves on.
  String get localAddress;

  CastSessionState get state;

  /// Every change of [state], in order.
  Stream<CastSessionState> get states;

  /// Starts [request] on the device. Done once the device took it; whether
  /// it plays shows in [state] (a LOAD_FAILED can come seconds later, as
  /// IDLE with [CastIdleReason.error]).
  Future<CastCommandResult> load(CastLoad request);

  Future<CastCommandResult> play();

  Future<CastCommandResult> pause();

  /// Moves a file to [position] from its start, keeping it paused or
  /// playing as it was.
  Future<CastCommandResult> seek(Duration position);

  /// Stops the media; the receiver stays on the TV.
  Future<CastCommandResult> stopMedia();

  /// The device's volume, 0–1. A device whose volume is fixed (the TV's
  /// own remote sets it, [CastVolume.fixed]) keeps its own.
  Future<CastCommandResult> setVolume(double level);

  Future<CastCommandResult> setMuted({required bool muted});

  /// Closes the receiver, so the TV returns to its home screen, and ends
  /// the session.
  Future<void> stop();

  /// Lets go of the receiver, leaving whatever it plays playing, and ends
  /// the session.
  Future<void> leave();
}

/// Where a session is, what the device plays, and its volume.
@freezed
abstract class CastSessionState with _$CastSessionState {
  const factory({
    @Default(CastLink.connected) CastLink link,

    /// Why the session ended, once [link] is [CastLink.ended].
    CastEnd? end,

    /// The app that took the device over, for [CastEnd.otherApp]: what
    /// "Living Room TV started YouTube" names.
    String? otherApp,

    /// The media session on the device; null before the first LOAD, and
    /// when the device has none.
    CastMediaStatus? media,
    @Default(CastVolume()) CastVolume volume,
  }) = _CastSessionState;
}

enum CastLink {
  connected,

  /// The connection broke; the client is connecting again.
  reconnecting,
  ended,
}

enum CastEnd {
  /// This app stopped the receiver ([CastReceiverSession.stop]).
  stopped,

  /// This app let go of it ([CastReceiverSession.leave]).
  left,

  /// The receiver closed on the device: its remote, or the device itself.
  closedOnDevice,

  /// Another app took the device, or another sender's receiver.
  otherApp,

  /// The connection broke and didn't come back.
  lost,
}

@freezed
abstract class CastVolume with _$CastVolume {
  const factory({
    @Default(1.0) double level,
    @Default(false) bool muted,

    /// The device's volume follows the TV's own (`controlType: fixed`):
    /// setting it changes nothing.
    @Default(false) bool fixed,
  }) = _CastVolume;
}

/// What the device's media player reports (MEDIA_STATUS).
@freezed
abstract class CastMediaStatus with _$CastMediaStatus {
  const factory({
    /// The device's id for this media session; a new LOAD makes another.
    required int sessionId,
    required CastPlayerState playerState,

    /// Why it is idle, when [playerState] is [CastPlayerState.idle].
    CastIdleReason? idleReason,

    /// Where it is, as of the report.
    @Default(Duration.zero) Duration position,

    /// A file's length; null for live streams and until the device knows.
    Duration? duration,

    /// 1 while playing.
    @Default(1.0) double rate,

    /// The URL loaded.
    String? contentId,

    /// The picture's size, once the device decodes it.
    int? videoWidth,
    int? videoHeight,
  }) = _CastMediaStatus;
}

/// docs/04: BUFFERING is not a stall; on live HLS it comes and goes many
/// times a minute with nothing visible.
enum CastPlayerState { idle, loading, buffering, playing, paused }

enum CastIdleReason {
  /// Played to its end; on a live continuous stream that means it dropped
  /// (ADR-004).
  finished,

  /// Stopped by a sender or the device's remote.
  cancelled,

  /// Replaced by another LOAD.
  interrupted,

  /// The device couldn't play it.
  error,
}

/// What to play on the device (LOAD).
@immutable
final class CastLoad {
  const new({
    required this.url,
    required this.contentType,
    required this.live,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.start = Duration.zero,
    this.duration,
  });

  /// Where the device fetches it: the relay, or a file the relay serves.
  /// A direct play (docs/04 rule 1) is a provider's URL, credentials and
  /// all: never log it without `redact()`.
  final String url;

  /// `application/x-mpegurl` for HLS, `video/mp4` for a continuous
  /// fragmented MP4 and for MP4 files (docs/04).
  final String contentType;

  /// A live stream (`LIVE`), or a file with a length (`BUFFERED`).
  final bool live;
  final String title;
  final String? subtitle;

  /// The picture the TV shows while it loads.
  final String? imageUrl;

  /// Where a file starts.
  final Duration start;

  /// A file's length, when known.
  final Duration? duration;

  @override
  String toString() =>
      'CastLoad($contentType, ${live ? 'live' : 'file'}'
      '${start == Duration.zero ? '' : ', start: $start'})';
}

/// How a command to the device went.
@immutable
sealed class CastCommandResult {
  const new();
}

/// The device took it. [media] is its status after, when it sent one.
final class CastDone extends CastCommandResult {
  const new([this.media]);

  final CastMediaStatus? media;
}

final class CastRefused extends CastCommandResult {
  const new(this.reason, [this.detail]);

  final CastRefusal reason;

  /// The device's own words, for the log.
  final String? detail;
}

/// No answer in time.
final class CastUnanswered extends CastCommandResult {
  const new();
}

/// Not connected: reconnecting, or the session has ended.
final class CastDisconnected extends CastCommandResult {
  const new();
}

enum CastRefusal {
  /// LOAD_FAILED: the device can't play it. It gives no reason (docs/04).
  loadFailed,

  /// LOAD_CANCELLED: a newer LOAD replaced it.
  loadCancelled,

  /// No media session: nothing is loaded, or it ended
  /// (INVALID_MEDIA_SESSION_ID).
  noMedia,

  /// Not now (INVALID_PLAYER_STATE).
  invalidState,

  /// Any other refusal (INVALID_REQUEST, INVALID_COMMAND, …).
  invalidRequest,
}
