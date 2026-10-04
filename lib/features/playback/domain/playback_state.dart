import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';

/// Where playback is (docs/03's watchdog states), for the preview pane,
/// the full-screen player and the pill.
@immutable
sealed class PlaybackState {
  const new();

  /// What this state is about; null only when idle.
  Playable? get item;

  /// The live channel this state is about; null when idle or for a movie
  /// or an episode. Live TV and the Guide only ever look at this.
  ChannelItem? get channel => switch (item) {
    PlayableChannel(:final channel) => channel,
    _ => null,
  };
}

final class PlaybackIdle extends PlaybackState {
  const new();

  @override
  Playable? get item => null;
}

/// Asked for, no picture yet.
final class PlaybackOpening extends PlaybackState {
  const new(this.item);

  @override
  final Playable item;
}

final class PlaybackPlaying extends PlaybackState {
  const new(this.item, {this.buffering = false});

  @override
  final Playable item;

  /// Paused to fill the buffer; the watchdog gives it 15 s.
  final bool buffering;
}

/// Lost the stream; trying again on its own ("Reconnecting… attempt 2 of
/// 6"), never with a dialog (docs/03). A file comes back where it was.
final class PlaybackReconnecting extends PlaybackState {
  const new(
    this.item, {
    required this.attempt,
    required this.maxAttempts,
    required this.problem,
  });

  @override
  final Playable item;

  /// 1-based: the attempt about to run.
  final int attempt;
  final int maxAttempts;

  /// Why the stream was lost.
  final PlaybackProblem problem;
}

/// Gave up, or can't play at all: the failure card (Retry / Next channel
/// or Next episode / Details).
final class PlaybackFailed extends PlaybackState {
  const new(this.item, this.problem, {this.attempts = 0});

  @override
  final Playable item;
  final PlaybackProblem problem;

  /// Automatic attempts made before giving up.
  final int attempts;
}

/// A file played to its end (never live: a live stream that ends has
/// dropped). Its connection is already let go.
final class PlaybackEnded extends PlaybackState {
  const new(this.item);

  @override
  final Playable item;
}

/// Playing on a Cast device (Phase 7 decision 2): the cast coordinator
/// has it and the laptop's player is stopped. What the TV is doing is the
/// cast coordinator's state.
final class PlaybackCasting extends PlaybackState {
  const new(this.item, {required this.deviceName});

  @override
  final Playable item;

  /// "Living Room TV".
  final String deviceName;
}

/// Where a file is, for the seek bar: reported a few times a second while
/// it plays, and at once after a seek or a pause.
@immutable
final class VodTimeline {
  const new({
    this.position = Duration.zero,
    this.duration,
    this.buffered = Duration.zero,
    this.paused = false,
  });

  final Duration position;

  /// The player's own length, else the provider's; null while neither is
  /// known.
  final Duration? duration;

  /// How far past [position] the player has read.
  final Duration buffered;
  final bool paused;

  Duration? get remaining => switch (duration) {
    final d? when d > position => d - position,
    final _? => Duration.zero,
    null => null,
  };

  @override
  bool operator ==(Object other) =>
      other is VodTimeline &&
      other.position == position &&
      other.duration == duration &&
      other.buffered == buffered &&
      other.paused == paused;

  @override
  int get hashCode => Object.hash(position, duration, buffered, paused);

  @override
  String toString() =>
      'VodTimeline($position of $duration${paused ? ', paused' : ''})';
}

/// What went wrong, in the terms the UI explains (docs/03's error
/// classes). [failure] carries the HTTP status when there was one, for
/// `serverAnswer()`; [detail] is the player's own text, for Details.
@immutable
final class PlaybackProblem {
  const new(this.kind, {this.failure, this.detail});

  final PlaybackProblemKind kind;
  final AppFailure? failure;
  final String? detail;

  /// Whether the watchdog tries again on its own.
  bool get retryable => kind.retryable;

  @override
  String toString() => 'PlaybackProblem(${kind.name}, $failure)';
}

enum PlaybackProblemKind {
  /// The stream dropped, stalled, timed out or couldn't be reached.
  network(retryable: true),

  /// The server answered with a 5xx.
  server(retryable: true),

  /// Every connection the account allows is in use (429, a panel's 403,
  /// or the account says so). Tried a few times: a panel can count the
  /// stream just closed for a moment.
  connectionLimit(retryable: true),

  /// 401/403: the provider refused the account.
  auth(retryable: false),

  /// 404: this channel is off the air.
  offline(retryable: false),

  /// The player can't decode it.
  unsupported(retryable: false),

  /// The app couldn't build the stream (keyring locked, source gone).
  unavailable(retryable: false),

  /// A file on this computer that is gone or can't be read (docs/09: no
  /// reconnects; Show in folder, Remove from library).
  fileUnreadable(retryable: false);

  new({required this.retryable});

  final bool retryable;
}
