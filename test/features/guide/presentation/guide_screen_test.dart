import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/presentation/guide_match_picker.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_request.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_sheet.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';

import '../../../app/app_harness.dart';
import '../guide_grid_fakes.dart';

/// The fixture of the test running, so its end can stop what it started.
GuideFixture? _fixture;

void main() {
  tearDown(() => _fixture = null);

  Future<(GuideFixture, AppUnderTest)> pump(
    WidgetTester tester, {
    bool source = true,
    bool guide = true,
    Future<void> Function(GuideFixture fixture)? before,
  }) async {
    final fixture = GuideFixture();
    _fixture = fixture;
    addTearDown(() => tester.runAsync(fixture.db.close));
    await tester.runAsync(() async {
      if (source) await fixture.seed(guide: guide);
      await before?.call(fixture);
    });
    final app = await pumpApp(
      tester,
      initialLocation: AppDestination.guide.path,
      overrides: fixture.overrides,
    );
    await _settle(tester);
    return (fixture, app);
  }

  group('the grid', () {
    testWidgets('draws the canvas: channels, programmes around now, the '
        'no-guide row, the ruler and the now pill', (tester) async {
      await pump(tester);

      for (final name in GuideFixture.channelNames) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('World News'), findsNothing, reason: 'hidden');
      // The view starts at 8:30 PM: what began before it says so.
      expect(find.text('‹ Continental Cup · Semi-final'), findsOneWidget);
      // Drawn from the view's edge, over its own clipped-away copy.
      expect(find.text('8:00 – 10:00 PM'), findsNWidgets(2));
      expect(
        find.text('Match of the Week: Extended Highlights'),
        findsOneWidget,
      );
      expect(find.text('‹ Tip-Off'), findsOneWidget);
      expect(
        find.text(
          'No guide information · Match to a guide channel',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('TUESDAY 15'), findsOneWidget);
      expect(find.text('8:30 PM'), findsOneWidget);
      expect(find.text('9:00'), findsOneWidget);
      expect(find.text('12:00 AM'), findsOneWidget);
      expect(find.text('9:22'), findsOneWidget, reason: 'the now pill');
      expect(_selectedPill(tester), 'Today');
      await _finish(tester);
    });

    testWidgets('past, now and later programmes read as such', (tester) async {
      await pump(tester);

      expect(
        find.bySemanticsLabel('Tip-Off, 8:00 – 9:00 PM, ended'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Continental Cup · Semi-final, 8:00 – 10:00 PM, on now',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Cup Countdown, 11:30 PM – 1:00 AM'),
        findsOneWidget,
      );
      await _finish(tester);
    });

    testWidgets('on the minute, the now line moves and a programme that '
        'ends turns past', (tester) async {
      final (fixture, _) = await pump(tester);

      fixture.live.fakes.now = GuideFixture.at(22, 2);
      await tester.pump(const Duration(minutes: 1));
      await _settle(tester);

      expect(find.text('10:02'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Continental Cup · Semi-final, 8:00 – 10:00 PM, ended',
        ),
        findsOneWidget,
      );
      await _finish(tester);
    });
  });

  group('the keyboard', () {
    testWidgets('a jump to the Guide lands in the grid once its rows show, '
        'on what is on now', (tester) async {
      final fixture = GuideFixture();
      _fixture = fixture;
      addTearDown(() => tester.runAsync(fixture.db.close));
      await tester.runAsync(fixture.seed);
      await pumpApp(tester, overrides: fixture.overrides);
      await _settle(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await _settle(tester);

      expect(_gridHasFocus(tester), isTrue);
      // The rows show, then their programmes.
      await _settle(tester);
      expect(_ringed(), 'Continental Cup · Semi-final');
      await _finish(tester);
    });

    testWidgets('lands on what is on now; → the next programme, ↓ the same '
        'time on the next channel, ← back', (tester) async {
      await pump(tester);
      await _focusGrid(tester);

      expect(_ringed(), 'Continental Cup · Semi-final');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_ringed(), 'Match of the Week: Extended Highlights');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_ringed(), 'Tennis Open · Quarter-finals', reason: 'at 10:00');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_ringed(), 'Pit Lane');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_ringed(), 'Classic Races: Harbor Circuit');
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_ringed(), 'Pit Lane');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_ringed(), 'Tennis Open · Quarter-finals');
      await _finish(tester);
    });

    testWidgets('→ past the edge moves the view; Home comes back to now', (
      tester,
    ) async {
      await pump(tester);
      await _focusGrid(tester);

      for (var i = 0; i < 3; i++) {
        await _key(tester, LogicalKeyboardKey.arrowRight);
      }
      expect(_ringed(), 'Overnight Sport');
      expect(find.text('8:30 PM'), findsNothing, reason: 'the view moved');

      await _key(tester, LogicalKeyboardKey.home);
      expect(_ringed(), 'Continental Cup · Semi-final');
      expect(find.text('8:30 PM'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('↑ on the first channel leaves the grid for the toolbar', (
      tester,
    ) async {
      await pump(tester);
      await _focusGrid(tester);

      await _key(tester, LogicalKeyboardKey.arrowUp);

      expect(_gridHasFocus(tester), isFalse);
      expect(_ringed(), isNull);
      await _finish(tester);
    });

    testWidgets('PageDown goes a screen down, to the channel with no guide', (
      tester,
    ) async {
      await pump(tester);
      await _focusGrid(tester);

      await _key(tester, LogicalKeyboardKey.pageDown);

      expect(_ringed(), 'No guide information');
      await _key(tester, LogicalKeyboardKey.pageUp);
      expect(_ringed(), 'Continental Cup · Semi-final');
      await _finish(tester);
    });
  });

  group('the detail sheet', () {
    testWidgets('a programme search asked for: every channel, the cursor '
        'on it, its sheet open', (tester) async {
      final fixture = GuideFixture();
      _fixture = fixture;
      addTearDown(() => tester.runAsync(fixture.db.close));
      await tester.runAsync(fixture.seed);
      final app = await pumpApp(tester, overrides: fixture.overrides);
      await _settle(tester);
      final (channel, programme) = (await tester.runAsync(() async {
        final channels = DbChannelRepository(fixture.db);
        final blueWater = (await channels.byRemoteKey(
          'src-1',
          '208',
        )).valueOrNull!;
        final row = await (fixture.db.select(
          fixture.db.epgPrograms,
        )..where((t) => t.title.equals('Harbor to Harbor'))).getSingle();
        return (
          blueWater,
          EpgProgramme(
            id: row.id,
            channelId: row.epgChannelId,
            start: DateTime.fromMillisecondsSinceEpoch(
              row.startUtc,
              isUtc: true,
            ),
            end: DateTime.fromMillisecondsSinceEpoch(row.endUtc, isUtc: true),
            title: row.title,
          ),
        );
      }))!;

      // As search does: the request, then the Guide.
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
          .read(guideProgrammeRequestProvider.notifier)
          .show(channel, programme);
      app.router.go(AppDestination.guide.path);
      await _settle(tester);
      await _settle(tester);

      final sheet = find.byType(GuideProgrammeSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Harbor to Harbor')),
        findsOneWidget,
      );
      expect(find.text('Blue Water · 208'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(GuideProgrammeSheet), findsNothing);
      expect(_gridHasFocus(tester), isTrue);
      // The cursor stands on it: Enter opens the same sheet again.
      await _key(tester, LogicalKeyboardKey.enter);
      expect(
        find.descendant(
          of: find.byType(GuideProgrammeSheet),
          matching: find.text('Harbor to Harbor'),
        ),
        findsOneWidget,
      );
      await _key(tester, LogicalKeyboardKey.escape);
      await _finish(tester);
    });

    testWidgets('Enter opens it on Watch channel; Esc closes it', (
      tester,
    ) async {
      await pump(tester);
      await _focusGrid(tester);

      await _key(tester, LogicalKeyboardKey.enter);

      expect(find.byType(GuideProgrammeSheet), findsOneWidget);
      final sheet = find.byType(GuideProgrammeSheet);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Continental Cup · Semi-final'),
        ),
        findsOneWidget,
      );
      expect(find.text('Today · 8:00 – 10:00 PM · Sport'), findsOneWidget);
      expect(find.text('Arena Sports 1 · 201'), findsOneWidget);
      expect(
        find.textContaining('The two surviving sides meet'),
        findsOneWidget,
      );
      expect(_focusedButton(tester), 'Watch channel');

      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(GuideProgrammeSheet), findsNothing);
      expect(_gridHasFocus(tester), isTrue, reason: 'back where it was');
      await _finish(tester);
    });

    testWidgets('Watch channel plays the channel full screen, zapping '
        "through the Guide's list; back on the Guide it stops", (tester) async {
      final (fixture, app) = await pump(tester);
      await _focusGrid(tester);
      await _key(tester, LogicalKeyboardKey.enter);

      await tester.tap(find.text('Watch channel'));
      await _settle(tester);

      expect(app.location, '/player');
      expect(fixture.live.rig.coordinator.current?.name, 'Arena Sports 1');
      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      expect(player.zapQuery?.sourceId, 'src-1');

      await _key(tester, LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(app.location, AppDestination.guide.path);
      expect(fixture.live.rig.coordinator.current, isNull);
      await _finish(tester);
    });

    testWidgets('Watch keeps playing with Live TV built behind the Guide', (
      tester,
    ) async {
      final (fixture, app) = await pump(tester);
      // Live TV built and left: it stops its own playback when left, and
      // must not take the Guide's player for leaving.
      app.router.go(AppDestination.liveTv.path);
      await _settle(tester);
      app.router.go(AppDestination.guide.path);
      await _settle(tester);
      await _focusGrid(tester);
      await _key(tester, LogicalKeyboardKey.enter);

      await tester.tap(find.text('Watch channel'));
      await _settle(tester);

      expect(app.location, '/player');
      expect(fixture.live.rig.coordinator.current?.name, 'Arena Sports 1');
      await _key(tester, LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(fixture.live.rig.coordinator.current, isNull);
      await _finish(tester);
    });

    testWidgets('a programme that has ended: Already finished, and the '
        'favorite first', (tester) async {
      final (fixture, _) = await pump(tester);

      await tester.tap(find.text('‹ Tip-Off'));
      await _settle(tester);

      expect(find.text('Already finished'), findsOneWidget);
      expect(_focusedButton(tester), 'Add to favorites');
      await tester.tap(find.text('Add to favorites'));
      await _settle(tester);
      expect(find.text('Remove from favorites'), findsOneWidget);
      final courtside = await tester.runAsync(
        () => fixture.db.channelsDao.byRemoteKey('src-1', '204'),
      );
      final favorites = await tester.runAsync(
        () => fixture.db.select(fixture.db.favorites).get(),
      );
      expect(favorites!.map((f) => f.remoteKey), [courtside!.remoteKey]);
      await _finish(tester);
    });
  });

  group('a channel with no guide', () {
    testWidgets('Enter opens the Match… picker over the grid, and a match '
        'fills the row in', (tester) async {
      final (fixture, _) = await pump(tester);
      await _focusGrid(tester);
      await _key(tester, LogicalKeyboardKey.pageDown);

      await _key(tester, LogicalKeyboardKey.enter);
      expect(find.byType(GuideMatchPicker), findsOneWidget);
      expect(find.text('Match Summit Outdoor'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).last, 'bluewater');
      await tester.pump(GuideMatchPicker.debounce);
      await _settle(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      await _settle(tester);

      expect(find.byType(GuideMatchPicker), findsNothing);
      expect(fixture.matching.calls, ['src-1']);
      expect(
        find.text(
          'No guide information · Match to a guide channel',
          findRichText: true,
        ),
        findsNothing,
      );
      expect(find.text('Deep Blue Racing'), findsNWidgets(2));
      await _finish(tester);
    });
  });

  group('moving through time', () {
    testWidgets('Tomorrow shows the same hours a day on; Jump to now comes '
        'back', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Tomorrow'));
      await _settle(tester);
      expect(find.text('WEDNESDAY 16'), findsOneWidget);
      expect(_selectedPill(tester), 'Tomorrow');
      expect(find.text('9:22'), findsNothing, reason: 'now is off screen');

      await tester.tap(find.text('Jump to now'));
      await _settle(tester);
      expect(find.text('TUESDAY 15'), findsOneWidget);
      expect(find.text('9:22'), findsOneWidget);
      expect(_selectedPill(tester), 'Today');
      await _finish(tester);
    });

    testWidgets('a sideways wheel, or Shift and the wheel, moves through '
        'time; the plain wheel scrolls the channels', (tester) async {
      await pump(tester);
      final grid = tester.getCenter(find.text('Fight Night'));

      await _wheel(tester, grid, const Offset(120, 0));
      expect(find.text('8:30 PM'), findsNothing);
      expect(find.text('9:00 PM'), findsOneWidget, reason: 'half an hour on');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _wheel(tester, grid, const Offset(0, 120));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(find.text('9:30 PM'), findsOneWidget);
      await _finish(tester);
    });
  });

  group('the category filter', () {
    testWidgets('lists the visible categories and shows one', (tester) async {
      await pump(tester);

      await tester.tap(find.text('All channels'));
      await _settle(tester);
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('News'), findsNothing, reason: 'hidden');

      await tester.tap(find.text('Favorites'));
      await _settle(tester);
      expect(find.text('No favorites yet'), findsOneWidget);
      expect(find.text('Arena Sports 1'), findsNothing);

      await tester.tap(find.text('Favorites'));
      await _settle(tester);
      await tester.tap(find.text('Sports'));
      await _settle(tester);
      expect(find.text('Arena Sports 1'), findsOneWidget);
      await _finish(tester);
    });
  });

  group('every state', () {
    testWidgets('no source: add one', (tester) async {
      await pump(tester, source: false);

      expect(find.text('No guide yet'), findsOneWidget);
      expect(find.text('Add a source'), findsOneWidget);
    });

    testWidgets('no guide yet: Settings → Guide, which opens there', (
      tester,
    ) async {
      final (_, app) = await pump(tester, guide: false);

      expect(find.text('No guide yet'), findsOneWidget);
      await tester.tap(find.text('Open Settings → Guide'));
      await _settle(tester);
      expect(app.location, AppDestination.settings.path);
      expect(find.text('Import guide'), findsOneWidget);
    });

    testWidgets('a first import running: its progress', (tester) async {
      final (fixture, _) = await pump(
        tester,
        guide: false,
        before: (fixture) => fixture.startImport(),
      );

      expect(find.text('Importing the guide…'), findsOneWidget);
      fixture.imports.report(
        'src-1',
        const EpgImportProgress(
          bytesRead: 2 * 1024 * 1024,
          totalBytes: 8 * 1024 * 1024,
        ),
      );
      await _settle(tester);
      expect(
        find.textContaining('Importing the guide · 2.0 MB of 8.0 MB'),
        findsOneWidget,
      );
    });

    testWidgets('a first import that failed: why, and Try again', (
      tester,
    ) async {
      final (fixture, _) = await pump(
        tester,
        guide: false,
        before: (fixture) async {
          final run = await fixture.startImport();
          await fixture.failImport(run, NetworkFailure());
        },
      );

      expect(find.text("Couldn't import the guide"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(fixture.imports.imported, ['src-1']);
    });

    testWidgets('a guide that has run out: Refresh guide', (tester) async {
      final (fixture, _) = await pump(
        tester,
        guide: false,
        before: (fixture) => fixture.importCanvasGuide(
          programmes: [_programme('arena1', 'Old', 18, 20)],
        ),
      );

      expect(find.text('Your guide has run out'), findsOneWidget);
      expect(
        find.text("It ends today at 8:00 PM. Refresh it to see what's on."),
        findsOneWidget,
      );
      await tester.tap(find.text('Refresh guide'));
      await _settle(tester);
      expect(fixture.imports.imported, ['src-1']);
    });

    testWidgets('a guide that runs out while the Guide is open says so '
        'when it does', (tester) async {
      final (fixture, _) = await pump(
        tester,
        guide: false,
        before: (fixture) => fixture.importCanvasGuide(
          programmes: [
            EpgProgramme(
              id: 0,
              channelId: 'arena1',
              start: GuideFixture.at(21),
              end: GuideFixture.at(21, 40),
              title: 'Last Word',
            ),
          ],
        ),
      );
      expect(find.text('Last Word'), findsOneWidget);

      fixture.live.fakes.now = GuideFixture.at(21, 41);
      await tester.pump(const Duration(minutes: 19));
      await _settle(tester);

      expect(find.text('Your guide has run out'), findsOneWidget);
      expect(find.text('Last Word'), findsNothing);
    });

    testWidgets('a guide that starts after today', (tester) async {
      await pump(
        tester,
        guide: false,
        before: (fixture) => fixture.importCanvasGuide(
          programmes: [_programme('arena1', 'Later', 48 + 9, 48 + 10)],
        ),
      );

      expect(find.text('Nothing in the guide for today'), findsOneWidget);
      expect(
        find.text(
          'It starts on Thu Sep 17 at 9:00 AM. If its times look shifted, '
          'set a time offset in Settings → Guide.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an import running over the guide in use: a thin line and '
        'its progress; the guide still drawn', (tester) async {
      await pump(tester, before: (fixture) => fixture.startImport());

      expect(find.bySemanticsLabel('Updating the guide'), findsOneWidget);
      expect(find.text('Importing the guide…'), findsOneWidget);
      expect(find.text('‹ Continental Cup · Semi-final'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('a refresh that failed offline: said in the toolbar, the '
        'guide still drawn', (tester) async {
      await pump(
        tester,
        before: (fixture) async {
          final run = await fixture.startImport();
          await fixture.failImport(run, NetworkFailure());
        },
      );

      expect(find.text('Offline · guide from just now'), findsOneWidget);
      expect(find.text('‹ Continental Cup · Semi-final'), findsOneWidget);
      await _finish(tester);
    });
  });
}

EpgProgramme _programme(String channel, String title, int from, int to) =>
    EpgProgramme(
      id: 0,
      channelId: channel,
      start: GuideFixture.at(from),
      end: GuideFixture.at(to),
      title: title,
    );

/// The title of the programme the focus ring is on, or "No guide
/// information" on that row; null with no ring.
String? _ringed() {
  final grid = find.byWidgetPredicate(
    (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
  );
  final rings = find.descendant(
    of: grid,
    matching: find.byWidgetPredicate((w) => w is FocusRing && w.visible),
  );
  if (rings.evaluate().isEmpty) return null;
  // The focused cell is the one its semantics call selected.
  final selected = find
      .descendant(
        of: grid,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.selected ?? false),
        ),
      )
      .evaluate();
  if (selected.isEmpty) return null;
  final label = (selected.first.widget as Semantics).properties.label ?? '';
  if (label.startsWith('No guide information')) return 'No guide information';
  return label.split(', ').first;
}

bool _gridHasFocus(WidgetTester tester) =>
    FocusManager.instance.primaryFocus?.debugLabel == 'guide grid';

Future<void> _focusGrid(WidgetTester tester) async {
  final grid = tester.widget<Focus>(
    find.byWidgetPredicate(
      (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
    ),
  );
  grid.focusNode!.requestFocus();
  await _settle(tester);
}

String? _focusedButton(WidgetTester tester) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return null;
  return focused.findAncestorWidgetOfExactType<AppButton>()?.label;
}

String? _selectedPill(WidgetTester tester) {
  final pills = tester.widget<SegmentedControl<DateTime?>>(
    find.byType(SegmentedControl<DateTime?>),
  );
  final selected = pills.value;
  return pills.options.where((o) => o.value == selected).firstOrNull?.label;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

Future<void> _wheel(WidgetTester tester, Offset at, Offset delta) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(at));
  await tester.sendEventToBinding(pointer.scroll(delta));
  await _settle(tester);
}

Future<void> _finish(WidgetTester tester) async {
  await _fixture?.live.rig.coordinator.stop();
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
