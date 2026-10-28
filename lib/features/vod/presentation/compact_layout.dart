import 'package:flutter/material.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/design/components.dart';

/// How Movies, Series, a title's page, Favorites and Search lay
/// themselves out on a phone (ADR-068): by the room they have, never by
/// the device's name. A desktop window (1024 × 640 at least) and a TV's
/// 1280 × 720 canvas are never compact.
abstract final class CompactLayout {
  /// Lower than this (a phone on its side, 360 px with its bars), a page
  /// scrolls as one column and a grid's cards are a phone's.
  static const shortHeight = 480.0;

  /// Narrower than a phone held upright ([WindowSizes.phoneWidth]).
  static bool narrow(double width) => width < WindowSizes.phoneWidth;

  /// A phone's room, upright or on its side.
  static bool fits(Size size) =>
      narrow(size.width) || size.height < shortHeight;

  /// A window this size: compact for its width or its height.
  static bool of(BuildContext context) => fits(MediaQuery.sizeOf(context));

  /// A finger's target: 44 px each way at least (docs/05, ADR-068), the
  /// height of a medium button.
  static double get touchTarget => AppButtonSize.m.height;
}

/// A small control (a chip, a grip) given a finger's target: a tap in the
/// room round it, up to [CompactLayout.touchTarget] each way, presses it
/// too. A tap on the control itself is still the control's own.
class TouchTarget extends StatelessWidget {
  const new({required this.onTap, required this.child, super.key});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTap: onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: CompactLayout.touchTarget,
        minHeight: CompactLayout.touchTarget,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    ),
  );
}
