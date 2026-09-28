import 'package:drift/drift.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/vod_launcher.dart';

import '../live_tv/live_tv_fakes.dart';
import '../playback/support/playback_fakes.dart';
import '../vod/vod_fakes.dart';

/// What Home was asked to play.
final class RecordingLauncher implements VodLauncher {
  final played = <String>[];

  @override
  Future<void> playMovie(MovieItem movie, {Duration? from}) async =>
      played.add('${movie.remoteKey} from ${from?.inMinutes ?? 0}');

  @override
  Future<void> playEpisode(
    SeriesItem series,
    EpisodeItem episode, {
    Duration? from,
  }) async => played.add('${episode.remoteKey} from ${from?.inMinutes ?? 0}');
}

/// Home on one database: [VodFakes]' movies and series, three channels
/// (Arena Sports 1 a favorite), a guide for them, the fake player.
final class HomeFakes {
  new() : vod = VodFakes() {
    rig = Rig(watchProgress: DbWatchProgress(vod.db, clock: () => vod.now));
  }

  final VodFakes vod;
  late final Rig rig;
  final guide = FakeGuide();
  final window = FakeWindow();
  final launcher = RecordingLauncher();

  AppDatabase get db => vod.db;
  DateTime get now => vod.now;

  /// The catalogue and the channels; nothing watched.
  Future<void> seed() async {
    await vod.seed();
    final live = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            sourceId: 'src-1',
            kind: CatalogueKind.live,
            remoteKey: '1',
            name: 'Sports',
          ),
        );
    ChannelsCompanion row(String key, String name, int number) =>
        ChannelsCompanion.insert(
          sourceId: 'src-1',
          remoteKey: key,
          name: name,
          number: Value(number),
          categoryId: Value(live),
          position: Value(number),
        );
    await db.channelsDao.upsertAll([
      row('201', 'Arena Sports 1', 201),
      row('202', 'Arena Sports 2', 202),
      row('203', 'Velocity Motors', 203),
    ]);
    await db.favoritesDao.add(UserItemType.live, 'src-1', '201', now);
    guide.byKey['201'] = NowNext(
      now: Programme(
        title: 'Continental Cup · Semi-final',
        start: now.subtract(const Duration(minutes: 30)),
        end: now.add(const Duration(minutes: 30)),
      ),
    );
  }

  /// A movie 72 minutes into its 118, channel 203 watched, and an
  /// episode of Glass Tide half-way.
  Future<void> seedHistory() async {
    await db.watchHistoryDao.touch(
      UserItemType.movie,
      'src-1',
      '501',
      now.subtract(const Duration(hours: 1)),
      positionMs: 72 * 60000,
      durationMs: 118 * 60000,
      completed: false,
    );
    await db.watchHistoryDao.touch(
      UserItemType.live,
      'src-1',
      '203',
      now.subtract(const Duration(hours: 2)),
    );
  }

  List<Override> get overrides => [
    ...vod.overrides,
    channelRepositoryProvider.overrideWithValue(
      DbChannelRepository(db, clock: () => now),
    ),
    guideServiceProvider.overrideWithValue(guide),
    playerEngineProvider.overrideWithValue(rig.engine),
    playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
    windowControlsProvider.overrideWithValue(window),
    vodLauncherProvider.overrideWithValue(launcher),
  ];
}
