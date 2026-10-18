import 'dart:async';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

const _tag = 'display';

/// The frame rates matched: a film's 23.976 and 24 fps (docs/plans/
/// tv-video-layer-and-frame-rate.md, item 2). The Bedroom TV has no 25 or
/// 50 Hz mode, and 29.97, 30, 59.94 and 60 already divide its 59.94/60.
const filmRateLow = 23.9;
const filmRateHigh = 24.1;

/// How near a mode's rate has to be to the film's: 23.976 and 24 are
/// different modes, 0.024 Hz apart.
const rateTolerance = 0.01;

/// A film or an episode at least this long has its rate matched; a
/// trailer or a clip plays on the display as it is.
const matchedLength = Duration(minutes: 15);

/// What [pickDisplayMode] found.
sealed class DisplayModePick {
  const new();
}

/// The display should switch to [mode].
final class SwitchDisplayMode extends DisplayModePick {
  const new(this.mode);

  final DisplayMode mode;
}

/// The display is at the film's rate already, in [mode].
final class DisplayModeMatches extends DisplayModePick {
  const new(this.mode);

  final DisplayMode mode;
}

/// No mode to switch to; [reason] says why, for the log.
final class NoDisplayMode extends DisplayModePick {
  const new(this.reason);

  /// "25 fps is not 23.976 or 24", "no 24 Hz mode at 1280x720".
  final String reason;
}

/// The mode a film at [fps] plays on: one at the display's current size
/// whose rate is within [rateTolerance] of a 23.976 or 24 fps film's.
DisplayModePick pickDisplayMode(DisplayFacts display, double? fps) {
  if (fps == null || fps.isNaN || fps <= 0) {
    return const NoDisplayMode("the film's frame rate isn't known");
  }
  if (fps < filmRateLow || fps > filmRateHigh) {
    return NoDisplayMode('${formatRate(fps)} fps is not 23.976 or 24');
  }
  final current = display.current;
  if (current == null) {
    return const NoDisplayMode("the display's mode isn't known");
  }
  double off(DisplayMode mode) => (mode.refreshRate - fps).abs();
  if (off(current) <= rateTolerance) return DisplayModeMatches(current);
  DisplayMode? best;
  for (final mode in display.modes) {
    if (!mode.sameSize(current) || off(mode) > rateTolerance) continue;
    if (best == null || off(mode) < off(best)) best = mode;
  }
  if (best == null) {
    return NoDisplayMode(
      'no ${formatRate(fps)} Hz mode at ${current.width}x${current.height}',
    );
  }
  return SwitchDisplayMode(best);
}

/// Why the TV's own Match content frame rate setting refuses a switch to
/// [target], or null when it allows it: Never never does, Seamless only
/// only to a rate the current mode reaches without the screen going dark
/// (on the Bedroom TV, none: every mode is its own group).
String? tvRefuses(DisplayFacts display, DisplayMode target) {
  switch (display.matchContentFrameRate) {
    case MatchContentFrameRate.never:
      return "the TV's Match content frame rate is Never";
    case MatchContentFrameRate.seamlessOnly:
      final seamless = display.alternativeRefreshRates.any(
        (rate) => (rate - target.refreshRate).abs() <= rateTolerance,
      );
      if (seamless) return null;
      final from = display.current?.refreshRate;
      return "the TV's Match content frame rate is Seamless only, and "
          "${formatRate(target.refreshRate)} Hz isn't seamless"
          '${from == null ? '' : ' from ${formatRate(from)} Hz'}';
    case MatchContentFrameRate.always || MatchContentFrameRate.unknown:
      return null;
  }
}

/// A TV's Match frame rate: a film at 23.976 or 24 fps moves the display
/// to its rate as part of its open, and the display goes back to the
/// TV's own mode when nothing needs it.
///
/// The coordinator tells it of every state ([playbackChanged]) and asks
/// it at a file's first frame ([beforeFilePlays]). A switch pauses the
/// player, asks the window for the mode, waits for the display to say it
/// changed ([changeTimeout] at most), then [settle]s; anything that fails
/// or takes too long ends it, and the film plays on at the mode the
/// display has. It never throws.
final class FrameRateMatcher {
  new({
    required this._display,
    required this._log,
    DateTime Function()? clock,
    this.changeTimeout = const Duration(seconds: 5),
    this.settle = const Duration(milliseconds: 1500),
    this.grace = const Duration(seconds: 2),
    this.callTimeout = const Duration(seconds: 2),
  }) : _clock = clock ?? DateTime.now {
    _changes = _display.changes.listen(_changed);
  }

