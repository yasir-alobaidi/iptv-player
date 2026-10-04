import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';

void main() {
  group('giving way', _givingWay);

  late SourceConnections connections;

  setUp(() => connections = SourceConnections());
  tearDown(() => connections.dispose());

  test('counted per source and holder', () {
    connections
      ..set('a', StreamHolder.player, 1)
      ..set('a', StreamHolder.cast, 2)
      ..set('b', StreamHolder.download, 1);
    expect(connections.held('a'), 3);
    expect(connections.held('a', except: StreamHolder.cast), 1);
    expect(connections.held('b'), 1);
    expect(connections.held('c'), 0);
    connections.set('a', StreamHolder.cast, 0);
    expect(connections.held('a'), 1);
  });

  test('room at once when there is some', () async {
    connections.set('a', StreamHolder.player, 1);
    expect(
      await connections.room('a', limit: 1, holder: StreamHolder.player),
      isTrue,
      reason: "the player's own doesn't count against it",
    );
    expect(
      await connections.room('a', limit: 2, holder: StreamHolder.cast),
      isTrue,
    );
  });

  test('room once another holder lets go', () async {
    connections.set('a', StreamHolder.cast, 1);
    final waiting = connections.room(
      'a',
      limit: 1,
      holder: StreamHolder.player,
    );
    var answered = false;
    unawaited(waiting.then((_) => answered = true));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(answered, isFalse);
    connections.set('a', StreamHolder.cast, 0);
    expect(await waiting, isTrue);
  });

  test('no room in time: false', () async {
    connections.set('a', StreamHolder.download, 1);
    expect(
      await connections.room(
        'a',
        limit: 1,
        holder: StreamHolder.player,
        within: const Duration(milliseconds: 50),
      ),
      isFalse,
    );
  });
}

void _givingWay() {
  late SourceConnections connections;
  setUp(() => connections = SourceConnections());
  tearDown(() => connections.dispose());

  test('a holder that gives way is asked to let go, and the wait ends as '
      'soon as it has', () async {
    final asked = <String>[];
    connections
      ..giveWay(StreamHolder.download, (source) {
        asked.add(source);
        // Closes on its own time, as a download flushing its file does.
        Timer(const Duration(milliseconds: 20), () {
          connections.set(source, StreamHolder.download, 0);
        });
      })
      ..set('a', StreamHolder.download, 1)
      ..set('b', StreamHolder.download, 1);

    final clock = Stopwatch()..start();
    expect(
      await connections.room('a', limit: 1, holder: StreamHolder.player),
      isTrue,
    );
    expect(clock.elapsed, lessThan(const Duration(seconds: 1)));
    expect(asked, ['a']);
    expect(connections.held('b'), 1);
  });

  test('nobody is asked when there is room, or by the holder itself, or '
      'where it holds nothing', () async {
    final asked = <String>[];
    connections
      ..giveWay(StreamHolder.download, asked.add)
      ..set('a', StreamHolder.download, 1);
    expect(
      await connections.room('a', limit: 2, holder: StreamHolder.player),
      isTrue,
    );
    expect(
      await connections.room(
        'a',
        limit: 1,
        holder: StreamHolder.download,
        within: const Duration(milliseconds: 10),
      ),
      isTrue,
    );
    connections.set('b', StreamHolder.cast, 1);
    expect(
      await connections.room(
        'b',
        limit: 1,
        holder: StreamHolder.player,
        within: const Duration(milliseconds: 10),
      ),
      isFalse,
    );
    expect(asked, isEmpty);
  });

  test('changes tell every count that moved', () async {
    var heard = 0;
    final listening = connections.changes.listen((_) => heard++);
    addTearDown(listening.cancel);
    connections
      ..set('a', StreamHolder.player, 1)
      ..set('a', StreamHolder.player, 1)
      ..set('a', StreamHolder.player, 0);
    expect(heard, 2);
  });
}
