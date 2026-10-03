import 'dart:async';

/// Who can hold a source's stream connections (hard rule 7).
enum StreamHolder {
  /// The laptop's player.
  player,

  /// A cast: the relay's proxy (its probe and its FFmpeg), or the TV
  /// reading the provider itself (a direct play).
  cast,

  /// Phase 8's downloads, which yield to playback.
  download,
}

/// The stream connections each holder has open at each source, so a
/// one-connection panel never gets a second: whoever opens next waits for
/// the others' to close (docs/03; Phase 7 step 6: local playback, the
/// relay and the TV's direct connection; Phase 8 adds downloads).
final class SourceConnections {
  final _held = <String, Map<StreamHolder, int>>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  /// What [holder] has open at [sourceId] now.
  void set(String sourceId, StreamHolder holder, int open) {
    final holders = _held.putIfAbsent(sourceId, () => {});
    final before = holders[holder] ?? 0;
    if (open > 0) {
      holders[holder] = open;
    } else {
      holders.remove(holder);
      if (holders.isEmpty) _held.remove(sourceId);
    }
    if (before != open && !_changes.isClosed) _changes.add(null);
  }

  /// The connections open at [sourceId], [except] one holder's.
  int held(String sourceId, {StreamHolder? except}) {
    var total = 0;
    (_held[sourceId] ?? const {}).forEach((holder, open) {
      if (holder != except) total += open;
    });
    return total;
  }

  /// Until fewer than [limit] connections other than [holder]'s are open
  /// at [sourceId], or [within] passes. True when there is room.
  Future<bool> room(
    String sourceId, {
    required int limit,
    required StreamHolder holder,
    Duration within = const Duration(seconds: 5),
  }) async {
    bool free() => held(sourceId, except: holder) < limit;
    if (free()) return true;
    final freed = Completer<bool>();
    final timer = Timer(within, () {
      if (!freed.isCompleted) freed.complete(false);
    });
    final listening = _changes.stream.listen((_) {
      if (free() && !freed.isCompleted) freed.complete(true);
    });
    try {
      return await freed.future;
    } finally {
      timer.cancel();
      await listening.cancel();
    }
  }

  Future<void> dispose() => _changes.close();
}
