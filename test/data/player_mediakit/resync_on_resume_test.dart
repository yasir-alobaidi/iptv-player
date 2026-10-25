import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';

void main() {
  bool resyncs({
    bool started = true,
    bool live = false,
    Duration pausedFor = const Duration(seconds: 5),
  }) => resyncsOnResume(started: started, live: live, pausedFor: pausedFor);

  test('a film or a file paused a second or more starts its sound afresh '
      'with the picture (ADR-054)', () {
    expect(resyncs(), isTrue);
    expect(resyncs(pausedFor: const Duration(seconds: 1)), isTrue);
    expect(resyncs(pausedFor: const Duration(minutes: 40)), isTrue);
  });

  test('a quick pause and play, a live channel, or a file not yet playing '
      'resume as they are', () {
    expect(resyncs(pausedFor: const Duration(milliseconds: 900)), isFalse);
    expect(resyncs(live: true), isFalse);
    expect(resyncs(started: false), isFalse);
  });
}
