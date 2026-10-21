import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

/// The episode after the one playing: a provider's, or the next file of
/// a show of the user's own (Phase 8).
@immutable
final class NextEpisode {
  const new({
    required this.item,
    required this.title,
    this.season,
    this.episode,
    this.duration,
    this.stillUrl,
    this.from,
  });

  factory provider(SeriesItem series, EpisodeItem episode, {Duration? from}) =>
      NextEpisode(
        item: PlayableEpisode(series, episode),
        title: episode.title,
        season: episode.season,
        episode: episode.episode,
        duration: episode.duration,
        stillUrl: episode.stillUrl,
        from: from,
      );

  factory local(LibraryItem file, {Duration? from}) => NextEpisode(
    item: PlayableLibraryItem(file),
    title: file.title,
    season: file.season,
    episode: file.episode,
    duration: file.duration,
    from: from,
  );

  final Playable item;
  final String title;
  final int? season;
  final int? episode;
  final Duration? duration;
  final String? stillUrl;

  /// Where it was left, when it was started and not finished.
  final Duration? from;

  @override
  bool operator ==(Object other) =>
      other is NextEpisode && other.item == item && other.from == from;

  @override
  int get hashCode => Object.hash(item, from);
}

/// What an episode's next-episode card shows (ADR-033): nothing; the
/// count (Next episode · N, Hide); or, at the end after a Hide, Play next
/// episode and Back to series.
enum NextCardPhase { none, count, end }

/// What the full-screen player does around a movie or an episode (Phase 5
/// step 6), apart from the widgets: the seek bar that moves at once while
/// one seek runs when the keys rest, the "Resumed from" line, and an
/// episode's next-episode card (decision 4; ADR-033).
final class VodPlayerController extends ChangeNotifier {
  new({
    required this._coordinator,
    required this._series,
    required this._progress,
    required this._onFinished,
    this._library,
  }) {
    _states = _coordinator.states.listen(_onState);
    _timelines = _coordinator.timelines.listen(_onTimeline);
    _onState(_coordinator.state);
  }

  /// The keys rest this long before the one seek runs, when no key-up
  /// ran it first ([release]).
  static const seekDebounce = Duration(milliseconds: 300);

  /// A seek's bubble stays this long after the seek runs, so a quick
  /// press doesn't blink it.
  static const seekShownFor = Duration(milliseconds: 800);
  static const resumedFor = Duration(seconds: 5);

  /// The card shows with this much of an episode left, counting …
  static const offerAt = Duration(minutes: 1);

  /// … when it is longer than this (a short one's last minute is too much
  /// of it) …
  static const offerLongerThan = Duration(minutes: 4);

  /// … down to this much left, when the next episode plays by itself: the
  /// moment the count of a short one ends too.
  static const playAt = Duration(seconds: 10);

  /// A short episode's card counts with this much left …
  static const nextEpisodeAt = Duration(seconds: 20);

  /// … from this, a second at a time.
  static const countdownFrom = 10;

  final PlaybackCoordinator _coordinator;
  final SeriesRepository _series;
  final WatchProgress _progress;

  /// A show of the user's own: its next file (Phase 8).
  final LibraryRepository? _library;

  /// A movie ended, or an episode with nothing after it: the player goes
  /// back to where it was opened from.
  final void Function(Playable item) _onFinished;

  late final StreamSubscription<PlaybackState> _states;
  late final StreamSubscription<VodTimeline> _timelines;

  Playable? _item;
  Duration? _pending;
  Timer? _seekTimer;
  Timer? _shownTimer;
  Duration? _resumedFrom;
  Timer? _resumedTimer;
  NextEpisode? _next;

  /// A longer episode's count, read off its timeline.
  int? _timelineCount;

  /// A short episode's count, a timer's.
  int? _countdown;

  /// The next episode has been asked for: nothing asks again.
  bool _leaving = false;
  Timer? _countdownTimer;
  bool _hidden = false;
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

  /// Where the keys are taking the bar.
  Duration? get pendingSeek => _pending;

  /// The bubble over the bar: while the keys move it, and
  /// [seekShownFor] after its seek runs.
  bool get showsSeek => _pending != null || _shownTimer != null;

  /// "Resumed from 24:10 · Home starts over", for its first 5 s.
  Duration? get resumedFrom => _resumedFrom;

  /// The episode after this one; null for a movie or the last episode.
  NextEpisode? get next => _next;

  /// The seconds until the next episode plays by itself, while the card
  /// counts (50 … 1, or 10 … 1 for a short episode).
  int? get countdown => _timelineCount ?? _countdown;

  /// What [countdown] counts from: the card's bar is out of it.
  int get countdownLength =>
      _timelineCount != null ? (offerAt - playAt).inSeconds : countdownFrom;

  /// The episode played to its end after its card was hidden: the card
  /// again, without the count.
  bool get ended => _ended;

  /// What the next-episode card shows now.
  NextCardPhase get card => switch (_next) {
    null => NextCardPhase.none,
    _ when _ended => NextCardPhase.end,
    _ when countdown != null => NextCardPhase.count,
    _ => NextCardPhase.none,
  };

  bool get _playing => _coordinator.state is PlaybackPlaying;

  /// Asked for, no picture yet: a resume on a slow panel can take a
  /// while, and the player says so rather than look frozen.
  bool get preparing => _item != null && _coordinator.state is PlaybackOpening;

