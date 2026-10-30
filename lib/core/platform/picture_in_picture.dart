import 'dart:async';

import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'picture_in_picture.g.dart';

/// What the full-screen player lets the system do as the app is left
/// (ADR-069): shrink the window to the picture in a corner of the screen,
/// as Home or the home gesture leaves the app.
@immutable
final class PictureInPictureWish {
  const new({this.size, this.pauseButton = false, this.paused = false});

  /// The picture's width and height in pixels, for the small window's
  /// shape (16:9 until it is known; the system keeps it between 1:2.39
  /// and 2.39:1).
  final (int, int)? size;

  /// A file's Play/Pause in the small window (a channel has none).
  final bool pauseButton;

  /// Paused: the button plays.
  final bool paused;

  @override
  bool operator ==(Object other) =>
      other is PictureInPictureWish &&
      other.size == size &&
      other.pauseButton == pauseButton &&
      other.paused == paused;

  @override
  int get hashCode => Object.hash(size, pauseButton, paused);

  @override
  String toString() =>
      'PictureInPictureWish(size: $size, pause button: $pauseButton, '
      'paused: $paused)';
}

/// What the system says of the small window.
sealed class PictureInPictureEvent {
  const new();
}

/// The window shrank to the picture.
final class PictureInPictureEntered extends PictureInPictureEvent {
  const new();
}

/// The window is the app's own size again: the user expanded it.
final class PictureInPictureExpanded extends PictureInPictureEvent {
  const new();
}

/// The user closed the small window: what played is over.
final class PictureInPictureClosed extends PictureInPictureEvent {
  const new();
}

/// The small window's Play/Pause.
final class PictureInPicturePlayPause extends PictureInPictureEvent {
  const new();
}

/// The system's picture-in-picture (Android 8 and later, on a phone, a
/// tablet or a Chromebook; a device without it ignores the wish). Never
/// throws: what can't be asked is logged.
abstract interface class PictureInPicture {
  /// While [wish] is set, leaving the app shrinks it to the picture; null
  /// leaves the app as ever (the player stops while away). Set again as
  /// what plays changes (its shape, a pause).
  Future<void> allow(PictureInPictureWish? wish);

  Stream<PictureInPictureEvent> get events;
}

/// No small window: the desktop, a TV and tests.
final class NoPictureInPicture implements PictureInPicture {
  const new();

  @override
  Future<void> allow(PictureInPictureWish? wish) async {}

  @override
  Stream<PictureInPictureEvent> get events => const Stream.empty();
}

/// `bootstrap()` gives a phone's, a tablet's and a Chromebook's
/// (`AndroidPictureInPicture`).
@Riverpod(keepAlive: true)
PictureInPicture pictureInPicture(Ref ref) => const NoPictureInPicture();

/// Whether the app is the small window now: the player draws the picture
/// alone in it.
@Riverpod(keepAlive: true)
class InPictureInPicture extends _$InPictureInPicture {
  @override
  bool build() {
    final events = ref.watch(pictureInPictureProvider).events.listen((event) {
      switch (event) {
        case PictureInPictureEntered():
          state = true;
        case PictureInPictureExpanded() || PictureInPictureClosed():
          state = false;
        case PictureInPicturePlayPause():
          break;
      }
    });
    ref.onDispose(events.cancel);
    return false;
  }
}