  final DisplayModes _display;
  final AppLog _log;
  final DateTime Function() _clock;

  /// The most a switch waits for the display to say it changed.
  final Duration changeTimeout;

  /// After the change, before the film plays: the TV's picture and sound
  /// come back a moment after the display reports the new mode.
  final Duration settle;

  /// How long the mode is kept after the player closes, so a next file
  /// at the same rate doesn't make the screen go dark twice.
  final Duration grace;

  /// The most any one call to the display or the player may take.
  final Duration callTimeout;

  late final StreamSubscription<DisplayMode> _changes;

  /// The mode asked for; null when none is (the TV's own).
  int? _requested;

  /// The display's mode before the first request: what going back
  /// returns to.
  DisplayMode? _own;

  /// The display's mode, as last read or reported.
  DisplayMode? _shown;

  /// A mode asked for that the display didn't switch to: not waited for
  /// again until the display shows it.
  int? _unanswered;

  /// The TV's own mode asked back, and when: logged when the display
  /// shows it.
  ({DisplayMode own, DateTime asked})? _returning;

  _Attempt? _attempt;
  Timer? _release;
  bool _disposed = false;

  /// Whether there is a display to match: a TV's, not the desktop's.
  bool get available => !_disposed && _display.available;

  /// A file's first frame, before it plays (the coordinator still says
  /// "Preparing…"). [enabled] is Settings → Playback → Match frame rate;
  /// [length] the file's; [fps] reads its rate; [pause] pauses the
  /// player. Completes when the file may play: at once when the display
  /// stays as it is, after the switch (or what ended it) otherwise.
  ///
  /// True when it paused the player: the caller plays it again, if what
  /// it paused is still what plays.
  Future<bool> beforeFilePlays({
    required bool enabled,
    required Duration? length,
    required Future<double?> Function() fps,
    required Future<void> Function() pause,
  }) async {
    if (!available) return false;
    _cancelRelease();
    _attempt?.end();
    final attempt = _attempt = _Attempt();
    try {
      await _prepare(
        attempt,
        enabled: enabled,
        length: length,
        fps: fps,
        pause: pause,
      );
    } on Object catch (error) {
      _log.warning(_tag, 'Match frame rate failed, playing on: $error');
    } finally {
      if (identical(_attempt, attempt)) _attempt = null;
      attempt.end();
    }
    return attempt.paused;
  }

  Future<void> _prepare(
    _Attempt attempt, {
    required bool enabled,
    required Duration? length,
    required Future<double?> Function() fps,
    required Future<void> Function() pause,
  }) async {
    final skip = !enabled
        ? 'Match frame rate is off'
        : length == null || length <= Duration.zero
        ? "the film's length isn't known"
        : length < matchedLength
        ? 'shorter than 15 minutes'
        : null;
    if (skip != null) {
      _log.info(_tag, 'Display mode left as it is: $skip');
      if (_requested == null) return;
      final display = await _bounded(_display.read);
      if (attempt.over) return;
      await _back(attempt, display?.current, pause, why: skip);
      return;
    }
    final display = await _bounded(_display.read);
    if (attempt.over) return;
    if (display == null) {
      _log.info(
        _tag,
        "Display mode left as it is: the display's modes couldn't be read",
      );
      _backToOwn("the display's modes couldn't be read");
      return;
    }
    if (display.current case final current?) _shown = current;
    final rate = await _bounded(fps);
    if (attempt.over) return;
    final film = rate == null ? '' : ' for a ${formatRate(rate)} fps film';
    switch (pickDisplayMode(display, rate)) {
      case DisplayModeMatches(:final mode):
        final kept = _requested == null ? 'already' : 'kept at';
        _log.info(_tag, 'Display mode $kept ${mode.logLabel}$film');
      case NoDisplayMode(:final reason):
        _left(display, reason);
        await _back(attempt, display.current, pause, why: reason);
      case SwitchDisplayMode(:final mode):
        if (tvRefuses(display, mode) case final refusal?) {
          _left(display, refusal);
          await _back(attempt, display.current, pause, why: refusal);
          return;
        }
        if (mode.id == _unanswered) {
          _left(display, "the display didn't switch to it before");
          return;
        }
        final from = display.current!;
        if (_requested == null) _own = from;
        await _move(
          attempt,
          ask: mode.id,
          to: mode,
          from: from,
          pause,
          "$film; the TV's Match content frame rate: "
          '${display.matchContentFrameRate.label}'
          '${display.apiLevel == null ? '' : ' (API ${display.apiLevel})'}',
          what: film,
        );
    }
  }

