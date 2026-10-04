import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';

/// F on a library item (docs/09: favorites for local files). A download
/// is its title's favorite — a movie's, or an episode's series' — so it
/// stays one whether it plays from the file or the provider; a file of
/// the user's own is a favorite by its quick hash.
final class LibraryFavorites {
  new(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// The quick hashes of the user's own files that are favorites.
  Stream<Set<String>> watchLocalKeys() => _db.favoritesDao.watchLocalKeys();

  Future<bool> isFavorite(LibraryItem item) async {
    final (type, sourceId, key) = _key(item);
    if (sourceId == null) {
      return (await _db.favoritesDao.watchLocalKeys().first).contains(key);
    }
    return (await _db.favoritesDao.watchKeys(type, sourceId).first).contains(
      key,
    );
  }

  Future<void> toggle(LibraryItem item) async {
    final on = !await isFavorite(item);
    final (type, sourceId, key) = _key(item);
    final at = _now().toUtc();
    if (sourceId == null) {
      on
          ? await _db.favoritesDao.addLocal(key, at)
          : await _db.favoritesDao.removeLocal(key);
    } else {
      on
          ? await _db.favoritesDao.add(type, sourceId, key, at)
          : await _db.favoritesDao.remove(type, sourceId, key);
    }
  }

  static (UserItemType, String?, String) _key(LibraryItem item) {
    final link = item.provider;
    if (link != null) {
      switch (link.type) {
        case VodType.movie:
          return (UserItemType.movie, link.sourceId, link.remoteKey);
        case VodType.episode when link.seriesKey != null:
          return (UserItemType.series, link.sourceId, link.seriesKey!);
        case VodType.episode:
          break;
      }
    }
    return (UserItemType.local, null, item.quickHash);
  }
}
