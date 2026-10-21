import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// A stream ready to open: built from the source at play time and never
/// kept longer than the session that plays it (hard rule 3).
@immutable
final class ResolvedStream {
  const new({
    required this.url,
    required this.maxConnections,
    this.userAgent,
    this.hls = false,
    this.customUserAgent = false,
    this.local = false,
    this.subtitleFiles = const [],
  });

  /// Carries the credentials.
  final String url;
  final String? userAgent;
  final bool hls;

  /// The source or its playlist line sets a User-Agent of its own, which
  /// a TV fetching the stream itself can't send (docs/04 rule 1).
  final bool customUserAgent;

  /// Streams the source allows at once: the user's override, the account's
  /// `max_connections`, or 1 when neither says.
  final int maxConnections;

  /// A file on this computer (a download, a library file): [url] is its
  /// path; it holds no connection and is never reconnected (docs/09).
  final bool local;

  /// Subtitle files beside it, added as tracks (docs/09).
  final List<String> subtitleFiles;

  @override
  String toString() =>
      'ResolvedStream(hls: $hls, maxConnections: $maxConnections'
      '${local ? ', local' : ''})';
}

/// Builds the URL to play, from the source, every time (docs/02: a
/// redirect's token expires, so a reconnect never reuses one).
abstract interface class StreamResolver {
  Future<Result<ResolvedStream>> live(ChannelItem channel);

  /// A movie's stream: its downloaded file when there is one (Phase 8
  /// decision 8), unless [downloaded] is false (the provider's, for a
  /// cast, until the cast sends files itself).
  Future<Result<ResolvedStream>> movie(MovieItem movie, {bool downloaded});

  Future<Result<ResolvedStream>> episode(
    EpisodeItem episode, {
    bool downloaded,
  });

  /// A library file of the user's own (Phase 8).
  Future<Result<ResolvedStream>> libraryFile(LibraryItem item);
}

/// What was watched, for the last-channel key and "recently watched".
abstract interface class PlaybackHistory {
  Future<Result<void>> recordLive(ChannelItem channel);

  /// Remote keys of the source's live channels, newest first.
  Future<Result<List<String>>> recentLive(String sourceId, {int limit = 20});
}

/// Where [PlaybackSettings] are kept.
abstract interface class PlaybackSettingsStore {
  Future<Result<PlaybackSettings>> load();

  Future<Result<void>> save(PlaybackSettings settings);
}

/// Settings → Playback (docs/05), as the player needs them.
@immutable
final class PlaybackSettings {
  const new({
    this.preset = BufferPreset.balanced,
    this.audioLanguages = const [],
    this.subtitleLanguages = const [],
    this.deinterlace,
    this.hardwareDecoding = true,
    this.matchFrameRate = false,
    this.matchChannelRate = true,
    this.pictureQuality = PictureQuality.standard,
    this.subtitleSize = SubtitleSize.medium,
  });

  /// Tolerant: anything unknown or damaged reads as the default.
  factory fromJson(Object? json) {
    if (json is! Map) return const PlaybackSettings();
    List<String> languages(Object? value) => [
      if (value is List)
        for (final v in value)
          if (v is String && v.trim().isNotEmpty) v.trim().toLowerCase(),
    ];
    return PlaybackSettings(
      preset:
          BufferPreset.values
              .where((p) => p.name == json['preset'])
              .firstOrNull ??
          BufferPreset.balanced,
      audioLanguages: languages(json['audio']),
      subtitleLanguages: languages(json['subtitles']),
      deinterlace: switch (json['deinterlace']) {
        'on' => true,
        'off' => false,
        _ => null,
      },
      hardwareDecoding: json['hwdec'] != 'off',
      // Not the old `matchFps`: it was written "on" for everyone who saved
      // any playback setting while On was the default (ADR-042).
      matchFrameRate: json['matchRate'] == 'on',
      matchChannelRate: json['matchChannels'] != 'off',
      pictureQuality: json['quality'] == 'high'
          ? PictureQuality.high
          : PictureQuality.standard,
      subtitleSize:
          SubtitleSize.values
              .where((s) => s.name == json['subtitleSize'])
              .firstOrNull ??
          SubtitleSize.medium,
    );
  }

