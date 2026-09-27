import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';

/// One channel's row of the Guide grid over a stretch of time.
@immutable
final class GuideRow {
  const new({required this.hasGuide, this.programmes = const []});

  /// False when the guide has nothing at all for the channel: the grid's
  /// dashed "No guide information" row.
  final bool hasGuide;

  /// The programmes overlapping the stretch asked for, in start order.
  final List<EpgProgramme> programmes;
}

/// What the Guide grid has read of the guide (ADR-011 decision 7): the
/// programmes of the channels it was asked about, by channel and by hour,
/// so a screen scrolled back to is drawn without a query.
///
/// The grid asks for the channels on screen plus a screen of margin, and
/// the hours on screen plus one either side; only the (channel, hour)
/// pieces not yet read are queried. One query runs at a time: a request
/// made meanwhile waits, and a newer one replaces it, so scrolling fast
/// never queues screens nobody will see.
///
/// The channels asked about least recently are forgotten past
/// [maxChannels]. A change to the guide (an import, a match) means
/// [reset].
final class GuideWindowCache extends ChangeNotifier {
  new(this._guide, {this.maxChannels = 600});

  final EpgRepository _guide;

  /// How many channels' rows are kept.
  final int maxChannels;

  /// In the order they were last asked about: the first is forgotten
  /// first.
  final _channels = <int, _Channel>{};

  ({List<int> ids, DateTime from, DateTime to})? _waiting;
  var _running = false;
  var _generation = 0;
  var _disposed = false;
  AppFailure? _failure;
  var _queries = 0;

  /// Queries sent to the guide so far (a load is one or two).
  @visibleForTesting
  int get queries => _queries;

  /// How many channels are held.
  @visibleForTesting
  int get channelCount => _channels.length;

  /// Why the last load failed; nothing loads again until [retry].
  AppFailure? get failure => _failure;

  /// [channelId]'s row over `[from, to)`, or null until every hour of it
  /// has been read.
  GuideRow? row(int channelId, DateTime from, DateTime to) {
    final channel = _channels[channelId];
    final hasGuide = channel?.hasGuide;
    if (channel == null || hasGuide == null) return null;
    if (!channel.covers(_hour(from), _hourCeil(to))) return null;
    if (!hasGuide) return const GuideRow(hasGuide: false);
    return GuideRow(hasGuide: true, programmes: channel.overlapping(from, to));
  }

  /// Every programme read for [channelId], in start order; empty when
  /// none has been.
  List<EpgProgramme> known(int channelId) =>
      _channels[channelId]?.sorted ?? const [];

  /// Whether every hour of `[from, to)` has been read for [channelId].
  bool isRead(int channelId, DateTime from, DateTime to) =>
      _channels[channelId]?.covers(_hour(from), _hourCeil(to)) ?? false;

  /// Reads what isn't held yet of [channelIds] over `[from, to)`, and
  /// notifies once it is.
  void request(List<int> channelIds, DateTime from, DateTime to) {
    if (_disposed || channelIds.isEmpty || !from.isBefore(to)) return;
    final first = _hour(from);
    final last = _hourCeil(to);
    final wanted = <int>[];
    int? low;
    int? high;
    for (final id in channelIds) {
      // Asked about again: the last to be forgotten.
      final channel = _channels.remove(id) ?? _Channel();
      _channels[id] = channel;
      var missing = channel.hasGuide == null;
      for (var hour = first; hour < last; hour++) {
        if (channel.hours.contains(hour)) continue;
        missing = true;
        if (low == null || hour < low) low = hour;
        if (high == null || hour > high) high = hour;
      }
      if (missing) wanted.add(id);
    }
    _forget(keep: channelIds.toSet());
    if (wanted.isEmpty) return;
    if (_running || _failure != null) {
      _waiting = (ids: channelIds, from: from, to: to);
      return;
    }
    unawaited(_load(wanted, low ?? first, (high ?? last - 1) + 1));
  }

