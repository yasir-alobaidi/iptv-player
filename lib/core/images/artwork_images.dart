import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

/// Where the app's pictures come from: posters, logos, backdrops, stills
/// (Phase 5 decision 6). Screens ask this for an [ImageProvider] and never
/// learn where the bytes live; `bootstrap()` puts the disk cache behind it
/// (`lib/data/images/`), tests and a bare run get [NetworkArtworkImages].
abstract interface class ArtworkImages {
  /// [url] as a picture about [width] logical pixels wide, decoded at that
  /// width times [devicePixelRatio] (a 2,000 px poster drawn at 170 px
  /// costs a 170 px bitmap); null when [url] can't be a picture.
  ImageProvider? image(
    String? url, {
    double? width,
    double devicePixelRatio = 1,
  });
}

/// Pictures straight from the network, decoded at the size drawn, with no
/// disk cache: what widget tests and the component gallery use.
final class NetworkArtworkImages implements ArtworkImages {
  const new();

  @override
  ImageProvider? image(
    String? url, {
    double? width,
    double devicePixelRatio = 1,
  }) {
    if (fileArtwork(url, width, devicePixelRatio) case final file?) {
      return file;
    }
    if (!isArtworkUrl(url)) return null;
    return decodedAt(NetworkImage(url!), width, devicePixelRatio);
  }
}

/// A picture on this computer as artwork's URL (a library video's frame,
/// a downloaded title's poster, a show folder's): screens pass it to
/// `artworkFor` like any other (Phase 8 step 6).
String localArtworkUrl(String path) => Uri.file(p.absolute(path)).toString();

/// A [localArtworkUrl] read from disk, decoded at the size drawn; null for
/// any other URL. Never through the network cache: the file is already
/// here.
ImageProvider? fileArtwork(
  String? url,
  double? width,
  double devicePixelRatio,
) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || uri.scheme != 'file') return null;
  return decodedAt(FileImage(File(uri.toFilePath())), width, devicePixelRatio);
}

/// Only http(s) URLs can be fetched; a junk icon (`n/a`, `about:blank`,
/// `htp:/…`) is no picture at all, and the stand-in shows at once.
bool isArtworkUrl(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

/// [image] decoded [width] × [devicePixelRatio] pixels wide, never wider
/// than the file.
ImageProvider decodedAt(
  ImageProvider image,
  double? width,
  double devicePixelRatio,
) => ResizeImage.resizeIfNeeded(
  width == null ? null : (width * devicePixelRatio).ceil(),
  null,
  image,
);

/// docs/06's cap on decoded pictures in memory.
const int decodedArtworkBytes = 150 * 1024 * 1024;

/// Caps Flutter's decoded-image cache at [decodedArtworkBytes]. Posters are
/// decoded small, so the count allows far more of them than the default.
void capDecodedImages(ImageCache cache) {
  cache
    ..maximumSizeBytes = decodedArtworkBytes
    ..maximumSize = 3000;
}
