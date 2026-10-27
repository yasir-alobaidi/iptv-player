import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/airplay/airplay_events.dart';

void main() {
  // A stand-in for the plist decoder: each body is a key into this table.
  final inner = Uint8List.fromList([2]);
  final plists = <int, Object?>{
    1: {
      'params': {'data': inner},
    },
    2: {
      'type': 'playbackState',
      'params': {'playbackState': 'Playing'},
    },
    3: {'type': 'playbackState', 'name': 'Stopped'},
    4: [1, 2],
  };
  Object? decode(Uint8List bytes) => plists[bytes.first];

  test('an event wrapped in params.data is unwrapped', () {
    final event = eventIn(Uint8List.fromList([1]), decode);
    expect(playbackStateIn(event!), 'playing');
  });

  test("the state from params, else the event's name", () {
    expect(
      playbackStateIn(eventIn(Uint8List.fromList([2]), decode)!),
      'playing',
    );
    expect(
      playbackStateIn(eventIn(Uint8List.fromList([3]), decode)!),
      'stopped',
    );
    expect(playbackStateIn({'type': 'other'}), isNull);
  });

  test('a body that is no plist of a map is no event', () {
    expect(eventIn(Uint8List.fromList([4]), decode), isNull);
    expect(eventIn(Uint8List.fromList([9]), decode), isNull);
  });
}
