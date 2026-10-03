import 'package:iptv_player/data/images/artwork_cache.dart';
import 'package:iptv_player/features/casting/domain/cast_items.dart';

/// The TV's picture from the artwork cache: a logo or a poster the
/// screens already showed is on disk, and anything else is fetched into
/// it first.
final class ArtworkCastPictures implements CastPictures {
  const new(this._cache);

  final ArtworkCache _cache;

  @override
  Future<String?> fileFor(String url) async {
    try {
      await _cache.bytes(url);
      final file = _cache.fileFor(url);
      return file.existsSync() ? file.path : null;
    } on Object {
      return null;
    }
  }
}
