import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/data/db/app_database.dart'
    show EpgMatchesCompanion, EpgProgramsCompanion;
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';

import '../../app/app_harness.dart';
import 'live_tv_fakes.dart';

/// The rig of the test running, so the test's end can stop its timers.
LiveTvFakes? _live;

/// Live TV over the app's own guide: the imported XMLTV guide read from
/// the database, with a short EPG behind it that has no network and
/// records every question.
void main() {
  tearDown(() => _live = null);

  Future<(LiveTvFakes, _ShortEpg)> pump(WidgetTester tester) async {
    final live = LiveTvFakes();
    final short = _ShortEpg();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(() async {
      await live.seed();
      await _seedGuide(live);
    });
    await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.importedGuideOverrides(short),
    );
    _live = live;
    await _settle(tester);
    return (live, short);
  }

  testWidgets('every row says what is on, from the database alone', (
    tester,
  ) async {
    final (live, short) = await pump(tester);
    final now = live.fakes.now;

    expect(_rowText('Continental Cup · Semi-final'), findsOneWidget);
    expect(_rowText('Morning Rally'), findsOneWidget);
    expect(
      _rowText(
        'Next ${formatClock(now.add(const Duration(minutes: 30)))} · '
        'Zebra Late Show',
      ),
      findsOneWidget,
      reason: 'a gap now, a programme to come',
    );
    expect(_rowText('No guide information'), findsOneWidget, reason: '203');
    expect(short.warmed, isEmpty);
    expect(short.asked, isEmpty);
    await _finish(tester);
  });

  testWidgets('the preview reads the imported guide, and the short EPG '
      'only for a channel it has nothing for', (tester) async {
    final (_, short) = await pump(tester);

    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);
    expect(find.text('Holders Northport face Valencia Azul.'), findsOneWidget);
    expect(find.text('Match of the Week'), findsOneWidget);

    await tester.tap(find.text('Zebra TV').first);
    await _settle(tester);
    expect(find.text('Nothing on right now'), findsOneWidget);
    expect(find.text('Zebra Late Show'), findsOneWidget);
    expect(short.asked, isEmpty, reason: 'the imported guide answered');

    await tester.tap(find.text('Velocity Motors').first);
    await _settle(tester);
    expect(short.asked, ['203']);
    expect(find.text('Pit Lane Live'), findsNWidgets(2), reason: 'and the row');
    await _finish(tester);
  });

  testWidgets('rows and the preview follow a change to the guide', (
    tester,
  ) async {
    final (live, short) = await pump(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);

    await tester.runAsync(() async {
      await _programme(live, 'velocity', 'Grand Prix Qualifying', from: -5);
      await _programme(live, 'arena.alt', 'Cup Replay', from: -10);
      await _match(live, '203', 'velocity');
      await _match(live, '201', 'arena.alt');
    });
    await _settle(tester);

    expect(_rowText('Grand Prix Qualifying'), findsOneWidget);
    expect(_rowText('No guide information'), findsNothing);
    expect(find.text('Cup Replay'), findsNWidgets(2), reason: 'row, preview');
    expect(find.text('Continental Cup · Semi-final'), findsNothing);
    expect(short.asked, isEmpty);
    await _finish(tester);
  });

  testWidgets('rows look their guide up again each minute', (tester) async {
    final (live, _) = await pump(tester);
    expect(_rowText('Continental Cup · Semi-final'), findsOneWidget);

    // Both programmes it knew of have ended.
    live.fakes.now = live.fakes.now.add(const Duration(minutes: 120));
    await tester.pump(const Duration(minutes: 1));
    await _settle(tester);

    expect(_rowText('Evening Final'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('a page is looked up in one go; nothing while Live TV is '
      'covered, again when it comes back and when the guide changes', (
    tester,
  ) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    final app = await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.overrides,
    );
    _live = live;
    await _settle(tester);
    expect(live.guide.warmed, [
      ['201', '202', '203', '900'],
    ]);

    app.router.go(AppDestination.favorites.path);
    await _settle(tester);
    await tester.pump(const Duration(minutes: 1));
    await _settle(tester);
    expect(live.guide.warmed, hasLength(1), reason: 'covered');

    app.router.go(AppDestination.liveTv.path);
    await _settle(tester);
    expect(live.guide.warmed, hasLength(2));

    live.guide.change();
    await _settle(tester);
    expect(live.guide.warmed, hasLength(3));
    await _finish(tester);
  });

  testWidgets("the player's OSD says a gap is a gap, and moves on when the "
      'next programme starts', (tester) async {
    final guide = FakeGuide();
    var now = DateTime.utc(2026, 9, 14, 12);
    const zebra = ChannelItem(
      id: 9,
      sourceId: 'src-1',
      remoteKey: '900',
      name: 'Zebra TV',
    );
    guide.byKey['900'] = NowNext(
      next: Programme(
        title: 'Zebra Late Show',
        start: now.add(const Duration(minutes: 30)),
        end: now.add(const Duration(minutes: 90)),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guideServiceProvider.overrideWithValue(guide),
          appClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: OsdBottom(channel: zebra, controls: []),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nothing on right now'), findsOneWidget);
    expect(find.text('No guide information'), findsNothing);
    expect(find.textContaining('Zebra Late Show'), findsOneWidget);

    // It asks again when the next programme starts, on its own.
    now = now.add(const Duration(minutes: 30));
    guide.byKey['900'] = NowNext(
      now: Programme(
        title: 'Zebra Late Show',
        start: now,
        end: now.add(const Duration(minutes: 60)),
      ),
    );
    await tester.pump(const Duration(minutes: 30));
    await tester.pump();

    expect(guide.asked, ['900', '900']);
    expect(find.text('Zebra Late Show'), findsOneWidget);
    expect(find.text('Nothing on right now'), findsNothing);
  });
}

Finder _rowText(String text) =>
    find.descendant(of: find.byType(ChannelRow), matching: find.text(text));

/// 201 has now and next (and one after), 202 now only, Zebra TV (900) a
/// gap before its next programme, and 203 no guide at all.
Future<void> _seedGuide(LiveTvFakes live) async {
  await _programme(
    live,
    'arena.sports',
    'Continental Cup · Semi-final',
    from: -30,
    minutes: 68,
    description: 'Holders Northport face Valencia Azul.',
  );
  await _programme(live, 'arena.sports', 'Match of the Week', from: 38);
  await _programme(
    live,
    'arena.sports',
    'Evening Final',
    from: 98,
    minutes: 120,
  );
  await _programme(live, 'arena.two', 'Morning Rally', from: -15);
  await _programme(live, 'zebra', 'Early Zebra', from: -90);
  await _programme(live, 'zebra', 'Zebra Late Show', from: 30);
  await _match(live, '201', 'arena.sports');
  await _match(live, '202', 'arena.two');
  await _match(live, '900', 'zebra');
}

Future<void> _match(LiveTvFakes live, String remoteKey, String xmltvId) async {
  final channel = await live.db.channelsDao.byRemoteKey('src-1', remoteKey);
  await live.db
      .into(live.db.epgMatches)
      .insertOnConflictUpdate(
        EpgMatchesCompanion.insert(
          channelId: Value(channel!.id),
          sourceId: 'src-1',
          xmltvId: xmltvId,
          rule: EpgMatchRule.exactId,
        ),
      );
}

Future<void> _programme(
  LiveTvFakes live,
  String xmltvId,
  String title, {
  required int from,
  int minutes = 60,
  String? description,
}) {
  final start = live.fakes.now.add(Duration(minutes: from));
  return live.db
      .into(live.db.epgPrograms)
      .insert(
        EpgProgramsCompanion.insert(
          sourceId: 'src-1',
          epgChannelId: xmltvId,
          startUtc: start.millisecondsSinceEpoch,
          endUtc: start.add(Duration(minutes: minutes)).millisecondsSinceEpoch,
          title: title,
          description: Value(description),
        ),
      );
}

/// The provider's short EPG with no network: it answers 203 only, and
/// records what it was asked, so a test can say no channel with an
/// imported guide ever reached it.
final class _ShortEpg implements GuideService {
  final asked = <String>[];
  final warmed = <List<String>>[];

  NowNext _answer(String remoteKey) => remoteKey == '203'
      ? NowNext(
          now: Programme(
            title: 'Pit Lane Live',
            start: DateTime.utc(2026, 9, 14, 11, 30),
            end: DateTime.utc(2026, 9, 14, 12, 30),
          ),
        )
      : NowNext.none;

  @override
  NowNext? cached(ChannelItem channel) =>
      asked.contains(channel.remoteKey) ? _answer(channel.remoteKey) : null;

  @override
  Future<Result<NowNext>> nowNext(ChannelItem channel) async {
    asked.add(channel.remoteKey);
    return Ok(_answer(channel.remoteKey));
  }

  @override
  Future<void> warm(List<ChannelItem> channels) async {
    warmed.add([for (final channel in channels) channel.remoteKey]);
  }

  @override
  Stream<void> get changes => const Stream.empty();
}

/// Stops playback so no watchdog timer outlives the test.
Future<void> _finish(WidgetTester tester) async {
  // Let a pending preview (350 ms) fire, then stop what it started.
  await tester.pump(const Duration(milliseconds: 400));
  await _live?.rig.coordinator.stop();
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
