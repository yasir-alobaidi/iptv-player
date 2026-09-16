import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// Volume and seek control. With [bubbleLabel] set it shows a time bubble
/// above the thumb while dragging, which is how the player seeks
/// (docs/05).
class AppSlider extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.bubbleLabel,
    this.bufferedValue,
    this.semanticLabel,
    this.enabled = true,
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
  final String? semanticLabel;
  final bool enabled;
  final FocusNode? focusNode;

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
    final showBubble = widget.bubbleLabel != null && (_dragging || _hovered);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            child: showBubble
                ? Align(
                    alignment: Alignment(widget.value * 2 - 1, 0),
                    child: _Bubble(label: widget.bubbleLabel!(widget.value)),
                  )
                : null,
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: colors.accentBase,
              inactiveTrackColor: colors.border,
              secondaryActiveTrackColor: colors.borderStrong,
              thumbColor: colors.textPrimary,
              overlayColor: colors.accentBase.withValues(
                alpha: tokens.focus.glowOpacity,
              ),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.colors.surface3,
        borderRadius: tokens.radii.xsAll,
        border: Border.all(color: tokens.colors.border),
      ),
      child: Text(
        label,
        style: tokens.text.monoMicro.copyWith(color: tokens.colors.textPrimary),
      ),
    );
  }
}
