import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/features/home/data/home_providers.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_state.g.dart';

/// How many a Home row shows at most (decision 5).
const homeRowLimit = 20;

/// Whether Home says "You're offline — downloads and local files still
/// play" (docs/05; Phase 8 decision 11). Phase 8 step 6 draws the banner.
@riverpod
Stream<bool> homeOffline(Ref ref) => ref.watch(networkStatusProvider).watch();

/// Continue watching, across every source (decision 5).
@riverpod
Stream<List<ContinueItem>> continueWatching(Ref ref) =>
    ref.watch(watchProgressProvider).continueWatching();

@riverpod
Stream<List<ChannelItem>> homeFavoriteChannels(Ref ref, String sourceId) => ref
    .watch(homeRepositoryProvider)
    .favoriteChannels(sourceId, limit: homeRowLimit);

@riverpod
Stream<List<ChannelItem>> homeRecentChannels(Ref ref, String sourceId) => ref
    .watch(homeRepositoryProvider)
    .recentChannels(sourceId, limit: homeRowLimit);

@riverpod
Stream<List<MovieItem>> homeRecentMovies(Ref ref, String sourceId) => ref
    .watch(homeRepositoryProvider)
    .recentMovies(sourceId, limit: homeRowLimit);

@riverpod
Stream<List<SeriesItem>> homeRecentSeries(Ref ref, String sourceId) => ref
    .watch(homeRepositoryProvider)
    .recentSeries(sourceId, limit: homeRowLimit);

/// Anything ever watched: until then Home leads with its hero.
@riverpod
Stream<bool> watchedAnything(Ref ref) =>
    ref.watch(homeRepositoryProvider).watchedAnything();

/// The first-run hero's counts: the source's visible channels, its movies
/// or its series.
@riverpod
Stream<int> homeCount(Ref ref, String sourceId, CatalogueKind kind) =>
    switch (kind) {
      CatalogueKind.live =>
        ref
            .watch(channelRepositoryProvider)
            .watchCount(ChannelQuery(sourceId: sourceId)),
      CatalogueKind.movie =>
        ref
            .watch(movieRepositoryProvider)
            .watchCount(TitleQuery(sourceId: sourceId)),
      CatalogueKind.series =>
        ref
            .watch(seriesRepositoryProvider)
            .watchCount(TitleQuery(sourceId: sourceId)),
    };
