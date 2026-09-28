import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/vod/data/db_movie_repository.dart';
import 'package:iptv_player/features/vod/data/db_series_repository.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/data/title_details_source.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vod_providers.g.dart';

/// `get_vod_info` / `get_series_info`, one client per source.
@Riverpod(keepAlive: true)
TitleDetailsSource titleDetailsSource(Ref ref) =>
    XtreamTitleDetails(ref.watch(sourceRepositoryProvider));

@Riverpod(keepAlive: true)
MovieRepository movieRepository(Ref ref) => DbMovieRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(titleDetailsSourceProvider),
  clock: ref.watch(appClockProvider),
);

@Riverpod(keepAlive: true)
SeriesRepository seriesRepository(Ref ref) => DbSeriesRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(titleDetailsSourceProvider),
  clock: ref.watch(appClockProvider),
);

@Riverpod(keepAlive: true)
WatchProgress watchProgress(Ref ref) => DbWatchProgress(
  ref.watch(appDatabaseProvider),
  clock: ref.watch(appClockProvider),
);
