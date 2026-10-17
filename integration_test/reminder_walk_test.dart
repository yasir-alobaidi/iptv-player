// Phase 9 step 6's walk (decision 13), keys only, on the real app,
// database, sync, guide import and player against the fake panel, with
// the app's clock and the desktop's notifications in the test's hand:
//
// Ctrl+K → an upcoming programme's title → Ctrl+R: "Reminder set", the
// keyboard still in the field → Esc → G: the Guide's bell counts one →
// the app closed and opened again → the bell still counts one; Enter on
// it lists the reminder; Enter on the row opens the Guide on its
// programme, whose sheet says it has one → the clock reaches the start,
// the window covered: the desktop's notification, once, and the reminder
// is gone from the list → Watch: the window comes forward with what the
// desktop gave, and the channel plays full screen → Esc.
//
// Plays the channel only with the stream samples (CI makes them);
// without, it checks the player was asked to.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_sheet.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_watch.dart';
import 'package:iptv_player/features/reminders/presentation/reminders_dialog.dart';
import 'package:iptv_player/features/search/data/search_providers.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/search/presentation/search_text.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';

import 'support/fake_panel.dart';
import 'support/guide_on.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets('a reminder set in search, kept through a restart, shown by '
      'the desktop at its start, and watched', (tester) async {
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    // The app's clock: the real one, until the walk moves it on.
    var ahead = Duration.zero;
    DateTime clock() => DateTime.now().add(ahead);
    final desktop = _Desktop();
    final window = _Window();

    final panel = (await tester.runAsync(
      () => FakePanel.start(streams: streamsAvailable),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    var app = (await tester.runAsync(
      () => PanelApp.open(
        panel,
        video: video,
        overrides: [
          appClockProvider.overrideWithValue(clock),
          systemNotificationsProvider.overrideWithValue(desktop),
          windowControlsProvider.overrideWithValue(window),
          guideSwitchedOn(),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(() => app.close()));
    final sourceId = app.sourceId;
    final imported = (await tester.runAsync(
      () =>
          app.container.read(guideImportServiceProvider).importGuide(sourceId),
    ))!;
    expect(imported.isOk, isTrue, reason: '${imported.failureOrNull}');

    /// What `bootstrap()` starts after the first frame: Watch is heard,
    /// and the scheduler keeps watch.
    Future<void> startReminders() async {
      app.container.read(reminderWatchesProvider);
      await tester.runAsync(
        () => app.container.read(reminderServiceProvider).start(),
      );
    }

    Future<Keys> show() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app.container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      final k = Keys(tester)..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return k;
    }

    Future<int> reminderCount() async =>
        (await app.container.read(reminderRepositoryProvider).all())
            .valueOrNull!
            .length;

    // An upcoming programme search shows among its first rows, on one of
    // the first channels (the ones with stream samples).
    final hit = (await tester.runAsync(() => _upcoming(app, clock())))!;
    final programme = hit.programme;
    final channel = hit.channel;
    final style = app.container.read(timeStyleProvider);

    await startReminders();
    var k = await show();

    // ── Ctrl+K → the title → down to its row → Ctrl+R.
    final overlay = find.byType(SearchOverlay);
    final field = find.descendant(
      of: overlay,
      matching: find.byType(EditableText),
    );
    final line = programmeHitLine(hit, now: clock(), sources: 1, style: style);

    /// Whether the cursor (the row with the Enter keycap) is on the
    /// programme's row.
    bool onItsRow() => find
        .descendant(
          of: find.ancestor(
            of: find.descendant(of: overlay, matching: find.text(line)),
            matching: find.byType(Row),
          ),
          matching: find.widgetWithText(Kbd, 'Enter'),
        )
        .evaluate()
        .isNotEmpty;

    await k.chord(LogicalKeyboardKey.keyK);
    await k.waitFor(field);
    await k.typeIn(field, programme.title);
    await k.waitFor(
      find.descendant(of: overlay, matching: find.text(line)),
      seconds: 10,
    );
    for (var i = 0; i < 12 && !onItsRow(); i++) {
      await k.press(LogicalKeyboardKey.arrowDown);
    }
    expect(onItsRow(), isTrue, reason: 'the cursor on "$line"');
    expect(
      find.descendant(of: overlay, matching: find.text(reminderSetLabel)),
      findsNothing,
    );
    // The footer says what Ctrl+R does here.
    expect(
      find.descendant(of: overlay, matching: find.widgetWithText(Kbd, 'R')),
      findsOneWidget,
    );

    await k.chord(LogicalKeyboardKey.keyR);
    await k.waitFor(
      find.descendant(of: overlay, matching: find.text(reminderSetLabel)),
    );
    await k.waitFor(
      find.text(reminderSetText(programme.start, clock(), style)),
    );
    final set = (await tester.runAsync(
      () => app.container.read(reminderRepositoryProvider).all(),
    ))!.valueOrNull!.single;
    expect(set.channelKey, channel.remoteKey);
    expect(set.xmltvId, programme.channelId);
    expect(set.title, programme.title);
    expect(set.start.isAtSameMomentAs(programme.start), isTrue);
    expect(k.focusIsOn(field), isTrue, reason: 'the keyboard stays put');

    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(() => overlay.evaluate().isEmpty, 'search closed');

    // ── G: the Guide's bell counts it.
    await k.press(LogicalKeyboardKey.keyG);
    await k.waitUntil(
      () => app.location == AppDestination.guide.path,
      'the Guide (${app.location})',
    );
    await k.waitFor(byLabel(remindersButtonLabel(1)));

    // ── Closed and opened again on the same database.
    await tester.pumpWidget(const SizedBox.shrink());
    app = (await tester.runAsync(app.restart))!;
    expect(await tester.runAsync(reminderCount), 1);
    await startReminders();
    k = await show();
    expect(desktop.shown, isEmpty, reason: 'not due yet');
    await k.press(LogicalKeyboardKey.keyG);
    await k.waitUntil(
      () => app.location == AppDestination.guide.path,
      'the Guide again (${app.location})',
    );
    await k.waitFor(byLabel(remindersButtonLabel(1)));
    await k.waitUntil(
      () => FocusManager.instance.primaryFocus?.debugLabel == 'guide grid',
      'the focus in the grid',
    );

    // ── The bell → Reminders → Enter on the row: the Guide on it.
    await k.tabTo(byLabel(remindersButtonLabel(1)), back: true);
    await k.press(LogicalKeyboardKey.enter);
    final list = find.byType(RemindersDialog);
    await k.waitFor(list);
    await k.waitFor(
      find.descendant(of: list, matching: find.text(programme.title)),
    );
    expect(
      k.focusedLabel(),
      reminderRowLabel(set, clock(), style),
      reason: 'the first row has the focus',
    );
    await k.press(LogicalKeyboardKey.enter);
    final sheet = find.byType(GuideProgrammeSheet);
    await k.waitFor(sheet);
    expect(list, findsNothing);
    await k.waitFor(
      find.descendant(of: sheet, matching: find.text(programme.title)),
    );
    await k.waitFor(
      find.descendant(
        of: sheet,
        matching: find.text('$reminderSetLabel · Remove'),
      ),
    );
    // Its cell in the grid has the bell.
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
        ),
        matching: find.byWidgetPredicate(
          (w) => w is AppIcon && w.icon == AppIcons.bellFilled,
        ),
      ),
      findsWidgets,
    );
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(() => sheet.evaluate().isEmpty, 'the sheet closed');

    // ── The clock reaches the start, the window covered: the desktop
    // says it, once, and the reminder is gone from the store.
    window.focused = false;
    ahead =
        programme.start.difference(DateTime.now()) + const Duration(seconds: 2);
    await tester.runAsync(
      () => app.container.read(reminderServiceProvider).scheduler.check(),
    );
    await k.waitUntil(() => desktop.shown.isNotEmpty, 'the notification');
    final notice = desktop.shown.single;
    expect(notice.title, programme.title);
    expect(notice.body, 'Starting now on ${channel.name}');
    expect(notice.action, 'Watch');
    expect(await tester.runAsync(reminderCount), 0);
    await tester.runAsync(
      () => app.container.read(reminderServiceProvider).scheduler.check(),
    );
    expect(desktop.shown, hasLength(1), reason: 'never twice');
    await k.waitFor(byLabel(remindersButtonLabel(0)));

    // ── Watch: the window forward with the desktop's token, the channel
    // full screen.
    final coordinator = app.container.read(playbackCoordinatorProvider);
    desktop.answer(
      NoticeResponse(notice.id, chosen: true, activationToken: 'walk-token'),
    );
    await k.waitUntil(
      () => app.location == '/player',
      'the player (${app.location})',
    );
    expect(window.raised, ['walk-token']);
    expect(coordinator.current?.remoteKey, channel.remoteKey);
    if (streamsAvailable) {
      await k.waitUntil(
        () => coordinator.state is PlaybackPlaying,
        'the channel playing (${coordinator.state})',
        seconds: 30,
      );
    }
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(
      () => app.location == AppDestination.guide.path,
      'back on the Guide (${app.location})',
    );
    await k.waitUntil(
      () => coordinator.current == null,
      'the stream stopped (${coordinator.state})',
    );
  });
}

