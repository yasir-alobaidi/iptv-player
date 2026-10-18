import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// The picture's own layer on Google TV (T1, ADR-035 §1,
/// docs/plans/tv-video-layer-and-frame-rate.md): in every TV build since
/// the Bedroom TV's go (the composer draws it itself, a quarter of a core
/// less than the texture, 4K and HDR as they are), with MainActivity's
/// transparent Flutter view and its `VideoLayer`.
/// `--dart-define=BIJOU_VIDEO_LAYER=off` builds the texture instead (to
/// compare, or to fall back), `clear` also leaves the window without a
/// background (Gradle reads the same define).
const _videoLayerBuild = String.fromEnvironment('BIJOU_VIDEO_LAYER');

/// Whether a build made with BIJOU_VIDEO_LAYER=[define] has the layer.
/// Exposed for tests.
bool videoLayerWanted(String define) => define != 'off';

/// Whether this build has the layer at all: a TV build, unless it was
/// built without it.
bool get videoLayerBuilt =>
    Platform.isAndroid && videoLayerWanted(_videoLayerBuild);

/// Whether a play goes on the layer: in T1 a file (a film or an episode,
/// which only ever plays full screen) on Android's direct output, in a
/// build that has it. Channels stay on the texture: their preview pane
/// and full screen share one picture. Exposed for tests.
bool playsOnLayer({
  required bool built,
  required bool direct,
  required bool live,
}) => built && direct && !live;

/// The layer's surface, as mpv takes it.
typedef LayerSurface = ({int wid, int width, int height});

/// MainActivity's `VideoLayer`, over its channel. A missing or broken
/// answer is no surface: the picture then stays on the texture.
final class VideoLayer {
  new({this._channel = const MethodChannel('bijou/video_layer')}) {
    _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;

  /// The surface went (Home took it, or the view was hidden): mpv must
  /// stop drawing into that `wid`.
  void Function(int wid)? onDestroyed;

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'destroyed' && call.arguments is int) {
      onDestroyed?.call(call.arguments as int);
    }
    return null;
  }

  /// Shows the layer and answers with its surface once it exists, or null
  /// when none came within [timeout].
  Future<LayerSurface?> show({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    try {
      final answer = await _channel
          .invokeMapMethod<String, Object?>('show')
          .timeout(timeout);
      return switch (answer) {
        {
          'wid': final int wid,
          'width': final int width,
          'height': final int height,
        }
            when wid != 0 =>
          (wid: wid, width: width, height: height),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  Future<void> hide() async {
    try {
      await _channel.invokeMethod<void>('hide');
    } on Object {
      // Nothing to hide.
    }
  }

  /// Whether the screen stays on: while the film plays, not while it is
  /// paused (as media_kit's `Video` holds its wakelock on the texture).
  /// `show` keeps it on.
  Future<void> keepAwake({required bool awake}) async {
    try {
      await _channel.invokeMethod<void>('keepAwake', awake);
    } on Object {
      // The screen keeps what it had.
    }
  }

  /// Where the picture goes, in the window's physical pixels.
  Future<void> setRect(Rect rect) async {
    try {
      await _channel.invokeMethod<void>('setRect', {
        'left': rect.left.round(),
        'top': rect.top.round(),
        'width': rect.width.round(),
        'height': rect.height.round(),
      });
    } on Object {
      // The picture keeps its last place.
    }
  }

  /// The layer's own account of itself, for the log.
  Future<String?> state() async {
    try {
      return await _channel.invokeMethod<String>('state');
    } on Object {
      return null;
    }
  }
}