  /// ←/→ (10 s) and Shift+←/→ (60 s): the bar moves at once; the seek
  /// runs when the key is let go ([release]), or once the keys rest.
  void nudge(Duration delta) {
    if (!_playing) return;
    final base = _pending ?? _coordinator.timeline.position;
    _pending = _clamp(base + delta);
    _seekTimer?.cancel();
    _seekTimer = Timer(seekDebounce, _commitSeek);
    notifyListeners();
  }

  /// The key that moved the bar is let go, or a button's press is done:
  /// its seek runs now, not after the rest (a held key's steps have all
  /// come by then; ADR-048). Nothing waiting, nothing to do.
  void release() => _commitSeek();

  /// A TV remote's ←/→, [repeats] into a hold: a press is 10 s; held, the
  /// steps grow to 30 s after about a second and to a minute after about
  /// three (Android repeats a held key 20 times a second), so the middle
  /// of a two-hour film is a few seconds' hold away.
  static Duration scrubStep(int repeats) => switch (repeats) {
    < 20 => const Duration(seconds: 10),
    < 60 => const Duration(seconds: 30),
    _ => const Duration(minutes: 1),
  };

  /// A TV remote's OK while its keys still move the bar: the seek runs
  /// now, and a paused file plays on from there. False when no seek is
  /// waiting.
  bool seekNow() {
    if (_pending == null) return false;
    final paused = _coordinator.timeline.paused;
    _commitSeek();
    if (paused) unawaited(_coordinator.setPaused(paused: false));
    return true;
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

  /// The card's Next episode, the end card's Play next episode, the row's
  /// Next episode, or the count's end; once. In the credits the episode
  /// left counts as watched, however short it is (a 2-minute episode is
  /// left at 92 %, under [completeAt]).
  void playNext() {
    final next = _next;
    if (next == null || _leaving) return;
    _leaving = true;
    _playNow(next);
  }

  void _playNow(NextEpisode next) {
    _stopCountdown();
    unawaited(
      _coordinator.playVod(next.item, from: next.from, finishedLeaving: true),
    );
    notifyListeners();
  }

  /// The card's Hide, Esc or a remote's Back: no card for the rest of
  /// this episode, which plays to its end, and nothing after it plays by
  /// itself; the end card offers it.
  void hideNext() {
    _hidden = true;
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
    _shownTimer?.cancel();
    _shownTimer = Timer(seekShownFor, () {
      _shownTimer = null;
      notifyListeners();
    });
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
    _shownTimer?.cancel();
    _shownTimer = null;
    _stopCountdown();
    _leaving = false;
    _hidden = false;
    _ended = false;
    _next = null;
    _resumedTimer?.cancel();
    _resumedFrom = item == null ? null : _coordinator.startedFrom;
    if (_resumedFrom != null) {
      _resumedTimer = Timer(resumedFor, _hideResumed);
    }
    switch (item) {
      case PlayableEpisode():
        unawaited(_findNext(item));
      case PlayableLibraryItem(item: final file)
          when file.kind == LibraryKind.episode:
        unawaited(_findNextFile(item, file));
      case _:
        break;
    }
    notifyListeners();
  }

  Future<void> _findNext(PlayableEpisode item) async {
    final found = (await _series.episodeAfter(item.episode)).valueOrNull;
    if (_disposed || _item != item || found == null) return;
    final from = await _resumeAt(found.ref);
    if (_disposed || _item != item) return;
    _next = NextEpisode.provider(item.series, found, from: from);
    notifyListeners();
  }

  Future<void> _findNextFile(Playable item, LibraryItem file) async {
    final found = await _library?.episodeAfter(file);
    if (_disposed || _item != item || found == null) return;
    final from = await _resumeAt(libraryVodRef(found));
    if (_disposed || _item != item) return;
    _next = NextEpisode.local(found, from: from);
    notifyListeners();
  }

  Future<Duration?> _resumeAt(VodRef ref) async {
    final mark = await _progress.watch(ref).first;
    return mark != null && mark.resumable ? mark.position : null;
  }

  void _onTimeline(VodTimeline timeline) {
    final left = timeline.remaining;
    final length = timeline.duration;
    final counting = _countdown != null;
    final credits =
        _next != null &&
        !_hidden &&
        !_ended &&
        !_leaving &&
        _playing &&
        left != null &&
        length != null;
    // A longer episode counts from a minute left, off its own time: a
    // pause holds the count, a seek moves it, seeking back out of the last
    // minute takes the card away (the user, on the TV: "it should show the
    // count down if u won't click anything then u will go to the next").
    if (credits && length > offerLongerThan && left <= offerAt) {
      final seconds = ((left - playAt).inMilliseconds / 1000).ceil();
      if (seconds <= 0) {
        final next = _next!;
        _leaving = true;
        _timelineCount = null;
        // After the coordinator's event, not inside it: the play publishes
        // the next item on the same stream.
        scheduleMicrotask(() {
          if (!_disposed && _next == next) _playNow(next);
        });
        notifyListeners();
        return;
      }
      _timelineCount = seconds;
    } else {
      _timelineCount = null;
    }
    final due =
        credits &&
        length > nextEpisodeAt &&
        length <= offerLongerThan &&
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
    if (_next != null) {
      if (_hidden) {
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
    _timelineCount = null;
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
    _shownTimer?.cancel();
    _resumedTimer?.cancel();
    _countdownTimer?.cancel();
    unawaited(_states.cancel());
    unawaited(_timelines.cancel());
    super.dispose();
  }
}
