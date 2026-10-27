import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/playback/presentation/time_corner.dart';

void main() {
  final evening = DateTime(2026, 9, 14, 21, 22);

  test("the corner's clock wakes at its next minute, never at once", () {
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

  group("the OSD's end time", _ends);
}

void _ends() {
  final noon = DateTime(2026, 9, 14, 12);
  const left = Duration(minutes: 55);

  test('a file ends when what is left has played, at its speed (ADR-065)', () {
    expect(osdEndsAt(noon, left, 1), noon.add(left));
    expect(
      osdEndsAt(noon, left, 2),
      noon.add(const Duration(minutes: 27, seconds: 30)),
    );
  });

  test('nothing for a channel, an unknown length, or the last minute', () {
    expect(osdEndsAt(noon, null, 1), isNull);
    expect(osdEndsAt(noon, const Duration(seconds: 59), 1), isNull);
    expect(osdEndsAt(noon, left, 0), isNull);
  });

  test("the end shown stays through the position's and the clock's steps, "
      'and moves for a seek or a new speed', () {
    final shown = noon.add(left);
    // The position a little behind the clock: a second's jitter.
    expect(
      osdEndsAt(noon.add(const Duration(seconds: 1)), left, 1, held: shown),
      shown,
    );
    // Paused for 29 s: still the same; then it moves.
    expect(
      osdEndsAt(noon.add(const Duration(seconds: 29)), left, 1, held: shown),
      shown,
    );
    expect(
      osdEndsAt(noon.add(const Duration(seconds: 31)), left, 1, held: shown),
      noon.add(left + const Duration(seconds: 31)),
    );
    // A seek of 10 minutes back.
    expect(
      osdEndsAt(noon, left + const Duration(minutes: 10), 1, held: shown),
      shown.add(const Duration(minutes: 10)),
    );
  });
}
