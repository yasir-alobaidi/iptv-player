// A throwaway trial, never shipped: T0 of
// docs/plans/tv-video-layer-and-frame-rate.md (how to build and read it:
// docs/plans/tv-video-layer-t0.md). One screen over the Android SurfaceView
// that MainActivity puts under a transparent FlutterSurfaceView in a build
// made with
//
//   flutter build apk --debug --target-platform android-arm \
//     -t lib/main_layer_trial.dart --dart-define=BIJOU_VIDEO_LAYER=true
//
// No Riverpod, no bootstrap, no database. Hard rule 9 (design tokens only)
// is waived for this one file: plain Flutter widgets, literal colours and
// sizes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const LayerTrialApp());
}

const _videoLayerDefine = bool.fromEnvironment('BIJOU_VIDEO_LAYER');

/// MainActivity's trial channel: `setSpeed(int)`, `logState()`.
const _channel = MethodChannel('bijou/layer_trial');

/// The pattern speeds the button cycles through; 0 freezes the pattern
/// (Android posts no new frames). 4 is Android's starting speed.
const _speeds = [1, 4, 16, 0];

const _white = Color(0xFFFFFFFF);

class LayerTrialApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bijou layer trial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0x00000000),
        canvasColor: const Color(0x00000000),
      ),
      home: const LayerTrialScreen(),
    );
  }
}

class LayerTrialScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<LayerTrialScreen> createState() => _LayerTrialScreenState();
}

class _LayerTrialScreenState extends State<LayerTrialScreen> {
  var _osdVisible = true;
  var _opaque = false;
  var _speedIndex = 1;
  var _last = 'Nothing pressed yet';
  var _framesLastSecond = 0;
  Timer? _meterTimer;

  @override
  void initState() {
    super.initState();
    _FrameMeter.instance.start();
    _meterTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _meterTimer?.cancel();
    super.dispose();
  }

  void _tick() {
    final frames = _FrameMeter.instance.takeCount();
    if (!mounted || frames == _framesLastSecond) return;
    // Showing the new number costs one frame; the meter leaves it out, so
    // an idle screen settles on 0.
    _FrameMeter.instance.expectOwnFrame();
    setState(() => _framesLastSecond = frames);
  }

  void _say(String message) => setState(() => _last = message);

  /// While the OSD is hidden, any key only brings it back (like the
  /// player): the focused button doesn't see it.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_osdVisible) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      setState(() {
        _osdVisible = true;
        _last = 'OSD back (${event.logicalKey.keyLabel})';
      });
    }
    return KeyEventResult.handled;
  }

  void _hideOsd() {
    setState(() {
      _osdVisible = false;
      _last = 'Hide OSD: any key brings it back';
    });
  }

  void _toggleOpaque() {
    setState(() {
      _opaque = !_opaque;
      _last = _opaque
          ? 'Opaque Flutter: a black full-screen background over the layer'
          : 'Transparent Flutter: the layer shows through';
    });
  }

  Future<void> _cycleSpeed() async {
    final next = (_speedIndex + 1) % _speeds.length;
    setState(() => _speedIndex = next);
    final speed = _speeds[next];
    final reply = await _call('setSpeed', speed);
    if (!mounted) return;
    final frozen = speed == 0 ? ' (frozen: no new frames)' : '';
    _say('Pattern speed $speed$frozen: $reply');
  }

  Future<void> _logState() async {
    final reply = await _call('logState');
    if (!mounted) return;
    _say('Log state: $reply');
  }

  Future<void> _showDialog() async {
    _say('Show dialog: a Flutter dialog over the picture');
    await showDialog<void>(context: context, builder: _dialog);
    if (!mounted) return;
    _say('Dialog closed');
  }

  Widget _dialog(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF202124),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A Flutter dialog over the picture',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Drawn on the same transparent Flutter surface; '
              'the barrier dims the pattern.',
            ),
            const SizedBox(height: 24),
            _TrialButton(
              label: 'Close',
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _call(String method, [Object? argument]) async {
    try {
      final result = await _channel.invokeMethod<Object?>(method, argument);
      return result?.toString() ?? 'ok';
    } on MissingPluginException {
      return 'no layer channel (a build without BIJOU_VIDEO_LAYER=true?)';
    } on PlatformException catch (e) {
      return 'error ${e.code}: ${e.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final speed = _speeds[_speedIndex];
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(color: _white, fontSize: 16),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: Stack(
            children: [
              if (_opaque)
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF000000)),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(framesLastSecond: _framesLastSecond),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_osdVisible,
                  child: AnimatedOpacity(
                    key: const ValueKey('trial-osd'),
                    opacity: _osdVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: _Osd(
                      last: _last,
                      buttons: [
                        _TrialButton(
                          label: 'Hide OSD',
                          autofocus: true,
                          onPressed: _hideOsd,
                        ),
                        _TrialButton(
                          label: 'Opaque Flutter: ${_opaque ? 'on' : 'off'}',
                          onPressed: _toggleOpaque,
                        ),
                        _TrialButton(
                          label: 'Pattern speed: $speed',
                          onPressed: () => unawaited(_cycleSpeed()),
                        ),
                        _TrialButton(
                          label: 'Show dialog',
                          onPressed: () => unawaited(_showDialog()),
                        ),
                        _TrialButton(
                          label: 'Log state',
                          onPressed: () => unawaited(_logState()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const new({required this.framesLastSecond});

  final int framesLastSecond;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: const Color(0xB3000000),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Bijou · video layer trial (T0)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Text('BIJOU_VIDEO_LAYER=$_videoLayerDefine'),
          const SizedBox(width: 24),
          Text('Flutter frames/s: $framesLastSecond'),
        ],
      ),
    );
  }
}

/// The player-like bottom gradient: the last action and the buttons.
class _Osd extends StatelessWidget {
  const new({required this.last, required this.buttons});

  final String last;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xE6000000)],
        ),
      ),
      child: Padding(
        // The TV's logical screen is 960 x 540.
        padding: const EdgeInsets.fromLTRB(32, 80, 32, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              last,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: buttons),
          ],
        ),
      ),
    );
  }
}

/// A D-pad button: arrows reach it, OK / Enter / Select activate it, and
/// focus draws a white ring.
class _TrialButton extends StatefulWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  State<_TrialButton> createState() => _TrialButtonState();
}

class _TrialButtonState extends State<_TrialButton> {
  var _focused = false;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
      onInvoke: _activate,
    ),
  };

  Object? _activate(Intent intent) {
    widget.onPressed();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      actions: _actions,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? const Color(0x40FFFFFF) : const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? _white : const Color(0x00FFFFFF),
              width: 3,
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Counts the frames Flutter draws, leaving out the one frame each change
/// of the on-screen counter costs (so an idle screen reads 0, not 1).
class _FrameMeter {
  new _();

  static final instance = _FrameMeter._();

  var _started = false;
  var _count = 0;
  var _ownFramePending = false;

  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (_ownFramePending) {
        _ownFramePending = false;
        return;
      }
      _count++;
    });
  }

  /// The frames since the last call.
  int takeCount() {
    final count = _count;
    _count = 0;
    return count;
  }

  void expectOwnFrame() => _ownFramePending = true;
}
