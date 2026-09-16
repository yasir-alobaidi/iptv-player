import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/tokens.dart';

/// A virtualized horizontal row of cards, with scroll arrows that appear
/// on hover (docs/05). Long rows stay cheap because items are built on
/// demand (hard rule 2).
class HorizontalRail extends StatefulWidget {
  const new({
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.controller,
    this.spacing,
    this.padding,
    super.key,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The rail's height; cards size themselves inside it.
  final double height;
  final ScrollController? controller;
  final double? spacing;
  final EdgeInsets? padding;

  @override
  State<HorizontalRail> createState() => _HorizontalRailState();
}

class _HorizontalRailState extends State<HorizontalRail> {
  late final ScrollController _controller =
      widget.controller ?? ScrollController();
  bool _ownsController = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onScroll() => setState(() {});

  bool get _canScrollBack => _controller.hasClients && _controller.offset > 1;

  bool get _canScrollForward =>
      _controller.hasClients &&
      _controller.offset < _controller.position.maxScrollExtent - 1;

  void _scrollBy(double delta) {
    final tokens = context.tokens;
    _controller.animateTo(
      (_controller.offset + delta).clamp(
        0,
        _controller.position.maxScrollExtent,
      ),
      duration: tokens.motion.base,
      curve: tokens.motion.baseCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spacing = widget.spacing ?? tokens.spacing.s12;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: widget.padding ?? EdgeInsets.zero,
              itemCount: widget.itemCount,
              separatorBuilder: (_, _) => SizedBox(width: spacing),
              itemBuilder: widget.itemBuilder,
            ),
            _EdgeArrow(
              alignment: Alignment.centerLeft,
              icon: AppIcons.chevronLeft,
              visible: _hovered && _canScrollBack,
              onPressed: () => _scrollBy(-widget.height * 2),
            ),
            _EdgeArrow(
              alignment: Alignment.centerRight,
              icon: AppIcons.chevronRight,
              visible: _hovered && _canScrollForward,
              onPressed: () => _scrollBy(widget.height * 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeArrow extends StatelessWidget {
  const new({
    required this.alignment,
    required this.icon,
    required this.visible,
    required this.onPressed,
  });

  final Alignment alignment;
  final AppIcons icon;
  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: tokens.motion.fast,
          curve: tokens.motion.fastCurve,
          // Arrows are a mouse convenience; the keyboard scrolls the rail
          // by moving focus, so they stay out of the tab order.
          child: ExcludeFocus(
            child: Semantics(
              button: true,
              label: alignment == Alignment.centerLeft
                  ? 'Scroll left'
                  : 'Scroll right',
              child: GestureDetector(
                onTap: visible ? onPressed : null,
                child: Container(
                  width: 36,
                  height: 36,
                  margin: EdgeInsets.all(tokens.spacing.s4),
                  decoration: BoxDecoration(
                    color: colors.surface3,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                    boxShadow: tokens.elevation.overlay,
                  ),
                  child: Center(
                    child: AppIcon(icon, size: 16, color: colors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
