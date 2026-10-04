import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

/// The failure card's title and message for [problem] (docs/05
/// microcopy), with what the server answered when it answered. [item]
/// says what failed: a channel unless it is a movie or an episode.
({String title, String message}) problemText(
  PlaybackProblem problem, {
  int attempts = 0,
  Playable? item,
}) {
  final answer = switch (problem.failure) {
    final failure? => serverAnswer(failure),
    null => null,
  };
  String withAnswer(String message) =>
      answer == null ? message : '$message $answer';
  final what = switch (item) {
    PlayableMovie() => 'movie',
    PlayableEpisode() => 'episode',
    PlayableLibraryItem() => 'video',
    PlayableChannel() || null => 'channel',
  };
  return switch (problem.kind) {
    PlaybackProblemKind.network || PlaybackProblemKind.server => (
      title: "This $what isn't responding",
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
    PlaybackProblemKind.offline when what != 'channel' => (
      title: 'No longer available',
      message: withAnswer(
        'This $what is no longer available from your provider.',
      ),
    ),
    PlaybackProblemKind.offline => (
      title: 'This channel is off the air',
      message: withAnswer('Your provider has nothing on it right now.'),
    ),
    PlaybackProblemKind.unsupported => (
      title: "This $what can't be played",
      message: "It uses a format this player can't decode.",
    ),
    PlaybackProblemKind.fileUnreadable => (
      title: 'This file is missing or damaged',
      message:
          "It isn't where the library found it, or it can't be read. "
          'Show it in its folder, or remove it from the library.',
    ),
    PlaybackProblemKind.unavailable => (
      title: "This $what can't start",
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
