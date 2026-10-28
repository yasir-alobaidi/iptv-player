import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [heading] above [body] in the height there is: the body takes what
/// the heading leaves, and never less than [minBodyHeight]; when that is
/// more than there is (a phone on its side, the keyboard up), the two
/// scroll as one. A phone's onboarding pages and About & diagnostics
/// (ADR-068), whose bodies are lists that want a height of their own.
class HeadingThenBody extends StatelessWidget {
  const new({
    required this.heading,
    required this.body,
    required this.minBodyHeight,
    super.key,
  });

  final Widget heading;
  final Widget body;
  final double minBodyHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: _HeadingThenBody(
        height: constraints.maxHeight,
        minBodyHeight: minBodyHeight,
        children: [heading, body],
      ),
    ),
  );
}

/// The compact frame's heading and body, in a scroll view [height] high:
/// the body takes the height the heading leaves, and never less than
/// [minBodyHeight] — then the two are taller than the view and scroll.
class _HeadingThenBody extends MultiChildRenderObjectWidget {
  const new({
    required this.height,
    required this.minBodyHeight,
    required super.children,
  });

  final double height;
  final double minBodyHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeadingThenBody(height: height, minBodyHeight: minBodyHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderHeadingThenBody renderObject,
  ) {
    renderObject
      ..height = height
      ..minBodyHeight = minBodyHeight;
  }
}

class _HeadingParentData extends ContainerBoxParentData<RenderBox>;

class _RenderHeadingThenBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeadingParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeadingParentData> {
  new({required this._height, required this._minBodyHeight});

  double _height;
  double get height => _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  double _minBodyHeight;
  double get minBodyHeight => _minBodyHeight;
  set minBodyHeight(double value) {
    if (value == _minBodyHeight) return;
    _minBodyHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeadingParentData) {
      child.parentData = _HeadingParentData();
    }
  }

  @override
  void performLayout() {
    final heading = firstChild!;
    final body = childAfter(heading)!;
    final width = constraints.maxWidth;
    heading.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final room = _height.isFinite ? _height - heading.size.height : 0.0;
    final bodyHeight = math.max(room, _minBodyHeight);
    body.layout(
      BoxConstraints.tightFor(width: width, height: bodyHeight),
      parentUsesSize: true,
    );
    (heading.parentData! as _HeadingParentData).offset = Offset.zero;
    (body.parentData! as _HeadingParentData).offset = Offset(
      0,
      heading.size.height,
    );
    size = constraints.constrain(Size(width, heading.size.height + bodyHeight));
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      firstChild!.getMinIntrinsicHeight(width) + _minBodyHeight;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
