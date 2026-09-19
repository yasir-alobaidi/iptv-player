import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// A stream ready to open: built from the source at play time and never
/// kept longer than the session that plays it (hard rule 3).
@immutable
final class ResolvedStream {
  const new({
    required this.url,
    required this.maxConnections,
    this.userAgent,
    this.hls = false,
  });

  /// Carries the credentials.
  final String url;
  final String? userAgent;
  final bool hls;

  /// Streams the source allows at once: the user's override, the account's
  /// `max_connections`, or 1 when neither says.
  final int maxConnections;

  @override
  String toString() =>
      'ResolvedStream(hls: $hls, maxConnections: $maxConnections)';
}

/// Builds the URL to play, from the source, every time (docs/02: a
/// redirect's token expires, so a reconnect never reuses one).
abstract interface class StreamResolver {
  Future<Result<ResolvedStream>> live(ChannelItem channel);
}

/// What was watched, for the last-channel key and "recently watched".
abstract interface class PlaybackHistory {
  Future<Result<void>> recordLive(ChannelItem channel);

  /// Remote keys of the source's live channels, newest first.
  Future<Result<List<String>>> recentLive(String sourceId, {int limit = 20});
}

/// Settings → Playback (docs/05), as the player needs them.
@immutable
final class PlaybackSettings {
  const new({
    this.preset = BufferPreset.balanced,
    this.audioLanguages = const [],
    this.subtitleLanguages = const [],
    this.deinterlace,
  });

  final BufferPreset preset;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;

  /// null = Auto.
  final bool? deinterlace;

  PlayRequest request(ResolvedStream stream) => PlayRequest(
    url: stream.url,
    userAgent: stream.userAgent,
    preset: preset,
    audioLanguages: audioLanguages,
    subtitleLanguages: subtitleLanguages,
    deinterlace: deinterlace,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaybackSettings &&
      other.preset == preset &&
      listEquals(other.audioLanguages, audioLanguages) &&
      listEquals(other.subtitleLanguages, subtitleLanguages) &&
      other.deinterlace == deinterlace;

  @override
  int get hashCode => Object.hash(
    preset,
    Object.hashAll(audioLanguages),
    Object.hashAll(subtitleLanguages),
    deinterlace,
  );
}
