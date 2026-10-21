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
}
