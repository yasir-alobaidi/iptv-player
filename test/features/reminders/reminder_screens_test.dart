import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/casting/presentation/casting_view.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_sheet.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_watch.dart';
import 'package:iptv_player/features/reminders/presentation/reminders_dialog.dart';
import 'package:iptv_player/features/search/data/search_providers.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/search/presentation/search_state.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';

import '../../app/app_harness.dart';
import '../casting/support/cast_fakes.dart';
import '../casting/support/cast_ui_harness.dart';
import '../guide/guide_grid_fakes.dart';
import '../live_tv/live_tv_fakes.dart';
import '../search/search_fakes.dart';
import 'reminder_fakes.dart';

/// Phase 9 step 6 (decision 13, sketches F–I): every place a reminder is
/// set, shown, listed and watched, by the keyboard and by the mouse.
void main() {
  late FakeReminders reminders;

  setUp(() => reminders = FakeReminders());

  group('search', () {
    late LiveTvFakes live;
    late AppUnderTest app;
    final now = DateTime.utc(2026, 9, 14, 12);
    const arena = ChannelItem(
      id: 201,
      sourceId: 'src-1',
      remoteKey: '201',
      name: 'Arena Sports 1',
      number: 201,
    );
    final onNow = ProgrammeHit(
      programme: EpgProgramme(
        id: 1,
        channelId: 'arena1',
        start: now.subtract(const Duration(minutes: 30)),
        end: now.add(const Duration(minutes: 55)),
        title: 'Arena Cup',
      ),
      channel: arena,
      sourceName: 'Northwind TV',
    );
    final later = ProgrammeHit(
      programme: EpgProgramme(
        id: 2,
        channelId: 'arena1',
        start: now.add(const Duration(days: 1, hours: 2)),
        end: now.add(const Duration(days: 1, hours: 3)),
        title: 'Arena Weekly',
      ),
      channel: arena,
      sourceName: 'Northwind TV',
    );

    /// Search open on "arena": what is on now, then what is on tomorrow.
    Future<void> open(WidgetTester tester) async {
      live = LiveTvFakes();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(live.seed);
      final search = ScriptedSearch()
        ..answers['arena'] = SearchResults(
          text: 'arena',
          programmes: SearchGroup([onNow, later]),
        );
      app = await pumpApp(
        tester,
        overrides: [
          ...live.overrides,
          searchRepositoryProvider.overrideWithValue(search),
          reminderRepositoryProvider.overrideWithValue(reminders),
        ],
      );
      await _settle(tester);
      await _ctrl(tester, LogicalKeyboardKey.keyK);
      await tester.enterText(find.byType(EditableText), 'arena');
      await tester.pump(searchDelay);
      await _settle(tester);
    }

    testWidgets('an upcoming programme says Remind me; one that is on has '
        'its LIVE badge instead', (tester) async {
      await open(tester);

      expect(find.text('Arena Cup'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text(remindMeLabel), findsOneWidget);
      // On the row that is on now, the footer has nothing to say of it.
      expect(find.widgetWithText(Kbd, 'R'), findsNothing);
    });

    testWidgets('Ctrl+R sets the reminder and the keyboard stays in the '
        'field; Ctrl+R again takes it back', (tester) async {
      await open(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      // The footer says what Ctrl+R does here.
      expect(find.widgetWithText(Kbd, 'R'), findsOneWidget);
      expect(find.text(remindMeLabel), findsNWidgets(2));

      await _ctrl(tester, LogicalKeyboardKey.keyR);

      final set = reminders.sorted.single;
      expect(set.sourceId, 'src-1');
      expect(set.channelKey, '201');
      expect(set.xmltvId, 'arena1');
      expect(set.channelName, 'Arena Sports 1');
      expect(set.title, 'Arena Weekly');
      expect(set.start, later.programme.start);
      expect(set.end, later.programme.end);
      expect(find.text(reminderSetLabel), findsOneWidget);
      expect(find.text(removeReminderLabel), findsOneWidget, reason: 'footer');
      expect(
        find.text(reminderSetText(set.start, now, TimeStyle.h12)),
        findsOneWidget,
        reason: 'the toast, over search',
      );
      expect(find.byType(SearchOverlay), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'search field');

      await _ctrl(tester, LogicalKeyboardKey.keyR);

      expect(reminders.sorted, isEmpty);
      expect(find.text(reminderSetLabel), findsNothing);
      await _nextToast(tester);
      expect(find.text(reminderRemovedText('Arena Weekly')), findsOneWidget);
      // The toast's Undo: the reminder is back.
      await tester.tap(find.text('Undo'));
      await _settle(tester);
      expect(reminders.sorted.single.title, 'Arena Weekly');
      expect(find.text(reminderSetLabel), findsOneWidget);
    });

    testWidgets('the Menu key has Remind me, with its shortcut', (
      tester,
    ) async {
      await open(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.contextMenu);

      final item = find.widgetWithText(AppMenu, remindMeLabel);
      expect(item, findsOneWidget);
      expect(find.text('Ctrl+R'), findsOneWidget);
      await tester.tap(
        find.descendant(of: item, matching: find.text(remindMeLabel)),
      );
      await _settle(tester);

      expect(reminders.sorted.single.title, 'Arena Weekly');
    });

    testWidgets('a programme that is on has no Remind me in its menu', (
      tester,
    ) async {
      await open(tester);
      await _key(tester, LogicalKeyboardKey.contextMenu);

      expect(find.byType(AppMenu), findsOneWidget);
      expect(find.widgetWithText(AppMenu, remindMeLabel), findsNothing);
    });

    testWidgets('a click on Remind me sets it and opens nothing', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text(remindMeLabel));
      await _settle(tester);

      expect(reminders.sorted.single.title, 'Arena Weekly');
      expect(find.byType(SearchOverlay), findsOneWidget);
      expect(app.router.state.uri.path, isNot(AppDestination.guide.path));

      // And a click on Reminder set takes it back.
      await tester.tap(find.text(reminderSetLabel));
      await _settle(tester);
      expect(reminders.sorted, isEmpty);
    });

    testWidgets('Ctrl+R on what is on now sets nothing and says why', (
      tester,
    ) async {
      await open(tester);

      await _ctrl(tester, LogicalKeyboardKey.keyR);

      expect(reminders.sorted, isEmpty);
      expect(find.text(reminderTooLateText('Arena Cup')), findsOneWidget);
    });

    testWidgets("a reminder that can't be kept says so", (tester) async {
      reminders.setFailure = StorageFailure('disk full');
      await open(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);

      await _ctrl(tester, LogicalKeyboardKey.keyR);

      expect(reminders.sorted, isEmpty);
      expect(find.textContaining("Couldn't set the reminder."), findsOneWidget);
      expect(find.text(reminderSetLabel), findsNothing);
    });
  });

  group('the Guide', () {
    late GuideFixture fixture;

    Future<AppUnderTest> pump(WidgetTester tester, {String? location}) async {
      fixture = GuideFixture();
      addTearDown(() => tester.runAsync(fixture.db.close));
      await tester.runAsync(fixture.seed);
      final app = await pumpApp(
        tester,
        initialLocation: location ?? AppDestination.guide.path,
        overrides: [
          ...fixture.overrides,
          reminderRepositoryProvider.overrideWithValue(reminders),
        ],
      );
      await _settle(tester);
      return app;
    }

    const upcoming = 'Match of the Week: Extended Highlights';

    testWidgets('R on an upcoming programme sets its reminder: the toast '
        'says when, its cell gets a bell and the toolbar counts it; R again '
        'removes it, and Ctrl+Z undoes that', (tester) async {
      await pump(tester);
      await _focusGrid(tester);
      expect(findByLabel(remindersButtonLabel(0)), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_ringed(), upcoming);

      await _key(tester, LogicalKeyboardKey.keyR);

      final set = reminders.sorted.single;
      expect(set.channelKey, '201');
      expect(set.xmltvId, 'arena1');
      expect(set.channelName, 'Arena Sports 1');
      expect(set.title, upcoming);
      expect(set.start.isAtSameMomentAs(GuideFixture.at(22)), isTrue);
      expect(set.end.isAtSameMomentAs(GuideFixture.at(23, 30)), isTrue);
      expect(find.text('Reminder set · Today, 10:00 PM'), findsOneWidget);
      expect(
        find.bySemanticsLabel('$upcoming, 10:00 – 11:30 PM, reminder set'),
        findsOneWidget,
      );
      expect(_bellsInGrid(), findsOneWidget);
      expect(findByLabel(remindersButtonLabel(1)), findsOneWidget);
      expect(_gridHasFocus(), isTrue);

      await _key(tester, LogicalKeyboardKey.keyR);

      expect(reminders.sorted, isEmpty);
      expect(_bellsInGrid(), findsNothing);
      expect(findByLabel(remindersButtonLabel(0)), findsOneWidget);
      await _nextToast(tester);
      expect(find.text(reminderRemovedText(upcoming)), findsOneWidget);

      await _ctrl(tester, LogicalKeyboardKey.keyZ);

      expect(reminders.sorted.single.title, upcoming);
      expect(_bellsInGrid(), findsOneWidget);
    });

    testWidgets('R on what is on now sets nothing and says why; on a '
        'channel with no guide it does nothing', (tester) async {
      await pump(tester);
      await _focusGrid(tester);
      expect(_ringed(), 'Continental Cup · Semi-final');

      await _key(tester, LogicalKeyboardKey.keyR);

      expect(reminders.sorted, isEmpty);
      expect(
        find.text(reminderTooLateText('Continental Cup · Semi-final')),
        findsOneWidget,
      );

      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_ringed(), 'No guide information');
      await _key(tester, LogicalKeyboardKey.keyR);
      expect(reminders.sorted, isEmpty);
    });

    testWidgets('a reminder of another channel, or of another source, puts '
        'no bell here', (tester) async {
      reminders
        // The same start, on a channel the grid doesn't list.
        ..add(start: GuideFixture.at(22), channelKey: '999')
        ..add(start: GuideFixture.at(22), channelKey: '201', sourceId: 'src-2');
      await pump(tester);

      expect(_bellsInGrid(), findsNothing);
      expect(findByLabel(remindersButtonLabel(2)), findsOneWidget);
    });

    testWidgets('the sheet of an upcoming programme has Remind me after '
        'Watch channel; pressed, it reads Reminder set · Remove', (
      tester,
    ) async {
      await pump(tester);
      await _focusGrid(tester);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.enter);

      final sheet = find.byType(GuideProgrammeSheet);
      expect(sheet, findsOneWidget);
      expect(_focusedButton(), 'Watch channel');
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focusedButton(), remindMeLabel);

      await _key(tester, LogicalKeyboardKey.enter);

      expect(reminders.sorted.single.title, upcoming);
      expect(_focusedButton(), '$reminderSetLabel · Remove');
      expect(sheet, findsOneWidget, reason: 'the sheet stays');

      await _key(tester, LogicalKeyboardKey.enter);

      expect(reminders.sorted, isEmpty);
      expect(_focusedButton(), remindMeLabel);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focusedButton(), 'Add to favorites');
    });

    testWidgets('the sheet of what is on now, or over, has no Remind me', (
      tester,
    ) async {
      await pump(tester);
      await _focusGrid(tester);
      await _key(tester, LogicalKeyboardKey.enter);

      expect(find.byType(GuideProgrammeSheet), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Watch channel'), findsOneWidget);
      expect(find.widgetWithText(AppButton, remindMeLabel), findsNothing);
    });

    testWidgets('a programme that started while its sheet was open: Remind '
        'me sets nothing and says so', (tester) async {
      await pump(tester);
      await _focusGrid(tester);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.enter);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focusedButton(), remindMeLabel);

      fixture.live.fakes.now = GuideFixture.at(22, 1);
      await _key(tester, LogicalKeyboardKey.enter);

      expect(reminders.sorted, isEmpty);
      expect(find.text(reminderTooLateText(upcoming)), findsOneWidget);
    });

    testWidgets('the bell is a stop before the category filter, and opens '
        'Reminders', (tester) async {
      reminders
        ..add(start: GuideFixture.at(22, 5), channelKey: '208')
        ..add(start: GuideFixture.at(23, 15), channelKey: '204');
      await pump(tester);
      await _focusGrid(tester);

      await _shiftTab(tester);
      expect(focusedLabelOf(tester), 'All channels');
      await _shiftTab(tester);
      expect(focusedLabelOf(tester), remindersButtonLabel(2));
      await _key(tester, LogicalKeyboardKey.enter);

      expect(find.byType(RemindersDialog), findsOneWidget);
      expect(find.text(remindersTitle(2)), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(RemindersDialog), findsNothing);
      expect(focusedLabelOf(tester), remindersButtonLabel(2));
    });

    testWidgets('Settings → Guide has the second door: the count, and '
        'Manage', (tester) async {
      reminders
        ..add(start: GuideFixture.at(22, 5), channelKey: '208')
        ..add(start: GuideFixture.at(23, 15), channelKey: '204')
        ..add(start: GuideFixture.at(23, 30), channelKey: '201');
      final app = await pump(tester, location: '/');
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
          .read(settingsLocationProvider.notifier)
          .showGuide('src-1');
      app.router.go(AppDestination.settings.path);
      await _settle(tester);

      expect(find.text(remindersTitle(3)), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Manage'));
      await _settle(tester);

      expect(find.byType(RemindersDialog), findsOneWidget);
    });
  });

  group('Reminders', () {
    late GuideFixture fixture;
    late Reminder harbor;
    late Reminder courtside;
    late Reminder weekend;

    /// The Guide, with three reminders unless [seed] is false, and their
    /// list open.
    Future<void> open(WidgetTester tester, {bool seed = true}) async {
      fixture = GuideFixture();
      addTearDown(() => tester.runAsync(fixture.db.close));
      await tester.runAsync(fixture.seed);
      if (seed) {
        // Set out of order: the list is soonest first.
        weekend = reminders.add(
          start: GuideFixture.at(4 * 24 + 10),
          title: 'Weekend Preview',
          channelName: 'Arena Sports 1',
          channelKey: '201',
          xmltvId: 'arena1',
        );
        harbor = reminders.add(
          start: GuideFixture.at(22, 5),
          title: 'Harbor to Harbor',
          channelKey: '208',
          xmltvId: 'bluewater',
        );
        courtside = reminders.add(
          start: GuideFixture.at(23, 15),
          length: const Duration(minutes: 105),
          title: 'Courtside Tonight',
          channelName: 'Courtside',
          channelKey: '204',
          xmltvId: 'courtside',
        );
      }
      await pumpApp(
        tester,
        initialLocation: AppDestination.guide.path,
        overrides: [
          ...fixture.overrides,
          reminderRepositoryProvider.overrideWithValue(reminders),
        ],
      );
      await _settle(tester);
      await tester.tap(
        findByLabel(remindersButtonLabel(reminders.sorted.length)),
      );
      await _settle(tester);
    }

    String rowLabel(Reminder reminder) =>
        reminderRowLabel(reminder, GuideFixture.now, TimeStyle.h12);

    testWidgets('lists them soonest first, each with its channel and when, '
        'the first one focused', (tester) async {
      await open(tester);

      expect(find.text(remindersTitle(3)), findsOneWidget);
      final rows = [
        for (final title in const [
          'Harbor to Harbor',
          'Courtside Tonight',
          'Weekend Preview',
        ])
          tester.getTopLeft(_inList(find.text(title))).dy,
      ];
      expect(rows, orderedEquals(rows.toList()..sort()));
      expect(find.text('Blue Water · Today, 10:05 PM'), findsOneWidget);
      expect(find.text('Courtside · Today, 11:15 PM'), findsOneWidget);
      expect(
        find.text('Arena Sports 1 · Sat Sep 19, 10:00 AM'),
        findsOneWidget,
      );
      expect(find.text(remindersLimit), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Remove'), findsNWidgets(3));
      expect(focusedLabelOf(tester), rowLabel(harbor));
    });

    testWidgets('the list is one Tab stop: arrows move through it, Tab '
        'leaves for Close', (tester) async {
      await open(tester);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(focusedLabelOf(tester), rowLabel(courtside));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(focusedLabelOf(tester), rowLabel(weekend));
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(focusedLabelOf(tester), rowLabel(courtside));
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focusedButton(), 'Close');
      // Back into the list, at its near end.
      await _shiftTab(tester);
      expect(focusedLabelOf(tester), rowLabel(weekend));
      // Nothing else to stop at: Tab comes round to Close again.
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focusedButton(), 'Close');
    });

    testWidgets('Delete removes the focused one, with Undo; the focus goes '
        'to the row that takes its place', (tester) async {
      await open(tester);

      await _key(tester, LogicalKeyboardKey.delete);

      expect(reminders.sorted, [courtside, weekend]);
      expect(_inList(find.text('Harbor to Harbor')), findsNothing);
      expect(find.text(remindersTitle(2)), findsOneWidget);
      expect(focusedLabelOf(tester), rowLabel(courtside));
      expect(
        find.text(reminderRemovedText('Harbor to Harbor')),
        findsOneWidget,
      );

      await _ctrl(tester, LogicalKeyboardKey.keyZ);

      expect(reminders.sorted.map((r) => r.title), [
        'Harbor to Harbor',
        'Courtside Tonight',
        'Weekend Preview',
      ]);
      expect(_inList(find.text('Harbor to Harbor')), findsOneWidget);
      expect(focusedLabelOf(tester), rowLabel(courtside));
    });

    testWidgets('Delete on the last row moves the focus up; on the only '
        'row, to Close, over the empty list', (tester) async {
      await open(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);

      await _key(tester, LogicalKeyboardKey.delete);
      expect(focusedLabelOf(tester), rowLabel(courtside));
      await _key(tester, LogicalKeyboardKey.delete);
      expect(focusedLabelOf(tester), rowLabel(harbor));
      await _key(tester, LogicalKeyboardKey.delete);

      expect(reminders.sorted, isEmpty);
      expect(find.text(noRemindersTitle), findsOneWidget);
      expect(_focusedButton(), 'Close');
    });

    testWidgets("a row's Remove does the same for the mouse", (tester) async {
      await open(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Remove').at(1));
      await _settle(tester);

      expect(reminders.sorted, [harbor, weekend]);
      expect(
        find.text(reminderRemovedText('Courtside Tonight')),
        findsOneWidget,
      );
      // The keyboard was on the first row, and stays there.
      expect(focusedLabelOf(tester), rowLabel(harbor));
    });

    testWidgets('Enter opens the Guide on the programme, its sheet open and '
        'saying it has a reminder', (tester) async {
      await open(tester);

      await _key(tester, LogicalKeyboardKey.enter);
      await _settle(tester);

      expect(find.byType(RemindersDialog), findsNothing);
      final sheet = find.byType(GuideProgrammeSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Harbor to Harbor')),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppButton, '$reminderSetLabel · Remove'),
        findsOneWidget,
      );
      await _key(tester, LogicalKeyboardKey.escape);
      expect(_ringed(), 'Harbor to Harbor');
    });

    testWidgets('a reminder whose channel is gone says so and stays in the '
        'list, where it can be removed', (tester) async {
      final gone = reminders.add(
        start: GuideFixture.at(21, 40),
        title: 'Late Scores',
        channelName: 'Old Sports',
        channelKey: '999',
      );
      await open(tester);
      expect(focusedLabelOf(tester), rowLabel(gone));

      await _key(tester, LogicalKeyboardKey.enter);

      expect(find.byType(RemindersDialog), findsOneWidget);
      expect(find.text(reminderChannelGoneText('Old Sports')), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.delete);
      expect(reminders.sorted, hasLength(3));
    });

    testWidgets('none set: where one is set, and Close has the focus', (
      tester,
    ) async {
      await open(tester, seed: false);

      expect(find.text(remindersTitle(0)), findsOneWidget);
      expect(find.text(noRemindersTitle), findsOneWidget);
      expect(find.text(noRemindersMessage), findsOneWidget);
      expect(_focusedButton(), 'Close');
      expect(find.widgetWithText(Kbd, 'Del'), findsNothing);

      await _key(tester, LogicalKeyboardKey.enter);
      expect(find.byType(RemindersDialog), findsNothing);
    });

    testWidgets("reminders that can't be read: why, and Try again", (
      tester,
    ) async {
      reminders.watchFailure = StorageFailure('the database is locked');
      await open(tester, seed: false);

      expect(find.text("Couldn't read your reminders"), findsOneWidget);
      expect(find.text(noRemindersTitle), findsNothing);

      reminders.watchFailure = null;
      await tester.tap(find.text('Try again'));
      await _settle(tester);

      expect(find.text("Couldn't read your reminders"), findsNothing);
      expect(find.text(noRemindersTitle), findsOneWidget);
    });
  });

  group('Watch', () {
    late LiveTvFakes live;
    late FakeNotifier notifier;
    late AppUnderTest app;
    late ProviderContainer container;
    final start = DateTime.utc(2026, 9, 14, 12);
    final reminder = Reminder(
      id: 7,
      sourceId: 'src-1',
      channelKey: '201',
      xmltvId: 'arena1',
      channelName: 'Arena Sports 1',
      title: 'Arena Weekly',
      start: start,
      end: start.add(const Duration(hours: 1)),
    );

    Future<void> pump(WidgetTester tester, {LiveTvFakes? fakes}) async {
      live = fakes ?? LiveTvFakes();
      notifier = FakeNotifier();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(live.seed);
      app = await pumpApp(
        tester,
        overrides: [
          ...live.overrides,
          systemNotificationsProvider.overrideWithValue(notifier),
          reminderRepositoryProvider.overrideWithValue(reminders),
        ],
      );
      await _settle(tester);
      // As bootstrap() does, before any reminder can show.
      container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      )..read(reminderWatchesProvider);
    }

    /// The reminder falls due, as the scheduler would say it.
    Future<void> due(WidgetTester tester, Reminder reminder) async {
      unawaited(
        container
            .read(reminderAlertsProvider)
            .show(DueReminder(reminder, ReminderTiming.startingNow)),
      );
      await _settle(tester);
    }

    Future<void> watchOnToast(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AppToast),
          matching: find.text('Watch'),
        ),
      );
      await _settle(tester);
    }

    Future<void> finish(WidgetTester tester) async {
      await live.rig.coordinator.stop();
      await _settle(tester);
    }

    testWidgets('Watch on the toast plays the channel full screen; Esc comes '
        'back, and the stream stops', (tester) async {
      await pump(tester);
      await due(tester, reminder);
      expect(
        find.text('Starting now · Arena Weekly on Arena Sports 1'),
        findsOneWidget,
      );
      expect(notifier.shown, isEmpty, reason: 'the window is in front');

      await watchOnToast(tester);

      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(live.rig.coordinator.current?.remoteKey, '201');

      await _key(tester, LogicalKeyboardKey.escape);

      expect(find.byType(PlayerScreen), findsNothing);
      expect(live.rig.coordinator.current, isNull);
      await finish(tester);
    });

    testWidgets("Watch on the desktop's notification brings the window "
        'forward with what the desktop gave, then plays', (tester) async {
      await pump(tester);
      live.window.focused = false;
      await due(tester, reminder);
      final notice = notifier.shown.single;
      expect(notice.title, 'Arena Weekly');
      expect(notice.body, 'Starting now on Arena Sports 1');
      expect(notice.action, 'Watch');
      expect(find.byType(AppToast), findsNothing);

      notifier.answer(
        NoticeResponse(notice.id, chosen: true, activationToken: 'token-1'),
      );
      await _settle(tester);

      expect(live.window.raised, ['token-1']);
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(live.rig.coordinator.current?.remoteKey, '201');
      await finish(tester);
    });

    testWidgets('search closes first', (tester) async {
      await pump(tester);
      await _ctrl(tester, LogicalKeyboardKey.keyK);
      expect(find.byType(SearchOverlay), findsOneWidget);
      await due(tester, reminder);

      await watchOnToast(tester);

      expect(find.byType(SearchOverlay), findsNothing);
      expect(find.byType(PlayerScreen), findsOneWidget);
      await finish(tester);
    });

    testWidgets('with the player already up it shows the new channel, and '
        "isn't opened twice", (tester) async {
      await pump(tester);
      final other = (await tester.runAsync(
        () => container
            .read(channelRepositoryProvider)
            .byRemoteKey('src-1', '202'),
      ))!.valueOrNull!;
      unawaited(live.rig.coordinator.playLive(other));
      unawaited(app.router.push<void>(playerRoutePath));
      await _settle(tester);
      expect(live.rig.coordinator.current?.remoteKey, '202');
      await due(tester, reminder);

      await watchOnToast(tester);

      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(live.rig.coordinator.current?.remoteKey, '201');
      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(PlayerScreen), findsNothing);
      await finish(tester);
    });

    testWidgets('a channel the source no longer lists says so, and nothing '
        'plays', (tester) async {
      await pump(tester);
      await due(
        tester,
        Reminder(
          id: 8,
          sourceId: 'src-1',
          channelKey: '999',
          xmltvId: 'old',
          channelName: 'Old Sports',
          title: 'Late Scores',
          start: start,
          end: start.add(const Duration(hours: 1)),
        ),
      );

      await watchOnToast(tester);

      expect(find.text(reminderChannelGoneText('Old Sports')), findsOneWidget);
      expect(find.byType(PlayerScreen), findsNothing);
      expect(live.rig.coordinator.current, isNull);
    });

    testWidgets('while casting it plays on the TV, and the casting view '
        'opens', (tester) async {
      final ui = CastUi();
      addTearDown(ui.dispose);
      live = ui.live;
      notifier = FakeNotifier();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(live.seed);
      app = await pumpApp(
        tester,
        initialLocation: AppDestination.liveTv.path,
        overrides: [
          ...ui.overrides,
          systemNotificationsProvider.overrideWithValue(notifier),
          reminderRepositoryProvider.overrideWithValue(reminders),
        ],
      );
      await settleCast(tester);
      container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      )..read(reminderWatchesProvider);
      try {
        unawaited(ui.cast.coordinator.connect(tvDevice));
        await settleCast(tester);
        expect(live.rig.coordinator.casting, isTrue);
        await due(tester, reminder);

        await watchOnToast(tester);
        await settleCast(tester, rounds: 8);

        expect(
          (ui.cast.coordinator.state.item! as PlayableChannel)
              .channel
              .remoteKey,
          '201',
        );
        expect(find.byType(CastingView), findsOneWidget);
        expect(find.byType(PlayerScreen), findsNothing);
        expect(live.rig.engine.opened, isEmpty, reason: 'no stream here');
      } finally {
        unawaited(ui.cast.coordinator.disconnect());
        await settleCast(tester);
        await live.rig.coordinator.stop();
      }
    });
  });
}

