import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/core/text/languages.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/presentation/cast_actions.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/player_sound.dart';
import 'package:iptv_player/features/playback/presentation/player_surface.dart';
import 'package:iptv_player/features/playback/presentation/vod_osd.dart';
import 'package:iptv_player/features/playback/presentation/vod_player_controller.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';

/// The full-screen player (canvas `Full-screen player`, docs/05 §4; its
/// controls as ADR-017 has them): the picture edge to edge, an OSD that
/// hides after [osdTimeout] without input (the cursor with it), and the
/// keyboard: ↑↓ and PageUp/PageDown zap (a banner at once, the stream
/// after [zapDebounce]), digits enter a number (committed after
/// [numberTimeout] or Enter), Backspace goes to the last channel, ← opens
/// the channel panel, + and − turn the volume, M mutes, A and S cycle
/// audio and subtitles, I shows the stream info, F or a double-click
/// toggles the window's full screen, Esc goes back. Every key has a
/// control on the OSD, large enough to read from across a room, and the
/// OSD is drawn larger in a larger window.
///
/// A movie or an episode (Phase 5 step 6) has its own face and keys:
/// Space or a click on the picture plays and pauses, ←/→ seek 10 s and
/// Shift+←/→ 60 s (the bar at once, the seek when the keys rest), ↑/↓
/// turn the volume, Home starts over, and Esc saves, stops and goes back;
/// the digits do nothing. Leaving the player any way at all stops the
/// file.
///
/// On a TV (docs/07) the remote's OK shows the controls: a channel's with
/// the focus on Channels, a file's after pausing or playing it; ↑/↓ in a
/// file show them too, on Play. While a control has the focus the arrows
/// and OK are the control's, and Back gives the picture the focus again.
class PlayerScreen extends ConsumerStatefulWidget {
  const new({this.zapQuery, super.key});

  /// The list ↑/↓ zap through: the Guide's, when it opened the player;
  /// otherwise the one Live TV shows.
  final ChannelQuery? zapQuery;

  static const osdTimeout = Duration(seconds: 3);

  /// While the keyboard is on one of the OSD's controls: time to read
  /// what the next one is.
  static const osdFocusTimeout = Duration(seconds: 6);

  /// What Speed offers a file.
  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const zapDebounce = Duration(milliseconds: 350);
  static const numberTimeout = Duration(milliseconds: 1500);
  static const bannerTime = Duration(seconds: 3);

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _focus = FocusNode(debugLabel: 'player');

  /// The control the remote lands on (a TV): a channel's Channels, a
  /// file's Play.
  final _entry = FocusNode(debugLabel: 'player controls');
  bool _osd = true;
  Timer? _osdTimer;

  ChannelItem? _zapTarget;
  Timer? _zapTimer;
  ChannelItem? _banner;
  Timer? _bannerTimer;

  String _digits = '';
  ChannelItem? _numberMatch;
  Timer? _numberTimer;

  bool _panel = false;
  bool _info = false;

  /// The window is in full screen (the player opens it so; F leaves it).
  bool _fullScreen = false;
  AspectMode _aspect = AspectMode.fit;

  /// How fast a file plays, for as long as the player is open: the next
  /// episode keeps it.
  double _speed = 1;

  WindowControls? _window;
  late final PlayerEngine _engine;
  late final PlaybackCoordinator _coordinator;
  late final VodPlayerController _vod;

  /// A file's OSD stays up while it opens, while paused or seeking, and
  /// while its card shows.
  bool _pinned = false;
  bool _card = false;

  /// An episode with one after it: the failure card offers it.
  bool _hasNext = false;

