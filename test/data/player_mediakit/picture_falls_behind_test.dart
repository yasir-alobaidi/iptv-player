import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';

void main() {
  const window = Duration(seconds: 5);
  bool behind(int dropped, double fps) =>
      pictureFallsBehind(dropped: dropped, fps: fps, window: window);

  test('more than 5 % of the frames dropped steps High down (ADR-055)', () {
    // 25 fps for 5 s: 125 frames.
    expect(behind(7, 25), isTrue);
    expect(behind(60, 25), isTrue);
    // 60 fps: 300 frames.
    expect(behind(16, 60), isTrue);
  });

  test('a few frames, or 5 % or less, is the system, not High', () {
    expect(behind(0, 25), isFalse);
    expect(behind(4, 24), isFalse, reason: 'under five');
    expect(behind(6, 25), isFalse, reason: '4.8 %');
    expect(behind(15, 60), isFalse, reason: '5 %');
  });
}
