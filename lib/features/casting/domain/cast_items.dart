import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';

/// What a cast needs of the item it plays.
@immutable
final class CastItemStream {
  const new({
    required this.key,
    required this.info,
    required this.upstream,
    required this.stream,
  });

  /// What its facts are remembered by (Phase 7 decision 4).
  final CastStreamKey key;

  /// What the planner needs to know of its source.
  final CastSourceInfo info;

  /// Its stream for the relay's proxy, built afresh for every connection.
  final CastUpstreamSource upstream;

  /// Its stream as first built, for a direct play (credentials and all:
  /// never logged) and the source's connection limit.
  final ResolvedStream stream;
}

/// The words and the picture the TV shows while it loads and plays
/// (LOAD's metadata).
@immutable
final class CastMetadata {
  const new({required this.title, this.subtitle, this.imageUrl});

  final String title;

  /// The programme on now, a movie's year, a series' name and episode.
  final String? subtitle;

  /// The logo, the poster or the episode's picture, as the provider names
  /// it; the app serves its cached copy to the TV.
  final String? imageUrl;
}

/// Turns what the screens play into what a cast needs: its stream through
/// [StreamResolver] (a URL built from the source on every connection,
/// ADR-009), and its metadata.
final class CastItems {
  new({required this._resolver, this._guide});

  final StreamResolver _resolver;
  final GuideService? _guide;

  Future<Result<CastItemStream>> resolve(Playable item) async {
    final first = await _resolve(item);
    final stream = first.valueOrNull;
    if (stream == null) return Err(first.failureOrNull!);
    return Ok(
      CastItemStream(
        key: keyOf(item),
        stream: stream,
        info: CastSourceInfo(
          sourceId: item.sourceId,
          live: item.live,
          hls: stream.hls,
          customUserAgent: stream.customUserAgent,
          fileExtension: switch (item) {
            PlayableMovie(:final movie) => movie.ext,
            PlayableEpisode(:final episode) => episode.ext,
            PlayableLibraryItem(:final item) => _extension(item.relPath),
            PlayableChannel() => null,
          },
        ),
        upstream: CastUpstreamSource(
          sourceId: item.sourceId,
          live: item.live,
          resolve: () async => switch (await _resolve(item)) {
            Ok(:final value) => Ok(
              CastUpstream(
                url: value.url,
                userAgent: value.userAgent,
                hls: value.hls,
                maxConnections: value.maxConnections,
              ),
            ),
            Err(:final failure) => Err(failure),
          },
        ),
      ),
    );
  }

  /// The provider's stream, also for a title that was downloaded: the
  /// TV reads URLs, and sending it the file comes with Phase 8 step 7.
  Future<Result<ResolvedStream>> _resolve(Playable item) => switch (item) {
    PlayableChannel(:final channel) => _resolver.live(channel),
    PlayableMovie(:final movie) => _resolver.movie(movie, downloaded: false),
    PlayableEpisode(:final episode) => _resolver.episode(
      episode,
      downloaded: false,
    ),
    PlayableLibraryItem() => Future.value(
      Err(InvalidInputFailure("A file from the library can't be cast yet.")),
    ),
  };

  static String? _extension(String relPath) {
    final dot = relPath.lastIndexOf('.');
    return dot < 0 ? null : relPath.substring(dot + 1).toLowerCase();
  }

  /// "201 · Arena Sports 1" and its programme; a movie and its year; an
  /// episode and its series. Never fails: the guide is optional.
  Future<CastMetadata> metadataFor(Playable item) async {
    switch (item) {
      case PlayableChannel(:final channel):
        String? programme;
        if (_guide case final guide?) {
          try {
            programme = (await guide.nowNext(channel)).valueOrNull?.now?.title;
          } on Object {
            programme = null;
          }
        }
        final number = channel.number;
        return CastMetadata(
          title: number == null ? channel.name : '$number · ${channel.name}',
          subtitle: programme,
          imageUrl: channel.logoUrl,
        );
      case PlayableMovie(:final movie):
        return CastMetadata(
          title: movie.name,
          subtitle: movie.year?.toString(),
          imageUrl: movie.posterUrl,
        );
      case PlayableEpisode(:final series, :final episode):
        return CastMetadata(
          title: episode.title,
          subtitle: '${series.name} · S${episode.season} E${episode.episode}',
          imageUrl: episode.stillUrl ?? series.posterUrl,
        );
      case PlayableLibraryItem(:final item):
        return CastMetadata(
          title: item.title,
          subtitle: item.kind == LibraryKind.episode
              ? '${item.showTitle ?? ''} · S${item.season} E${item.episode}'
              : item.year?.toString(),
        );
    }
  }
}

/// What [item]'s facts are remembered by.
CastStreamKey keyOf(Playable item) => switch (item) {
  PlayableChannel(:final channel) => CastStreamKey(
    sourceId: channel.sourceId,
    kind: CastStreamKind.live,
    id: channel.remoteKey,
  ),
  PlayableMovie(:final movie) => CastStreamKey(
    sourceId: movie.sourceId,
    kind: CastStreamKind.movie,
    id: movie.remoteKey,
  ),
  PlayableEpisode(:final episode) => CastStreamKey(
    sourceId: episode.sourceId,
    kind: CastStreamKind.episode,
    id: episode.remoteKey,
  ),
  PlayableLibraryItem(:final item) => CastStreamKey(
    sourceId: '',
    kind: CastStreamKind.libraryFile,
    id: item.quickHash,
  ),
};

/// The file a picture is cached in, for the relay to serve to the TV.
abstract interface class CastPictures {
  /// The local copy of [url], fetched if need be; null when there is none.
  /// Never throws.
  Future<String?> fileFor(String url);
}

/// No pictures (tests, a build without the cache).
final class NoCastPictures implements CastPictures {
  const new();

  @override
  Future<String?> fileFor(String url) async => null;
}
