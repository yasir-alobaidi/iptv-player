import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/data/short_epg_guide.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'live_tv_providers.g.dart';

@Riverpod(keepAlive: true)
ChannelRepository channelRepository(Ref ref) =>
    DbChannelRepository(ref.watch(appDatabaseProvider));

/// How many channels [query] matches, live.
@riverpod
Stream<int> channelCount(Ref ref, ChannelQuery query) =>
    ref.watch(channelRepositoryProvider).watchCount(query);

/// Now and next for the channels on screen (decision 2).
@Riverpod(keepAlive: true)
GuideService guideService(Ref ref) =>
    ShortEpgGuide(ref.watch(sourceRepositoryProvider));

/// What's on [channel] now and next; [NowNext.none] when unknown.
@riverpod
Future<NowNext> nowNext(Ref ref, ChannelItem channel) async {
  final result = await ref.watch(guideServiceProvider).nowNext(channel);
  ref.read(guideRevisionProvider.notifier).bump();
  return result.valueOrNull ?? NowNext.none;
}

/// Counts guide lookups, so rows showing only what is already cached
/// redraw when a lookup lands.
@Riverpod(keepAlive: true)
class GuideRevision extends _$GuideRevision {
  @override
  int build() => 0;

  void bump() => state++;
}

/// [channel] as the database has it now (a favorite toggled, a rename).
@riverpod
Stream<ChannelItem?> freshChannel(Ref ref, ChannelItem channel) async* {
  final repository = ref.watch(channelRepositoryProvider);
  // A count query runs again on every change to channels or favorites.
  await for (final _ in repository.watchCount(
    ChannelQuery(sourceId: channel.sourceId, showHidden: true),
  )) {
    yield (await repository.byRemoteKey(
      channel.sourceId,
      channel.remoteKey,
    )).valueOrNull;
  }
}
