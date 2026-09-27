import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_match_summary.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../live_tv/live_tv_fakes.dart';

/// The canvas's `Guide` artboard as data: Tuesday 15 September at
/// 9:22 PM, local time, and its nine Sports channels (201–209) — eight
/// with a guide, Summit Outdoor (209) without — plus a hidden News
/// category the Guide must leave out. The real repositories and guide
/// over an in-memory database; the importer and the matcher are fakes.
final class GuideFixture {
  new() : live = LiveTvFakes() {
    live.fakes.now = now;
  }

  /// A local wall-clock time, never an instant: the grid draws times in
  /// the viewer's zone (see `goldenNow()`).
  static final now = DateTime(2026, 9, 15, 21, 22);

  final LiveTvFakes live;
  final imports = FakeGuideImports();
  late final matching = FakeRematch(this);
  final _short = _NoShortEpg();
  late int sports;

  AppDatabase get db => live.db;

  /// [hour]:[minute] on the fixture's day; hours past 23 run into the
  /// next day.
  static DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 15, hour, minute);

  List<Override> get overrides => [
    ...live.importedGuideOverrides(_short),
    guideImportServiceProvider.overrideWithValue(imports),
    guideMatchingProvider.overrideWithValue(matching),
  ];

  /// The source, its categories and channels; with [guide], the
  /// canvas's programmes imported and matched.
  Future<void> seed({bool guide = true}) async {
    live.fakes.sources.seed();
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
    final news = await category('2', 'News', hidden: true);
    ChannelsCompanion row(String key, String name, int number, int cat) =>
        ChannelsCompanion.insert(
          sourceId: 'src-1',
          remoteKey: key,
          name: name,
          number: Value(number),
          categoryId: Value(cat),
          position: Value(number),
        );
    await db.channelsDao.upsertAll([
      for (final (i, name) in channelNames.indexed)
        row('${201 + i}', name, 201 + i, sports),
      row('301', 'World News', 301, news),
    ]);
    if (guide) await importCanvasGuide();
  }

  static const channelNames = [
    'Arena Sports 1',
    'Arena Sports 2',
    'Velocity Motors',
    'Courtside',
    'Fight Night',
    'Fairway',
    'Ringside Classics',
    'Blue Water',
    'Summit Outdoor',
  ];

  /// The guide channel each of 201–208 is matched to; 209 has none.
  static const guideIds = [
    'arena1',
    'arena2',
    'velocity',
    'courtside',
    'fightnight',
    'fairway',
    'ringside',
    'bluewater',
  ];

  /// The canvas's programmes, and one overnight each so a wide window
  /// has no gaps. Times are (hour, minute) on the fixture's day; hours
  /// past 23 run into the next day.
  static const schedule = <String, List<(String, int, int, int, int)>>{
    'arena1': [
      ('Continental Cup · Semi-final', 20, 0, 22, 0),
      ('Match of the Week: Extended Highlights', 22, 0, 23, 30),
      ('Cup Countdown', 23, 30, 25, 0),
      ('Overnight Sport', 25, 0, 28, 0),
      // Saturday 19: the guide reaches five days, as the canvas's pills.
      ('Weekend Preview', 4 * 24 + 10, 0, 4 * 24 + 11, 0),
    ],
    'arena2': [
      ('Tennis Open · Quarter-finals', 19, 30, 22, 45),
      ('Tennis Open: Day Review', 22, 45, 24, 15),
      ('Rally Replay', 24, 15, 25, 0),
      ('Overnight Tennis', 25, 0, 28, 0),
    ],
    'velocity': [
      ('Grand Prix Qualifying', 20, 30, 21, 35),
      ('Pit Lane', 21, 35, 22, 5),
      ('Classic Races: Harbor Circuit', 22, 5, 24, 0),
      ('Motor Mondays', 24, 0, 25, 0),
      ('Overnight Motors', 25, 0, 28, 0),
    ],
    'courtside': [
      ('Tip-Off', 20, 0, 21, 0),
      ('Harbor Kings vs Ridge City', 21, 0, 23, 15),
      ('Courtside Tonight', 23, 15, 25, 0),
      ('Overnight Hoops', 25, 0, 28, 0),
    ],
    'fightnight': [
      ('Undercard · Live from Riverside Arena', 20, 15, 22, 15),
      ('Main Event: Okoye vs Varga', 22, 15, 25, 0),
      ('Overnight Fights', 25, 0, 28, 0),
    ],
    'fairway': [
      ('Coastal Classic · Round 3', 19, 0, 23, 30),
      ('Swing Clinic', 23, 30, 25, 0),
      ('Overnight Golf', 25, 0, 28, 0),
    ],
    'ringside': [
      ('Legends Corner', 20, 30, 21, 0),
      ('Great Bouts of the 90s', 21, 0, 21, 40),
      ('Title Fights Revisited', 21, 40, 23, 0),
      ('Ringside Archive', 23, 0, 25, 0),
      ('Overnight Boxing', 25, 0, 28, 0),
    ],
    'bluewater': [
      ('Ocean Race Highlights', 20, 30, 22, 5),
      ('Harbor to Harbor', 22, 5, 23, 5),
      ('Deep Blue Racing', 23, 5, 25, 0),
      ('Overnight Sailing', 25, 0, 28, 0),
    ],
  };

  /// Descriptions for the detail sheet.
  static const descriptions = {
    'Continental Cup · Semi-final':
        'The two surviving sides meet at Riverside Arena for a place in '
        "Sunday's final. Coverage starts with build-up from the tunnel.",
  };

  /// Imports [programmes] (by default the canvas's) the way the importer
  /// does — start, stage, swap — then matches 201–208 to them.
  Future<void> importCanvasGuide({List<EpgProgramme>? programmes}) async {
    final all = programmes ?? canvasProgrammes();
    final repository = DbEpgRepository(db, clock: () => now);
    try {
      final run = (await repository.startImport('src-1')).valueOrNull!;
      await repository.stageChannels(run, [
        for (final id in {for (final p in all) p.channelId})
          GuideChannel(xmltvId: id, displayName: id),
      ]);
      await repository.stagePrograms(run, all);
      await repository.commitImport(sourceId: 'src-1', importRun: run);
    } finally {
      await repository.dispose();
    }
    for (final (i, id) in guideIds.indexed) {
      await match('${201 + i}', id);
    }
  }

  static List<EpgProgramme> canvasProgrammes() => [
    for (final entry in schedule.entries)
      for (final (title, h1, m1, h2, m2) in entry.value)
        EpgProgramme(
          id: 0,
          channelId: entry.key,
          start: at(h1, m1),
          end: at(h2, m2),
          title: title,
          description: descriptions[title],
          category: 'Sport',
        ),
  ];

  Future<void> match(String remoteKey, String xmltvId) async {
    final channel = await db.channelsDao.byRemoteKey('src-1', remoteKey);
    await db
        .into(db.epgMatches)
        .insertOnConflictUpdate(
          EpgMatchesCompanion.insert(
            channelId: Value(channel!.id),
            sourceId: 'src-1',
            xmltvId: xmltvId,
            rule: EpgMatchRule.exactId,
          ),
        );
  }

  /// Opens an import that is still running, as the importer would.
  Future<int> startImport() async {
    final repository = DbEpgRepository(db, clock: () => now);
    try {
      return (await repository.startImport('src-1')).valueOrNull!;
    } finally {
      await repository.dispose();
    }
  }

  /// Ends import [run] as failed with [failure]; the guide in use stays.
  Future<void> failImport(int run, AppFailure failure) async {
    final repository = DbEpgRepository(db, clock: () => now);
    try {
      await repository.abandonImport(
        run,
        outcome: GuideImportOutcome.failed,
        failure: failure,
      );
    } finally {
      await repository.dispose();
    }
  }
}

