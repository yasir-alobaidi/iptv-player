import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iptv_player/design/focus/app_intents.dart';
import 'package:iptv_player/design/focus/focus_ring.dart';
import 'package:iptv_player/design/focus/focus_visibility.dart';
import 'package:iptv_player/design/tokens.dart';

export 'package:iptv_player/design/focus/focus_ring.dart'
    show AppFocusRing, RingPlacement;

/// The arrows' and Tab's move to [node], every traversal policy's
/// `requestFocusCallback` ([appTraversalPolicy]). A [FocusableSurface]
/// scrolls itself into view, its ring and margin with it, in one
/// animation (its reveal); Flutter's own callback first jumps the view to
/// the control's edge, so each move was a jump and then a glide (the
/// user, on the Bedroom TV: moving between posters "like jumping").
/// Anything else is scrolled to as Flutter does, animated.
void revealingFocus(
  FocusNode node, {
  double? alignment,
  ScrollPositionAlignmentPolicy? alignmentPolicy,
  Curve? curve,
  Duration? duration,
}) {
  if (_surfaceNodes[node] ?? false) {
    node.requestFocus();
    return;
  }
  final motion = node.context?.tokens.motion;
  FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
    node,
    alignment: alignment,
    alignmentPolicy: alignmentPolicy,
    curve: curve ?? motion?.baseCurve ?? Curves.ease,
    duration: duration ?? motion?.base ?? Duration.zero,
  );
}

/// The traversal policy of every pane and group: reading order, moved by
/// [revealingFocus].
FocusTraversalPolicy appTraversalPolicy() =>
    ReadingOrderTraversalPolicy(requestFocusCallback: revealingFocus);

