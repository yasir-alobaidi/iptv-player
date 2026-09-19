import 'dart:convert';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/m3u/m3u_credentials.dart';
import 'package:iptv_player/data/providers/provider_http.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/stream_urls.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/sources/data/db_source_overview_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

/// Builds stream URLs from the source and its secrets at play time: the
/// Xtream path from the server and credentials, an M3U line's template
/// filled in from the playlist URL's secrets (docs/02).
final class DbStreamResolver implements StreamResolver {
  new(this._db, this._sources);

  final AppDatabase _db;
  final SourceRepository _sources;

  @override
  Future<Result<ResolvedStream>> live(ChannelItem channel) async {
    final found = await _sources.byId(channel.sourceId);
    if (found case Err(:final failure)) return Err(failure);
    final source = found.valueOrNull;
    if (source == null) {
      return Err(NotFoundFailure('source ${channel.sourceId}'));
    }
    final secrets = await _sources.credentialsFor(source.id);
    if (secrets case Err(:final failure)) return Err(failure);
    final credentials = secrets.valueOrNull!;
    return await Result.guard(() async {
      final row = await _db.channelsDao.byRemoteKey(
        channel.sourceId,
        channel.remoteKey,
      );
      final sourceRow = await _db.sourcesDao.byId(source.id);
      final account = parseStoredAccount(sourceRow?.accountJson);
      final maxConnections =
          source.maxConnectionsOverride ?? account?.maxConnections ?? 1;
      final lineAgent = _userAgent(row?.extrasJson);
      final userAgent = source.userAgent ?? lineAgent ?? defaultUserAgent;
      switch (source.type) {
        case SourceType.xtream:
          final hls = source.liveFormat == LiveFormat.hls;
          return ResolvedStream(
            url: xtreamLiveUrl(
              server: credentials.url,
              username: credentials.username ?? '',
              password: credentials.password ?? '',
              streamId: channel.remoteKey,
              hls: hls,
            ),
            userAgent: userAgent,
            hls: hls,
            maxConnections: maxConnections < 1 ? 1 : maxConnections,
          );
        case SourceType.m3uUrl || SourceType.m3uFile:
          final template = row?.streamUrl;
          if (template == null) {
            throw const FormatException('this channel has no stream URL');
          }
          final url = fillUrl(template, playlistSecrets(credentials.url));
          return ResolvedStream(
            url: url,
            userAgent: userAgent,
            hls: Uri.tryParse(url)?.path.endsWith('.m3u8') ?? false,
            maxConnections: maxConnections < 1 ? 1 : maxConnections,
          );
      }
    });
  }

  static String? _userAgent(String? extrasJson) {
    if (extrasJson == null) return null;
    try {
      final extras = jsonDecode(extrasJson);
      if (extras is Map && extras['user_agent'] is String) {
        return extras['user_agent'] as String;
      }
    } on FormatException {
      // A damaged extras column only loses the line's own User-Agent.
    }
    return null;
  }
}
