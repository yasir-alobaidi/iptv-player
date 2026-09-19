import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iptv_player/design/components/app_menu.dart';
import 'package:iptv_player/design/tokens.dart';

/// Shows [builder]'s dialog (usually an `AppDialog`) over a scrim on the
/// root navigator, and completes with what it pops.
///
/// Esc closes it through the app's global Esc action, which pops whatever
/// is on top; a click on the scrim does the same. The dialog's route keeps
/// focus inside it until it closes, then gives it back to where it was.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final tokens = context.tokens;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: tokens.colors.scrim,
    transitionDuration: tokens.motion.fast,
    transitionBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (dialogContext, animation, secondary) => Material(
      type: MaterialType.transparency,
      child: builder(dialogContext),
    ),
  );
}

/// Opens an [AppMenu] under the control [anchor] belongs to (or above
/// it, when there is no room below), with the first item focused.
///
/// Choosing an item closes the menu first, then runs the item, so an item
/// that opens a dialog or navigates starts from a closed menu.
Future<void> showAppMenu(
  BuildContext anchor, {
  required List<AppMenuItem> items,
  double width = 240,
}) {
  final box = anchor.findRenderObject()! as RenderBox;
  final navigator = Navigator.of(anchor, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final rect = Rect.fromPoints(
    box.localToGlobal(Offset.zero, ancestor: overlay),
    box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
  );
  return navigator.push(
    _MenuRoute(
      anchor: rect,
      width: width,
      duration: anchor.tokens.motion.fast,
      items: items,
    ),
  );
}

class _MenuRoute extends PopupRoute<void> {
  new({
    required this.anchor,
    required this.width,
    required this.duration,
    required this.items,
  });

  final Rect anchor;
  final double width;
  final Duration duration;
  final List<AppMenuItem> items;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close menu';

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final closing = [
      for (final item in items)
        if (item.label.isEmpty || item.onPressed == null)
          item
        else
          AppMenuItem(
            label: item.label,
            icon: item.icon,
            shortcut: item.shortcut,
            destructive: item.destructive,
            checked: item.checked,
            onPressed: () {
              Navigator.of(context).pop();
              // After the pop, so focus is back on the anchor first.
              scheduleMicrotask(item.onPressed!);
            },
          ),
    ];
    return FadeTransition(
      opacity: animation,
      child: CustomSingleChildLayout(
        delegate: _MenuLayout(anchor: anchor, gap: context.tokens.spacing.s4),
        child: Material(
          type: MaterialType.transparency,
          child: AppMenu(items: closing, width: width, autofocus: true),
        ),
      ),
    );
  }
}

/// Below the anchor, left edges aligned; flipped above or pulled in
/// wherever the window's edge is in the way.
class _MenuLayout extends SingleChildLayoutDelegate {
  const new({required this.anchor, required this.gap});

  final Rect anchor;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    var x = anchor.left;
    if (x + child.width > size.width - gap) {
      x = anchor.right - child.width;
    }
    var y = anchor.bottom + gap;
    if (y + child.height > size.height - gap) {
      y = anchor.top - gap - child.height;
    }
    return Offset(
      x.clamp(gap, (size.width - child.width - gap).clamp(gap, size.width)),
      y.clamp(gap, (size.height - child.height - gap).clamp(gap, size.height)),
    );
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor || old.gap != gap;
}
