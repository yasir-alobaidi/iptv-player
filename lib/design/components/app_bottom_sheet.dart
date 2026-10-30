import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/app_button.dart';
import 'package:iptv_player/design/components/app_icon_button.dart';
import 'package:iptv_player/design/focus/focus_pane.dart';
import 'package:iptv_player/design/tokens.dart';

/// Shows [builder]'s sheet (an [AppBottomSheet]) up from the window's bottom
/// edge, over a scrim, on the root navigator; completes with what it pops.
///
/// As a dialog (`showAppDialog`): Esc and a tap on the scrim close it, and
/// the focus stays inside it until it closes. It slides up, or fades in
/// with reduce motion.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final tokens = context.tokens;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: tokens.colors.scrim,
    transitionDuration: tokens.motion.base,
    transitionBuilder: (context, animation, secondary, child) {
      final motion = context.tokens.motion;
      if (motion.reduceMotion) {
        return FadeTransition(opacity: animation, child: child);
      }
      return SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: motion.baseCurve)),
        ),
        child: child,
      );
    },
    pageBuilder: (sheetContext, animation, secondary) =>
        Material(type: MaterialType.transparency, child: builder(sheetContext)),
  );
}

/// A phone's sheet (ADR-068, docs/05 "Bottom sheets"): what opens as a
/// dialog in a wider window comes up from the bottom edge of a phone's
/// held upright. The window's width (at most [maxWidth],
/// centred in a wider one), rounded at the top, with a handle to drag it
/// down by, its title and a close button, then [child]; above the
/// system's gesture bar, and above its keyboard while that is up.
///
/// [tall] for a list that scrolls: the sheet takes most of the window
/// rather than its content's height.
class AppBottomSheet extends StatefulWidget {
  const new({
    required this.title,
    required this.child,
    this.subtitle,
    this.tall = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool tall;

  /// The handle's pill.
  static const handleWidth = 36.0;
  static const handleHeight = 4.0;

  /// The widest a sheet gets, centred, in a window wider than a phone's.
  static const maxWidth = 640.0;

  /// How much of the window a [tall] sheet takes.
  static const tallShare = 0.82;

  /// A drag down this far, or a flick this fast, closes the sheet.
  static const closeDistance = 96.0;
  static const closeVelocity = 700.0;

  @override
  State<AppBottomSheet> createState() => _AppBottomSheetState();
}

class _AppBottomSheetState extends State<AppBottomSheet> {
  double _drag = 0;

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;
    final window = MediaQuery.sizeOf(context);
    final system = MediaQuery.viewPaddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final room = math.max<double>(0, window.height - system.top - spacing.s24);
    final radius = Radius.circular(tokens.radii.lg);

    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) =>
          setState(() => _drag = math.max(0, _drag + details.delta.dy)),
      onVerticalDragEnd: (details) {
        if (_drag > AppBottomSheet.closeDistance ||
            details.velocity.pixelsPerSecond.dy >
                AppBottomSheet.closeVelocity) {
          _close();
        } else {
          setState(() => _drag = 0);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: spacing.s8),
          Center(
            child: Container(
              width: AppBottomSheet.handleWidth,
              height: AppBottomSheet.handleHeight,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: tokens.radii.pillAll,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.s20,
              spacing.s8,
              spacing.s8,
              spacing.s8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.h3.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (widget.subtitle case final subtitle?) ...[
                        SizedBox(height: spacing.s4),
                        Text(
                          subtitle,
                          style: tokens.text.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: spacing.s8),
                AppIconButton(
                  icon: AppIcons.close,
                  tooltip: 'Close',
                  size: AppButtonSize.m.height,
                  onPressed: _close,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return FocusPane(
      debugLabel: 'sheet',
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: AppBottomSheet.maxWidth,
              maxHeight: room,
            ),
            height: widget.tall ? room * AppBottomSheet.tallShare : null,
            padding: EdgeInsets.only(bottom: math.max(system.bottom, keyboard)),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.vertical(top: radius),
              border: Border(top: BorderSide(color: colors.border)),
              boxShadow: tokens.elevation.overlay,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Flexible(
                  fit: widget.tall ? FlexFit.tight : FlexFit.loose,
                  // The sheet keeps clear of the system's bars itself: a
                  // list in it would add the status bar's height again.
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    removeLeft: true,
                    removeRight: true,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
