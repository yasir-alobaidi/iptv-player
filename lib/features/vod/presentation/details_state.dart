import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'details_state.g.dart';

/// The movie a details page is about, as the grid row knows it; null when
/// the provider no longer has it.
@riverpod
Future<Result<MovieItem?>> movieItem(
  Ref ref,
  String sourceId,
  String remoteKey,
) => ref.watch(movieRepositoryProvider).byRemoteKey(sourceId, remoteKey);

@riverpod
Future<Result<SeriesItem?>> seriesItem(
  Ref ref,
  String sourceId,
  String remoteKey,
) => ref.watch(seriesRepositoryProvider).byRemoteKey(sourceId, remoteKey);
