import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

/// Where the details pages' data comes from: Xtream's `get_vod_info` and
/// `get_series_info`, asked for one title at a time. An M3U source offers
/// none; its details are what the playlist gave.
abstract interface class TitleDetailsSource {
  Future<bool> offers(String sourceId);

  Future<Result<XtreamMovieInfo>> movie(String sourceId, String remoteKey);

  Future<Result<XtreamSeriesInfo>> series(String sourceId, String remoteKey);
}

/// [TitleDetailsSource] over one [XtreamClient] per source, so a source's
/// requests go one at a time (the client queues them, hard rule 7). They
/// run beside a sync: they are small, and the user is waiting for them
/// (Phase 5 decision 2). The client is made again when the source's
/// server, sign-in or User-Agent changed.
final class XtreamTitleDetails implements TitleDetailsSource {
  new(this._sources, {this.maxAttempts = 2});

  final SourceRepository _sources;

  /// A details page is waited on: one retry for a 429 or 5xx, not three.
  final int maxAttempts;

  final _clients = <String, ({String signature, XtreamClient client})>{};

  @override
  Future<bool> offers(String sourceId) async =>
      (await _sources.byId(sourceId)).valueOrNull?.type == SourceType.xtream;

  @override
  Future<Result<XtreamMovieInfo>> movie(String sourceId, String remoteKey) =>
      _with(sourceId, (client) => client.movieInfo(remoteKey));

  @override
  Future<Result<XtreamSeriesInfo>> series(String sourceId, String remoteKey) =>
      _with(sourceId, (client) => client.seriesInfo(remoteKey));

  Future<Result<T>> _with<T>(
    String sourceId,
    Future<Result<T>> Function(XtreamClient client) call,
  ) async {
    final found = await _sources.byId(sourceId);
    if (found case Err(:final failure)) return Err(failure);
    final source = found.valueOrNull;
    if (source == null || source.type != SourceType.xtream) {
      return Err(NotFoundFailure('no Xtream source $sourceId'));
    }
    final secrets = await _sources.credentialsFor(sourceId);
    if (secrets case Err(:final failure)) return Err(failure);
    final credentials = secrets.valueOrNull!;
    // Kept in memory only, like the client itself: never logged.
    final signature = [
      credentials.url,
      credentials.username,
      credentials.password,
      source.userAgent,
    ].join('\n');
    final kept = _clients[sourceId];
    final client = kept != null && kept.signature == signature
        ? kept.client
        : XtreamClient(
            server: credentials.url,
            username: credentials.username ?? '',
            password: credentials.password ?? '',
            userAgent: source.userAgent,
            maxAttempts: maxAttempts,
          );
    _clients[sourceId] = (signature: signature, client: client);
    return await call(client);
  }
}
