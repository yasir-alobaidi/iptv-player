import 'package:flutter/material.dart';
import 'package:iptv_player/design/text_scale.dart';
import 'package:iptv_player/design/tokens.dart';

/// Volume and seek control. With [bubbleLabel] set it shows a time bubble
/// above the thumb while dragging or hovered, which is how the player
/// seeks (docs/05), and whenever [showBubble] says so (the player's seek
/// keys).
class AppSlider extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.bubbleLabel,
    this.bufferedValue,
    this.showBubble = false,
    this.semanticLabel,
    this.enabled = true,
    this.compact = false,
    this.overVideo = false,
    this.activeColor,
    this.focusNode,
    super.key,
  });

  /// 0..1.
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Formats the bubble text, e.g. `(v) => '01:12:04'`. Null hides it.
  final String Function(double value)? bubbleLabel;

  /// How much of the stream the relay has ready, 0..1.
  final double? bufferedValue;

  /// Shows the bubble without a drag or a hover.
  final bool showBubble;
  final String? semanticLabel;
  final bool enabled;

  /// No room kept above for the bubble: a volume slider in a row.
  final bool compact;

  /// On the player's OSD (ADR-017): a thicker track and a larger thumb
  /// and bubble, and a track that shows over any picture.
  final bool overVideo;

  /// The filled part; the accent when null.
  final Color? activeColor;
  final FocusNode? focusNode;

  /// The room an [overVideo] slider keeps above its bar for the bubble.
  static double bubbleRoom(BuildContext context) => context.scaled(28);

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  bool _dragging = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final player = tokens.player;
    final over = widget.overVideo;
    final showBubble =
        widget.bubbleLabel != null &&
        (_dragging || _hovered || widget.showBubble);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.compact)
            SizedBox(
              height: over ? AppSlider.bubbleRoom(context) : 20,
              child: showBubble
                  ? Align(
                      alignment: Alignment(widget.value * 2 - 1, 0),
                      child: _Bubble(
                        label: widget.bubbleLabel!(widget.value),
                        large: over,
                      ),
                    )
                  : null,
            ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: over ? player.seekTrackHeight : 4,
              activeTrackColor: widget.activeColor ?? colors.accentBase,
              inactiveTrackColor: over
                  ? colors.textPrimary.withValues(alpha: player.tileOpacity * 2)
                  : colors.border,
              secondaryActiveTrackColor: over
                  ? colors.textPrimary.withValues(alpha: player.tileOpacity * 4)
                  : colors.borderStrong,
              thumbColor: colors.textPrimary,
              overlayColor: colors.accentBase.withValues(
                alpha: tokens.focus.glowOpacity,
              ),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: over ? player.seekThumbRadius : 7,
              ),
              overlayShape: RoundSliderOverlayShape(
                overlayRadius: over ? player.seekHaloRadius : 14,
              ),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: widget.value.clamp(0, 1),
              secondaryTrackValue: widget.bufferedValue?.clamp(0, 1),
              focusNode: widget.focusNode,
              label: widget.semanticLabel,
              onChanged: widget.enabled ? widget.onChanged : null,
              onChangeStart: (_) => setState(() => _dragging = true),
              onChangeEnd: (value) {
                setState(() => _dragging = false);
                widget.onChangeEnd?.call(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const new({required this.label, this.large = false});

  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = large ? tokens.text.mono : tokens.text.monoMicro;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? tokens.spacing.s12 : tokens.spacing.s8,
        vertical: large ? tokens.spacing.s4 : 2,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surface3,
        borderRadius: tokens.radii.xsAll,
        border: Border.all(color: tokens.colors.border),
      ),
      child: Text(
        label,
        style: style.copyWith(color: tokens.colors.textPrimary),
      ),
    );
  }
}
