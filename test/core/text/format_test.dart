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
}
