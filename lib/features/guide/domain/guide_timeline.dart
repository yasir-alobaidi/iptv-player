import 'package:flutter/foundation.dart';

/// The Guide grid's time axis (docs/05 §5): where a moment sits, in
/// pixels from the left edge of everything the grid can scroll to.
///
/// Times are compared as instants and labelled in local time. Half hours
/// are the local clock's, so a zone half an hour off UTC still gets its
/// ruler on :00 and :30.
@immutable
final class GuideTimeline {
  const new({required this.origin, required this.end, required this.hourWidth});

  /// The axis for a guide whose programmes run from [firstStart] to
  /// [lastEnd], seen at [now]: from the retention window's start
  /// (yesterday, ADR-011 decision 4) or the guide's first programme,
  /// whichever is later, to the guide's last programme. It always holds
  /// the view [viewStartFor] gives for [now] and a day after it, and
  /// never reaches more than [maxAhead] past [now].
  factory forGuide({
    required DateTime now,
    required double hourWidth,
    DateTime? firstStart,
    DateTime? lastEnd,
  }) {
    var from = now.subtract(const Duration(days: 1));
    if (firstStart != null && firstStart.isAfter(from)) from = firstStart;
    final start = viewStartFor(now);
    if (from.isAfter(start)) from = start;
    var to = lastEnd ?? now;
    final soonest = now.add(const Duration(days: 1));
    final latest = now.add(maxAhead);
    if (to.isBefore(soonest)) to = soonest;
    if (to.isAfter(latest)) to = latest;
    return GuideTimeline(
      origin: floorToHalfHour(from),
      end: ceilToHalfHour(to),
      hourWidth: hourWidth,
    );
  }

  /// The furthest ahead the grid scrolls: the longest Keep (14 days) and
  /// a day to spare.
  static const maxAhead = Duration(days: 15);

  static const _halfHour = Duration(minutes: 30);

  /// The leftmost moment the grid shows, on a half hour.
  final DateTime origin;

  /// The rightmost moment, on a half hour.
  final DateTime end;

  final double hourWidth;

  /// The whole axis, in pixels.
  double get width => xOf(end);

  /// Where [at] sits, in pixels from [origin].
  double xOf(DateTime at) =>
      at.difference(origin).inMicroseconds *
      hourWidth /
      Duration.microsecondsPerHour;

  /// The moment at [x] pixels from [origin].
  DateTime timeAt(double x) => origin.add(durationOf(x));

  /// How long [width] pixels last.
  Duration durationOf(double width) => Duration(
    microseconds: (width * Duration.microsecondsPerHour / hourWidth).round(),
  );

  /// Where the view starts to show [at]: the half hour before the one it
  /// falls in, so the now line sits a little way in (canvas: 9:22 →
  /// 8:30).
  static DateTime viewStartFor(DateTime at) =>
      floorToHalfHour(at).subtract(_halfHour);

  /// The half hours from the one [from] falls in up to [to], for the
  /// ruler.
  List<DateTime> ticks(DateTime from, DateTime to) {
    final ticks = <DateTime>[];
    for (
      var tick = floorToHalfHour(from);
      tick.isBefore(to);
      tick = tick.add(_halfHour)
    ) {
      ticks.add(tick);
    }
    return ticks;
  }

  /// The local days the axis reaches, from [now]'s: the Guide's day
  /// pills. Each is the day's local midnight.
  List<DateTime> days(DateTime now) {
    final days = <DateTime>[];
    for (var day = startOfDay(now); day.isBefore(end); day = nextDay(day)) {
      days.add(day);
    }
    return days;
  }

  /// [x] kept inside the axis for a view [viewWidth] pixels wide.
  double clampX(double x, double viewWidth) {
    final max = width - viewWidth;
    if (max <= 0) return 0;
    return x.clamp(0, max).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is GuideTimeline &&
      other.origin == origin &&
      other.end == end &&
      other.hourWidth == hourWidth;

  @override
  int get hashCode => Object.hash(origin, end, hourWidth);
}

/// The local half hour [at] falls in.
DateTime floorToHalfHour(DateTime at) {
  final local = at.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute < 30 ? 0 : 30,
  );
}

/// [at], or the next local half hour when it isn't on one.
DateTime ceilToHalfHour(DateTime at) {
  final floor = floorToHalfHour(at);
  return floor.isBefore(at) ? floor.add(const Duration(minutes: 30)) : floor;
}

/// Local midnight of [at]'s day.
DateTime startOfDay(DateTime at) {
  final local = at.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Local midnight of the day after [day]'s, whatever the clocks do in
/// between (a day can be 23 or 25 hours long).
DateTime nextDay(DateTime day) {
  final local = day.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}

/// [day] at [at]'s local time of day: "Tomorrow" in the Guide shows the
/// same hours as today.
DateTime onDay(DateTime day, DateTime at) {
  final d = day.toLocal();
  final t = at.toLocal();
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}
