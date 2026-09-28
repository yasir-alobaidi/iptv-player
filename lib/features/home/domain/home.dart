import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// Home's rows for the source being browsed (Phase 5 decision 5), each
/// again whenever what it shows changes. Continue watching spans every
/// source and comes from `WatchProgress`. A failure arrives as the
/// stream's error, an `AppFailure`.
abstract interface class HomeRepository {
  /// The source's favorite channels, in the channel list's order.
  Stream<List<ChannelItem>> favoriteChannels(String sourceId, {int limit});

  /// The source's channels, most recently watched first.
  Stream<List<ChannelItem>> recentChannels(String sourceId, {int limit});

  /// The provider's date, else the order the app first saw them.
  Stream<List<MovieItem>> recentMovies(String sourceId, {int limit});

  /// By `last_modified`: a series with new episodes comes forward.
  Stream<List<SeriesItem>> recentSeries(String sourceId, {int limit});

  /// Whether anything was ever watched, on any source — a channel counts.
  /// Until then Home leads with its first-run hero.
  Stream<bool> watchedAnything();
}
