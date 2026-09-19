import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// Where playback is (docs/03's watchdog states), for the preview pane,
/// the full-screen player and the pill.
@immutable
sealed class PlaybackState {
  const new();

  /// The channel this state is about; null only when idle.
  ChannelItem? get channel;
}

final class PlaybackIdle extends PlaybackState {
  const new();

  @override
  ChannelItem? get channel => null;
}

/// Asked for, no picture yet.
final class PlaybackOpening extends PlaybackState {
  const new(this.channel);

  @override
  final ChannelItem channel;
}

final class PlaybackPlaying extends PlaybackState {
  const new(this.channel, {this.buffering = false});

  @override
  final ChannelItem channel;

  /// Paused to fill the buffer; the watchdog gives it 15 s.
  final bool buffering;
}

/// Lost the stream; trying again on its own ("Reconnecting… attempt 2 of
/// 6"), never with a dialog (docs/03).
final class PlaybackReconnecting extends PlaybackState {
  const new(
    this.channel, {
    required this.attempt,
    required this.maxAttempts,
    required this.problem,
  });

  @override
  final ChannelItem channel;

  /// 1-based: the attempt about to run.
  final int attempt;
  final int maxAttempts;

  /// Why the stream was lost.
  final PlaybackProblem problem;
}

/// Gave up, or can't play at all: the failure card (Retry / Next channel
/// / Details).
final class PlaybackFailed extends PlaybackState {
  const new(this.channel, this.problem, {this.attempts = 0});

  @override
  final ChannelItem channel;
  final PlaybackProblem problem;

  /// Automatic attempts made before giving up.
  final int attempts;
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
  unavailable(retryable: false);

  new({required this.retryable});

  final bool retryable;
}
