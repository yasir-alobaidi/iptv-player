import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// A picture over its stand-in (docs/05: "image fade-in", "generated tiles
/// for missing logos"): [fallback] shows while [image] loads, when it
/// fails, and when there is none; the picture fades in over it
/// (`motion.fast`), and the stand-in fades out, so a transparent logo never
/// shows the monogram through it. A picture the cache already holds shows
/// at once.
class ArtworkImage extends StatelessWidget {
  const new({
    required this.image,
    required this.fallback,
    this.fit = BoxFit.cover,
    super.key,
  });

  final ImageProvider? image;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) return fallback;
    final motion = context.tokens.motion;
    return Image(
      image: image,
      fit: fit,
      gaplessPlayback: true,
      // Nothing is said about a picture that doesn't come: the stand-in
      // stays, which is all a broken logo needs (docs/05).
      errorBuilder: (context, _, _) => fallback,
      frameBuilder: (context, child, frame, synchronous) {
        if (synchronous) return child;
        final shown = frame != null;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            AnimatedOpacity(
              opacity: shown ? 0 : 1,
              duration: motion.fast,
              curve: motion.fastCurve,
              child: fallback,
            ),
            AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: motion.fast,
              curve: motion.fastCurve,
              child: child,
            ),
          ],
        );
      },
    );
  }
}
