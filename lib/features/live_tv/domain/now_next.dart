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

/// Now and next for the channels on screen (Phase 3: the provider's short
/// EPG, decision 2; Phase 4 puts the XMLTV guide behind it).
abstract interface class GuideService {
  /// What the last lookup found, without asking again.
  NowNext? cached(ChannelItem channel);

  Future<Result<NowNext>> nowNext(ChannelItem channel);
}
