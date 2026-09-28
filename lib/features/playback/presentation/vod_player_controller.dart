import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

/// What the full-screen player does around a movie or an episode (Phase 5
/// step 6), apart from the widgets: the seek bar that moves at once while
/// one seek runs when the keys rest, the "Resumed from" line, and an
/// episode's next-episode card (decision 4).
final class VodPlayerController extends ChangeNotifier {
  new({
    required this._coordinator,
    required this._series,
    required this._progress,
    required this._onFinished,
  }) {
    _states = _coordinator.states.listen(_onState);
    _timelines = _coordinator.timelines.listen(_onTimeline);
    _onState(_coordinator.state);
  }

  /// The keys rest this long before the one seek runs.
  static const seekDebounce = Duration(milliseconds: 300);
  static const resumedFor = Duration(seconds: 5);

  /// The card shows with this much of the episode left …
  static const nextEpisodeAt = Duration(seconds: 20);

  /// … and counts down from this.
  static const countdownFrom = 10;

  final PlaybackCoordinator _coordinator;
  final SeriesRepository _series;
  final WatchProgress _progress;

  /// A movie ended, or an episode with nothing after it: the player goes
  /// back to where it was opened from.
  final void Function(Playable item) _onFinished;

  late final StreamSubscription<PlaybackState> _states;
  late final StreamSubscription<VodTimeline> _timelines;

  Playable? _item;
  Duration? _pending;
  Timer? _seekTimer;
  Duration? _resumedFrom;
  Timer? _resumedTimer;
  EpisodeItem? _next;
  Duration? _nextFrom;
  int? _countdown;
  Timer? _countdownTimer;
  bool _cancelled = false;
  bool _ended = false;
  bool _disposed = false;

  /// The movie or episode shown; null for live.
  Playable? get item => _item;

  /// The coordinator's timeline, with a seek the keys are still moving
  /// shown in its place.
  VodTimeline get timeline {
    final at = _coordinator.timeline;
    final pending = _pending;
    return pending == null
        ? at
        : VodTimeline(
            position: pending,
            duration: at.duration,
            paused: at.paused,
          );
  }

  /// Where the keys are taking the bar; the bubble shows while set.
  Duration? get pendingSeek => _pending;

  /// "Resumed from 24:10 · Home starts over", for its first 5 s.
  Duration? get resumedFrom => _resumedFrom;

  /// The episode after this one; null for a movie or the last episode.
  EpisodeItem? get next => _next;

  /// 10 … 1 while the card counts down.
  int? get countdown => _countdown;

  /// The episode played to its end after its card was cancelled: the card
  /// again, without the count.
  bool get ended => _ended;

  bool get _playing => _coordinator.state is PlaybackPlaying;

  /// Asked for, no picture yet: a resume on a slow panel can take a
  /// while, and the player says so rather than look frozen.
  bool get preparing => _item != null && _coordinator.state is PlaybackOpening;

  /// ←/→ (10 s) and Shift+←/→ (60 s): the bar moves at once.
  void nudge(Duration delta) {
    if (!_playing) return;
    final base = _pending ?? _coordinator.timeline.position;
    _pending = _clamp(base + delta);
    _seekTimer?.cancel();
    _seekTimer = Timer(seekDebounce, _commitSeek);
    notifyListeners();
  }

  /// The seek bar dragged: the bar follows; [commit] runs the seek.
  void dragTo(Duration position, {bool commit = false}) {
    if (!_playing) return;
    _pending = _clamp(position);
    _seekTimer?.cancel();
    if (commit) {
      _commitSeek();
    } else {
      notifyListeners();
    }
  }

  /// Home: the start, at once.
  void startOver() {
    _seekTimer?.cancel();
    _pending = null;
    _hideResumed();
    unawaited(_coordinator.seek(Duration.zero));
    notifyListeners();
  }

  void togglePause() =>
      unawaited(_coordinator.setPaused(paused: !_coordinator.timeline.paused));

