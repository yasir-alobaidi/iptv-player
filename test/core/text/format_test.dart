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
}
