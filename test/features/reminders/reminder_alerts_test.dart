import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/reminders/domain/reminder_scheduler.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_alerts.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';
import 'package:logger/logger.dart';

import '../live_tv/live_tv_fakes.dart' show FakeWindow;
import 'reminder_fakes.dart';

/// Phase 9 decision 10, sketch I: where a due reminder is said, and what
/// its Watch does.
void main() {
  // A local evening: what the sentences say is the viewer's own time.
  final start = DateTime(2026, 10, 14, 21, 30);
  final reminder = Reminder(
    id: 3,
    sourceId: 'src-1',
    channelKey: '212',
    xmltvId: 'bluewater.uk',
    channelName: 'Blue Water',
    title: 'The Harbor Pilot',
    start: start,
    end: start.add(const Duration(hours: 1)),
  );
  const startingNow = ReminderTiming.startingNow;

  late FakeNotifier notifier;
  late FakeWindow window;
  late AppNotices notices;
  late List<AppNotice> toasts;
  late List<ReminderWatch> watches;
  late ReminderAlerts alerts;
  var style = TimeStyle.h12;

  setUp(() {
    notifier = FakeNotifier();
    window = FakeWindow();
    notices = AppNotices();
    toasts = [];
    watches = [];
    style = TimeStyle.h12;
    notices.stream.listen(toasts.add);
    alerts = ReminderAlerts(
      notifier: notifier,
      window: window,
      notices: notices,
      timeStyle: () => style,
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
      clock: () => DateTime(2026, 10, 14, 12),
      focusWait: const Duration(milliseconds: 400),
    );
    alerts.watches.listen(watches.add);
  });
  tearDown(() async {
    await alerts.dispose();
    await notifier.dispose();
    await notices.dispose();
  });

  group('the window in front', () {
    test('a toast inside the app with Watch, and no notification: one on '
        'top of the app you are looking at is noise', () async {
      await alerts.show(DueReminder(reminder, startingNow));
      await pumpEventQueue();

      expect(notifier.shown, isEmpty);
      expect(
        toasts.single.message,
        'Starting now · The Harbor Pilot on Blue Water',
      );
      expect(toasts.single.actionLabel, 'Watch');

      toasts.single.onAction!();
      await pumpEventQueue();
      expect(watches.single.reminder, reminder);
      expect(watches.single.activationToken, isNull);
    });

    test('one that fell due while the app was closed says it is on, and '
        'until when', () async {
      await alerts.show(DueReminder(reminder, ReminderTiming.onNow));
      await pumpEventQueue();

      expect(
        toasts.single.message,
        'On now · The Harbor Pilot on Blue Water, until 10:30 PM',
      );
    });
  });

  group('the window covered or minimized', () {
    setUp(() => window.focused = false);

    test('a system notification: the title, where it starts, and Watch; no '
        'toast', () async {
      await alerts.show(DueReminder(reminder, startingNow));
      await pumpEventQueue();

      final notice = notifier.shown.single;
      expect(notice.title, 'The Harbor Pilot');
      expect(notice.body, 'Starting now on Blue Water');
      expect(notice.action, 'Watch');
      expect(toasts, isEmpty);
    });

    test('late and still on, in the chosen clock', () async {
      style = TimeStyle.h24;

      await alerts.show(DueReminder(reminder, ReminderTiming.onNow));

      expect(notifier.shown.single.body, 'On now on Blue Water, until 22:30');
    });

    test('Watch on the notification: the reminder, with the desktop’s '
        'token when it gave one', () async {
      await alerts.show(DueReminder(reminder, startingNow));

      notifier.answer(
        NoticeResponse(
          notifier.shown.single.id,
          chosen: true,
          activationToken: 'token-9f2',
        ),
      );
      await pumpEventQueue();

      expect(watches.single.reminder, reminder);
      expect(watches.single.activationToken, 'token-9f2');
    });

    test('an answer is taken once: a second for the same notice does '
        'nothing', () async {
      await alerts.show(DueReminder(reminder, startingNow));
      final id = notifier.shown.single.id;

      notifier
        ..answer(NoticeResponse(id, chosen: true))
        ..answer(NoticeResponse(id, chosen: true));
      await pumpEventQueue();

      expect(watches, hasLength(1));
    });

    test('closed on GNOME, and the window came to the front a moment '
        'later: that was a click on the notice, so it is Watch', () async {
      await alerts.show(DueReminder(reminder, startingNow));

      notifier.answer(NoticeResponse(notifier.shown.single.id, chosen: false));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(watches, isEmpty);
      // The shell raised the window.
      window.focused = true;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(watches.single.reminder, reminder);
    });

    test(
      'closed, and the window stayed where it was: only dismissed',
      () async {
        await alerts.show(DueReminder(reminder, startingNow));

        notifier.answer(
          NoticeResponse(notifier.shown.single.id, chosen: false),
        );
        await Future<void>.delayed(const Duration(milliseconds: 700));

        expect(watches, isEmpty);
      },
    );

    test('two notices: each answer plays its own reminder', () async {
      final scores = reminder.movedTo(
        start.add(const Duration(hours: 2)),
        start.add(const Duration(hours: 3)),
      );
      await alerts.show(DueReminder(reminder, startingNow));
      await alerts.show(DueReminder(scores, startingNow));
      expect(notifier.shown[0].id, isNot(notifier.shown[1].id));

      notifier.answer(NoticeResponse(notifier.shown[1].id, chosen: true));
      await pumpEventQueue();

      expect(watches.single.reminder, scores);
    });

    test('a system with no notifications: the toast instead, never '
        'nothing', () async {
      notifier.works = false;

      await alerts.show(DueReminder(reminder, startingNow));
      await pumpEventQueue();

      expect(notifier.shown, isEmpty);
      expect(
        toasts.single.message,
        'Starting now · The Harbor Pilot on Blue Water',
      );
      expect(toasts.single.actionLabel, 'Watch');
    });
  });

  group('after a guide refresh', () {
    FollowedReminder moved(Duration by, {required bool worthSaying}) =>
        FollowedReminder(
          reminder,
          ReminderMoved(
            start.add(by),
            start.add(by).add(const Duration(hours: 1)),
            worthSaying: worthSaying,
          ),
        );

    test('a move worth saying is said, with the new time', () async {
      alerts.sayFollowed([
        moved(const Duration(minutes: 15), worthSaying: true),
      ]);
      await pumpEventQueue();

      expect(
        toasts.single.message,
        'The Harbor Pilot moved to 9:45 PM. Your reminder moved with it.',
      );
    });

    test('a move to another day says the day', () async {
      alerts.sayFollowed([moved(const Duration(hours: 3), worthSaying: true)]);
      await pumpEventQueue();

      expect(
        toasts.single.message,
        'The Harbor Pilot moved to Tomorrow, 12:30 AM. Your reminder moved '
        'with it.',
      );
    });

    test(
      'a small move says nothing; a programme that is gone says so once',
      () async {
        alerts.sayFollowed([
          moved(const Duration(minutes: 2), worthSaying: false),
          FollowedReminder(reminder, const ReminderGone()),
        ]);
        await pumpEventQueue();

        expect(
          toasts.single.message,
          'The Harbor Pilot is no longer in the guide. Its reminder was '
          'removed.',
        );
      },
    );
  });

  test('the sentences, in both clocks', () {
    final due = DueReminder(reminder, ReminderTiming.onNow);
    final now = DateTime(2026, 10, 13, 12);

    expect(
      reminderNoticeBody(due, TimeStyle.h12),
      'On now on Blue Water, until 10:30 PM',
    );
    expect(
      reminderToast(due, TimeStyle.h24),
      'On now · The Harbor Pilot on Blue Water, until 22:30',
    );
    expect(reminderWhen(start, now, TimeStyle.h12), 'Tomorrow, 9:30 PM');
    expect(reminderWhen(start, now, TimeStyle.h24), 'Tomorrow, 21:30');
    expect(
      reminderWhen(start, DateTime(2026, 10, 14, 8), TimeStyle.h12),
      'Today, 9:30 PM',
    );
  });

  test('once disposed it says nothing', () async {
    await alerts.dispose();

    await alerts.show(DueReminder(reminder, startingNow));
    alerts.sayFollowed([FollowedReminder(reminder, const ReminderGone())]);
    await pumpEventQueue();

    expect(toasts, isEmpty);
    expect(notifier.shown, isEmpty);
  });
}
