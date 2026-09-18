import 'package:flutter/material.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// One option in a [SegmentedControl].
@immutable
class SegmentOption<T> {
  const new({required this.value, required this.label, this.icon, this.count});

  final T value;
  final String label;
  final IconData? icon;

  /// A quieter figure after the label (canvas: "Live TV 412").
  final String? count;
}

/// A small group of mutually exclusive options (canvas: the No. / A–Z
/// sort switch). Each segment is separately focusable.
class SegmentedControl<T> extends StatelessWidget {
  const new({
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: tokens.radii.smAll,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options) ...[
              if (option != options.first) const SizedBox(width: 2),
              _Segment<T>(
                option: option,
                selected: option.value == value,
                onPressed: enabled ? () => onChanged(option.value) : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const new({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  final SegmentOption<T> option;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return FocusableSurface(
      onPressed: onPressed,
      enabled: onPressed != null,
      background: selected ? colors.border : null,
      hoverBackground: selected ? colors.border : colors.surface3,
      borderRadius: tokens.radii.xsAll,
      semanticLabel: option.count == null
          ? option.label
          : '${option.label}, ${option.count}',
      builder: (context, states) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.s8 + 2,
          vertical: tokens.spacing.s4 + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 14,
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
              SizedBox(width: tokens.spacing.s4 + 2),
            ],
            Text(
              option.label,
              style: tokens.text.labelSmall.copyWith(
                color: selected ? colors.textPrimary : colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (option.count != null) ...[
              SizedBox(width: tokens.spacing.s4 + 2),
              Text(
                option.count!,
                style: tokens.text.labelSmall.copyWith(
                  color: selected ? colors.textSecondary : colors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