  /// Play now, or the end card's Play next episode.
  void playNext() {
    final item = _item;
    final next = _next;
    if (item is! PlayableEpisode || next == null) return;
    _stopCountdown();
    unawaited(
      _coordinator.playVod(PlayableEpisode(item.series, next), from: _nextFrom),
    );
  }

  /// Esc on the card: this episode plays to its end.
  void cancelNext() {
    _cancelled = true;
    _stopCountdown();
    notifyListeners();
  }

  void _commitSeek() {
    _seekTimer?.cancel();
    final target = _pending;
    if (target == null) return;
    _hideResumed();
    // The coordinator's timeline is at the target before this returns.
    unawaited(_coordinator.seek(target));
    _pending = null;
    notifyListeners();
  }

  Duration _clamp(Duration position) {
    final length = _coordinator.timeline.duration;
    if (position < Duration.zero) return Duration.zero;
    if (length != null && position > length) return length;
    return position;
  }

  void _onState(PlaybackState state) {
    final item = state.item;
    if (item != null && item.live) {
      _reset(null);
      return;
    }
    if (item != _item && item != null) _reset(item);
    notifyListeners();
    if (state is PlaybackEnded && item != null) {
      // Not while the coordinator is still telling its listeners: what
      // comes next starts a new state of its own.
      scheduleMicrotask(() {
        if (!_disposed && _coordinator.state == state) _onEnded(item);
      });
    }
  }

  /// A new movie or episode: nothing carried over from the last one.
  void _reset(Playable? item) {
    if (item == _item) return;
    _item = item;
    _seekTimer?.cancel();
    _pending = null;
    _stopCountdown();
    _cancelled = false;
    _ended = false;
    _next = null;
    _nextFrom = null;
    _resumedTimer?.cancel();
    _resumedFrom = item == null ? null : _coordinator.startedFrom;
    if (_resumedFrom != null) {
      _resumedTimer = Timer(resumedFor, _hideResumed);
    }
    if (item is PlayableEpisode) unawaited(_findNext(item));
    notifyListeners();
  }

  Future<void> _findNext(PlayableEpisode item) async {
    final found = (await _series.episodeAfter(item.episode)).valueOrNull;
    if (_disposed || _item != item || found == null) return;
    final mark = await _progress.watch(found.ref).first;
    if (_disposed || _item != item) return;
    _next = found;
    _nextFrom = mark != null && mark.resumable ? mark.position : null;
    notifyListeners();
  }

  void _onTimeline(VodTimeline timeline) {
    final left = timeline.remaining;
    final counting = _countdown != null;
    final due =
        _next != null &&
        !_cancelled &&
        !_ended &&
        _playing &&
        left != null &&
        timeline.duration! > nextEpisodeAt &&
        left <= nextEpisodeAt;
    if (due && !counting) {
      _countdown = countdownFrom;
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), _tick);
    } else if (!due && counting) {
      // Seeked back out of the credits.
      _stopCountdown();
    }
    notifyListeners();
  }

  void _tick(Timer timer) {
    // A paused picture holds the count.
    if (_coordinator.timeline.paused) return;
    final left = (_countdown ?? 1) - 1;
    if (left <= 0) {
      playNext();
      return;
    }
    _countdown = left;
    notifyListeners();
  }

  void _onEnded(Playable item) {
    if (item is PlayableEpisode && _next != null) {
      if (_cancelled) {
        _ended = true;
        notifyListeners();
      } else {
        playNext();
      }
      return;
    }
    _onFinished(item);
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdown = null;
  }

  void _hideResumed() {
    _resumedTimer?.cancel();
    if (_resumedFrom == null) return;
    _resumedFrom = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _seekTimer?.cancel();
    _resumedTimer?.cancel();
    _countdownTimer?.cancel();
    unawaited(_states.cancel());
    unawaited(_timelines.cancel());
    super.dispose();
  }
}
