import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/guide/domain/guide_timeline.dart';

void main() {
  // Local times: the axis is laid out on the local clock.
  final now = DateTime(2026, 9, 15, 21, 22);

  group('the axis for a guide', () {
    test('runs from yesterday to the guide end, on half hours', () {
      final timeline = GuideTimeline.forGuide(
        now: now,
        hourWidth: 240,
        firstStart: now.subtract(const Duration(days: 3)),
        lastEnd: DateTime(2026, 9, 20, 23, 50),
      );

      expect(timeline.origin, DateTime(2026, 9, 14, 21));
      expect(timeline.end, DateTime(2026, 9, 21));
      expect(timeline.xOf(timeline.origin), 0);
      expect(timeline.xOf(DateTime(2026, 9, 14, 22, 30)), 360);
    });

    test('starts at the guide first programme when that is later', () {
      final timeline = GuideTimeline.forGuide(
        now: now,
        hourWidth: 240,
        firstStart: DateTime(2026, 9, 15, 6, 10),
      );

      expect(timeline.origin, DateTime(2026, 9, 15, 6));
    });

    test('always holds the view for now and a day after it', () {
      final lateStart = GuideTimeline.forGuide(
        now: now,
        hourWidth: 240,
        firstStart: DateTime(2026, 9, 15, 23),
        lastEnd: DateTime(2026, 9, 15, 22),
      );

      expect(lateStart.origin, DateTime(2026, 9, 15, 20, 30));
      expect(lateStart.end, DateTime(2026, 9, 16, 21, 30));
    });

    test('never reaches further than 15 days ahead', () {
      final timeline = GuideTimeline.forGuide(
        now: now,
        hourWidth: 240,
        lastEnd: now.add(const Duration(days: 60)),
      );

      expect(timeline.end, DateTime(2026, 9, 30, 21, 30));
    });
  });

  test('the view starts the half hour before the one now is in', () {
    expect(GuideTimeline.viewStartFor(now), DateTime(2026, 9, 15, 20, 30));
    expect(
      GuideTimeline.viewStartFor(DateTime(2026, 9, 15, 21)),
      DateTime(2026, 9, 15, 20, 30),
    );
    expect(
      GuideTimeline.viewStartFor(DateTime(2026, 9, 15, 0, 10)),
      DateTime(2026, 9, 14, 23, 30),
    );
  });

  test('pixels and times convert both ways', () {
    final timeline = GuideTimeline(
      origin: DateTime(2026, 9, 15, 20),
      end: DateTime(2026, 9, 16, 2),
      hourWidth: 240,
    );

    expect(timeline.width, 1440);
    expect(timeline.xOf(DateTime(2026, 9, 15, 21, 22)), closeTo(328, 1e-9));
    expect(timeline.timeAt(328), DateTime(2026, 9, 15, 21, 22));
    expect(timeline.durationOf(60), const Duration(minutes: 15));
    expect(timeline.clampX(-10, 400), 0);
    expect(timeline.clampX(5000, 400), 1040);
    expect(timeline.clampX(300, 2000), 0, reason: 'wider than the axis');
  });

  test('ticks fall on every local half hour of the stretch', () {
    final timeline = GuideTimeline(
      origin: DateTime(2026, 9, 15, 20),
      end: DateTime(2026, 9, 16, 2),
      hourWidth: 240,
    );

    expect(
      timeline.ticks(DateTime(2026, 9, 15, 20, 40), DateTime(2026, 9, 15, 22)),
      [
        DateTime(2026, 9, 15, 20, 30),
        DateTime(2026, 9, 15, 21),
        DateTime(2026, 9, 15, 21, 30),
      ],
    );
  });

  test('the days run from today to the axis end', () {
    final timeline = GuideTimeline(
      origin: DateTime(2026, 9, 14, 21),
      end: DateTime(2026, 9, 18, 0, 30),
      hourWidth: 240,
    );

    expect(timeline.days(now), [
      DateTime(2026, 9, 15),
      DateTime(2026, 9, 16),
      DateTime(2026, 9, 17),
      DateTime(2026, 9, 18),
    ]);
  });

  test('half hours, days and a time of day on another day', () {
    expect(
      floorToHalfHour(DateTime(2026, 9, 15, 21, 59, 59)),
      DateTime(2026, 9, 15, 21, 30),
    );
    expect(
      ceilToHalfHour(DateTime(2026, 9, 15, 21, 30)),
      DateTime(2026, 9, 15, 21, 30),
    );
    expect(
      ceilToHalfHour(DateTime(2026, 9, 15, 21, 31)),
      DateTime(2026, 9, 15, 22),
    );
    expect(startOfDay(now), DateTime(2026, 9, 15));
    expect(nextDay(DateTime(2026, 12, 31)), DateTime(2027));
    expect(
      onDay(DateTime(2026, 9, 17), DateTime(2026, 9, 15, 20, 30)),
      DateTime(2026, 9, 17, 20, 30),
    );
  });
}
