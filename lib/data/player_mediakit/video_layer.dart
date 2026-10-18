import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// The trial of the picture's own layer on Google TV (T1,
/// docs/plans/tv-video-layer-and-frame-rate.md): built only with
/// `--dart-define=BIJOU_VIDEO_LAYER=true` (or `clear`, which also leaves
/// the window without a background), which also turns on MainActivity's
/// transparent Flutter view and its `VideoLayer`.
const _videoLayerBuild = String.fromEnvironment('BIJOU_VIDEO_LAYER');

/// Whether this build has the layer at all.
bool get videoLayerBuilt =>
    Platform.isAndroid &&
    (_videoLayerBuild == 'true' || _videoLayerBuild == 'clear');

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
