import 'package:flutter/painting.dart';
import 'package:iptv_player/core/images/artwork_store.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';

/// [ArtworkStore] over the app's [ArtworkCache] and Flutter's cache of
/// decoded images.
final class CachedArtworkStore implements ArtworkStore {
  const new(this._cache);

  final ArtworkCache _cache;

  @override
  Future<Result<ArtworkUsage>> usage() => Result.guard(
    () async => (bytes: await _cache.size(), maxBytes: _cache.maxBytes),
  );

  @override
  Future<Result<void>> clear() => Result.guard(() async {
    await _cache.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });
}
