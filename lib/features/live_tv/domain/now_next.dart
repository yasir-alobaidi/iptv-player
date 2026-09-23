import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

@immutable
final class Programme {
  const new({
    required this.title,
    required this.start,
    required this.end,
    this.description,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String? description;

  /// 0..1 through the programme at [now].
  double progressAt(DateTime now) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(start).inSeconds / total).clamp(0, 1).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is Programme &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.description == description;

  @override
  int get hashCode => Object.hash(title, start, end, description);
}

/// What's on a channel now and next. Both can be missing.
@immutable
final class NowNext {
  const new({this.now, this.next});

  static const none = NowNext();

  final Programme? now;
  final Programme? next;

  @override
  bool operator ==(Object other) =>
      other is NowNext && other.now == now && other.next == next;

  @override
  int get hashCode => Object.hash(now, next);
}

/// Now and next for the channels on screen: the imported XMLTV guide, with
/// the provider's short EPG behind it (Phase 4 decision 1).
abstract interface class GuideService {
  /// What the last lookup found, without asking again; null while nothing
  /// was looked up for [channel] (or what was has run out).
  NowNext? cached(ChannelItem channel);

  Future<Result<NowNext>> nowNext(ChannelItem channel);

  /// Looks a page of channels up in one go, so [cached] can answer for
  /// every row. A no-op where that would cost a request per channel.
  Future<void> warm(List<ChannelItem> channels);

  /// Fires when answers may be stale (a new guide, new matches): whoever
  /// shows one should ask again.
  Stream<void> get changes;
}
