import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/images/artwork_images.dart';

/// Hands [images] to every screen below it, so any widget can ask for a
/// picture with [artworkFor] — the app root puts the disk cache here; a
/// widget test without one gets [NetworkArtworkImages].
class ArtworkScope extends InheritedWidget {
  const new({required this.images, required super.child, super.key});

  final ArtworkImages images;

  /// Without a dependency: the cache is made once, at launch.
  static ArtworkImages of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ArtworkScope>()?.images ??
      const NetworkArtworkImages();

  @override
  bool updateShouldNotify(ArtworkScope oldWidget) =>
      !identical(oldWidget.images, images);
}

/// [url] as a picture about [width] logical pixels wide, decoded at the
/// screen's pixel density; null when [url] can't be a picture.
ImageProvider? artworkFor(BuildContext context, String? url, {double? width}) =>
    ArtworkScope.of(context).image(
      url,
      width: width,
      devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    );