  void _left(DisplayFacts display, String reason) => _log.info(
    _tag,
    'Display mode left at ${display.current?.logLabel ?? 'its mode'}: '
    '$reason',
  );

  /// A file that isn't matched while a mode is still asked for (a
  /// trailer after a film, the switch turned off): the TV's own mode
  /// comes back as part of its open, so it doesn't start in the dark.
  Future<void> _back(
    _Attempt attempt,
    DisplayMode? current,
    Future<void> Function() pause, {
    required String why,
  }) async {
    if (_requested == null) return;
    final own = _own;
    final from = current ?? _shown;
    if (own == null || from == null || from.id == own.id) {
      _backToOwn(why);
      return;
    }
    _own = null;
    await _move(
      attempt,
      ask: 0,
      to: own,
      from: from,
      pause,
      ", back to the TV's own: $why",
    );
  }

  /// [mode] is [target]: the same id, or the same size and rate (a
  /// display may number its modes again after a switch).
  static bool _isMode(DisplayMode mode, DisplayMode target) =>
      mode.id == target.id ||
      (mode.sameSize(target) &&
          (mode.refreshRate - target.refreshRate).abs() <= rateTolerance);

  /// Pauses, asks for [ask] (0: none), waits for the display to show
  /// [to], then settles. Whatever ends it early, the caller plays on.
  ///
  /// [why] ends the line logged as it asks; [what] (the film's rate, by
  /// default [why]) the lines after.
  Future<void> _move(
    _Attempt attempt,
    Future<void> Function() pause,
    String why, {
    required int ask,
    required DisplayMode to,
    required DisplayMode from,
    String? what,
  }) async {
    final fromTo =
        '${from.width}x${from.height} ${formatRate(from.refreshRate)} → '
        '${to.sameSize(from) ? '' : '${to.width}x${to.height} '}'
        '${formatRate(to.refreshRate)} Hz';
    final change = '$fromTo${what ?? why}';
    // Said before the pause is asked: a pause that fails half-way is
    // still played out of.
    attempt.paused = true;
    await _bounded(pause);
    if (attempt.over) return;
    final started = _clock();
    final shown = attempt.waitFor(to);
    // Before the request goes: a stop while it is on its way still
    // clears it.
    _requested = ask == 0 ? null : ask;
    _returning = ask == 0 ? (own: to, asked: started) : null;
    _log.info(_tag, 'Display mode asked: $fromTo$why');
    final asked = await _bounded(() => _display.request(ask)) ?? false;
    if (attempt.over) return;
    if (!asked) {
      _log.warning(
        _tag,
        "Display mode $change: couldn't be asked for, playing on",
      );
      return;
    }
    final now = _shown;
    final reached =
        (now != null && _isMode(now, to)) ||
        await shown.timeout(changeTimeout, onTimeout: () => false);
    if (attempt.over) return;
    if (!reached) {
      if (ask != 0) _unanswered = ask;
      _log.warning(
        _tag,
        'Display mode $change: no change within '
        '${changeTimeout.inSeconds} s, playing on',
      );
      return;
    }
    if (ask != 0) {
      final took = _clock().difference(started);
      _log.info(
        _tag,
        'Display mode now ${to.logLabel}, ${_seconds(took)} after asking',
      );
    }
    await attempt.sleep(settle);
  }

