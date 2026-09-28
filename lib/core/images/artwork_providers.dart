import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'artwork_providers.g.dart';

/// Where screens get their pictures. Plain network images unless
/// `bootstrap()` puts the disk cache behind it (Phase 5 decision 6).
@Riverpod(keepAlive: true)
ArtworkImages artworkImages(Ref ref) => const NetworkArtworkImages();
