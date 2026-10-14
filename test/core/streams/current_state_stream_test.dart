import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/streams/current_state_stream.dart';

void main() {
  late String state;
  late StreamController<String> changes;

  void set(String next) {
    state = next;
    changes.add(next);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    state = 'idle';
    // As the playback coordinator's: listeners are told inside the change.
    changes = StreamController<String>.broadcast(sync: true);
  });

  tearDown(() => changes.close());

  test(
    'says where things are, then where they are after each change',
    () async {
      final heard = <String>[];
      final listening = currentThenChanges(
        () => state,
        changes.stream,
      ).listen(heard.add);
      await settle();
      expect(heard, ['idle']);

      set('opening');
      await settle();
      set('playing');
      await settle();
      expect(heard, ['idle', 'opening', 'playing']);
      await listening.cancel();
    },
  );

  test('a listener that was away is told where things are now, and '
      'nothing of what it missed', () async {
    final heard = <String>[];
    final listening = currentThenChanges(
      () => state,
      changes.stream,
    ).listen(heard.add);
    set('playing');
    await settle();
    heard.clear();

    // The change and the pause in one go: as when the screen that
    // listens leaves because of the change it was just told.
    set('casting');
    listening.pause();
    await settle();
    set('casting, a minute in');
    set('idle');
    set('opening');
    await settle();
    expect(heard, isEmpty, reason: 'nothing while away');

    listening.resume();
    await settle();
    expect(heard, ['opening'], reason: 'where things are, once');

    set('playing');
    await settle();
    expect(heard, ['opening', 'playing']);
    await listening.cancel();
  });

  test('changes made in one go arrive as the last of them', () async {
    final heard = <String>[];
    final listening = currentThenChanges(
      () => state,
      changes.stream,
    ).listen(heard.add);
    await settle();
    heard.clear();

    set('opening');
    set('playing');
    await settle();
    expect(heard, ['playing']);
    await listening.cancel();
  });

  test('a listener is never told inside the change itself', () async {
    final heard = <String>[];
    final listening = currentThenChanges(() => state, changes.stream).listen((
      value,
    ) {
      heard.add(value);
      // Answering a state by changing it must not land inside the
      // change that told it (a synchronous stream would throw).
      if (value == 'failed') set('retrying');
    });
    await settle();
    set('failed');
    expect(heard, ['idle'], reason: 'not yet: the change is still going on');
    await settle();
    await settle();
    expect(heard, ['idle', 'failed', 'retrying']);
    await listening.cancel();
  });

  test('stops listening to the changes when its listener leaves, and ends '
      'when they end', () async {
    final stream = currentThenChanges(() => state, changes.stream);
    final listening = stream.listen((_) {});
    await settle();
    expect(changes.hasListener, isTrue);
    await listening.cancel();
    expect(changes.hasListener, isFalse);

    var done = false;
    currentThenChanges(
      () => state,
      changes.stream,
    ).listen((_) {}, onDone: () => done = true);
    await settle();
    await changes.close();
    await settle();
    expect(done, isTrue);
  });
}
