import 'dart:async';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';

/// Phase 4 decision 1: the imported guide answers for a channel whenever it
/// has a programme on now or next; otherwise (an unmatched channel, or one
/// whose guide has run out) the provider's short EPG does. Screens keep
/// asking one [GuideService] and never learn where an answer came from.
///
/// Warming reaches the imported guide only: the short EPG is a request per
/// channel, asked about the channel someone is looking at and nothing more.
///
/// With the guide switched off ([importedOn] false, ADR-031) the imported
/// guide isn't asked at all: the short EPG answers alone, warming does
/// nothing, and a channel it has no programme for is unknown rather than
/// "no guide", so a row shows its name and nothing under it.
final class CompositeGuide implements GuideService {
  new({
    required this._imported,
    required this._fallback,
    this._importedOn = true,
  });

  final GuideService _imported;
  final GuideService _fallback;
  final _switched = StreamController<void>.broadcast();

  bool _importedOn;

  /// Whether the imported guide is asked (the guide's switch). A change
  /// says every answer may be stale ([changes]), so lists look again.
  bool get importedOn => _importedOn;
  set importedOn(bool on) {
    if (on == _importedOn) return;
    _importedOn = on;
    if (!_switched.isClosed) _switched.add(null);
  }

  /// The imported answer when it has something, else the short EPG's, else
  /// the imported empty answer (so a row can say there is none), else null
  /// (nothing looked up yet).
  @override
  NowNext? cached(ChannelItem channel) {
    if (!_importedOn) {
      final answer = _fallback.cached(channel);
      return answer != null && _hasProgramme(answer) ? answer : null;
    }
    final imported = _imported.cached(channel);
    if (imported != null && _hasProgramme(imported)) return imported;
    return _fallback.cached(channel) ?? imported;
  }

  @override
  Future<Result<NowNext>> nowNext(ChannelItem channel) async {
    if (!_importedOn) return await _fallback.nowNext(channel);
    final imported = await _imported.nowNext(channel);
    if (imported case Ok(:final value) when _hasProgramme(value)) {
      return imported;
    }
    return await _fallback.nowNext(channel);
  }

  @override
  Future<void> warm(List<ChannelItem> channels) async {
    if (_importedOn) await _imported.warm(channels);
  }

  @override
  late final Stream<void> changes = _merged();

  /// Ends [changes]' part that says the switch moved.
  Future<void> dispose() => _switched.close();

  Stream<void> _merged() {
    final subscriptions = <StreamSubscription<void>>[];
    late final StreamController<void> controller;
    controller = StreamController<void>.broadcast(
      onListen: () => subscriptions.addAll([
        for (final changes in [
          _imported.changes,
          _fallback.changes,
          _switched.stream,
        ])
          changes.listen(controller.add),
      ]),
      onCancel: () async {
        final ending = [...subscriptions];
        subscriptions.clear();
        for (final subscription in ending) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  static bool _hasProgramme(NowNext answer) =>
      answer.now != null || answer.next != null;
}
