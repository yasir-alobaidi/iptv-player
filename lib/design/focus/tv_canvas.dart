import 'package:flutter/widgets.dart';

/// A TV's screen as the app lays it out (ADR-026): [width] logical pixels
/// wide, the height the screen's shape gives, scaled to fill the screen.
///
/// Why: Android gives a 1080p TV 960 × 540, narrower than any window the
/// desktop's layouts were drawn for, so every screen took its narrowest
/// form with desktop-sized parts — four posters a row, one row in view,
/// a Continue watching card half the screen wide (the user: "the sizes of
/// the components all over the app are not … optimized to the screen
/// size"). At 1280 the layouts are the canvas's own; the text is made
/// [textScale] larger with it, to read from across a room.
class TvCanvas extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  /// The canvas's width: the size docs/05's layouts are drawn for.
  static const width = 1280.0;

  /// How much larger text is on a TV, on top of the user's own size.
  static const textScale = 1.2;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    if (screen.width <= 0 || screen.height <= 0 || screen.width >= width) {
      return child;
    }
    final ratio = screen.width / width;
    final canvas = Size(width, screen.height / ratio);
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: canvas,
        child: MediaQuery(
          data: media.copyWith(
            size: canvas,
            devicePixelRatio: media.devicePixelRatio * ratio,
            padding: media.padding / ratio,
            viewPadding: media.viewPadding / ratio,
            viewInsets: media.viewInsets / ratio,
          ),
          child: child,
        ),
      ),
    );
  }
}
