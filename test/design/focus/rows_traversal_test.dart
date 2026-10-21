import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/focus/rows_traversal.dart';

/// A form's ↑/↓ (ADR-050): the nearest row that way, then the control
/// closest across.
void main() {
  // Settings → Playback on a TV, roughly: a wide control on the left of
  // its row's right-hand side, narrow switches under it, a wide field.
  const lowLatency = Rect.fromLTRB(1450, 160, 1610, 196);
  const balanced = Rect.fromLTRB(1612, 160, 1720, 196);
  const auto = Rect.fromLTRB(1640, 230, 1710, 266);
  const deinterlaceOff = Rect.fromLTRB(1780, 230, 1850, 266);
  const channelsOff = Rect.fromLTRB(1715, 296, 1780, 332);
  const channelsOn = Rect.fromLTRB(1782, 296, 1850, 332);
  const audio = Rect.fromLTRB(1490, 460, 1850, 508);
  const all = [
    lowLatency,
    balanced,
    auto,
    deinterlaceOff,
    channelsOff,
    channelsOn,
    audio,
  ];
  Rect? next(Rect from, {required bool down}) => nearestInNextRow(
    from,
    all.where((rect) => rect != from),
    (rect) => rect,
    down: down,
  );

  test('down goes to the next row, however narrow its control and wherever '
      'it sits across', () {
    expect(next(lowLatency, down: true), auto);
    expect(next(auto, down: true), channelsOff);
    expect(next(channelsOn, down: true), audio);
  });

  test('in that row, the control closest across', () {
    expect(next(balanced, down: true), auto);
    expect(next(deinterlaceOff, down: true), channelsOn);
    expect(next(audio, down: false), channelsOff);
  });

  test('up goes to the row above; nothing past the first or the last', () {
    expect(next(channelsOff, down: false), deinterlaceOff);
    expect(next(auto, down: false), balanced);
    expect(next(lowLatency, down: false), isNull);
    expect(next(audio, down: true), isNull);
  });

  test('a control in the same row is never a row away', () {
    expect(
      nearestInNextRow(lowLatency, [balanced], (rect) => rect, down: true),
      isNull,
    );
  });
}
