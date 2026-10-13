import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/reminders/domain/reminder_scheduler.dart';
import 'package:logger/logger.dart';

import 'reminder_fakes.dart';

/// Phase 9 decision 12: a reminder follows its programme through a
/// guide refresh.
void main() {
  final start = DateTime.utc(2026, 10, 14, 21, 30);
  final reminder = Reminder(
    id: 1,
    sourceId: 'src-1',
    channelKey: '212',
    xmltvId: 'bluewater.uk',
    channelName: 'Blue Water',
    title: 'The Harbor Pilot',
    start: start,
    end: start.add(const Duration(hours: 1)),
  );

  ({DateTime start, DateTime end}) showing(
    Duration shift, {
    Duration length = const Duration(hours: 1),
  }) => (start: start.add(shift), end: start.add(shift).add(length));

  group('the rule for one reminder', () {
    test('the programme where it was: kept', () {
      expect(
        followReminder(
          reminder,
          GuideAnswer(showings: [showing(Duration.zero)], covers: true),
        ),
        isA<ReminderKept>(),
      );
    });

    test('moved by a quarter of an hour: the reminder moves, and says so', () {
      final follow = followReminder(
        reminder,
        GuideAnswer(
          showings: [showing(const Duration(minutes: 15))],
          covers: true,
        ),
      ) as ReminderMoved;

      expect(follow.start, start.add(const Duration(minutes: 15)));
      expect(follow.end, start.add(const Duration(minutes: 75)));
      expect(follow.worthSaying, isTrue);
    });

    test('moved by under five minutes: it moves without a word; by exactly '
        'five, it says so', () {
      ReminderMoved moved(Duration by) => followReminder(
        reminder,
        GuideAnswer(showings: [showing(by)], covers: true),
      ) as ReminderMoved;

      expect(moved(const Duration(minutes: 4)).worthSaying, isFalse);
      expect(moved(const Duration(minutes: -3)).worthSaying, isFalse);
      expect(moved(const Duration(minutes: 5)).worthSaying, isTrue);
      expect(moved(const Duration(minutes: -30)).worthSaying, isTrue);
    });

    test('the same start with another end: moved, without a word', () {
      final follow = followReminder(
        reminder,
        GuideAnswer(
          showings: [
            showing(Duration.zero, length: const Duration(minutes: 90)),
          ],
          covers: true,
        ),
      ) as ReminderMoved;

      expect(follow.end, start.add(const Duration(minutes: 90)));
      expect(follow.worthSaying, isFalse);
    });

    test('a daily programme: the showing nearest the reminder is the one', () {
      final follow = followReminder(
        reminder,
        GuideAnswer(
          showings: [
            showing(const Duration(hours: -11)),
            showing(const Duration(minutes: 30)),
            showing(const Duration(hours: 11)),
          ],
          covers: true,
        ),
      ) as ReminderMoved;

      expect(follow.start, start.add(const Duration(minutes: 30)));
    });

    test('not in a guide that covers that time: gone', () {
      expect(
        followReminder(reminder, const GuideAnswer(covers: true)),
        isA<ReminderGone>(),
      );
    });

    test("a guide that doesn't reach that time says nothing: kept. A guide "
        "that is missing isn't a programme that was cancelled", () {
      expect(
        followReminder(reminder, const GuideAnswer()),
        isA<ReminderKept>(),
      );
    });

    test('found only further off than 12 hours: not the same showing', () {
      final far = [showing(const Duration(hours: 13))];

      expect(
        followReminder(reminder, GuideAnswer(showings: far, covers: true)),
        isA<ReminderGone>(),
      );
      expect(
        followReminder(reminder, GuideAnswer(showings: far)),
        isA<ReminderKept>(),
      );
    });
  });

  group("a source's reminders after its guide went live", () {
    late FakeReminders reminders;
    late FakeReminderGuide guide;
    late ReminderFollower follower;

    setUp(() {
      reminders = FakeReminders();
      guide = FakeReminderGuide();
      follower = ReminderFollower(
        reminders: reminders,
        guide: guide,
        log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
      );
    });

    test(
      'one moved, one gone, one kept, and another source left alone',
      () async {
        final pilot = reminders.add(start: start);
        final scores = reminders.add(
          start: start.add(const Duration(hours: 2)),
          title: 'Late Scores',
          channelKey: '204',
          xmltvId: 'courtside.uk',
        );
        final forecast = reminders.add(
          start: start.add(const Duration(hours: 9)),
          title: 'Coastal Forecast',
        );
        final elsewhere = reminders.add(
          start: start,
          title: 'Elsewhere',
          sourceId: 'src-2',
        );
        guide.answers['The Harbor Pilot'] = GuideAnswer(
          showings: [showing(const Duration(minutes: 15))],
          covers: true,
        );
        guide.answers['Late Scores'] = const GuideAnswer(covers: true);

        final changed = await follower.follow('src-1');

        expect(
          [for (final c in changed) (c.before.title, c.outcome.runtimeType)],
          [('The Harbor Pilot', ReminderMoved), ('Late Scores', ReminderGone)],
        );
        final left = reminders.sorted;
        expect(
          left.singleWhere((r) => r.id == pilot.id).start,
          start.add(const Duration(minutes: 15)),
        );
        expect(left.any((r) => r.id == scores.id), isFalse);
        expect(left.any((r) => r.id == forecast.id), isTrue);
        expect(left.any((r) => r.id == elsewhere.id), isTrue);
        expect(guide.asked, isNot(contains(contains('Elsewhere'))));
      },
    );

    test("a guide that can't be read changes nothing", () async {
      reminders.add(start: start);
      guide.failure = StorageFailure('locked');

      expect(await follower.follow('src-1'), isEmpty);
      expect(reminders.sorted, hasLength(1));
    });

    test('a programme that moved onto another reminder of the same channel: '
        'one reminder is left, not two for one programme', () async {
      reminders
        ..add(start: start)
        ..add(start: start.add(const Duration(minutes: 30)));
      guide.answers['The Harbor Pilot'] = GuideAnswer(
        showings: [showing(const Duration(minutes: 30))],
        covers: true,
      );

      await follower.follow('src-1');

      expect(reminders.sorted, hasLength(1));
      expect(
        reminders.sorted.single.start,
        start.add(const Duration(minutes: 30)),
      );
    });
  });
}