/// The importer the Guide sees: records what it was asked, and reports
/// progress when the test says.
final class FakeGuideImports implements GuideImportService {
  final _progress = StreamController<(String, EpgImportProgress)>.broadcast();
  final imported = <String>[];

  void report(String sourceId, EpgImportProgress progress) =>
      _progress.add((sourceId, progress));

  @override
  Stream<(String, EpgImportProgress)> get progress => _progress.stream;

  @override
  bool isImporting(String sourceId) => false;

  @override
  Future<Result<EpgImportCounts>> importGuide(String sourceId) async {
    imported.add(sourceId);
    return const Ok(EpgImportCounts());
  }

  @override
  Future<Result<EpgImportCounts>> reimport(String sourceId) =>
      importGuide(sourceId);

  @override
  Future<void> cancel(String sourceId) async {}

  @override
  Future<Result<GuideOrigin>> guideOrigin(String sourceId) async =>
      const Ok(GuideOrigin(GuideOriginKind.panel));
}

/// The matcher as far as the Guide needs it: the user's mappings become
/// matches, as the real match job writes them.
final class FakeRematch implements GuideMatching {
  new(this._fixture);

  final GuideFixture _fixture;
  final calls = <String>[];

  @override
  Future<Result<EpgMatchSummary>> rematch(String sourceId) async {
    calls.add(sourceId);
    final db = _fixture.db;
    final mappings = await db.select(db.epgMappings).get();
    for (final mapping in mappings) {
      await _fixture.match(mapping.channelRemoteKey, mapping.xmltvId);
    }
    return Ok(EpgMatchSummary(channels: mappings.length));
  }
}

/// No provider short EPG: the Guide never asks it.
final class _NoShortEpg implements GuideService {
  @override
  NowNext? cached(ChannelItem channel) => null;

  @override
  Future<Result<NowNext>> nowNext(ChannelItem channel) async =>
      const Ok(NowNext.none);

  @override
  Future<void> warm(List<ChannelItem> channels) async {}

  @override
  Stream<void> get changes => const Stream.empty();
}