/// A programme that starts in a while, on one of the first three channels
/// in number order, which search lists among its first rows by its title.
Future<ProgrammeHit> _upcoming(PanelApp app, DateTime now) async {
  final container = app.container;
  final channels =
      (await container
              .read(channelRepositoryProvider)
              .range(ChannelQuery(sourceId: app.sourceId), 0, 3))
          .valueOrNull!;
  final guide =
      (await container
              .read(epgRepositoryProvider)
              .windowForChannels(
                [for (final channel in channels) channel.id],
                now.add(const Duration(minutes: 30)),
                now.add(const Duration(hours: 12)),
              ))
          .valueOrNull!;
  final search = container.read(searchRepositoryProvider);
  for (final channel in channels) {
    for (final programme in guide[channel.id] ?? const <EpgProgramme>[]) {
      if (!programme.start.isAfter(now.add(const Duration(minutes: 30)))) {
        continue;
      }
      final found = (await search.search(
        programme.title,
        now: now,
        preferredSourceId: app.sourceId,
      )).valueOrNull;
      for (final hit in found?.programmes.hits ?? const <ProgrammeHit>[]) {
        if (hit.programme.id == programme.id &&
            hit.channel.remoteKey == channel.remoteKey) {
          return hit;
        }
      }
    }
  }
  throw StateError('no upcoming programme that search lists');
}

/// The desktop's notifications, recorded; the test answers them.
final class _Desktop implements SystemNotifier {
  final shown = <SystemNotice>[];
  final _responses = StreamController<NoticeResponse>.broadcast();

  @override
  Future<bool> show(SystemNotice notice) async {
    shown.add(notice);
    return true;
  }

  @override
  Stream<NoticeResponse> get responses => _responses.stream;

  void answer(NoticeResponse response) => _responses.add(response);

  // The app's containers come and go with its restarts; this one stays.
  @override
  Future<void> dispose() async {}
}

/// The window, as the reminders and the player ask of it.
final class _Window implements WindowControls {
  bool focused = true;
  bool fullScreen = false;
  final raised = <String?>[];

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen({required bool on}) async => fullScreen = on;

  @override
  Future<bool> isFocused() async => focused;

  @override
  Future<void> bringToFront({String? activationToken}) async {
    raised.add(activationToken);
    focused = true;
  }
}
