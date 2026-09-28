import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';

/// [ArtworkImages] over the app's [ArtworkCache] (Phase 5 decision 6).
final class CachedArtworkImages implements ArtworkImages {
  const new(this._cache);

  final ArtworkCache _cache;

  @override
  ImageProvider? image(
    String? url, {
    double? width,
    double devicePixelRatio = 1,
  }) {
    if (!isArtworkUrl(url)) return null;
    return decodedAt(CachedArtwork(url!, _cache), width, devicePixelRatio);
  }
}

/// One picture from [ArtworkCache]. Flutter's image cache keys it by URL,
/// and [ResizeImage] around it by the size it is decoded at.
@immutable
final class CachedArtwork extends ImageProvider<CachedArtwork> {
  const new(this.url, this._cache);

  final String url;
  final ArtworkCache _cache;

  @override
  Future<CachedArtwork> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    CachedArtwork key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(key, decode),
    scale: 1,
    debugLabel: 'artwork',
  );

  static Future<ui.Codec> _load(
    CachedArtwork key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key._cache.bytes(key.url);
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } on Object {
      // A damaged file: fetched again next time.
      await key._cache.forget(key.url);
      throw const ArtworkUnavailable('does not decode');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CachedArtwork &&
      other.url == url &&
      identical(other._cache, _cache);

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'CachedArtwork(${redact(url)})';
}
