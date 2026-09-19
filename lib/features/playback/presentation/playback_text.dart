import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

/// The failure card's title and message for [problem] (docs/05
/// microcopy), with what the server answered when it answered.
({String title, String message}) problemText(
  PlaybackProblem problem, {
  int attempts = 0,
}) {
  final answer = switch (problem.failure) {
    final failure? => serverAnswer(failure),
    null => null,
  };
  String withAnswer(String message) =>
      answer == null ? message : '$message $answer';
  return switch (problem.kind) {
    PlaybackProblemKind.network || PlaybackProblemKind.server => (
      title: "This channel isn't responding",
      message: withAnswer(
        attempts > 0
            ? 'We tried $attempts ${attempts == 1 ? 'time' : 'times'}.'
            : 'It stopped before a picture came through.',
      ),
    ),
    PlaybackProblemKind.connectionLimit => (
      title: 'Your connection limit is reached',
      message: withAnswer(
        'Your provider allows a set number of streams at once, and they '
        'are in use. Stop playback on other devices and try again.',
      ),
    ),
    PlaybackProblemKind.auth => (
      title: 'Your provider refused this account',
      message: withAnswer(
        'The subscription may have expired or been suspended. Check it '
        'in Settings → Sources.',
      ),
    ),
    PlaybackProblemKind.offline => (
      title: 'This channel is off the air',
      message: withAnswer('Your provider has nothing on it right now.'),
    ),
    PlaybackProblemKind.unsupported => (
      title: "This channel can't be played",
      message: "It uses a format this player can't decode.",
    ),
    PlaybackProblemKind.unavailable => (
      title: "This channel can't start",
      message: switch (problem.failure) {
        final failure? => failureWithAnswer(failure),
        null => 'The app could not build the stream address.',
      },
    ),
  };
}

/// "Reconnecting… attempt 2 of 6" (canvas).
String reconnectingText(PlaybackReconnecting state) =>
    'Reconnecting… attempt ${state.attempt} of ${state.maxAttempts}';

/// "1080p", "4K", "576p" from a picture height.
String? resolutionLabel(int? height) => switch (height) {
  null || <= 0 => null,
  >= 2000 => '4K',
  >= 1400 => '1440p',
  final h => '${h}p',
};
