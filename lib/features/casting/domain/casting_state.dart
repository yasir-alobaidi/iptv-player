import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

part 'casting_state.freezed.dart';

/// Where a cast session is (docs/05's casting view and bar, sketch D).
enum CastPhase {
  /// No session.
  off,

  /// Joining the device: the connection, then its receiver (3–6 s on
  /// Living Room TV when it isn't running).
  connecting,

  /// Joined, with nothing playing: before the first play, or after the
  /// TV's remote stopped it.
  idle,

  /// Getting the stream ready: its facts, the relay's first segments, the
  /// LOAD, until the TV plays.
  preparing,
  playing,

  /// A movie or an episode played to its end on the TV.
  ended,

  /// Stopped by a problem ([CastingState.problem]): Try again, Play here,
  /// Details.
  failed,
}

/// What the casting view, the casting bar and Live TV show of a cast.
@freezed
abstract class CastingState with _$CastingState {
  const factory({
    @Default(CastPhase.off) CastPhase phase,

    /// The device, while there is a session.
    CastDevice? device,

    /// What is cast, or was when it ended or failed.
    Playable? item,

    /// How it is cast: the badge, its sentence and the details line.
    CastPlan? plan,

    /// Paused, with our controls or the TV's remote.
    @Default(false) bool paused,

    /// The TV is filling its buffer. On live HLS this comes and goes with
    /// nothing visible (docs/04): the view may show it, never as a stall.
    @Default(false) bool buffering,

    /// The connection to the device broke and is being made again; the TV
    /// plays on meanwhile (the pill).
    @Default(false) bool reconnecting,
    @Default(CastVolume()) CastVolume volume,

    /// Why it failed, for [CastPhase.failed].
    CastProblem? problem,
  }) = _CastingState;

  const new _();

  /// A session is on: plays go to the device (Phase 7 decision 2).
  bool get active => phase != CastPhase.off;
}

/// Why a cast failed, in terms the casting view explains (sketch D).
@immutable
final class CastProblem {
  const new(this.kind, {this.stream, this.detail});

  final CastProblemKind kind;

  /// For [CastProblemKind.stream]: docs/03's class of the provider's
  /// answer, so a cast fails with the same words as playing here.
  final PlaybackProblem? stream;

  /// Technical text for Details: the device's or FFmpeg's own words.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is CastProblem &&
      other.kind == kind &&
      other.stream?.kind == stream?.kind &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, stream?.kind, detail);

  @override
  String toString() =>
      'CastProblem(${kind.name}${stream == null ? '' : ', $stream'})';
}

enum CastProblemKind {
  /// Nothing answered at the device's address.
  deviceUnreachable,

  /// The device didn't start the receiver.
  receiverRefused,

  /// The provider's stream failed ([CastProblem.stream] says how).
  stream,

  /// The TV never fetched the stream from this computer: a firewall, a
  /// VPN, or another network ("Living Room TV couldn't reach this
  /// computer").
  computerUnreachable,

  /// The TV couldn't play it, and nothing left to change would help.
  deviceCantPlay,

  /// The picture needs re-encoding and nothing here can.
  cantReencode,

  /// The relay failed: FFmpeg, or too many restarts.
  relay,

  /// The stream has neither a picture nor a sound.
  nothingToPlay,
}

/// Something worth a toast (step 7): the quiet fallbacks and the ends the
/// user didn't ask for.
@immutable
sealed class CastNotice {
  const new(this.deviceName);

  /// "Living Room TV".
  final String deviceName;
}

/// The session ended on the device's side: its remote closed the
/// receiver, another app took it, or it went quiet.
final class CastSessionClosed extends CastNotice {
  const new(super.deviceName, this.end, {this.otherApp});

  final CastEnd end;

  /// What took the device over, for [CastEnd.otherApp].
  final String? otherApp;
}

/// The cast changed its plan by itself after the device refused the
/// first one (docs/05: "Automatic fallbacks are quiet: badge change +
/// small toast").
final class CastPlanChanged extends CastNotice {
  const new(super.deviceName, {required this.before, required this.after});

  final CastPlan before;
  final CastPlan after;
}

/// The TV's remote stopped what played.
final class CastStoppedOnDevice extends CastNotice {
  const new(super.deviceName);
}
