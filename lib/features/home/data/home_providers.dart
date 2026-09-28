import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/home/data/db_home_repository.dart';
import 'package:iptv_player/features/home/domain/home.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_providers.g.dart';

@Riverpod(keepAlive: true)
HomeRepository homeRepository(Ref ref) => DbHomeRepository(
  ref.watch(appDatabaseProvider),
  channels: ref.watch(channelRepositoryProvider),
  movies: ref.watch(movieRepositoryProvider),
  series: ref.watch(seriesRepositoryProvider),
);
