import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/m3u/m3u_credentials.dart';
import 'package:iptv_player/data/providers/provider_http.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/stream_urls.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/sources/data/db_source_overview_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// Builds stream URLs from the source and its secrets at play time: the
/// Xtream path from the server and credentials, an M3U line's template
/// filled in from the playlist URL's secrets (docs/02).
final class DbStreamResolver implements StreamResolver {
  new(this._db, this._sources);

  final AppDatabase _db;
  final SourceRepository _sources;

  @override
  Future<Result<ResolvedStream>> live(ChannelItem channel) => _resolve(
    channel.sourceId,
    line: () async {
      final row = await _db.channelsDao.byRemoteKey(
        channel.sourceId,
        channel.remoteKey,
      );
      return (template: row?.streamUrl, extras: row?.extrasJson);
    },
    xtream: (credentials, source) {
      final hls = source.liveFormat == LiveFormat.hls;
      return (
        url: xtreamLiveUrl(
          server: credentials.url,
          username: credentials.username ?? '',
          password: credentials.password ?? '',
          streamId: channel.remoteKey,
          hls: hls,
        ),
        hls: hls,
      );
    },
  );

  @override
  Future<Result<ResolvedStream>> movie(MovieItem movie) => _resolve(
    movie.sourceId,
    line: () async {
      final row = await _db.moviesDao.byRemoteKey(
        movie.sourceId,
        movie.remoteKey,
      );
      return (template: row?.streamUrl, extras: row?.extrasJson);
    },
    xtream: (credentials, _) => (
      url: xtreamMovieUrl(
        server: credentials.url,
        username: credentials.username ?? '',
        password: credentials.password ?? '',
        streamId: movie.remoteKey,
        extension: _extension(movie.ext),
      ),
      hls: false,
    ),
  );

  @override
  Future<Result<ResolvedStream>> episode(EpisodeItem episode) => _resolve(
    episode.sourceId,
    line: () async {
      final row = await _episodeRow(episode);
      return (template: row?.streamUrl, extras: row?.extrasJson);
    },
    xtream: (credentials, _) => (
      url: xtreamEpisodeUrl(
        server: credentials.url,
        username: credentials.username ?? '',
        password: credentials.password ?? '',
        episodeId: episode.remoteKey,
        extension: _extension(episode.ext),
      ),
      hls: false,
    ),
  );

  /// What every stream needs from its source: the credentials, the
  /// connection limit and the User-Agent; [xtream] builds a panel's URL,
  /// [line] reads an M3U line's template and extras.
  Future<Result<ResolvedStream>> _resolve(
    String sourceId, {
    required Future<({String? template, String? extras})> Function() line,
    required ({String url, bool hls}) Function(
      SourceCredentials credentials,
      Source source,
    )
    xtream,
  }) async {
    final found = await _sources.byId(sourceId);
    if (found case Err(:final failure)) return Err(failure);
    final source = found.valueOrNull;
    if (source == null) return Err(NotFoundFailure('source $sourceId'));
    final secrets = await _sources.credentialsFor(source.id);
    if (secrets case Err(:final failure)) return Err(failure);
    final credentials = secrets.valueOrNull!;
    return await Result.guard(() async {
      final row = await line();
      final sourceRow = await _db.sourcesDao.byId(source.id);
      final account = parseStoredAccount(sourceRow?.accountJson);
      final limit =
          source.maxConnectionsOverride ?? account?.maxConnections ?? 1;
      final maxConnections = limit < 1 ? 1 : limit;
      final ownAgent = source.userAgent ?? _userAgent(row.extras);
      final userAgent = ownAgent ?? defaultUserAgent;
      switch (source.type) {
        case SourceType.xtream:
          final (:url, :hls) = xtream(credentials, source);
          return ResolvedStream(
            url: url,
            userAgent: userAgent,
            hls: hls,
            maxConnections: maxConnections,
            customUserAgent: ownAgent != null,
          );
        case SourceType.m3uUrl || SourceType.m3uFile:
          final template = row.template;
          if (template == null) {
            throw const FormatException('this item has no stream URL');
          }
          final url = fillUrl(template, playlistSecrets(credentials.url));
          return ResolvedStream(
            url: url,
            userAgent: userAgent,
            hls: Uri.tryParse(url)?.path.endsWith('.m3u8') ?? false,
            maxConnections: maxConnections,
            customUserAgent: ownAgent != null,
          );
      }
    });
  }

  Future<EpisodeRow?> _episodeRow(EpisodeItem episode) async {
    final series = await _db.seriesDao.byRemoteKey(
      episode.sourceId,
      episode.seriesKey,
    );
    if (series == null) return null;
    return await (_db.select(_db.episodes)..where(
          (e) =>
              e.seriesId.equals(series.id) &
              e.remoteKey.equals(episode.remoteKey),
        ))
        .getSingleOrNull();
  }

  /// A panel always sends `container_extension`; one that didn't most
  /// likely serves MP4.
  static String _extension(String? ext) {
    final trimmed = ext?.trim().toLowerCase();
    return trimmed == null || trimmed.isEmpty ? 'mp4' : trimmed;
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
