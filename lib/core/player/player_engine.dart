import 'package:flutter/widgets.dart';

/// The one player the app owns (docs/03): opened again for every channel,
/// never recreated. The UI and the coordinator talk to this; only
/// `lib/data/player_mediakit/` knows it is libmpv (hard rule 6).
abstract interface class PlayerEngine {
  /// Everything the player reports, in order. Broadcast: the watchdog,
  /// the coordinator and the UI each listen.
  Stream<PlayerEvent> get events;

  /// Opens [request], replacing whatever was playing. Completes once the
  /// player has taken the URL, not when the first frame shows: that
  /// arrives as [PlayerFirstFrame].
  Future<void> open(PlayRequest request);

  /// Stops and lets go of the stream's connection. Completes when the
  /// player has closed it, which a one-connection panel waits for.
  Future<void> stop();

  Future<void> setPaused({required bool paused});

  /// 0–100.
  Future<void> setVolume(double volume);

  Future<void> setMuted({required bool muted});

  /// A track id from [PlayerTracks], or null for none (subtitles) / auto.
  Future<void> selectAudio(String? id);

  Future<void> selectSubtitle(String? id);

  Future<void> setAspect(AspectMode mode);

  Future<void> setDeinterlace({required bool on});

  /// The numbers the stream-info overlay shows (key I), read now.
  Future<StreamInfo> streamInfo();

  /// The picture. Build it wherever the video should show (the preview
  /// pane, full screen); there is one picture, whichever widget shows it.
  /// [background] fills the letterbox (a design token, hard rule 9).
  Widget videoView({
    required Color background,
    Key? key,
    BoxFit fit = BoxFit.contain,
  });

  Future<void> dispose();
}

/// How much the player buffers (docs/03, Settings → Playback).
enum BufferPreset {
  lowLatency(openTimeout: Duration(seconds: 8)),
  balanced(openTimeout: Duration(seconds: 12)),
  stable(openTimeout: Duration(seconds: 20));

  new({required this.openTimeout});

  /// No first frame within this long → the watchdog reconnects.
  final Duration openTimeout;
}

enum AspectMode { fit, fill, stretch, ratio16x9, ratio4x3 }

/// What to play and how.
@immutable
final class PlayRequest {
  const new({
    required this.url,
    this.userAgent,
    this.live = true,
    this.preset = BufferPreset.balanced,
    this.audioLanguages = const [],
    this.subtitleLanguages = const [],
    this.deinterlace,
  });

  /// Carries credentials: never log it without `redact()`.
  final String url;
  final String? userAgent;
  final bool live;
  final BufferPreset preset;

  /// Preferred languages, most wanted first (ISO 639 codes).
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;

  /// null = Auto (follow the stream's interlacing).
  final bool? deinterlace;

  @override
  String toString() => 'PlayRequest(live: $live, preset: ${preset.name})';
}

/// Something the player reports.
sealed class PlayerEvent {
  const new();
}

/// A new [PlayRequest] was taken; [generation] counts opens, so a late
/// event from the previous stream can be told apart.
final class PlayerOpening extends PlayerEvent {
  const new(this.generation);

  final int generation;
}

/// The first picture (or, with no video, the first audio) is out.
final class PlayerFirstFrame extends PlayerEvent {
  const new(this.generation);

  final int generation;
}

/// Where playback is and how much is buffered ahead.
final class PlayerProgress extends PlayerEvent {
  const new({required this.position, required this.buffered});

  final Duration position;
  final Duration buffered;
}

/// The player paused to fill its buffer, or resumed.
final class PlayerBuffering extends PlayerEvent {
  const new({required this.buffering});

  final bool buffering;
}

/// The stream ended. On a live stream that means the connection dropped.
final class PlayerEnded extends PlayerEvent {
  const new();
}

/// The player couldn't open or keep playing. [message] is the player's
/// own text, already redacted; it goes behind Details, never in front.
final class PlayerFailed extends PlayerEvent {
  const new(this.message);

  final String message;
}

/// The picture's size changed (a new stream, or a codec switch mid-stream).
final class PlayerVideoChanged extends PlayerEvent {
  const new({required this.width, required this.height});

  final int width;
  final int height;
}

/// The stream's audio and subtitle tracks, and which are on.
final class PlayerTracks extends PlayerEvent {
  const new({
    required this.audio,
    required this.subtitles,
    this.audioId,
    this.subtitleId,
  });

  final List<MediaTrack> audio;
  final List<MediaTrack> subtitles;
  final String? audioId;
  final String? subtitleId;
}

@immutable
final class MediaTrack {
  const new({
    required this.id,
    this.title,
    this.language,
    this.codec,
    this.channels,
  });

  final String id;
  final String? title;
  final String? language;
  final String? codec;

  /// e.g. `stereo`, `5.1`.
  final String? channels;

  @override
  bool operator ==(Object other) =>
      other is MediaTrack &&
      other.id == id &&
      other.title == title &&
      other.language == language &&
      other.codec == codec &&
      other.channels == channels;

  @override
  int get hashCode => Object.hash(id, title, language, codec, channels);
}

/// The stream-info overlay's numbers. Any of them can be unknown.
@immutable
final class StreamInfo {
  const new({
    this.width,
    this.height,
    this.fps,
    this.videoCodec,
    this.hardwareDecoder,
    this.audioCodec,
    this.audioChannels,
    this.videoBitrate,
    this.buffered,
    this.droppedFrames,
    this.interlaced,
  });

  final int? width;
  final int? height;
  final double? fps;
  final String? videoCodec;

  /// mpv's `hwdec-current`: `vaapi`, `nvdec`, … or null for software.
  final String? hardwareDecoder;
  final String? audioCodec;
  final int? audioChannels;

  /// Bits per second.
  final int? videoBitrate;
  final Duration? buffered;
  final int? droppedFrames;
  final bool? interlaced;
}