/// Rounds enough for a menu's item (run once the menu has faded out) and
/// the reads it starts.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await _settle(tester);
}

Future<void> _shiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await _settle(tester);
}

/// What [finder] finds inside the Reminders dialog: the Guide behind it
/// has the same programmes in its cells.
Finder _inList(Finder finder) =>
    find.descendant(of: find.byType(RemindersDialog), matching: finder);

/// Toasts take turns: the one shown has its three seconds, then the next.
Future<void> _nextToast(WidgetTester tester) async {
  await tester.pump(AppToast.defaultDuration);
  await _settle(tester);
}

Finder get _grid => find.byWidgetPredicate(
  (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
);

Future<void> _focusGrid(WidgetTester tester) async {
  tester.widget<Focus>(_grid).focusNode!.requestFocus();
  await _settle(tester);
}

bool _gridHasFocus() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'guide grid';

/// The bells the grid's cells draw.
Finder _bellsInGrid() => find.descendant(
  of: _grid,
  matching: find.byWidgetPredicate(
    (w) => w is AppIcon && w.icon == AppIcons.bellFilled,
  ),
);

/// The title of the programme the keyboard's cursor is on, or "No guide
/// information" on that row.
String? _ringed() {
  final selected = find
      .descendant(
        of: _grid,
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

String? _focusedButton() => FocusManager.instance.primaryFocus?.context
    ?.findAncestorWidgetOfExactType<AppButton>()
    ?.label;