/// The pointers a long press opens a control's menu for: a finger or a
/// pen, never a mouse (ADR-068).
const Set<PointerDeviceKind> _touch = {
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

/// The nodes [FocusableSurface]s focus by, which reveal themselves.
final _surfaceNodes = Expando<bool>('FocusableSurface');

/// What a focused control inside brings into view with it, above it: a
/// row of cards' heading (Home). Back on a row, the TV showed its card
/// with the heading half under the top bar (ADR-029).
class RevealArea extends SingleChildRenderObjectWidget {
  const new({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRevealArea();
}

class _RenderRevealArea extends RenderProxyBox;

/// The interaction states a [FocusableSurface] passes to its builder.
@immutable
class SurfaceStates {
  const new({
    this.focused = false,
    this.hovered = false,
    this.pressed = false,
    this.disabled = false,
  });

  final bool focused;
  final bool hovered;
  final bool pressed;
  final bool disabled;

  /// True when the element should look raised — hovered by the mouse or
  /// focused by the keyboard.
  bool get highlighted => (focused || hovered) && !disabled;

  @override
  bool operator ==(Object other) =>
      other is SurfaceStates &&
      other.focused == focused &&
      other.hovered == hovered &&
      other.pressed == pressed &&
      other.disabled == disabled;

  @override
  int get hashCode => Object.hash(focused, hovered, pressed, disabled);
}

/// Forces the interaction states of every [FocusableSurface] below it,
/// so a state sheet can show hover, focus and pressed side by side. Only
/// the Component Gallery and goldens use this; real screens never do.
class SurfaceStateOverride extends InheritedWidget {
  const new({required this.states, required super.child, super.key});

  final SurfaceStates states;

  static SurfaceStates? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SurfaceStateOverride>()
      ?.states;

  @override
  bool updateShouldNotify(SurfaceStateOverride oldWidget) =>
      oldWidget.states != states;
}

/// How a focused surface grows (docs/05: tiles and cards scale to 1.03,
/// rows stay at 1.0).
enum FocusGrowth { none, tile }

/// Wraps every interactive element: focus and hover handling, Enter/Space
/// activation, the item menu, and the design system's focus ring (2 px
/// accent ring + 4 px glow at 25 %).
///
/// On an accent-filled surface pass `onAccent: true`; the ring inverts to
/// the primary text color, because an accent ring on an accent button is
/// invisible. On a surface filled with the text color pass `onLight: true`
/// for the same reason: a TV's white ring is the accent there.
class FocusableSurface extends StatefulWidget {
  const new({
    required this.builder,
    this.onPressed,
    this.onMenu,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.borderRadius,
    this.background,
    this.hoverBackground,
    this.onAccent = false,
    this.onLight = false,
    this.growth = FocusGrowth.none,
    this.semanticLabel,
    this.semanticButton = true,
    this.mouseCursor,
    this.canRequestFocus = true,
    this.focusOnPress = true,
    this.ring = true,
    this.ringPlacement = RingPlacement.outside,
    super.key,
  });

  /// Convenience constructor for a fixed child that does not change with
  /// the interaction state.
  factory child({
    required Widget child,
    VoidCallback? onPressed,
    VoidCallback? onMenu,
    FocusNode? focusNode,
    bool autofocus = false,
    bool enabled = true,
    BorderRadius? borderRadius,
    Color? background,
    Color? hoverBackground,
    bool onAccent = false,
    bool onLight = false,
    FocusGrowth growth = FocusGrowth.none,
    String? semanticLabel,
    bool semanticButton = true,
    MouseCursor? mouseCursor,
    bool canRequestFocus = true,
    bool focusOnPress = true,
    RingPlacement ringPlacement = RingPlacement.outside,
    Key? key,
  }) => FocusableSurface(
    key: key,
    builder: (_, _) => child,
    onPressed: onPressed,
    onMenu: onMenu,
    focusNode: focusNode,
    autofocus: autofocus,
    enabled: enabled,
    borderRadius: borderRadius,
    background: background,
    hoverBackground: hoverBackground,
    onAccent: onAccent,
    onLight: onLight,
    growth: growth,
    semanticLabel: semanticLabel,
    semanticButton: semanticButton,
    mouseCursor: mouseCursor,
    canRequestFocus: canRequestFocus,
    focusOnPress: focusOnPress,
    ringPlacement: ringPlacement,
  );

  final Widget Function(BuildContext context, SurfaceStates states) builder;
  final VoidCallback? onPressed;
  final VoidCallback? onMenu;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final BorderRadius? borderRadius;
  final Color? background;
  final Color? hoverBackground;
  final bool onAccent;
  final bool onLight;
  final FocusGrowth growth;
  final String? semanticLabel;
  final bool semanticButton;
  final MouseCursor? mouseCursor;
  final bool canRequestFocus;

  /// Whether a press of a pointer puts the keyboard's focus here, where a
  /// press hides the rings ([FocusVisibility]). Off on the player's
  /// controls: its keys are the picture's (Space pauses, the arrows
  /// seek), and a click on Subtitles would leave Space opening its menu.
  final bool focusOnPress;

  /// The focus ring. Off where the control draws its focus itself: the
  /// TV's keyboard keys (ADR-026: neighbours 6 px away), a card that
  /// rings its picture and not its caption (ADR-029).
  final bool ring;

  /// The ring outside the control, or inside it for a row that fills its
  /// list (ADR-029).
  final RingPlacement ringPlacement;

  /// A disabled element is never focusable (hard rule 5's counterpart: it
  /// must not be a dead stop in the tab order).
  bool get _interactive => enabled && onPressed != null;

  @override
  State<FocusableSurface> createState() => _FocusableSurfaceState();
}

class _FocusableSurfaceState extends State<FocusableSurface> {
  /// The focus is here (the highlight Flutter would show).
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  /// The node when the widget gives none: [revealingFocus] knows a
  /// surface by its node.
  FocusNode? _ownNode;

  FocusNode get _node =>
      widget.focusNode ??
      (_ownNode ??= FocusNode(debugLabel: 'FocusableSurface'));

  @override
  void dispose() {
    FocusVisibility.shown.removeListener(_onShown);
    _ownNode?.dispose();
    super.dispose();
  }

  /// The focus is here and shows: on a desktop, only while the keyboard
  /// is in use ([FocusVisibility]).
  bool get _focusShown => _focused && FocusVisibility.shown.value;

  /// The rings came or went while the focus is here. Nothing scrolls for
  /// it: the key that brought them back may move the focus a frame later
  /// (a grid's PageDown), and the control it lands on reveals itself.
  void _onShown() {
    if (mounted) setState(() {});
  }

  /// A press takes the focus, so the keys go on from the control clicked
  /// (and its pane remembers it), its ring hidden until a key.
  void _focusFromPointer() {
    if (!FocusVisibility.installed || !widget.focusOnPress) return;
    final node = _node;
    if (node.canRequestFocus && !node.hasPrimaryFocus) node.requestFocus();
  }

  void _activate() {
    if (!widget._interactive) return;
    widget.onPressed?.call();
  }

  void _menu() {
    if (!widget.enabled) return;
    widget.onMenu?.call();
  }

  /// A finger held on the control (ADR-068): its menu, as the desktop's
  /// right-click and the TV's held OK open it. The keyboard's focus comes
  /// here first, so it is back here when the menu closes.
  void _longPress() {
    if (!widget.enabled || widget.onMenu == null) return;
    unawaited(Feedback.forLongPress(context));
    _focusFromPointer();
    _menu();
  }

  /// Scrolls the focused control into view with its ring, its growth and
  /// [AppFocusTokens.revealMargin] round it: the traversal's own scroll
  /// stops at the control's edge, which left the ring cut off by the
  /// screen or a row's edge (ADR-029).
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusShown) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final focus = context.tokens.focus;
      final size = box.size;
      final reach = switch ((widget.ring, widget.ringPlacement)) {
        _ when widget.growth == FocusGrowth.tile => focus.tileReach(
          size.longestSide,
        ),
        (true, RingPlacement.outside) => focus.reach,
        _ => 0.0,
      };
      final margin = reach + focus.revealMargin;
      var rect = (Offset.zero & size).inflate(margin);
      // What the control comes with, above it: its row's heading.
      final area = context.findAncestorRenderObjectOfType<_RenderRevealArea>();
      if (area != null && area.attached && area.hasSize) {
        final top = box.globalToLocal(area.localToGlobal(Offset.zero)).dy;
        if (top < rect.top) {
          rect = Rect.fromLTRB(rect.left, top, rect.right, rect.bottom);
        }
      }
      // Always, even with no margin: the arrows' move leaves the scroll
      // to this ([revealingFocus]).
      box.showOnScreen(
        rect: rect,
        duration: context.tokens.motion.base,
        curve: context.tokens.motion.baseCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final focus = tokens.focus;
    final motion = tokens.motion;
    final radius = widget.borderRadius ?? tokens.radii.controlAll;
    final disabled = !widget.enabled;

    final states =
        SurfaceStateOverride.maybeOf(context) ??
        SurfaceStates(
          focused: _focusShown,
          hovered: _hovered,
          pressed: _pressed,
          disabled: disabled,
        );

    final background = states.hovered && !states.disabled
        ? (widget.hoverBackground ?? widget.background)
        : widget.background;

    final scale =
        states.focused && widget.growth == FocusGrowth.tile && motion.allowScale
        ? focus.tileScale
        : 1.0;

    Widget surface = AppFocusRing(
      visible: states.focused && widget.ring,
      borderRadius: radius,
      onAccent: widget.onAccent,
      onLight: widget.onLight,
      placement: widget.ringPlacement,
      child: AnimatedContainer(
        duration: motion.fast,
        curve: motion.fastCurve,
        decoration: BoxDecoration(color: background, borderRadius: radius),
        child: widget.builder(context, states),
      ),
    );

    if (scale != 1.0) {
      surface = AnimatedScale(
        scale: scale,
        duration: motion.fast,
        curve: motion.fastCurve,
        child: surface,
      );
    }

    final node = _node;
    _surfaceNodes[node] = true;
    return FocusableActionDetector(
      enabled: widget._interactive && widget.canRequestFocus,
      focusNode: node,
      autofocus: widget.autofocus,
      mouseCursor:
          widget.mouseCursor ??
          (widget._interactive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic),
      shortcuts: AppShortcuts.surface,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
        AppMenuIntent: CallbackAction<AppMenuIntent>(
          onInvoke: (_) {
            _menu();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) {
        if (value == _focused) return;
        setState(() => _focused = value);
        // Only the focused surface hears the rings come and go.
        if (value) {
          FocusVisibility.shown.addListener(_onShown);
        } else {
          FocusVisibility.shown.removeListener(_onShown);
        }
        // Not for a click: the control clicked stays where it is.
        if (_focusShown) _reveal();
      },
      onShowHoverHighlight: (value) {
        if (value != _hovered) setState(() => _hovered = value);
      },
      child: Semantics(
        label: widget.semanticLabel,
        button: widget.semanticButton,
        enabled: widget.enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget._interactive ? _activate : null,
          onSecondaryTap: widget.onMenu == null ? null : _menu,
          // A right-click too: the menu closed, the focus is back here.
          onSecondaryTapDown: widget.onMenu == null
              ? null
              : (_) => _focusFromPointer(),
          onTapDown: widget._interactive
              ? (_) {
                  _focusFromPointer();
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: widget._interactive
              ? (_) => setState(() => _pressed = false)
              : null,
          onTapCancel: widget._interactive
              ? () => setState(() => _pressed = false)
              : null,
          // A long press only by touch or a pen: a mouse held down is
          // still a click, and with no menu nothing joins the arena, so
          // the mouse, the keyboard and a TV's remote are as before.
          child: GestureDetector(
            supportedDevices: _touch,
            onLongPress: widget.onMenu == null ? null : _longPress,
            child: surface,
          ),
        ),
      ),
    );
  }
}