  /// Forgets everything: the guide changed. A load already running is
  /// ignored when it lands.
  void reset() {
    _generation++;
    _channels.clear();
    _waiting = null;
    _failure = null;
    if (!_disposed) notifyListeners();
  }

  /// After a failure: lets the next [request] load again.
  void retry() {
    if (_failure == null) return;
    _failure = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load(List<int> ids, int firstHour, int endHour) async {
    _running = true;
    final generation = _generation;
    final unknown = [
      for (final id in ids)
        if (_channels[id]?.hasGuide == null) id,
    ];
    final from = DateTime.fromMillisecondsSinceEpoch(
      firstHour * _hourMs,
      isUtc: true,
    );
    final to = DateTime.fromMillisecondsSinceEpoch(
      endHour * _hourMs,
      isUtc: true,
    );
    Result<Set<int>> withGuide = const Ok({});
    if (unknown.isNotEmpty) {
      _queries++;
      withGuide = await _guide.channelsWithGuide(unknown);
    }
    Result<Map<int, List<EpgProgramme>>> window = const Ok({});
    if (withGuide is Ok) {
      _queries++;
      window = await _guide.windowForChannels(ids, from, to);
    }
    _running = false;
    if (_disposed) return;
    if (generation != _generation) {
      _next();
      return;
    }
    switch ((withGuide, window)) {
      case (Ok(value: final guided), Ok(value: final programmes)):
        for (final id in ids) {
          final channel = _channels[id];
          // Forgotten while it loaded.
          if (channel == null) continue;
          if (unknown.contains(id)) channel.hasGuide = guided.contains(id);
          channel.add(programmes[id] ?? const []);
          for (var hour = firstHour; hour < endHour; hour++) {
            channel.hours.add(hour);
          }
        }
        notifyListeners();
        _next();
      case (Err(:final failure), _) || (_, Err(:final failure)):
        _failure = failure;
        _waiting = null;
        notifyListeners();
    }
  }

  void _next() {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null) request(waiting.ids, waiting.from, waiting.to);
  }

  void _forget({required Set<int> keep}) {
    if (_channels.length <= maxChannels) return;
    final drop = <int>[];
    var over = _channels.length - maxChannels;
    for (final id in _channels.keys) {
      if (over == 0) break;
      if (keep.contains(id)) continue;
      drop.add(id);
      over--;
    }
    drop.forEach(_channels.remove);
  }

  static const int _hourMs = Duration.millisecondsPerHour;

  static int _hour(DateTime at) => at.millisecondsSinceEpoch ~/ _hourMs;

  static int _hourCeil(DateTime at) {
    final ms = at.millisecondsSinceEpoch;
    return ms % _hourMs == 0 ? ms ~/ _hourMs : ms ~/ _hourMs + 1;
  }
}

/// One channel's programmes and the hours they were read for.
final class _Channel {
  /// Null until the first load that asked about it lands.
  bool? hasGuide;
  final hours = <int>{};
  final _byId = <int, EpgProgramme>{};
  List<EpgProgramme>? _sorted;

  List<EpgProgramme> get sorted =>
      _sorted ??= (_byId.values.toList()
        ..sort((a, b) => a.start.compareTo(b.start)));

  bool covers(int first, int end) {
    for (var hour = first; hour < end; hour++) {
      if (!hours.contains(hour)) return false;
    }
    return true;
  }

  void add(List<EpgProgramme> programmes) {
    if (programmes.isEmpty) return;
    for (final programme in programmes) {
      _byId[programme.id] = programme;
    }
    _sorted = null;
  }

  /// The programmes overlapping `[from, to)`, in start order.
  List<EpgProgramme> overlapping(DateTime from, DateTime to) {
    final all = sorted;
    // The first that ends after [from]: programmes don't overlap one
    // another, so ends are in start order too.
    var low = 0;
    var high = all.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (all[mid].end.isAfter(from)) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    final found = <EpgProgramme>[];
    for (var i = low; i < all.length && all[i].start.isBefore(to); i++) {
      if (all[i].end.isAfter(from)) found.add(all[i]);
    }
    return found;
  }
}