  /// Every state the coordinator goes through: the player closing lets
  /// the mode go after the [grace], a channel at once; a stop during a
  /// switch ends it and clears the request.
  void playbackChanged(PlaybackState state) {
    if (!available) return;
    switch (state) {
      case PlaybackIdle():
        if (_attempt case final attempt?) {
          attempt.end();
          _attempt = null;
          _backToOwn('the player stopped during the switch');
        } else {
          _backAfterGrace('the player closed');
        }
      case PlaybackOpening(:final item):
        // Another play: the open being switched for is over, and the
        // next first frame decides.
        _attempt?.end();
        _attempt = null;
        _cancelRelease();
        if (item.live) _backToOwn('a channel plays');
      case _:
        break;
    }
  }

  /// The app left the screen (a TV's Home, another app, sleep): the
  /// system drops the request then anyway; none is left behind.
  void away() {
    if (!available) return;
    _attempt?.end();
    _attempt = null;
    _backToOwn('the app left the screen');
  }

  void _backAfterGrace(String why) {
    if (_requested == null) return;
    _release?.cancel();
    _release = Timer(grace, () {
      _release = null;
      _backToOwn(why);
    });
  }

  void _cancelRelease() {
    _release?.cancel();
    _release = null;
  }

  /// Asks for no mode: the TV's own comes back, with no pause and no
  /// wait (nothing of a film plays).
  void _backToOwn(String why) {
    _cancelRelease();
    if (_requested == null) return;
    _requested = null;
    final own = _own;
    _own = null;
    final shown = _shown;
    // Logged when the display shows it, unless it never left.
    _returning = own == null || (shown != null && _isMode(shown, own))
        ? null
        : (own: own, asked: _clock());
    _log.info(
      _tag,
      "Display mode asked: back to the TV's own"
      '${own == null ? '' : ', ${own.logLabel}'}: $why',
    );
    unawaited(_bounded(() => _display.request(0)));
  }

  void _changed(DisplayMode mode) {
    _shown = mode;
    if (mode.id == _unanswered) _unanswered = null;
    if (_returning case (:final own, :final asked) when _isMode(mode, own)) {
      _returning = null;
      _log.info(
        _tag,
        "Display mode back to the TV's own, ${mode.logLabel}, "
        '${_seconds(_clock().difference(asked))} after asking',
      );
    }
    _attempt?.shown(mode);
  }

  /// [call], or null when it fails or takes longer than [callTimeout].
  Future<T?> _bounded<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(callTimeout);
    } on Object catch (error) {
      _log.info(_tag, 'A display call failed: $error');
      return null;
    }
  }

  static String _seconds(Duration took) =>
      '${(took.inMilliseconds / 1000).toStringAsFixed(1)} s';

  /// Lets the mode go: the app is closing.
  Future<void> dispose() async {
    if (_disposed) return;
    _attempt?.end();
    _attempt = null;
    _backToOwn('the player is closing');
    _disposed = true;
    await _changes.cancel();
  }
}

/// One file's switch: ended by a stop, another play, or the next file's
/// first frame.
final class _Attempt {
  /// The player was paused for it.
  bool paused = false;
  bool over = false;
  final _ended = Completer<void>();
  DisplayMode? _waitingFor;
  Completer<bool>? _shown;

  /// True when the display shows [mode]; false when this ends first.
  Future<bool> waitFor(DisplayMode mode) {
    _waitingFor = mode;
    return (_shown = Completer<bool>()).future;
  }

  void shown(DisplayMode mode) {
    final waiting = _shown;
    final target = _waitingFor;
    if (waiting == null ||
        waiting.isCompleted ||
        target == null ||
        !FrameRateMatcher._isMode(mode, target)) {
      return;
    }
    waiting.complete(true);
  }

  /// [time], or less when this ends first.
  Future<void> sleep(Duration time) {
    final done = Completer<void>();
    final timer = Timer(time, done.complete);
    unawaited(
      _ended.future.then((_) {
        timer.cancel();
        if (!done.isCompleted) done.complete();
      }),
    );
    return done.future;
  }

  void end() {
    if (over) return;
    over = true;
    _ended.complete();
    if (_shown case final waiting? when !waiting.isCompleted) {
      waiting.complete(false);
    }
  }
}
