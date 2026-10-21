import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';

void main() {
  const to = Duration(minutes: 10, seconds: 10);
  bool again(
    Duration position, {
    bool seeking = false,
    bool cacheWait = false,
  }) => seekPlaysAgain(
    to: to,
    position: position,
    seeking: seeking,
    cacheWait: cacheWait,
  );

  test('the clock at the target is not playing again yet: mpv says the '
      'target from the moment a seek starts (ADR-048)', () {
    // Before mpv has even heard of the seek: no "seeking" yet, no cache
    // wait, and the clock already at the target.
    expect(again(to), isFalse);
    expect(again(to + const Duration(microseconds: 400)), isFalse);
  });

  test('a frame or more past the target, done seeking and not waiting for '
      'the cache, plays again', () {
    expect(again(to + const Duration(milliseconds: 42)), isTrue);
    expect(again(to + const Duration(seconds: 1)), isTrue);
  });

  test('still seeking or waiting for the cache is not playing again', () {
    final past = to + const Duration(milliseconds: 42);
    expect(again(past, seeking: true), isFalse);
    expect(again(past, cacheWait: true), isFalse);
  });

  test('the clock far from the target is the old place, not the new', () {
    expect(again(to - const Duration(seconds: 10)), isFalse);
    expect(again(to + const Duration(seconds: 10)), isFalse);
  });
}
