import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';

/// Where plays go while a cast session is on (Phase 7 decision 2): the
/// cast coordinator. The screens keep calling the playback coordinator,
/// which passes their plays on.
abstract interface class RemotePlayback {
  /// The device, as the user named it: "Living Room TV".
  String get deviceName;

  /// Plays [item] on the device, a file from [from].
  Future<void> play(Playable item, {Duration? from});

  /// Tries what failed again.
  Future<void> retry();

  /// Moves the file playing on the device to [position].
  Future<void> seek(Duration position);

  Future<void> setPaused({required bool paused});
}

/// What the laptop was playing when a cast session took over: the cast
/// starts from it (decision 2: "Cast while watching moves what is playing
/// to the TV; a movie keeps its position").
@immutable
final class PlaybackHandover {
  const new({required this.item, this.position, this.info, this.tracks});

  final Playable item;

  /// Where a file was; null for live.
  final Duration? position;

  /// What the player knew of the stream while it showed it (Phase 7
  /// decision 4's cheapest facts); null when it had no picture yet.
  final StreamInfo? info;

  /// Its tracks, and which audio was on.
  final PlayerTracks? tracks;
}
