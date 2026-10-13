import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/app_slider.dart';
import 'package:iptv_player/design/components/app_tooltip.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/text_scale.dart';
import 'package:iptv_player/design/tokens.dart';

/// Draws [child] larger in a larger window (ADR-017): the OSD is laid out
/// for [AppPlayerTokens.designSize] and scaled up with the picture, so
/// its controls and its words keep their share of the screen. A window
/// smaller than that keeps the drawn sizes.
class OsdScale extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final scale = context.tokens.player.scaleFor(size);
      if (scale == 1 || !size.isFinite) return child;
      final inner = size / scale;
      return FittedBox(
        fit: BoxFit.fill,
        child: SizedBox.fromSize(
          size: inner,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(size: inner),
            child: child,
          ),
        ),
      );
    },
  );
}

/// A control on the full-screen player's OSD (ADR-017): a large tile over
/// the picture, its icon in white, so it reads over any scene and from
/// across a room.
///
/// A control that has a state says it in words beside its icon
/// ([label]: "Subtitles: Off") where its row has room for them
/// ([OsdControlRow]); with no room it is the icon alone and [tooltip]
/// names it. [text] takes the icon's place for a control whose state is
/// its face ("1×"). [primary] is Play / Pause: a size up, round, filled.
class OsdButton extends StatelessWidget {
  const new({
    required this.tooltip,
    this.icon,
    this.text,
    this.label,
    this.shortcut,
    this.onPressed,
    this.selected = false,
    this.primary = false,
    this.focusNode,
    super.key,
  }) : assert(icon != null || text != null, 'an icon or a text face');

  final AppIcons? icon;
  final String? text;
  final String tooltip;
  final String? label;

  /// Shown as a keycap in the tooltip.
  final String? shortcut;
  final VoidCallback? onPressed;

  /// On: subtitles showing, a favorite, the stream info open.
  final bool selected;
  final bool primary;
  final FocusNode? focusNode;

  /// The widest a state's words get before they are cut with "…", at
  /// the canvas's text size.
  static const labelMaxWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final player = tokens.player;
    final size = primary ? player.primarySize : player.controlSize;
    final words = _OsdLabels.of(context) ? label : null;
    final radius = primary ? tokens.radii.pillAll : tokens.radii.mdAll;
    final ink = primary
        ? colors.bg
        : selected
        ? colors.accentHover
        : colors.textPrimary;

