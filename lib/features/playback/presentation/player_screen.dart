import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
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
import 'package:iptv_player/features/playback/presentation/player_surface.dart';
import 'package:iptv_player/features/playback/presentation/vod_osd.dart';
import 'package:iptv_player/features/playback/presentation/vod_player_controller.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';

/// The full-screen player (canvas `Full-screen player`, docs/05 §4): the
/// picture edge to edge, an OSD that hides after [osdTimeout] without
/// input (the cursor with it), and the keyboard: ↑↓ and PageUp/PageDown
/// zap (a banner at once, the stream after [zapDebounce]), digits enter a
/// number (committed after [numberTimeout] or Enter), Backspace goes to
/// the last channel, ← opens the channel panel, M mutes, A and S cycle
/// audio and subtitles, I shows the stream info, F or a double-click
/// toggles the window's full screen, Esc goes back.
///
/// A movie or an episode (Phase 5 step 6) has its own face and keys:
/// Space plays and pauses, ←/→ seek 10 s and Shift+←/→ 60 s (the bar at
/// once, the seek when the keys rest), Home starts over, and Esc saves,
/// stops and goes back; ↑/↓ and the digits do nothing. Leaving the player
/// any way at all stops the file.
class PlayerScreen extends ConsumerStatefulWidget {
  const new({this.zapQuery, super.key});

  /// The list ↑/↓ zap through: the Guide's, when it opened the player;
  /// otherwise the one Live TV shows.
  final ChannelQuery? zapQuery;

  static const osdTimeout = Duration(seconds: 3);
  static const zapDebounce = Duration(milliseconds: 350);
  static const numberTimeout = Duration(milliseconds: 1500);
  static const bannerTime = Duration(seconds: 3);

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _focus = FocusNode(debugLabel: 'player');
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
  bool _muted = false;

