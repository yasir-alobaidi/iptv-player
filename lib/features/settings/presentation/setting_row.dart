import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// Whether Settings shows one pane at a time (a phone's width, ADR-068):
/// a section's rows then put their control under their words, and its
/// segmented controls fill the width at a touch target's height.
class SettingsOnePane extends InheritedWidget {
  const new({required this.onePane, required super.child, super.key});

  final bool onePane;

  /// False outside Settings' one pane: the desktop's and the TV's rows.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsOnePane>()?.onePane ??
      false;

  @override
  bool updateShouldNotify(SettingsOnePane oldWidget) =>
      oldWidget.onePane != onePane;
}

/// One setting: its name and what it does on the left, the control on
/// the right (Settings → Playback's layout). Where the two no longer fit
/// side by side, at larger text or in a narrow window, the control goes
/// under the words; it never clips (Phase 9 decision 3). In Settings' one
/// pane (a phone) the control is always under them ([StackedSetting]).
class SettingRow extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.control,
    super.key,
  });

  final String title;
  final String description;
  final Widget control;

  /// The words keep at least this much room beside the control, grown
  /// with the text.
  static const _wordsMinWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    if (SettingsOnePane.of(context)) {
      return StackedSetting(
        title: title,
        description: Text(
          description,
          style: tokens.text.caption.copyWith(color: colors.textTertiary),
        ),
        control: control,
      );
    }
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tokens.text.label.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: tokens.spacing.s4),
        Text(
          description,
          style: tokens.text.caption.copyWith(color: colors.textTertiary),
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: _SideBySide(
        minFirst: context.scaled(_wordsMinWidth),
        gap: tokens.spacing.s24,
        stackedGap: tokens.spacing.s12,
        first: words,
        second: control,
      ),
    );
  }
}

/// A setting on a phone's width (Settings' one pane, ADR-068): its title
/// and what it does, then its control under them, at the left and never
/// wider than the row; a segmented control fills the row
/// ([SegmentedFill]), its options all in sight.
class StackedSetting extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.control,
    this.padding,
    super.key,
  });

  final String title;
  final Widget description;
  final Widget control;

  /// Above and below the row; 16 px unless given.
  final double? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      padding: EdgeInsets.symmetric(vertical: padding ?? tokens.spacing.s16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: tokens.text.label.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: tokens.spacing.s4),
          description,
          SizedBox(height: tokens.spacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedFill(child: control),
          ),
        ],
      ),
    );
  }
}

/// [first] takes the room [second] leaves, on one line; when that would
/// leave [first] under [minFirst], [second] goes under it instead.
class _SideBySide extends StatelessWidget {
  const new({
    required this.first,
    required this.second,
    required this.minFirst,
    required this.gap,
    required this.stackedGap,
  });

  final Widget first;
  final Widget second;
  final double minFirst;
  final double gap;
  final double stackedGap;

  @override
  Widget build(BuildContext context) => _SideBySideLayout(
    minFirst: minFirst,
    gap: gap,
    stackedGap: stackedGap,
    children: [first, second],
  );
}

class _SideBySideLayout extends MultiChildRenderObjectWidget {
  const new({
    required this.minFirst,
    required this.gap,
    required this.stackedGap,
    required super.children,
  });

  final double minFirst;
  final double gap;
  final double stackedGap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSideBySide(minFirst: minFirst, gap: gap, stackedGap: stackedGap);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSideBySide renderObject,
  ) {
    renderObject
      ..minFirst = minFirst
      ..gap = gap
      ..stackedGap = stackedGap;
  }
}

class _SideParentData extends ContainerBoxParentData<RenderBox>;

class _RenderSideBySide extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SideParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SideParentData> {
  new({required this._minFirst, required this._gap, required this._stackedGap});

  double _minFirst;
  double get minFirst => _minFirst;
  set minFirst(double value) {
    if (value == _minFirst) return;
    _minFirst = value;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _stackedGap;
  double get stackedGap => _stackedGap;
  set stackedGap(double value) {
    if (value == _stackedGap) return;
    _stackedGap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SideParentData) {
      child.parentData = _SideParentData();
    }
  }

  @override
  void performLayout() {
    final first = firstChild!;
    final second = childAfter(first)!;
    final width = constraints.maxWidth;
    second.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    final beside = width - second.size.width - _gap;
    final firstData = first.parentData! as _SideParentData;
    final secondData = second.parentData! as _SideParentData;
    if (beside >= _minFirst) {
      first.layout(
        BoxConstraints.tightFor(width: beside),
        parentUsesSize: true,
      );
      final height = first.size.height > second.size.height
          ? first.size.height
          : second.size.height;
      firstData.offset = Offset(0, (height - first.size.height) / 2);
      secondData.offset = Offset(
        width - second.size.width,
        (height - second.size.height) / 2,
      );
      size = constraints.constrain(Size(width, height));
    } else {
      first.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      firstData.offset = Offset.zero;
      secondData.offset = Offset(0, first.size.height + _stackedGap);
      size = constraints.constrain(
        Size(width, first.size.height + _stackedGap + second.size.height),
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
