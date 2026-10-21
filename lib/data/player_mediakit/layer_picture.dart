import 'package:flutter/widgets.dart';

/// The picture on its own layer (T1, T2; ADR-045): a hole in the app
/// where it shows, and its place, in physical pixels, told to
/// [onPlaced] whenever this one is on screen and has moved. A channel's
/// preview pane and its full screen are two of these over one layer: the
/// one on top places it, and the preview takes it back when the player
/// closes over it. [child] is drawn over the picture (its subtitles).
/// The layer keeps the screen awake while it shows (MainActivity's
/// VideoLayer), as media_kit's `Video` does on the texture.
class LayerPicture extends StatefulWidget {
  const new({required this.onPlaced, required this.child, super.key});

  final ValueChanged<Rect> onPlaced;
  final Widget child;

  @override
  State<LayerPicture> createState() => _LayerPictureState();
}

class _LayerPictureState extends State<LayerPicture> {
  Rect? _told;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_place);
  }

  /// After every frame drawn while this is mounted (it schedules none of
  /// its own): the layer follows when this one is the one on screen.
  void _place(Duration _) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback(_place);
    // Covered by another destination, or by the player's own page.
    if (!TickerMode.valuesOf(context).enabled) return;
    if (!(ModalRoute.isCurrentOf(context) ?? true)) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final ratio = View.of(context).devicePixelRatio;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero) * ratio,
      box.localToGlobal(box.size.bottomRight(Offset.zero)) * ratio,
    );
    if (rect == _told) return;
    _told = rect;
    widget.onPlaced(rect);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Uncovered again (the player closed over the preview): told anew,
    // since the page on top moved the layer meanwhile.
    if (ModalRoute.isCurrentOf(context) ?? true) _told = null;
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Through whatever the app painted under it (the preview's card):
      // the layer shows here. Its own picture layer, too simple for the
      // raster cache, which would keep the clear to itself.
      const RepaintBoundary(child: CustomPaint(painter: LayerHole())),
      widget.child,
    ],
  );
}

/// Clears what is under it, down to the layer behind the app. Exposed for
/// tests.
class LayerHole extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawRect(Offset.zero & size, Paint()..blendMode = BlendMode.clear);

  @override
  bool shouldRepaint(LayerHole oldDelegate) => false;
}
