import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/text/format.dart';

void main() {
  test('formatCount groups thousands', () {
    expect(formatCount(0), '0');
    expect(formatCount(999), '999');
    expect(formatCount(1000), '1,000');
    expect(formatCount(12340), '12,340');
    expect(formatCount(1234567), '1,234,567');
    expect(formatCount(-4500), '-4,500');
  });

  test('formatDate is month, day, year', () {
    expect(formatDate(DateTime(2026, 11, 3, 12)), 'Nov 3, 2026');
  });

  test('formatBytes picks a unit', () {
    expect(formatBytes(512), '512 bytes');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(50 * 1024 * 1024), '50.0 MB');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(milliseconds: 400)), '<1 s');
    expect(formatDuration(const Duration(seconds: 42)), '42 s');
    expect(formatDuration(const Duration(seconds: 72)), '1 min 12 s');
    expect(formatDuration(const Duration(minutes: 2)), '2 min');
  });

  test('formatAgo: minutes, hours, then days, then the date', () {
    final now = DateTime(2026, 9, 14, 12);
    String ago(Duration d) => formatAgo(now.subtract(d), now);

    expect(ago(const Duration(seconds: 20)), 'just now');
    expect(ago(const Duration(minutes: 12)), '12 min ago');
    expect(ago(const Duration(hours: 3)), '3 h ago');
    expect(formatAgo(DateTime(2026, 9, 13, 8), now), 'yesterday');
    expect(formatAgo(DateTime(2026, 9, 10, 23), now), '4 days ago');
    expect(formatAgo(DateTime(2026, 8, 30), now), 'on Aug 30, 2026');
    // A clock that runs ahead reads as just now, not "in 5 min".
    expect(formatAgo(now.add(const Duration(minutes: 5)), now), 'just now');
  });

  test('formatShortDate drops the year', () {
    expect(formatShortDate(DateTime(2026, 11, 3, 12)), 'Nov 3');
  });

  test('a runtime: minutes, then hours and minutes', () {
    expect(formatRuntime(const Duration(minutes: 52)), '52 min');
    expect(formatRuntime(const Duration(minutes: 118)), '1 h 58 min');
    expect(formatRuntime(const Duration(minutes: 120)), '2 h');
    expect(formatRuntime(const Duration(seconds: 20)), '1 min');
  });

  test('a position, as players write it', () {
    expect(formatPosition(const Duration(minutes: 24, seconds: 10)), '24:10');
    expect(
      formatPosition(const Duration(hours: 1, minutes: 12, seconds: 40)),
      '1:12:40',
    );
    expect(formatPosition(const Duration(seconds: 5)), '0:05');
    expect(formatPosition(const Duration(seconds: -3)), '0:00');
  });

  group('the clock (Settings → Appearance → Clock)', () {
    final morning = DateTime(2026, 9, 14, 8, 5);
    final noon = DateTime(2026, 9, 14, 12);
    final evening = DateTime(2026, 9, 14, 20);
    final late = DateTime(2026, 9, 14, 22);
    final midnight = DateTime(2026, 9, 15);

    test('12-hour: no leading zero, 12 at noon and midnight', () {
      expect(formatClock(morning, TimeStyle.h12), '8:05 AM');
      expect(formatClock(noon, TimeStyle.h12), '12:00 PM');
      expect(formatClock(midnight, TimeStyle.h12), '12:00 AM');
      expect(formatClockShort(evening, TimeStyle.h12), '8:00');
    });

    test('24-hour: two digits, and nothing to drop from the short form', () {
      expect(formatClock(morning, TimeStyle.h24), '08:05');
      expect(formatClock(evening, TimeStyle.h24), '20:00');
      expect(formatClock(midnight, TimeStyle.h24), '00:00');
      expect(formatClockShort(evening, TimeStyle.h24), '20:00');
    });

    test('a range says AM or PM once when both ends share it', () {
      expect(formatTimeRange(evening, late, TimeStyle.h12), '8:00 – 10:00 PM');
      expect(
        formatTimeRange(morning, evening, TimeStyle.h12),
        '8:05 AM – 8:00 PM',
      );
      expect(
        formatTimeRangeShort(evening, late, TimeStyle.h12),
        '8:00 – 10:00',
      );
    });

    test('a 24-hour range is the two times, whole', () {
      expect(formatTimeRange(evening, late, TimeStyle.h24), '20:00 – 22:00');
      expect(formatTimeRange(morning, evening, TimeStyle.h24), '08:05 – 20:00');
      expect(
        formatTimeRangeShort(evening, late, TimeStyle.h24),
        '20:00 – 22:00',
      );
    });
  });
}
