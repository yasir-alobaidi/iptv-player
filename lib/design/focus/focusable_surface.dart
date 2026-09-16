import 'package:flutter/material.dart';
import 'package:iptv_player/design/focus/app_intents.dart';
import 'package:iptv_player/design/focus/focus_ring.dart';
import 'package:iptv_player/design/tokens.dart';

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
/// invisible.
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
    this.growth = FocusGrowth.none,
    this.semanticLabel,
    this.semanticButton = true,
    this.mouseCursor,
    this.canRequestFocus = true,
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
    FocusGrowth growth = FocusGrowth.none,
    String? semanticLabel,
    bool semanticButton = true,
    MouseCursor? mouseCursor,
    bool canRequestFocus = true,
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
    growth: growth,
    semanticLabel: semanticLabel,
    semanticButton: semanticButton,
    mouseCursor: mouseCursor,
    canRequestFocus: canRequestFocus,
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
  final FocusGrowth growth;
  final String? semanticLabel;
  final bool semanticButton;
  final MouseCursor? mouseCursor;
  final bool canRequestFocus;

  /// A disabled element is never focusable (hard rule 5's counterpart: it
  /// must not be a dead stop in the tab order).
  bool get _interactive => enabled && onPressed != null;

  @override
  State<FocusableSurface> createState() => _FocusableSurfaceState();
}

class _FocusableSurfaceState extends State<FocusableSurface> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  void _activate() {
    if (!widget._interactive) return;
    widget.onPressed?.call();
  }

  void _menu() {
    if (!widget.enabled) return;
    widget.onMenu?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final focus = tokens.focus;
    final motion = tokens.motion;
    final radius = widget.borderRadius ?? tokens.radii.controlAll;
    final disabled = !widget.enabled;

    final states =
        SurfaceStateOverride.maybeOf(context) ??
        SurfaceStates(
          focused: _focused,
          hovered: _hovered,
          pressed: _pressed,
          disabled: disabled,
        );

    final ringColor = widget.onAccent ? colors.textPrimary : colors.accentBase;
    final glowColor = colors.accentBase.withValues(
      alpha: widget.onAccent ? focus.onAccentGlowOpacity : focus.glowOpacity,
    );
    final glowWidth = widget.onAccent
        ? focus.onAccentGlowWidth
        : focus.glowWidth;

    final background = states.hovered && !states.disabled
        ? (widget.hoverBackground ?? widget.background)
        : widget.background;

    final scale =
        states.focused && widget.growth == FocusGrowth.tile && motion.allowScale
        ? focus.tileScale
        : 1.0;

    Widget surface = FocusRing(
      visible: states.focused,
      borderRadius: radius,
      ringColor: ringColor,
      glowColor: glowColor,
      ringWidth: focus.ringWidth,
      glowWidth: glowWidth,
      duration: motion.fast,
      curve: motion.fastCurve,
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

    return FocusableActionDetector(
      enabled: widget._interactive && widget.canRequestFocus,
      focusNode: widget.focusNode,
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
        if (value != _focused) setState(() => _focused = value);
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
          onTapDown: widget._interactive
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: widget._interactive
              ? (_) => setState(() => _pressed = false)
              : null,
          onTapCancel: widget._interactive
              ? () => setState(() => _pressed = false)
              : null,
          child: surface,
        ),
      ),
    );
  }
}