  @override
  void initState() {
    super.initState();
    _window = ref.read(windowControlsProvider);
    _engine = ref.read(playerEngineProvider);
    _coordinator = ref.read(playbackCoordinatorProvider);
    _vod = VodPlayerController(
      coordinator: _coordinator,
      series: ref.read(seriesRepositoryProvider),
      progress: ref.read(watchProgressProvider),
      onFinished: _finished,
      library: ref.read(libraryRepositoryProvider),
    )..addListener(_onVod);
    // The file was asked for before the player came up: its state so far.
    final (pinned, card, hasNext) = _vodFlags();
    _pinned = pinned;
    _card = card;
    _hasNext = hasNext;
    // While casting, the casting view takes the player's place (Phase 7
    // decision 2): a play that opened the player, or Cast from its OSD.
    // The coordinator is asked too: what the provider says may be from
    // before this screen was there to hear it.
    _castWatch = ref.listenManual(playbackStateProvider, (_, next) {
      if (next.value is PlaybackCasting && _coordinator.casting) {
        _handOffToCast();
      }
    });
    if (_coordinator.casting) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handOffToCast());
    } else {
      _fullScreen = true;
      unawaited(_window!.setFullScreen(on: true));
    }
    // The keyboard moving onto a control restarts the OSD's clock with
    // the longer wait (the Tab that moved it was heard before it moved).
    _focus.addListener(_onFocusMoved);
    _showOsd();
  }

  void _onFocusMoved() {
    if (mounted && _osd) _showOsd();
  }

  bool _handedOff = false;
  ProviderSubscription<AsyncValue<PlaybackState>>? _castWatch;

  void _handOffToCast() {
    if (_handedOff || !mounted) return;
    _handedOff = true;
    ref.read(castingViewOpenProvider.notifier).open();
    _exit();
  }

  @override
  void dispose() {
    // Before the stop below: it changes the state this listens to.
    _castWatch?.close();
    _osdTimer?.cancel();
    _zapTimer?.cancel();
    _bannerTimer?.cancel();
    _numberTimer?.cancel();
    _vod
      ..removeListener(_onVod)
      ..dispose();
    _focus
      ..removeListener(_onFocusMoved)
      ..dispose();
    _entry.dispose();
    unawaited(_window?.setFullScreen(on: false));
    // The preview and the next thing played are at the recorded speed
    // and shape again.
    if (_speed != 1) unawaited(_engine.setSpeed(1));
    if (_aspect != AspectMode.fit) unawaited(_engine.setAspect(AspectMode.fit));
    // A file plays only here: whichever way the player was left, it stops
    // (and saves where it was). Live carries on in the preview.
    if (_coordinator.item case final item? when !item.live) {
      unawaited(_coordinator.stop());
    }
    super.dispose();
  }

  bool get _isVod => _coordinator.item?.live == false;

  /// Whether a file's OSD is pinned up, its card shows, and it has a next
  /// episode.
  (bool, bool, bool) _vodFlags() {
    final card = _vod.countdown != null || _vod.ended;
    final pinned =
        _vod.item != null &&
        (_vod.timeline.paused ||
            _vod.preparing ||
            _vod.pendingSeek != null ||
            card);
    return (pinned, card, _vod.next != null);
  }

  void _onVod() {
    final (pinned, card, hasNext) = _vodFlags();
    if (pinned == _pinned && card == _card && hasNext == _hasNext) return;
    final cardGone = _card && !card;
    setState(() {
      _pinned = pinned;
      _card = card;
      _hasNext = hasNext;
    });
    // The card had the focus; the player takes it back.
    if (cardGone) _focus.requestFocus();
    if (!pinned) _showOsd();
  }

  /// A movie played to its end, or the last episode: back to its page.
  void _finished(Playable item) {
    if (!mounted) return;
    final router = GoRouter.of(context);
    switch (item) {
      case PlayableMovie(:final movie):
        router.go(movieDetailsPath(movie));
      case PlayableEpisode(:final series):
        router.go(seriesDetailsPath(series));
      case PlayableLibraryItem():
        router.go(AppDestination.library.path);
      case PlayableChannel():
        _exit();
    }
  }

  /// The list being zapped through: the one the player was opened from.
  ChannelQuery? get _query {
    if (widget.zapQuery case final query?) return query;
    final view = ref.read(liveTvControllerProvider);
    if (view != null) return view.query;
    final current = ref.read(playbackCoordinatorProvider).current;
    return current == null ? null : ChannelQuery(sourceId: current.sourceId);
  }

  /// The keyboard or the remote is on one of the OSD's controls.
  bool get _onControl => _focus.hasFocus && !_focus.hasPrimaryFocus;

  void _showOsd() {
    _osdTimer?.cancel();
    if (!_osd) setState(() => _osd = true);
    // The keyboard on a control: the OSD stays long enough to read it.
    final onControl = _onControl;
    _osdTimer = Timer(
      onControl ? PlayerScreen.osdFocusTimeout : PlayerScreen.osdTimeout,
      () {
        if (!mounted || _panel || _pinned) return;
        setState(() => _osd = false);
        // A control nobody can see must not be the one Enter presses.
        if (_onControl) _focus.requestFocus();
      },
    );
  }

  void _play(ChannelItem channel) {
    ref.read(liveTvControllerProvider.notifier).select(channel);
    unawaited(ref.read(playbackCoordinatorProvider).playLive(channel));
  }

  void _showBanner(ChannelItem channel) {
    _bannerTimer?.cancel();
    setState(() => _banner = channel);
    _bannerTimer = Timer(PlayerScreen.bannerTime, () {
      if (mounted) setState(() => _banner = null);
    });
  }

  /// ↑ (-1) and ↓ (+1): the banner at once, the stream after a moment,
  /// so holding the key runs through channels without opening each.
  Future<void> _zap(int delta) async {
    final query = _query;
    final from = _zapTarget ?? ref.read(playbackCoordinatorProvider).current;
    if (query == null || from == null) return;
    final repository = ref.read(channelRepositoryProvider);
    final count = await repository.watchCount(query).first;
    if (count == 0) return;
    final index = (await repository.indexOf(query, from.id)).valueOrNull ?? -1;
    final target = ((index + delta) % count + count) % count;
    final next = (await repository.range(query, target, 1)).valueOrNull;
    if (!mounted || next == null || next.isEmpty) return;
    final channel = next.first;
    _zapTarget = channel;
    _showBanner(channel);
    _zapTimer?.cancel();
    _zapTimer = Timer(PlayerScreen.zapDebounce, () {
      _zapTarget = null;
      _play(channel);
    });
  }

  Future<void> _digit(int digit) async {
    if (_digits.length >= 5) return;
    final digits = '$_digits$digit';
    setState(() => _digits = digits);
    _numberTimer?.cancel();
    _numberTimer = Timer(PlayerScreen.numberTimeout, _commitNumber);
    final sourceId = _query?.sourceId;
    if (sourceId == null) return;
    final match =
        (await ref
                .read(channelRepositoryProvider)
                .byNumber(sourceId, int.parse(digits)))
            .valueOrNull;
    if (mounted && digits == _digits) setState(() => _numberMatch = match);
  }

  void _commitNumber() {
    _numberTimer?.cancel();
    final match = _numberMatch;
    setState(() {
      _digits = '';
      _numberMatch = null;
    });
    if (match != null) {
      _showBanner(match);
      _play(match);
    }
  }

  Future<void> _lastChannel() async {
    final coordinator = ref.read(playbackCoordinatorProvider);
    final sourceId = coordinator.current?.sourceId ?? _query?.sourceId;
    if (sourceId == null) return;
    final last = await coordinator.lastChannel(sourceId);
    if (!mounted || last == null) return;
    _showBanner(last);
    _play(last);
  }

  Future<void> _cycleAudio() => _cycle(audio: true);

  Future<void> _cycleSubtitles() => _cycle(audio: false);

  Future<void> _cycle({required bool audio}) async {
    final tracks = ref.read(playerTracksProvider).value;
    if (tracks == null) return;
    final engine = ref.read(playerEngineProvider);
    if (audio) {
      if (tracks.audio.length < 2) return;
      final index = tracks.audio.indexWhere((t) => t.id == tracks.audioId);
      await engine.selectAudio(
        tracks.audio[(index + 1) % tracks.audio.length].id,
      );
    } else {
      // Off, then each subtitle track in turn.
      final ids = <String?>[null, for (final t in tracks.subtitles) t.id];
      final index = ids.indexOf(tracks.subtitleId);
      await engine.selectSubtitle(ids[(index + 1) % ids.length]);
    }
  }

  PlayerSoundController get _sound =>
      ref.read(playerSoundControllerProvider.notifier);

  Future<void> _toggleWindowFullScreen() async {
    final window = ref.read(windowControlsProvider);
    final on = !await window.isFullScreen();
    await window.setFullScreen(on: on);
    if (mounted) setState(() => _fullScreen = on);
  }

  Future<void> _toggleFavorite(ChannelItem channel) => ref
      .read(channelRepositoryProvider)
      .setFavorite(channel, on: !channel.isFavorite);

  void _setSpeed(double speed) {
    setState(() => _speed = speed);
    unawaited(_engine.setSpeed(speed));
  }

  void _openPanel() => setState(() => _panel = true);

  /// + and − (and the number pad's) turn the volume in every face of the
  /// player.
  static int? _volumeStep(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.equal ||
    LogicalKeyboardKey.add ||
    LogicalKeyboardKey.numpadAdd => 1,
    LogicalKeyboardKey.minus || LogicalKeyboardKey.numpadSubtract => -1,
    _ => null,
  };

  void _exit() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go(switch (_coordinator.item) {
      PlayableMovie(:final movie) => movieDetailsPath(movie),
      PlayableEpisode(:final series) => seriesDetailsPath(series),
      PlayableLibraryItem() => AppDestination.library.path,
      _ => '/live',
    });
  }

  /// The end card's Back to series.
  void _backToSeries() {
    switch (_vod.item) {
      case PlayableEpisode(:final series):
        GoRouter.of(context).go(seriesDetailsPath(series));
      case PlayableLibraryItem():
        GoRouter.of(context).go(AppDestination.library.path);
      case _:
        break;
    }
  }

  /// The remote's keys the player takes. Their key-up is taken too: one
  /// left to Android is acted on again (a media key reaches another app's
  /// session).
  static final Set<LogicalKeyboardKey> _remoteKeys = {
    LogicalKeyboardKey.channelUp,
    LogicalKeyboardKey.channelDown,
    LogicalKeyboardKey.info,
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPause,
    LogicalKeyboardKey.mediaFastForward,
    LogicalKeyboardKey.mediaRewind,
    LogicalKeyboardKey.mediaStop,
  };

  /// The system's back (a TV remote's Back), as Esc: what is open closes
  /// first, then the player is left. One press, one step: handled as a
  /// key, its key-up went on to Android as a second back, which left the
  /// app from a section's root (the user, on the Bedroom TV).
  Future<bool> _onBack() async {
    if (_panel) {
      _closePanel();
    } else if (_info) {
      setState(() => _info = false);
    } else if (_isVod && _vod.countdown != null) {
      _vod.cancelNext();
    } else if (_onTv && _onControl) {
      _toPicture();
    } else {
      _exit();
    }
    return true;
  }

  /// A TV's Back from a control: the picture has the focus again, and the
  /// OSD goes (unless a paused file keeps it).
  void _toPicture() {
    _osdTimer?.cancel();
    _focus.requestFocus();
    if (!_panel && !_pinned) setState(() => _osd = false);
  }

  /// The OSD, with the remote on its [_entry] control.
  void _showControls() {
    _showOsd();
    // A hidden OSD is still built (only see-through): its controls are
    // there to focus.
    if (_entry.context != null) _entry.requestFocus();
  }

  /// A TV remote's OK with the picture focused (through [TvSelectKey]'s
  /// [ActivateIntent]): a typed number goes; a file pauses or plays on;
  /// a channel shows its controls.
  void _onSelect() {
    if (_digits.isNotEmpty) {
      _commitNumber();
    } else if (_isVod) {
      _showOsd();
      _vod.togglePause();
    } else {
      _showControls();
    }
  }

  /// On a TV, while a control has the focus, these are the control's:
  /// they move between the controls and press them.
  static final Set<LogicalKeyboardKey> _controlKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return _remoteKeys.contains(event.logicalKey)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    _showOsd();
    // Ctrl+2, Ctrl+K and the like are the app's, not a digit or a seek.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (_volumeStep(event.logicalKey) case final step?) {
      _sound.nudge(step);
      return KeyEventResult.handled;
    }
    final onTv = _onTv;
    if (onTv && _onControl && _controlKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (_isVod) return _onVodKey(event, onTv: onTv);
    final key = _remoteLiveKey(event.logicalKey);
    // Digits, and a typed number's Enter and Backspace.
    final digit = _digitOf(key);
    if (digit != null) {
      unawaited(_digit(digit));
      return KeyEventResult.handled;
    }
    if (_digits.isNotEmpty) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        _commitNumber();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.backspace) {
        setState(() {
          _digits = _digits.substring(0, _digits.length - 1);
          _numberMatch = null;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _numberTimer?.cancel();
        setState(() => _digits = '');
        return KeyEventResult.handled;
      }
    }
    // The channel panel moves with the arrows and plays with Enter.
    if (_panel &&
        (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.pageUp ||
            key == LogicalKeyboardKey.pageDown ||
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent &&
        key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.handled;
    }
    switch (key) {
      case LogicalKeyboardKey.escape:
        if (_info) {
          setState(() => _info = false);
        } else {
          _exit();
        }
      case LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.pageUp:
        unawaited(_zap(-1));
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.pageDown:
        unawaited(_zap(1));
      case LogicalKeyboardKey.arrowLeft:
        _openPanel();
      case LogicalKeyboardKey.arrowRight when onTv:
        _showControls();
      case LogicalKeyboardKey.backspace:
        unawaited(_lastChannel());
      case LogicalKeyboardKey.keyM:
        _sound.toggleMute();
      case LogicalKeyboardKey.keyA:
        unawaited(_cycleAudio());
      case LogicalKeyboardKey.keyS:
        unawaited(_cycleSubtitles());
      case LogicalKeyboardKey.keyI:
        setState(() => _info = !_info);
      case LogicalKeyboardKey.keyF:
        unawaited(_toggleWindowFullScreen());
      default:
        // Tab, Enter and Space reach the OSD's controls.
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// A TV remote's keys as the keyboard's (docs/07): Channel Up and Down
  /// page through the channels, Info is I. Back isn't here: it arrives as
  /// the system's back ([_onBack]), once.
  static LogicalKeyboardKey _remoteLiveKey(LogicalKeyboardKey key) =>
      switch (key) {
        LogicalKeyboardKey.channelUp => LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.channelDown => LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.info => LogicalKeyboardKey.keyI,
        _ => key,
      };

  /// A film's remote keys (docs/07): Stop is Esc, Info is I, play/pause
  /// is Space, fast forward and rewind step as → and ← do.
  static LogicalKeyboardKey _remoteVodKey(LogicalKeyboardKey key) =>
      switch (key) {
        LogicalKeyboardKey.mediaStop => LogicalKeyboardKey.escape,
        LogicalKeyboardKey.info => LogicalKeyboardKey.keyI,
        LogicalKeyboardKey.mediaPlayPause => LogicalKeyboardKey.space,
        LogicalKeyboardKey.mediaFastForward => LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.mediaRewind => LogicalKeyboardKey.arrowLeft,
        _ => key,
      };

  KeyEventResult _onVodKey(KeyEvent event, {required bool onTv}) {
    final key = _remoteVodKey(event.logicalKey);
    final repeat = event is KeyRepeatEvent;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    const step = Duration(seconds: 10);
    const bigStep = Duration(seconds: 60);
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        _vod.nudge(-(shift ? bigStep : step));
      case LogicalKeyboardKey.arrowRight:
        _vod.nudge(shift ? bigStep : step);
      // A TV has no volume of its own: ↑/↓ reach the controls.
      case LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowDown when onTv:
        if (!repeat) _showControls();
      case LogicalKeyboardKey.arrowUp:
        _sound.nudge(1);
      case LogicalKeyboardKey.arrowDown:
        _sound.nudge(-1);
      case _ when repeat:
        break;
      case LogicalKeyboardKey.escape:
        if (_info) {
          setState(() => _info = false);
        } else if (_vod.countdown != null) {
          _vod.cancelNext();
        } else {
          _exit();
        }
      case LogicalKeyboardKey.space:
        _vod.togglePause();
      case LogicalKeyboardKey.mediaPlay when _vod.timeline.paused:
        _vod.togglePause();
      case LogicalKeyboardKey.mediaPause when !_vod.timeline.paused:
        _vod.togglePause();
      case LogicalKeyboardKey.mediaPlay || LogicalKeyboardKey.mediaPause:
        break;
      case LogicalKeyboardKey.home:
        _vod.startOver();
      case LogicalKeyboardKey.keyM:
        _sound.toggleMute();
      case LogicalKeyboardKey.keyA:
        unawaited(_cycleAudio());
      case LogicalKeyboardKey.keyS:
        unawaited(_cycleSubtitles());
      case LogicalKeyboardKey.keyI:
        setState(() => _info = !_info);
      case LogicalKeyboardKey.keyF:
        unawaited(_toggleWindowFullScreen());
      case LogicalKeyboardKey.pageUp ||
          LogicalKeyboardKey.pageDown ||
          LogicalKeyboardKey.backspace:
        // Live's zapping keys; nothing to zap through here.
        break;
      default:
        if (_digitOf(key) != null) break;
        // Tab and Enter reach the OSD's controls and the card.
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static int? _digitOf(LogicalKeyboardKey key) {
    const digits = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad0,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = digits.indexOf(key);
    if (i >= 0) return i;
    final j = numpad.indexOf(key);
    return j >= 0 ? j : null;
  }

  /// A track as its menu names it: "English · Commentary · ac3 · 5.1".
  static String _trackLine(MediaTrack t) => [
    _trackName(t),
    if (t.title != null && t.language != null) t.title!,
    ?t.codec,
    ?t.channels,
  ].join(' · ');

  /// A track in a word or two: its language, else its title.
  static String _trackName(MediaTrack t) => switch (t.language) {
    final code? when code.isNotEmpty && code != 'und' => languageName(code),
    _ => t.title ?? 'Track ${t.id}',
  };

  Future<void> _trackMenu(BuildContext anchor, {required bool audio}) {
    final tracks = ref.read(playerTracksProvider).value;
    return showAppMenu(
      anchor,
      width: 280,
      items: audio
          ? [
              for (final t in tracks?.audio ?? const <MediaTrack>[])
                AppMenuItem(
                  label: _trackLine(t),
                  checked: t.id == tracks?.audioId,
                  onPressed: () => unawaited(_engine.selectAudio(t.id)),
                ),
              if ((tracks?.audio ?? const []).isEmpty)
                const AppMenuItem(label: 'No audio tracks'),
            ]
          : [
              AppMenuItem(
                label: 'Off',
                checked: tracks?.subtitleId == null,
                onPressed: () => unawaited(_engine.selectSubtitle(null)),
              ),
              for (final t in tracks?.subtitles ?? const <MediaTrack>[])
                AppMenuItem(
                  label: _trackLine(t),
                  checked: t.id == tracks?.subtitleId,
                  onPressed: () => unawaited(_engine.selectSubtitle(t.id)),
                ),
            ],
    );
  }

  static const List<(AspectMode, String)> _aspects = [
    (AspectMode.fit, 'Fit'),
    (AspectMode.fill, 'Fill (crop)'),
    (AspectMode.stretch, 'Stretch'),
    (AspectMode.ratio16x9, '16:9'),
    (AspectMode.ratio4x3, '4:3'),
  ];

  Future<void> _aspectMenu(BuildContext anchor) => showAppMenu(
    anchor,
    items: [
      for (final (mode, name) in _aspects)
        AppMenuItem(
          label: name,
          checked: mode == _aspect,
          onPressed: () {
            setState(() => _aspect = mode);
            unawaited(_engine.setAspect(mode));
          },
        ),
    ],
  );

  /// "1×", "1.25×".
  static String _speedLabel(double speed) =>
      '${speed == speed.roundToDouble() ? speed.round() : speed}×';

  Future<void> _speedMenu(BuildContext anchor) => showAppMenu(
    anchor,
    items: [
      for (final speed in PlayerScreen.speeds)
        AppMenuItem(
          label: speed == 1 ? '1× · Normal' : _speedLabel(speed),
          checked: speed == _speed,
          onPressed: () => _setSpeed(speed),
        ),
    ],
  );

  /// On a TV the remote's volume and mute keys work the TV itself, and
  /// there is no window (docs/07): neither control is drawn there.
  bool get _onTv => ref.read(formFactorProvider) == FormFactor.tv;

  /// The volume: Mute and the level, after what is used most.
  Widget _volume(PlayerSound sound) => Padding(
    padding: EdgeInsets.only(left: context.tokens.spacing.s12),
    child: OsdVolume(
      volume: sound.volume,
      muted: sound.muted,
      shortcut: 'M',
      onToggleMute: _sound.toggleMute,
      onChanged: (volume) {
        _showOsd();
        _sound.setVolume(volume);
      },
    ),
  );

  /// The OSD's right-hand controls, live or not: what is heard and read,
  /// then the picture, then where it plays.
  List<Widget> _controls(PlayerTracks? tracks, {required bool vod}) {
    final audio = tracks?.audio
        .where((t) => t.id == tracks.audioId)
        .firstOrNull;
    final subtitle = tracks?.subtitles
        .where((t) => t.id == tracks.subtitleId)
        .firstOrNull;
    return [
      Builder(
        builder: (anchor) => OsdButton(
          icon: AppIcons.audio,
          tooltip: 'Audio',
          label: audio == null ? 'Audio' : 'Audio: ${_trackName(audio)}',
          shortcut: 'A',
          onPressed: () => unawaited(_trackMenu(anchor, audio: true)),
        ),
      ),
      Builder(
        builder: (anchor) => OsdButton(
          icon: AppIcons.subtitles,
          tooltip: 'Subtitles',
          label: subtitle == null
              ? 'Subtitles: Off'
              : 'Subtitles: ${_trackName(subtitle)}',
          shortcut: 'S',
          selected: subtitle != null,
          onPressed: () => unawaited(_trackMenu(anchor, audio: false)),
        ),
      ),
      if (vod)
        Builder(
          builder: (anchor) => OsdButton(
            text: _speedLabel(_speed),
            tooltip: 'Speed',
            selected: _speed != 1,
            onPressed: () => unawaited(_speedMenu(anchor)),
          ),
        ),
      Builder(
        builder: (anchor) => OsdButton(
          icon: AppIcons.aspectRatio,
          tooltip:
              'Picture size: '
              '${_aspects.firstWhere((a) => a.$1 == _aspect).$2}',
          selected: _aspect != AspectMode.fit,
          onPressed: () => unawaited(_aspectMenu(anchor)),
        ),
      ),
      OsdButton(
        icon: AppIcons.info,
        tooltip: 'Stream info',
        shortcut: 'I',
        selected: _info,
        onPressed: () => setState(() => _info = !_info),
      ),
      if (ref.watch(castsToTvsProvider))
        OsdButton(
          icon: AppIcons.cast,
          tooltip: 'Cast',
          shortcut: 'C',
          onPressed: () => unawaited(castFrom(context)),
        ),
      // A TV has no window: the picture is always the whole screen.
      if (!_onTv)
        OsdButton(
          icon: _fullScreen ? AppIcons.exitFullscreen : AppIcons.fullscreen,
          tooltip: _fullScreen ? 'Exit full screen' : 'Full screen',
          shortcut: 'F',
          onPressed: () => unawaited(_toggleWindowFullScreen()),
        ),
    ];
  }

  /// A channel's own controls, from the left: the list, the channel
  /// before and after, the one watched last, then the volume.
  List<Widget> _channelControls(PlayerSound sound) => [
    OsdButton(
      icon: AppIcons.channelList,
      tooltip: 'Channels',
      shortcut: '←',
      selected: _panel,
      focusNode: _entry,
      onPressed: _openPanel,
    ),
    OsdButton(
      icon: AppIcons.chevronUp,
      tooltip: 'Previous channel',
      shortcut: '↑',
      onPressed: () => unawaited(_zap(-1)),
    ),
    OsdButton(
      icon: AppIcons.chevronDown,
      tooltip: 'Next channel',
      shortcut: '↓',
      onPressed: () => unawaited(_zap(1)),
    ),
    OsdButton(
      icon: AppIcons.lastChannel,
      tooltip: 'Last channel',
      shortcut: 'Backspace',
      onPressed: () => unawaited(_lastChannel()),
    ),
    if (!_onTv) _volume(sound),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(playbackStateProvider).value;
    final item = state?.item;
    final playing = state?.channel;
    // The row may be stale (a favorite toggled since): read it fresh.
    final channel = playing == null
        ? null
        : ref.watch(freshChannelProvider(playing)).value ?? playing;
    final vod = item != null && !item.live;
    final tracks = ref.watch(playerTracksProvider).value;
    final sound = ref.watch(playerSoundControllerProvider);
    final showOsd = _osd || _panel || _pinned || state is PlaybackFailed;

    Widget osd(Widget child) => AnimatedOpacity(
      opacity: showOsd ? 1 : 0,
      duration: showOsd ? tokens.motion.osdIn : tokens.motion.osdOut,
      child: IgnorePointer(ignoring: !showOsd, child: child),
    );

    // A page of its own, outside the shell: it needs its own Material for
    // text and ink to look right.
    return BackButtonListener(
      onBackButtonPressed: _onBack,
      child: Material(
        color: tokens.colors.video,
        child: Actions(
          actions: {
            if (_onTv)
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _onSelect();
                  return null;
                },
              ),
          },
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            // On a TV the arrows move between the controls only: the
            // picture, as big as the screen, would be the next stop
            // every way. Back gives it the focus again.
            skipTraversal: _onTv,
            onKeyEvent: _onKey,
            child: MouseRegion(
              cursor: showOsd ? MouseCursor.defer : SystemMouseCursors.none,
              onHover: (_) => _showOsd(),
              child: Listener(
                // The wheel over the picture turns the volume.
                onPointerSignal: (signal) {
                  if (signal is! PointerScrollEvent || _panel) return;
                  _showOsd();
                  _sound.nudge(signal.scrollDelta.dy < 0 ? 1 : -1);
                },
                child: ColoredBox(
                  color: tokens.colors.video,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // The picture's clicks are heard under the OSD and
                      // under the failure card: a control answers at once,
                      // with no wait for a second click.
                      PlayerSurface(
                        badges: false,
                        onPictureTap: vod ? _vod.togglePause : _showOsd,
                        onPictureDoubleTap: () =>
                            unawaited(_toggleWindowFullScreen()),
                        onNext: !vod
                            ? () => unawaited(_zap(1))
                            : _hasNext
                            ? _vod.playNext
                            : null,
                        nextLabel: vod ? 'Next episode' : 'Next channel',
                        beforeShowInFolder: () =>
                            _window?.setFullScreen(on: false) ?? Future.value(),
                        onFileRemoved: () {
                          if (mounted) _exit();
                        },
                      ),
                      OsdScale(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (vod)
                              osd(
                                ListenableBuilder(
                                  listenable: _vod,
                                  builder: (context, _) =>
                                      _vodOsd(item, tracks, sound),
                                ),
                              )
                            else if (channel != null)
                              osd(
                                Column(
                                  children: [
                                    OsdTop(channel: channel, onBack: _exit),
                                    const Spacer(),
                                    OsdBottom(
                                      channel: channel,
                                      leading: _channelControls(sound),
                                      trailing: [
                                        OsdButton(
                                          icon: channel.isFavorite
                                              ? AppIcons.starFilled
                                              : AppIcons.star,
                                          tooltip: channel.isFavorite
                                              ? 'Remove from favorites'
                                              : 'Add to favorites',
                                          selected: channel.isFavorite,
                                          onPressed: () => unawaited(
                                            _toggleFavorite(channel),
                                          ),
                                        ),
                                        ..._controls(tracks, vod: false),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            if (_banner case final banner? when !_panel)
                              Positioned(
                                top:
                                    tokens.spacing.s48 * 2 + tokens.spacing.s16,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: ChannelBanner(channel: banner),
                                ),
                              ),
                            if (_digits.isNotEmpty)
                              Positioned(
                                top:
                                    tokens.spacing.s48 * 2 + tokens.spacing.s16,
                                right: tokens.spacing.s32,
                                child: NumberEntry(
                                  digits: _digits,
                                  match: _numberMatch,
                                ),
                              ),
                            if (_info)
                              Positioned(
                                top:
                                    tokens.spacing.s48 * 2 + tokens.spacing.s16,
                                left: tokens.spacing.s32,
                                child: const StreamInfoOverlay(),
                              ),
                            if (_panel)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: 0,
                                child: CallbackShortcuts(
                                  bindings: {
                                    const SingleActivator(
                                      LogicalKeyboardKey.arrowRight,
                                    ): _closePanel,
                                    const SingleActivator(
                                      LogicalKeyboardKey.escape,
                                    ): _closePanel,
                                  },
                                  child: ChannelPanel(
                                    query:
                                        _query ??
                                        ChannelQuery(
                                          sourceId: channel?.sourceId ?? '',
                                        ),
                                    current: channel,
                                    onPlay: (c) {
                                      _closePanel();
                                      _showBanner(c);
                                      _play(c);
                                    },
                                    onClose: _closePanel,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _vodOsd(Playable item, PlayerTracks? tracks, PlayerSound sound) {
    final tokens = context.tokens;
    final next = _vod.next;
    final countdown = _vod.countdown;
    final card = next != null && (countdown != null || _vod.ended);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Paused: Play where the eye is. Not while the file still opens,
        // or under the next-episode card.
        if (_vod.timeline.paused && !_vod.preparing && !card && !_vod.ended)
          Center(child: OsdCenterPlay(onPressed: _vod.togglePause)),
        Column(
          children: [
            VodOsdTop(item: item, onBack: _exit),
            const Spacer(),
            if (card)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: tokens.spacing.s32),
                  child: NextEpisodeCard(
                    key: ValueKey(next.item.remoteKey),
                    next: next,
                    countdown: countdown,
                    onPlay: _vod.playNext,
                    onSecondary: countdown != null
                        ? _vod.cancelNext
                        : _backToSeries,
                  ),
                ),
              ),
            VodOsdBottom(
              timeline: _vod.timeline,
              seeking: _vod.pendingSeek != null,
              resumedFrom: _vod.resumedFrom,
              preparing: _vod.preparing,
              onTogglePause: _vod.togglePause,
              onNudge: _vod.nudge,
              onDrag: _vod.dragTo,
              onStartOver: _vod.startOver,
              onNext: next == null ? null : _vod.playNext,
              playFocusNode: _entry,
              leading: [if (!_onTv) _volume(sound)],
              trailing: _controls(tracks, vod: true),
            ),
          ],
        ),
      ],
    );
  }

  void _closePanel() {
    setState(() => _panel = false);
    _focus.requestFocus();
    _showOsd();
  }
}
