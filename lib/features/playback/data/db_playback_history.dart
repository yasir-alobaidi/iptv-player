import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';

final class DbPlaybackHistory implements PlaybackHistory {
  new(this._db, {this._clock = DateTime.now});

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<Result<void>> recordLive(ChannelItem channel) => Result.guard(
    () => _db.watchHistoryDao.touch(
      UserItemType.live,
      channel.sourceId,
      channel.remoteKey,
      _clock(),
    ),
  );

  @override
  Future<Result<List<String>>> recentLive(String sourceId, {int limit = 20}) =>
      Result.guard(() async {
        final rows = await _db.watchHistoryDao.recent(
          UserItemType.live,
          sourceId,
          limit: limit,
        );
        return [for (final row in rows) row.remoteKey];
      });
}