    return AppTooltip(
      message: tooltip,
      shortcut: shortcut,
      child: FocusableSurface(
        onPressed: onPressed,
        enabled: onPressed != null,
        focusNode: focusNode,
        borderRadius: radius,
        semanticLabel: label ?? tooltip,
        builder: (context, states) => Opacity(
          opacity: states.disabled ? 0.4 : 1,
          child: AnimatedContainer(
            duration: tokens.motion.fast,
            height: size,
            constraints: BoxConstraints(minWidth: size),
            padding: EdgeInsets.symmetric(
              horizontal: words == null && text == null
                  ? 0
                  : tokens.spacing.s16,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: primary
                  ? (states.pressed ? colors.textEmphasis : colors.textPrimary)
                  : colors.textPrimary.withValues(
                      alpha: states.highlighted || states.pressed
                          ? player.tileActiveOpacity
                          : player.tileOpacity,
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon case final icon?)
                  AppIcon(
                    icon,
                    size: primary ? player.primaryIconSize : player.iconSize,
                    color: ink,
                  )
                else
                  Text(
                    text!,
                    maxLines: 1,
                    style: tokens.text.titleSmall.copyWith(color: ink),
                  ),
                if (words != null) ...[
                  SizedBox(width: tokens.spacing.s8 + 2),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.scaled(labelMaxWidth),
                    ),
                    child: Text(
                      words,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the controls under it say their state in words.
class _OsdLabels extends InheritedWidget {
  const new({required this.show, required super.child});

  final bool show;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OsdLabels>()?.show ?? false;

  @override
  bool updateShouldNotify(_OsdLabels oldWidget) => oldWidget.show != show;
}

/// The OSD's row of controls (ADR-017): [leading] from the left edge —
/// what is used most — and [trailing] at the right. From
/// [AppPlayerTokens.labelsFrom] wide, the controls that have a state say
/// it in words; narrower, every control is its icon. Should the words
/// still not fit (two long track names), [trailing] is drawn a little
/// smaller rather than cut.
class OsdControlRow extends StatelessWidget {
  const new({required this.leading, required this.trailing, super.key});

  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final player = context.tokens.player;
    List<Widget> spaced(List<Widget> controls) => [
      for (final (i, control) in controls.indexed) ...[
        if (i > 0) SizedBox(width: player.controlGap),
        control,
      ],
    ];
    // Two labels at most are long (Audio, Subtitles): larger text asks
    // for that much more room before the words show.
    final grown =
        2 * (context.scaled(OsdButton.labelMaxWidth) - OsdButton.labelMaxWidth);
    return LayoutBuilder(
      builder: (context, constraints) => _OsdLabels(
        show: constraints.maxWidth >= player.labelsFrom + grown,
        child: Row(
          children: [
            ...spaced(leading),
            SizedBox(width: player.groupGap),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: spaced(trailing),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The OSD's volume (ADR-017): Mute and the level in one tile. The
/// button is the keyboard's stop (its keys change the level from
/// anywhere in the player); the slider is the mouse's, and the wheel
/// over it turns the volume too.
class OsdVolume extends StatelessWidget {
  const new({
    required this.volume,
    required this.muted,
    required this.onToggleMute,
    required this.onChanged,
    this.shortcut,
    this.focusNode,
    super.key,
  });

  /// 0–100.
  final double volume;
  final bool muted;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onChanged;
  final String? shortcut;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final player = tokens.player;
    final silent = muted || volume <= 0;
    final level = '${volume.round()}%';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: tokens.radii.mdAll,
        color: colors.textPrimary.withValues(alpha: player.tileOpacity),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTooltip(
            message: silent ? 'Unmute' : 'Mute',
            shortcut: shortcut,
            child: FocusableSurface(
              onPressed: onToggleMute,
              focusNode: focusNode,
              borderRadius: tokens.radii.mdAll,
              hoverBackground: colors.textPrimary.withValues(
                alpha: player.tileActiveOpacity - player.tileOpacity,
              ),
              semanticLabel: silent ? 'Unmute' : 'Mute, volume $level',
              builder: (context, states) => SizedBox.square(
                dimension: player.controlSize,
                child: Center(
                  child: AppIcon(
                    silent
                        ? AppIcons.volumeOff
                        : volume < 50
                        ? AppIcons.volumeLow
                        : AppIcons.volumeHigh,
                    size: player.iconSize,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          // The level is the keyboard's through the player's own keys:
          // the bar is for the mouse, not a Tab stop of its own.
          ExcludeFocus(
            child: Listener(
              onPointerSignal: (signal) {
                if (signal is! PointerScrollEvent) return;
                final step = signal.scrollDelta.dy < 0 ? 5.0 : -5.0;
                onChanged((volume + step).clamp(0, 100).toDouble());
              },
              child: SizedBox(
                width: player.volumeWidth,
                child: AppSlider(
                  value: silent ? 0 : volume / 100,
                  compact: true,
                  overVideo: true,
                  activeColor: colors.textPrimary,
                  semanticLabel: 'Volume',
                  onChanged: (value) => onChanged(value * 100),
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.s8),
        ],
      ),
    );
  }
}

/// Play, in the middle of a paused picture (ADR-017): what a click on
/// the picture does, drawn where the eye is. The mouse's; the keyboard
/// has Space and the Play button under the seek bar.
class OsdCenterPlay extends StatelessWidget {
  const new({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final player = tokens.player;
    // One Play for a screen reader and for the keyboard: the button under
    // the seek bar.
    return ExcludeSemantics(
      child: FocusableSurface(
        onPressed: onPressed,
        canRequestFocus: false,
        borderRadius: tokens.radii.pillAll,
        semanticButton: false,
        builder: (context, states) => AnimatedContainer(
          duration: tokens.motion.fast,
          width: player.centerPlaySize,
          height: player.centerPlaySize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.video.withValues(
              alpha: states.hovered ? 0.75 : player.centerPlayOpacity,
            ),
            border: Border.all(
              color: colors.textPrimary.withValues(alpha: 0.9),
              width: 2,
            ),
          ),
          child: AppIcon(
            AppIcons.play,
            size: player.centerPlayIconSize,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