  final BufferPreset preset;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;

  /// null = Auto.
  final bool? deinterlace;

  /// Automatic uses the graphics card when it can; false is Off, which
  /// decodes on the processor (Phase 9 decision 4).
  final bool hardwareDecoding;

  /// A TV's Match frame rate: a film at 23.976 or 24 fps switches the
  /// display to its rate, when the TV's own setting allows. Off unless
  /// switched on: each switch darkens the screen for a second or two
  /// (ADR-042); the desktop never shows or uses it.
  final bool matchFrameRate;

  /// A TV's Match frame rate for channels (ADR-044): a channel at 25 or
  /// 50 fps switches the display to 50 Hz when it has such a mode, and
  /// the next channel keeps it. On unless switched off: the screen goes
  /// dark only as Live TV starts and ends, never between channels.
  final bool matchChannelRate;

  /// The desktop's Picture quality; a TV ignores it.
  final PictureQuality pictureQuality;

  /// How large subtitles are over the picture (ADR-038). Unlike the rest,
  /// it shows at once on what is playing: the picture's view reads it.
  final SubtitleSize subtitleSize;

  PlaybackSettings copyWith({
    BufferPreset? preset,
    List<String>? audioLanguages,
    List<String>? subtitleLanguages,
    bool? Function()? deinterlace,
    bool? hardwareDecoding,
    bool? matchFrameRate,
    bool? matchChannelRate,
    PictureQuality? pictureQuality,
    SubtitleSize? subtitleSize,
  }) => PlaybackSettings(
    preset: preset ?? this.preset,
    audioLanguages: audioLanguages ?? this.audioLanguages,
    subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
    deinterlace: deinterlace == null ? this.deinterlace : deinterlace(),
    hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
    matchFrameRate: matchFrameRate ?? this.matchFrameRate,
    matchChannelRate: matchChannelRate ?? this.matchChannelRate,
    pictureQuality: pictureQuality ?? this.pictureQuality,
    subtitleSize: subtitleSize ?? this.subtitleSize,
  );

  /// As stored in the `settings` table.
  Map<String, Object?> toJson() => {
    'preset': preset.name,
    'audio': audioLanguages,
    'subtitles': subtitleLanguages,
    'deinterlace': switch (deinterlace) {
      null => 'auto',
      true => 'on',
      false => 'off',
    },
    'hwdec': hardwareDecoding ? 'auto' : 'off',
    'matchRate': matchFrameRate ? 'on' : 'off',
    'matchChannels': matchChannelRate ? 'on' : 'off',
    'quality': pictureQuality.name,
    'subtitleSize': subtitleSize.name,
  };

  /// [live] false opens a file, from [start] when given.
  PlayRequest request(
    ResolvedStream stream, {
    bool live = true,
    Duration? start,
  }) => PlayRequest(
    url: stream.url,
    userAgent: stream.userAgent,
    live: live,
    preset: preset,
    audioLanguages: audioLanguages,
    subtitleLanguages: subtitleLanguages,
    deinterlace: deinterlace,
    start: start,
    subtitleFiles: stream.subtitleFiles,
    hardwareDecoding: hardwareDecoding,
    pictureQuality: pictureQuality,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaybackSettings &&
      other.preset == preset &&
      listEquals(other.audioLanguages, audioLanguages) &&
      listEquals(other.subtitleLanguages, subtitleLanguages) &&
      other.deinterlace == deinterlace &&
      other.hardwareDecoding == hardwareDecoding &&
      other.matchFrameRate == matchFrameRate &&
      other.matchChannelRate == matchChannelRate &&
      other.pictureQuality == pictureQuality &&
      other.subtitleSize == subtitleSize;

  @override
  int get hashCode => Object.hash(
    preset,
    Object.hashAll(audioLanguages),
    Object.hashAll(subtitleLanguages),
    deinterlace,
    hardwareDecoding,
    matchFrameRate,
    matchChannelRate,
    pictureQuality,
    subtitleSize,
  );
}
