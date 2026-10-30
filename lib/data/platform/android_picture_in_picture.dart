import 'dart:async';

import 'package:flutter/services.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/picture_in_picture.dart';

const _tag = 'pip';

/// A phone's, a tablet's or a Chromebook's picture-in-picture (ADR-069),
/// over `MainActivity`'s `bijou/pip` channel (`PictureInPicture.kt`).
///
/// - `allow {on, width, height, pauseButton, paused}` → nothing; the
///   system shrinks the app to the picture as it is left while on.
/// - `changed {inPip, closed}` (to Dart) → the window shrank, came back,
///   or was closed.
/// - `action {name: playPause}` (to Dart) → the small window's button.
///
/// What arrives is read tolerantly, and a failure is logged, never
/// thrown (hard rule 1's spirit).
final class AndroidPictureInPicture implements PictureInPicture {
  new({required this._log, this._channel = const MethodChannel('bijou/pip')}) {
    _channel.setMethodCallHandler(_called);
  }

  final AppLog _log;
  final MethodChannel _channel;
  final _events = StreamController<PictureInPictureEvent>.broadcast();

  @override
  Future<void> allow(PictureInPictureWish? wish) async {
    try {
      await _channel.invokeMethod<void>('allow', {
        'on': wish != null,
        'width': wish?.size?.$1,
        'height': wish?.size?.$2,
        'pauseButton': wish?.pauseButton ?? false,
        'paused': wish?.paused ?? false,
      });
    } on Object catch (error) {
      _log.warning(_tag, "Picture-in-picture couldn't be set: $error");
    }
  }

  @override
  Stream<PictureInPictureEvent> get events => _events.stream;

  Future<Object?> _called(MethodCall call) async {
    if (pictureInPictureEventFrom(call.method, call.arguments)
        case final event?) {
      _log.info(_tag, switch (event) {
        PictureInPictureEntered() => 'The app is the small window',
        PictureInPictureExpanded() => 'The small window was expanded',
        PictureInPictureClosed() => 'The small window was closed',
        PictureInPicturePlayPause() => "The small window's Play/Pause",
      });
      _events.add(event);
    } else {
      _log.info(_tag, "A call that couldn't be read: ${call.method}");
    }
    return null;
  }
}

/// What the activity said; null when it can't be read.
PictureInPictureEvent? pictureInPictureEventFrom(
  String method,
  Object? arguments,
) {
  if (arguments is! Map) return null;
  return switch (method) {
    'changed' => switch ((arguments['inPip'], arguments['closed'])) {
      (true, _) => const PictureInPictureEntered(),
      (false, true) => const PictureInPictureClosed(),
      (false, _) => const PictureInPictureExpanded(),
      _ => null,
    },
    'action' when arguments['name'] == 'playPause' =>
      const PictureInPicturePlayPause(),
    _ => null,
  };
}
