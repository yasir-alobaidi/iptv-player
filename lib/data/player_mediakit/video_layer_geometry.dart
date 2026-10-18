import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Where the picture goes on its own layer (T1): [video], the picture's
/// display size (its shape with any Picture size ratio applied), fitted
/// into [box], the picture widget's place on screen in physical pixels,
/// as [fit] says. [BoxFit.contain] (Fit and the ratios) letterboxes or
/// pillarboxes; [BoxFit.cover] (Fill) is larger than the box, which the
/// screen crops; [BoxFit.fill] (Stretch) is the box. Centred, in whole
/// pixels; null when there is nothing to fit.
///
/// The composer scales the decoder's frames to this rect itself: mpv's
/// direct output has no scaler of its own (ADR-025).
Rect? videoLayerRect({
  required Rect box,
  required Size video,
  required BoxFit fit,
}) {
  if (box.isEmpty || video.isEmpty || !box.isFinite) return null;
  final Size size;
  switch (fit) {
    case BoxFit.fill:
      size = box.size;
    case BoxFit.cover:
      final scale = math.max(
        box.width / video.width,
        box.height / video.height,
      );
      size = video * scale;
    case BoxFit.contain ||
        BoxFit.fitWidth ||
        BoxFit.fitHeight ||
        BoxFit.none ||
        BoxFit.scaleDown:
      final scale = math.min(
        box.width / video.width,
        box.height / video.height,
      );
      size = video * scale;
  }
  final placed = Alignment.center.inscribe(size, box);
  final left = placed.left.roundToDouble();
  final top = placed.top.roundToDouble();
  return Rect.fromLTRB(
    left,
    top,
    math.max(left + 1, placed.right.roundToDouble()),
    math.max(top + 1, placed.bottom.roundToDouble()),
  );
}
