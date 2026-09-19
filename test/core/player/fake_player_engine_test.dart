import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/player/player_engine.dart';

void main() {
  test('records opens and reports what the test scripts', () async {
    final engine = FakePlayerEngine();
    final events = <PlayerEvent>[];
    engine.events.listen(events.add);

    await engine.open(const PlayRequest(url: 'a'));
    engine
      ..firstFrame()
      ..progress(const Duration(seconds: 1));
    await engine.open(const PlayRequest(url: 'b'));
    engine.fail('boom');

    expect(engine.opened.map((r) => r.url), ['a', 'b']);
    expect(events, [
      isA<PlayerOpening>().having((e) => e.generation, 'generation', 1),
      isA<PlayerFirstFrame>().having((e) => e.generation, 'generation', 1),
      isA<PlayerProgress>(),
      isA<PlayerOpening>().having((e) => e.generation, 'generation', 2),
      isA<PlayerFailed>().having((e) => e.message, 'message', 'boom'),
    ]);
    expect(engine.playing, isFalse);
  });

  test('stop takes as long as the connection takes to close', () async {
    final engine = FakePlayerEngine(
      stopDelay: const Duration(milliseconds: 30),
    );
    await engine.open(const PlayRequest(url: 'a'));
    final watch = Stopwatch()..start();

    await engine.stop();

    expect(
      watch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 30)),
    );
    expect(engine.calls, ['stop']);
    expect(engine.current, isNull);
  });
}