  WindowControls? _window;
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
    _castWatch = ref.listenManual(playbackStateProvider, (_, next) {
      if (next.value is PlaybackCasting) _handOffToCast();
    });
    if (_coordinator.casting) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handOffToCast());
    } else {
      unawaited(_window!.setFullScreen(on: true));
    }
    _showOsd();
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
    _focus.dispose();
    unawaited(_window?.setFullScreen(on: false));
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

  void _showOsd() {
    _osdTimer?.cancel();
    if (!_osd) setState(() => _osd = true);
    _osdTimer = Timer(PlayerScreen.osdTimeout, () {
      if (mounted && !_panel && !_pinned) setState(() => _osd = false);
    });
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

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await ref.read(playerEngineProvider).setMuted(muted: _muted);
  }

  Future<void> _toggleWindowFullScreen() async {
    final window = ref.read(windowControlsProvider);
    await window.setFullScreen(on: !await window.isFullScreen());
  }

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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    _showOsd();
    // Ctrl+2, Ctrl+K and the like are the app's, not a digit or a seek.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (_isVod) return _onVodKey(event);
    final key = event.logicalKey;
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
        setState(() => _panel = true);
      case LogicalKeyboardKey.backspace:
        unawaited(_lastChannel());
      case LogicalKeyboardKey.keyM:
        unawaited(_toggleMute());
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

  KeyEventResult _onVodKey(KeyEvent event) {
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    const step = Duration(seconds: 10);
    const bigStep = Duration(seconds: 60);
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        _vod.nudge(-(shift ? bigStep : step));
      case LogicalKeyboardKey.arrowRight:
        _vod.nudge(shift ? bigStep : step);
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
      case LogicalKeyboardKey.home:
        _vod.startOver();
      case LogicalKeyboardKey.keyM:
        unawaited(_toggleMute());
      case LogicalKeyboardKey.keyA:
        unawaited(_cycleAudio());
      case LogicalKeyboardKey.keyS:
        unawaited(_cycleSubtitles());
      case LogicalKeyboardKey.keyI:
        setState(() => _info = !_info);
      case LogicalKeyboardKey.keyF:
        unawaited(_toggleWindowFullScreen());
      case LogicalKeyboardKey.arrowUp ||
          LogicalKeyboardKey.arrowDown ||
          LogicalKeyboardKey.pageUp ||
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

  Future<void> _trackMenu(BuildContext anchor, {required bool audio}) {
    final tracks = ref.read(playerTracksProvider).value;
    final engine = ref.read(playerEngineProvider);
    String label(MediaTrack t) => [
      t.title ?? t.language ?? 'Track ${t.id}',
      if (t.title != null && t.language != null) t.language!,
      ?t.codec,
      ?t.channels,
    ].join(' · ');
    return showAppMenu(
      anchor,
      width: 280,
      items: audio
          ? [
              for (final t in tracks?.audio ?? const <MediaTrack>[])
                AppMenuItem(
                  label: label(t),
                  checked: t.id == tracks?.audioId,
                  onPressed: () => unawaited(engine.selectAudio(t.id)),
                ),
              if ((tracks?.audio ?? const []).isEmpty)
                const AppMenuItem(label: 'No audio tracks'),
            ]
          : [
              AppMenuItem(
                label: 'Off',
                checked: tracks?.subtitleId == null,
                onPressed: () => unawaited(engine.selectSubtitle(null)),
              ),
              for (final t in tracks?.subtitles ?? const <MediaTrack>[])
                AppMenuItem(
                  label: label(t),
                  checked: t.id == tracks?.subtitleId,
                  onPressed: () => unawaited(engine.selectSubtitle(t.id)),
                ),
            ],
    );
  }

  Future<void> _aspectMenu(BuildContext anchor) {
    final engine = ref.read(playerEngineProvider);
    return showAppMenu(
      anchor,
      items: [
        for (final (mode, name) in const [
          (AspectMode.fit, 'Fit'),
          (AspectMode.fill, 'Fill (crop)'),
          (AspectMode.stretch, 'Stretch'),
          (AspectMode.ratio16x9, '16:9'),
          (AspectMode.ratio4x3, '4:3'),
        ])
          AppMenuItem(
            label: name,
            onPressed: () => unawaited(engine.setAspect(mode)),
          ),
      ],
    );
  }

  /// The OSD's right-hand controls, live or not.
  List<Widget> _controls(PlayerTracks? tracks) => [
    Builder(
      builder: (anchor) => AppIconButton(
        icon: AppIcons.audio,
        tooltip: 'Audio',
        shortcut: 'A',
        onPressed: () => unawaited(_trackMenu(anchor, audio: true)),
      ),
    ),
    Builder(
      builder: (anchor) => AppIconButton(
        icon: AppIcons.subtitles,
        tooltip: 'Subtitles',
        shortcut: 'S',
        selected: tracks?.subtitleId != null,
        onPressed: () => unawaited(_trackMenu(anchor, audio: false)),
      ),
    ),
    Builder(
      builder: (anchor) => AppIconButton(
        icon: AppIcons.aspectRatio,
        tooltip: 'Aspect',
        onPressed: () => unawaited(_aspectMenu(anchor)),
      ),
    ),
    AppIconButton(
      icon: _muted ? AppIcons.volumeOff : AppIcons.volumeHigh,
      tooltip: _muted ? 'Unmute' : 'Mute',
      shortcut: 'M',
      onPressed: () => unawaited(_toggleMute()),
    ),
    AppIconButton(
      icon: AppIcons.info,
      tooltip: 'Stream info',
      shortcut: 'I',
      selected: _info,
      onPressed: () => setState(() => _info = !_info),
    ),
    AppIconButton(
      icon: AppIcons.cast,
      tooltip: 'Cast',
      shortcut: 'C',
      onPressed: () => unawaited(castFrom(context)),
    ),
    AppIconButton(
      icon: AppIcons.exitFullscreen,
      tooltip: 'Exit full screen',
      shortcut: 'Esc',
      onPressed: _exit,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(playbackStateProvider).value;
    final item = state?.item;
    final channel = state?.channel;
    final vod = item != null && !item.live;
    final tracks = ref.watch(playerTracksProvider).value;
    final showOsd = _osd || _panel || _pinned || state is PlaybackFailed;

    Widget osd(Widget child) => AnimatedOpacity(
      opacity: showOsd ? 1 : 0,
      duration: showOsd ? tokens.motion.osdIn : tokens.motion.osdOut,
      child: IgnorePointer(ignoring: !showOsd, child: child),
    );

    // A page of its own, outside the shell: it needs its own Material for
    // text and ink to look right.
    return Material(
      color: tokens.colors.video,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: showOsd ? MouseCursor.defer : SystemMouseCursors.none,
          onHover: (_) => _showOsd(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => unawaited(_toggleWindowFullScreen()),
            child: ColoredBox(
              color: tokens.colors.video,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlayerSurface(
                    badges: false,
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
                  if (vod)
                    osd(
                      ListenableBuilder(
                        listenable: _vod,
                        builder: (context, _) => _vodOsd(item, tracks),
                      ),
                    )
                  else if (channel != null)
                    osd(
                      Column(
                        children: [
                          OsdTop(channel: channel),
                          const Spacer(),
                          OsdBottom(
                            channel: channel,
                            controls: _controls(tracks),
                          ),
                        ],
                      ),
                    ),
                  if (_banner case final banner? when !_panel)
                    Positioned(
                      top: tokens.spacing.s48 * 2,
                      left: 0,
                      right: 0,
                      child: Center(child: ChannelBanner(channel: banner)),
                    ),
                  if (_digits.isNotEmpty)
                    Positioned(
                      top: tokens.spacing.s48 * 2,
                      right: tokens.spacing.s32,
                      child: NumberEntry(digits: _digits, match: _numberMatch),
                    ),
                  if (_info)
                    Positioned(
                      top: tokens.spacing.s48 * 2,
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
                          const SingleActivator(LogicalKeyboardKey.arrowRight):
                              _closePanel,
                          const SingleActivator(LogicalKeyboardKey.escape):
                              _closePanel,
                        },
                        child: ChannelPanel(
                          query:
                              _query ??
                              ChannelQuery(sourceId: channel?.sourceId ?? ''),
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
          ),
        ),
      ),
    );
  }

  Widget _vodOsd(Playable item, PlayerTracks? tracks) {
    final tokens = context.tokens;
    final next = _vod.next;
    final countdown = _vod.countdown;
    return Column(
      children: [
        VodOsdTop(item: item),
        const Spacer(),
        if (next != null && (countdown != null || _vod.ended))
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
          controls: _controls(tracks),
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
