import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iptv_player/design/components/app_button.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// Below it, every [SegmentedControl] fills the width it is given (a
/// phone's settings, ADR-068): its segments share each line, at least a
/// touch target high, and wrap onto a second line rather than leave one
/// out of sight.
class SegmentedFill extends InheritedWidget {
  const new({required super.child, this.fill = true, super.key});

  final bool fill;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SegmentedFill>()?.fill ??
      false;

  @override
  bool updateShouldNotify(SegmentedFill oldWidget) => oldWidget.fill != fill;
}

/// One option in a [SegmentedControl].
@immutable
class SegmentOption<T> {
  const new({
    required this.value,
    required this.label,
    this.icon,
    this.count,
    this.swatch,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// A dot of this color before the label (Settings → Appearance's
  /// accents).
  final Color? swatch;

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
    this.fill,
    super.key,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  /// Fills the width it is given, the segments sharing it at a touch
  /// target's height; null: as the [SegmentedFill] above says.
  final bool? fill;

  /// A segment's height when the control fills its width: a finger's.
  static const double touchHeight = touchTargetSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    if (fill ?? SegmentedFill.of(context)) {
      return Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: tokens.radii.smAll,
            border: Border.all(color: colors.border),
          ),
          child: _FilledSegments(
            spacing: 2,
            minHeight: touchHeight,
            children: [
              for (final option in options)
                _Segment<T>(
                  option: option,
                  selected: option.value == value,
                  filled: true,
                  onPressed: enabled ? () => onChanged(option.value) : null,
                ),
            ],
          ),
        ),
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: tokens.radii.smAll,
          border: Border.all(color: colors.border),
        ),
        // One line wherever it fits; where it doesn't (larger text, a
        // narrow window) the segments wrap rather than clip.
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final option in options)
              _Segment<T>(
                option: option,
                selected: option.value == value,
                onPressed: enabled ? () => onChanged(option.value) : null,
              ),
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
    this.filled = false,
  });

  final SegmentOption<T> option;
  final bool selected;
  final VoidCallback? onPressed;

  /// In a control that fills its width: the label centred in the room the
  /// segment is given, wrapping when even a line of its own is too narrow.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final label = Text(
      option.label,
      textAlign: filled ? TextAlign.center : null,
      style: tokens.text.labelSmall
          .withWeight(700)
          .copyWith(
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
    );

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (option.swatch != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: option.swatch,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: tokens.spacing.s4 + 2),
            ],
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 14,
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
              SizedBox(width: tokens.spacing.s4 + 2),
            ],
            if (filled) Flexible(child: label) else label,
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

/// The segments of a control that fills its width: as many to a line as
/// fit at their own widths, each line's room shared out — evenly when
/// every segment of the line fits an even share — and every segment at
/// least [minHeight] high. A segment wider than a line has the line.
class _FilledSegments extends MultiChildRenderObjectWidget {
  const new({
    required this.spacing,
    required this.minHeight,
    required super.children,
  });

  final double spacing;
  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFilledSegments(spacing: spacing, minHeight: minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderFilledSegments renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..minHeight = minHeight;
  }
}

class _FilledParentData extends ContainerBoxParentData<RenderBox>;

typedef _Placed = ({RenderBox box, double natural});

class _RenderFilledSegments extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FilledParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FilledParentData> {
  new({required this._spacing, required this._minHeight});

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _minHeight;
  double get minHeight => _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FilledParentData) {
      child.parentData = _FilledParentData();
    }
  }

  List<RenderBox> get _segments {
    final segments = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      segments.add(child);
      child = childAfter(child);
    }
    return segments;
  }

  /// The segments each line [width] wide holds, in order, with their own
  /// widths.
  List<List<_Placed>> _lines(double width) {
    final lines = <List<_Placed>>[];
    var line = <_Placed>[];
    var used = 0.0;
    for (final box in _segments) {
      final natural = box.getMaxIntrinsicWidth(double.infinity);
      if (line.isNotEmpty && used + _spacing + natural > width) {
        lines.add(line);
        line = [];
      }
      used = line.isEmpty ? natural : used + _spacing + natural;
      line.add((box: box, natural: natural));
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  /// Each segment's width in a [line] [width] wide.
  List<double> _widths(List<_Placed> line, double width) {
    final gaps = _spacing * (line.length - 1);
    final share = (width - gaps) / line.length;
    if (line.every((segment) => segment.natural <= share)) {
      return [for (final _ in line) share];
    }
    final natural = line.fold<double>(0, (sum, s) => sum + s.natural);
    final extra = (width - gaps - natural) / line.length;
    return [
      for (final segment in line) (segment.natural + extra).clamp(0.0, width),
    ];
  }

  double _widthFor(BoxConstraints constraints) => constraints.hasBoundedWidth
      ? constraints.maxWidth
      : computeMaxIntrinsicWidth(double.infinity);

  /// Lays the segments out (or, [dry], only measures them) and returns the
  /// height they take at [width].
  double _layOut(double width, {required bool dry}) {
    var top = 0.0;
    for (final (index, line) in _lines(width).indexed) {
      if (index > 0) top += _spacing;
      final widths = _widths(line, width);
      var tallest = _minHeight;
      final heights = <double>[];
      for (final (i, segment) in line.indexed) {
        final constraints = BoxConstraints(
          minWidth: widths[i],
          maxWidth: widths[i],
          minHeight: _minHeight,
        );
        final double height;
        if (dry) {
          height = segment.box.getDryLayout(constraints).height;
        } else {
          segment.box.layout(constraints, parentUsesSize: true);
          height = segment.box.size.height;
        }
        heights.add(height);
        if (height > tallest) tallest = height;
      }
      if (!dry) {
        var left = 0.0;
        for (final (i, segment) in line.indexed) {
          (segment.box.parentData! as _FilledParentData).offset = Offset(
            left,
            top + (tallest - heights[i]) / 2,
          );
          left += widths[i] + _spacing;
        }
      }
      top += tallest;
    }
    return top;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var widest = 0.0;
    for (final box in _segments) {
      final width = box.getMinIntrinsicWidth(height);
      if (width > widest) widest = width;
    }
    return widest;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final segments = _segments;
    if (segments.isEmpty) return 0;
    var sum = _spacing * (segments.length - 1);
    for (final box in segments) {
      sum += box.getMaxIntrinsicWidth(height);
    }
    return sum;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final room = width.isFinite
        ? width
        : computeMaxIntrinsicWidth(double.infinity);
    var height = 0.0;
    for (final (index, line) in _lines(room).indexed) {
      final widths = _widths(line, room);
      var tallest = _minHeight;
      for (final (i, segment) in line.indexed) {
        final h = segment.box.getMaxIntrinsicHeight(widths[i]);
        if (h > tallest) tallest = h;
      }
      height += tallest + (index == 0 ? 0 : _spacing);
    }
    return height;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final width = _widthFor(constraints);
    return constraints.constrain(Size(width, _layOut(width, dry: true)));
  }

  @override
  void performLayout() {
    final width = _widthFor(constraints);
    size = constraints.constrain(Size(width, _layOut(width, dry: false)));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
