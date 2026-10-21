import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/playback/presentation/time_corner.dart';

void main() {
  final evening = DateTime(2026, 9, 14, 21, 22);

  group('what the time corner says', () {
    test('the clock as the OSD writes it, 12 or 24 hours', () {
      expect(timeCornerWords(evening, TimeStyle.h12).clock, '9:22 PM');
      expect(timeCornerWords(evening, TimeStyle.h24).clock, '21:22');
    });

    test('the time left, rounded up to the minute: the clock and it add up '
        'to the end', () {
      String? left(Duration d) =>
          timeCornerWords(evening, TimeStyle.h12, left: d).left;

      expect(left(const Duration(hours: 1, minutes: 12)), '1 h 12 min left');
      expect(left(const Duration(minutes: 37, seconds: 1)), '38 min left');
      expect(left(const Duration(minutes: 38)), '38 min left');
      expect(left(const Duration(minutes: 59, seconds: 30)), '1 h left');
      expect(left(const Duration(hours: 2)), '2 h left');
      expect(
        left(const Duration(hours: 2, minutes: 4, seconds: 1)),
        '2 h 5 min left',
      );
      expect(left(const Duration(seconds: 5)), '1 min left');
      expect(left(const Duration(microseconds: 1)), '1 min left');
    });

    test('nothing left, or not known, says nothing', () {
      expect(timeCornerWords(evening, TimeStyle.h12).left, isNull);
      expect(
        timeCornerWords(evening, TimeStyle.h12, left: Duration.zero).left,
        isNull,
      );
      expect(
        timeCornerWords(
          evening,
          TimeStyle.h12,
          left: const Duration(minutes: -3),
        ).left,
        isNull,
        reason: 'a programme the guide has not moved past yet',
      );
    });

    test('the same words are equal: a tick within the minute changes '
        'nothing', () {
      expect(
        timeCornerWords(
          evening,
          TimeStyle.h12,
          left: const Duration(minutes: 37, seconds: 50),
        ),
        timeCornerWords(
          evening.add(const Duration(seconds: 20)),
          TimeStyle.h12,
          left: const Duration(minutes: 37, seconds: 30),
        ),
      );
    });
  });

  group('when the time corner may change', () {
    test("the clock's next minute", () {
      expect(timeCornerWait(evening), const Duration(minutes: 1));
      expect(
        timeCornerWait(evening.add(const Duration(seconds: 20))),
        const Duration(seconds: 40),
      );
      expect(
        timeCornerWait(
          evening.add(const Duration(seconds: 59, milliseconds: 999)),
        ),
        const Duration(milliseconds: 1),
      );
    });

    test("a programme's next whole minute left, when that comes first", () {
      final now = evening.add(const Duration(seconds: 10));
      // Ends on a minute: both turn together.
      expect(
        timeCornerWait(now, end: DateTime(2026, 9, 14, 22)),
        const Duration(seconds: 50),
      );
      // Ends at 21:59:30: its minutes turn at :30.
      expect(
        timeCornerWait(now, end: DateTime(2026, 9, 14, 21, 59, 30)),
        const Duration(seconds: 20),
      );
      // At :40 the clock's minute comes first.
      expect(
        timeCornerWait(now, end: DateTime(2026, 9, 14, 21, 59, 5)),
        const Duration(seconds: 50),
      );
      // Over: the clock alone.
      expect(timeCornerWait(now, end: evening), const Duration(seconds: 50));
    });

    test('never nothing, so a timer on it never spins', () {
      for (var ms = 0; ms < 60000; ms += 250) {
        final now = evening.add(Duration(milliseconds: ms));
        for (final end in [
          DateTime(2026, 9, 14, 22),
          DateTime(2026, 9, 14, 21, 40, 17, 300),
          now,
          now.add(const Duration(minutes: 3)),
        ]) {
          final wait = timeCornerWait(now, end: end);
          expect(wait, greaterThan(Duration.zero));
          expect(wait, lessThanOrEqualTo(const Duration(minutes: 1)));
        }
      }
    });

    test('the words do change when the wait is up, and not before', () {
      final end = DateTime(2026, 9, 14, 21, 59, 30);
      var now = evening.add(const Duration(seconds: 10));
      for (var i = 0; i < 6; i++) {
        final wait = timeCornerWait(now, end: end);
        TimeCornerWords at(DateTime t) =>
            timeCornerWords(t, TimeStyle.h12, left: end.difference(t));
        expect(
          at(now.add(wait - const Duration(microseconds: 1))),
          at(now),
          reason: 'unchanged until $wait after $now',
        );
        expect(at(now.add(wait)), isNot(at(now)), reason: 'changed $wait on');
        now = now.add(wait);
      }
    });
  });
}
