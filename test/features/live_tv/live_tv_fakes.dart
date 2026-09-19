import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/sources/data/db_category_repository.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../onboarding/onboarding_fakes.dart';
import '../playback/support/playback_fakes.dart';

/// The Live TV screen on a real in-memory catalogue (channels, categories,
/// favorites read through the real repositories), a coordinator on the
/// fake player, and a guide that answers from [guide].
final class LiveTvFakes {
  new()
    : fakes = OnboardingFakes(),
      // Widget tests end with no timers pending: drift closes a stream
      // query on a timer unless told to do it at once.
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );

  final OnboardingFakes fakes;
  final AppDatabase db;
  final rig = Rig();
  final guide = FakeGuide();
  late int sports;
  late int news;

  /// A source `src-1` with Sports (3 channels), News (2, hidden) and one
  /// uncategorized channel.
  Future<void> seed() async {
    fakes.sources.seed();
    final now = fakes.now;
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: 'src-1',
            type: SourceType.xtream,
            name: 'Northwind TV',
            url: 'http://northwind.test',
            createdAt: now,
            updatedAt: now,
          ),
        );
    Future<int> category(String key, String name, {bool hidden = false}) => db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            sourceId: 'src-1',
            kind: CatalogueKind.live,
            remoteKey: key,
            name: name,
            isHidden: Value(hidden),
          ),
        );
    sports = await category('1', 'Sports');
    news = await category('2', 'News', hidden: true);
    ChannelsCompanion row(String key, String name, int number, int? cat) =>
        ChannelsCompanion.insert(
          sourceId: 'src-1',
          remoteKey: key,
          name: name,
          number: Value(number),
          categoryId: Value(cat),
          position: Value(number),
        );
    await db.channelsDao.upsertAll([
      row('201', 'Arena Sports 1', 201, sports),
      row('202', 'Arena Sports 2', 202, sports),
      row('203', 'Velocity Motors', 203, sports),
      row('301', 'World News', 301, news),
      row('302', 'City News', 302, news),
      row('900', 'Zebra TV', 900, null),
    ]);
  }

  List<Override> get overrides => [
    sourceRepositoryProvider.overrideWithValue(fakes.sources),
    syncServiceProvider.overrideWithValue(fakes.sync),
    sourceOverviewRepositoryProvider.overrideWithValue(fakes.overviews),
    appClockProvider.overrideWithValue(() => fakes.now),
    appDatabaseProvider.overrideWithValue(db),
    categoryRepositoryProvider.overrideWithValue(DbCategoryRepository(db)),
    channelRepositoryProvider.overrideWithValue(
      DbChannelRepository(db, clock: () => fakes.now),
    ),
    guideServiceProvider.overrideWithValue(guide),
    playerEngineProvider.overrideWithValue(rig.engine),
    playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
  ];
}

final class FakeGuide implements GuideService {
  final Map<String, NowNext> byKey = {};
  final List<String> asked = [];

  @override
  NowNext? cached(ChannelItem channel) => byKey[channel.remoteKey];

  @override
  Future<Result<NowNext>> nowNext(ChannelItem channel) async {
    asked.add(channel.remoteKey);
    return Ok(byKey[channel.remoteKey] ?? NowNext.none);
  }
}
