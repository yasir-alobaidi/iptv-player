import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'live_tv_providers.g.dart';

@Riverpod(keepAlive: true)
ChannelRepository channelRepository(Ref ref) =>
    DbChannelRepository(ref.watch(appDatabaseProvider));

/// How many channels [query] matches, live.
@riverpod
Stream<int> channelCount(Ref ref, ChannelQuery query) =>
    ref.watch(channelRepositoryProvider).watchCount(query);
