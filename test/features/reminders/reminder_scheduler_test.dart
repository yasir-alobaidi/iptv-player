// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/reminders/domain/reminder_scheduler.dart';
import 'package:logger/logger.dart';

import 'reminder_fakes.dart';

/// Phase 9 decision 10, under fake time: a reminder shows at its
/// programme's start, never twice, and never for a programme that is
/// over.
void main() {
  final launch = DateTime.utc(2026, 10, 14, 20);

  /// Runs [body] with a scheduler over [reminders], the clock at
  /// [launch] and moving with the fake time, plus [skew] (a clock that
  /// was set while the app ran).
  void run(
    void Function(
      FakeAsync async,
      FakeReminders reminders,
      ReminderScheduler scheduler,
      List<DueReminder> shown,
      void Function(Duration) setClock,
    )
    body, {
    Future<void> Function(DueReminder)? onDue,
  }) {
    fakeAsync((async) {
      final reminders = FakeReminders();
      final shown = <DueReminder>[];
      var skew = Duration.zero;
      final scheduler = ReminderScheduler(
        reminders: reminders,
        onDue: (due) async {
          shown.add(due);
          await onDue?.call(due);
        },
        log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
        clock: () => launch.add(async.elapsed).add(skew),
      );
      body(async, reminders, scheduler, shown, (by) => skew = by);
      scheduler.dispose();
      async.flushMicrotasks();
    });
  }

  test('on time: shown at the start, as "starting now", and taken out of '
      'the store', () {
    run((async, reminders, scheduler, shown, _) {
      final reminder = reminders.add(
        start: launch.add(const Duration(minutes: 90)),
      );
      scheduler.start();
      async.elapse(const Duration(minutes: 89, seconds: 59));
      expect(shown, isEmpty);

      async.elapse(const Duration(seconds: 1));

      expect(shown.single.reminder, reminder);
      expect(shown.single.timing, ReminderTiming.startingNow);
      expect(reminders.sorted, isEmpty);
    });
  });

  test('never twice: hours of looking again show nothing more', () {
    run((async, reminders, scheduler, shown, _) {
      reminders.add(start: launch.add(const Duration(minutes: 5)));
      scheduler.start();

      async.elapse(const Duration(hours: 6));

      expect(shown, hasLength(1));
    });
  });

  test('late and still on (the app was closed at the start): shown at '
      'launch as "on now"', () {
    run((async, reminders, scheduler, shown, _) {
      reminders.add(start: launch.subtract(const Duration(minutes: 20)));

      scheduler.start();
      async.flushMicrotasks();

      expect(shown.single.timing, ReminderTiming.onNow);
      expect(reminders.sorted, isEmpty);
    });
  });

  test('late and over: dropped without a word', () {
    run((async, reminders, scheduler, shown, _) {
      reminders.add(start: launch.subtract(const Duration(hours: 3)));

      scheduler.start();
      async.elapse(const Duration(hours: 1));

      expect(shown, isEmpty);
      expect(reminders.sorted, isEmpty);
    });
  });

  test('a sleep across the start: the timer never ran, and the look every '
      'minute shows it once the computer wakes, while it is still on', () {
    run((async, reminders, scheduler, shown, setClock) {
      reminders.add(start: launch.add(const Duration(minutes: 30)));
      scheduler.start();
      async.elapse(const Duration(minutes: 10));

      // Asleep for 40 minutes: no timer fires, the wall clock moves on.
      setClock(const Duration(minutes: 40));
      expect(shown, isEmpty);
      async.elapse(const Duration(minutes: 1));

      expect(shown.single.timing, ReminderTiming.onNow);
    });
  });

  test('a sleep right across a programme: it is over on waking, and '
      'nothing shows', () {
    run((async, reminders, scheduler, shown, setClock) {
      reminders.add(start: launch.add(const Duration(minutes: 30)));
      scheduler.start();
      async.elapse(const Duration(minutes: 10));

      setClock(const Duration(hours: 8));
      async.elapse(const Duration(minutes: 2));

      expect(shown, isEmpty);
      expect(reminders.sorted, isEmpty);
    });
  });

  test('the clock set back: nothing shows early, and it shows when the '
      'start really comes', () {
    run((async, reminders, scheduler, shown, setClock) {
      reminders.add(start: launch.add(const Duration(minutes: 30)));
      scheduler.start();
      async.elapse(const Duration(minutes: 20));

      // Ten minutes to go; the clock is set back an hour.
      setClock(const Duration(hours: -1));
      async.elapse(const Duration(minutes: 30));
      expect(shown, isEmpty, reason: 'the first timer fired early');

      async.elapse(const Duration(minutes: 40));
      expect(shown.single.timing, ReminderTiming.startingNow);
    });
  });

  test('the clock set forward past the start: shown at the next look', () {
    run((async, reminders, scheduler, shown, setClock) {
      reminders.add(start: launch.add(const Duration(hours: 2)));
      scheduler.start();
      async.elapse(const Duration(minutes: 5));

      setClock(const Duration(hours: 2));
      async.elapse(const Duration(minutes: 1));

      expect(shown, hasLength(1));
    });
  });

  test('two at the same minute: both show, each once, the earlier set '
      'first', () {
    run((async, reminders, scheduler, shown, _) {
      final at = launch.add(const Duration(minutes: 10));
      final first = reminders.add(start: at);
      final second = reminders.add(
        start: at,
        title: 'Late Scores',
        channelKey: '204',
      );
      scheduler.start();

      async.elapse(const Duration(minutes: 10));

      expect([for (final due in shown) due.reminder.id], [first.id, second.id]);
      async.elapse(const Duration(hours: 1));
      expect(shown, hasLength(2));
    });
  });

  test('one set while the app runs, sooner than the next: it shows at its '
      'own time', () {
    run((async, reminders, scheduler, shown, _) {
      reminders.add(start: launch.add(const Duration(hours: 5)));
      scheduler.start();
      async.elapse(const Duration(minutes: 1, seconds: 10));

      reminders.add(
        start: launch.add(const Duration(minutes: 3, seconds: 20)),
        title: 'Sooner',
      );
      async.elapse(const Duration(minutes: 2, seconds: 9));
      expect(shown, isEmpty);

      async.elapse(const Duration(seconds: 1));
      expect(shown.single.reminder.title, 'Sooner');
    });
  });

  test('one removed before its start never shows', () {
    run((async, reminders, scheduler, shown, _) {
      final reminder = reminders.add(
        start: launch.add(const Duration(minutes: 10)),
      );
      scheduler.start();
      async.elapse(const Duration(minutes: 5));

      reminders.remove(reminder.id);
      async.elapse(const Duration(hours: 1));

      expect(shown, isEmpty);
    });
  });

  test("a reminder that can't be taken out of the store isn't shown: "
      'better late than twice', () {
    run((async, reminders, scheduler, shown, _) {
      reminders
        ..add(start: launch.add(const Duration(minutes: 1)))
        ..removeFailure = StorageFailure('locked');
      scheduler.start();
      async.elapse(const Duration(minutes: 5));
      expect(shown, isEmpty);

      // The store works again: shown at the next look, still on.
      reminders.removeFailure = null;
      async.elapse(const Duration(minutes: 1));
      expect(shown, hasLength(1));
    });
  });

  test("a list that can't be read is read again at the next look", () {
    run((async, reminders, scheduler, shown, _) {
      reminders
        ..add(start: launch.add(const Duration(seconds: 30)))
        ..readFailure = StorageFailure('locked');
      scheduler.start();
      async.elapse(const Duration(seconds: 59));
      expect(shown, isEmpty);

      reminders.readFailure = null;
      async.elapse(const Duration(seconds: 1));
      expect(shown, hasLength(1));
    });
  });

  test('showing one that throws does not stop the next', () {
    run(
      (async, reminders, scheduler, shown, _) {
        reminders
          ..add(start: launch.add(const Duration(minutes: 1)))
          ..add(
            start: launch.add(const Duration(minutes: 2)),
            title: 'Late Scores',
          );
        scheduler.start();

        async.elapse(const Duration(minutes: 3));

        expect(
          [for (final due in shown) due.reminder.title],
          ['The Harbor Pilot', 'Late Scores'],
        );
      },
      onDue: (due) async {
        if (due.reminder.title == 'The Harbor Pilot') {
          throw StateError('no notification service');
        }
      },
    );
  });

  test('once disposed, nothing shows and no timer is left', () {
    fakeAsync((async) {
      final reminders = FakeReminders()
        ..add(start: launch.add(const Duration(minutes: 1)));
      final shown = <DueReminder>[];
      final scheduler = ReminderScheduler(
        reminders: reminders,
        onDue: shown.add,
        log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
        clock: () => launch.add(async.elapsed),
      )..start();
      async.flushMicrotasks();

      scheduler.dispose();
      async.elapse(const Duration(hours: 1));

      expect(shown, isEmpty);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
