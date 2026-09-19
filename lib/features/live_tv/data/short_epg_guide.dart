import 'dart:async';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

/// [GuideService] from Xtream's `get_short_epg` (ADR-010 decision 2): for
/// the channels the screen asks about only, cached for [ttl], one request
/// at a time per source (the client queues them). M3U sources have no
/// short EPG and get [NowNext.none] until the Phase 4 guide.
final class ShortEpgGuide implements GuideService {
  new(
    this._sources, {
    this.ttl = const Duration(minutes: 5),
    this._clock = DateTime.now,
  });

  final SourceRepository _sources;
  final Duration ttl;
  final DateTime Function() _clock;

  final _cache = <(String, String), (DateTime, NowNext)>{};
  final _inFlight = <(String, String), Future<Result<NowNext>>>{};
  final _clients = <String, XtreamClient?>{};

  @override
  NowNext? cached(ChannelItem channel) {
    final entry = _cache[(channel.sourceId, channel.remoteKey)];
    if (entry == null) return null;
    return _clock().difference(entry.$1) < ttl ? entry.$2 : null;
  }

  @override
  Future<Result<NowNext>> nowNext(ChannelItem channel) {
    final hit = cached(channel);
    if (hit != null) return Future.value(Ok(hit));
    final key = (channel.sourceId, channel.remoteKey);
    return _inFlight[key] ??= _fetch(channel)
        .whenComplete(() => _inFlight.remove(key));
  }

  Future<Result<NowNext>> _fetch(ChannelItem channel) async {
    final client = await _client(channel.sourceId);
    if (client == null) return const Ok(NowNext.none);
    final result = await client.shortEpg(channel.remoteKey, limit: 3);
    final entries = result.valueOrNull?.items;
    if (entries == null) return Err(result.failureOrNull!);
    final now = _clock();
    final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));
    Programme? current;
    Programme? next;
    for (final e in sorted) {
      final programme = Programme(
        title: e.title,
        start: e.start,
        end: e.end,
        description: e.description,
      );
      if (!e.start.isAfter(now) && e.end.isAfter(now)) {
        current = programme;
      } else if (e.start.isAfter(now) && next == null) {
        next = programme;
      }
    }
    final found = NowNext(now: current, next: next);
    _cache[(channel.sourceId, channel.remoteKey)] = (now, found);
    return Ok(found);
  }

  Future<XtreamClient?> _client(String sourceId) async {
    if (_clients.containsKey(sourceId)) return _clients[sourceId];
    final source = (await _sources.byId(sourceId)).valueOrNull;
    XtreamClient? client;
    if (source != null && source.type == SourceType.xtream) {
      final credentials = (await _sources.credentialsFor(sourceId)).valueOrNull;
      if (credentials != null) {
        client = XtreamClient(
          server: credentials.url,
          username: credentials.username ?? '',
          password: credentials.password ?? '',
          userAgent: source.userAgent,
          maxAttempts: 1,
        );
      }
    }
    return _clients[sourceId] = client;
  }
}
