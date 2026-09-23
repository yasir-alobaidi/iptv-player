import 'dart:async';
import 'dart:math' as math;

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';

/// [GuideService] from the imported XMLTV guide: now and next for a page of
/// channels in one indexed query (`EpgRepository.nowNextForChannels`),
/// remembered by channel row id.
///
/// What is remembered never shows a programme that has ended: [cached]
/// reads an answer at the clock's time, so when "now" has ended and
/// "next" has started, next becomes now, and when both have ended the
/// channel is unknown again (null) until it is looked up. [nowNext] asks
/// the database again once the answer it has changes shape.
///
/// When the repository says the guide changed (an import, the matcher),
/// every answer goes stale and [changes] fires: [nowNext] and [warm] ask
/// again, while [cached] keeps showing the last answer until the new one
/// lands, so a list doesn't blink empty between the two.
final class DbGuide implements GuideService {
  new(this._repository, {this._clock = DateTime.now}) {
    _subscription = _repository.watchChanges().listen(
      (_) => _invalidate(),
      onError: (Object _) {},
    );
  }

  final EpgRepository _repository;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _subscription;
  final _changes = StreamController<void>.broadcast();

  /// Insertion-ordered: oldest lookup first, so the cap drops what was
  /// looked up longest ago.
  final _cache = <int, _Entry>{};

  /// Moves on every change the repository reports; an entry looked up
  /// under an older one is stale.
  int _generation = 0;

  /// A page's worth of channels per statement, at most. Far below
  /// SQLite's limit on bound variables, and more than a screen holds.
  static const chunk = 500;

  /// How many channels are remembered: a hundred pages of Live TV, with
  /// their descriptions. Scrolling through 50,000 channels must not keep
  /// every one of them.
  static const maxEntries = 10000;

  @override
  NowNext? cached(ChannelItem channel) =>
      _cache[channel.id]?.answerAt(_clock());

  @override
  Future<Result<NowNext>> nowNext(ChannelItem channel) async {
    final entry = _cache[channel.id];
    final at = _clock();
    if (entry != null && entry.generation == _generation && entry.holdsAt(at)) {
      return Ok(entry.answer);
    }
    final result = await _lookUp([channel.id]);
    return result.map((_) => _cache[channel.id]?.answer ?? NowNext.none);
  }

  @override
  Future<void> warm(List<ChannelItem> channels) async {
    final ids = {for (final channel in channels) channel.id}.toList();
    for (var i = 0; i < ids.length; i += chunk) {
      await _lookUp(ids.sublist(i, math.min(i + chunk, ids.length)));
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }

  /// One statement for [ids]. A failure keeps what was remembered: the
  /// next warm tries again.
  Future<Result<void>> _lookUp(List<int> ids) async {
    final generation = _generation;
    final at = _clock();
    final result = await _repository.nowNextForChannels(ids, at);
    return result.map((found) {
      for (final id in ids) {
        // A lookup from before a change never replaces one from after it.
        if ((_cache[id]?.generation ?? generation) > generation) continue;
        _cache.remove(id);
        _cache[id] = _Entry(
          _nowNext(found[id] ?? EpgNowNext.none),
          fetchedAt: at,
          generation: generation,
        );
      }
      while (_cache.length > maxEntries) {
        _cache.remove(_cache.keys.first);
      }
    });
  }

  void _invalidate() {
    _generation++;
    if (!_changes.isClosed) _changes.add(null);
  }

  static NowNext _nowNext(EpgNowNext found) =>
      NowNext(now: _programme(found.now), next: _programme(found.next));

  static Programme? _programme(EpgProgramme? programme) => programme == null
      ? null
      : Programme(
          title: programme.title,
          start: programme.start,
          end: programme.end,
          description: programme.description,
        );
}

/// One channel's answer as the database gave it at [fetchedAt].
final class _Entry {
  const new(this.answer, {required this.fetchedAt, required this.generation});

  final NowNext answer;
  final DateTime fetchedAt;
  final int generation;

  /// Whether [answer] is still exactly right at [at]: nothing in it has
  /// ended or started since it was fetched.
  bool holdsAt(DateTime at) {
    if (at.isBefore(fetchedAt)) return false;
    final boundary = _boundary;
    return boundary == null || at.isBefore(boundary);
  }

  /// The moment [answer] changes shape: "now" ends, or "next" starts.
  DateTime? get _boundary {
    DateTime? earliest;
    for (final moment in [answer.now?.end, answer.next?.start]) {
      if (moment == null || !moment.isAfter(fetchedAt)) continue;
      if (earliest == null || moment.isBefore(earliest)) earliest = moment;
    }
    return earliest;
  }

  /// [answer] moved on to [at]: what has ended is dropped, a "next" that
  /// has started becomes "now". Null when everything it knew has ended —
  /// unknown, not "no guide": the channel wants looking up again.
  NowNext? answerAt(DateTime at) {
    if (holdsAt(at)) return answer;
    if (answer.now == null && answer.next == null) return answer;
    final left = [
      for (final programme in [answer.now, answer.next])
        if (programme != null && programme.end.isAfter(at)) programme,
    ];
    if (left.isEmpty) return null;
    Programme? now;
    Programme? next;
    for (final programme in left) {
      if (!programme.start.isAfter(at)) {
        now ??= programme;
      } else {
        next ??= programme;
      }
    }
    return NowNext(now: now, next: next);
  }
}
