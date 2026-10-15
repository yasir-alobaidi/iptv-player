import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/kbd.dart';
import 'package:iptv_player/design/components/remote_keyboard.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/focus/tv_mode.dart';
import 'package:iptv_player/design/text_scale.dart';
import 'package:iptv_player/design/tokens.dart';

/// The top bar's search box (canvas: 40 px tall, radius 10, magnifier on
/// the left, `Ctrl K` keycap on the right).
///
/// With [onTap] set it behaves as a button that opens the search overlay
/// (the shell's use, Phase 1 step 4); otherwise it is a live text field,
/// which on a TV the remote types in with [showRemoteKeyboard].
class SearchField extends StatefulWidget {
  const new({
    this.controller,
    this.focusNode,
    this.hint = 'Search channels, shows, movies',
    this.shortcut = 'Ctrl K',
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.width,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;

  /// Keycap shown at the right; null hides it.
  final String? shortcut;

  /// When set the field is a button, not an input.
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final double? width;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _ownsFocusNode = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _ownController.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() => _focused = _focusNode.hasFocus);

  late final TextEditingController _ownController = TextEditingController();
  TextEditingController get _controller => widget.controller ?? _ownController;

  void _openKeyboard() => showRemoteKeyboard(
    context,
    controller: _controller,
    label: widget.hint,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final asButton = widget.onTap != null;
    final onTv = TvMode.of(context);
    // In button mode FocusableSurface draws the ring, so the box keeps
    // its resting border instead of showing focus twice.
    final showsOwnFocus = _focused && !asButton;

    final body = asButton
        ? Text(
            widget.hint,
            // One line, whatever the text size: a hint that wraps is cut
            // by the box.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.label
                .withWeight(500)
                .copyWith(color: colors.textTertiary),
          )
        : RemoteTextEntry(
            onOpen: _openKeyboard,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              // A TV types with the remote's keyboard, never
              // Android's (a keyboard plugged in still types).
              keyboardType: onTv ? TextInputType.none : null,
              showCursor: onTv ? false : null,
              enableInteractiveSelection: !onTv,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: tokens.text.label
                  .withWeight(500)
                  .copyWith(color: colors.textPrimary),
              cursorColor: colors.accentBase,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: tokens.text.label
                    .withWeight(500)
                    .copyWith(color: colors.textTertiary),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );

    final box = AnimatedContainer(
      duration: tokens.motion.fast,
      curve: tokens.motion.fastCurve,
      width: widget.width,
      height: context.scaled(40),
      padding: EdgeInsets.only(
        left: tokens.spacing.s12,
        right: tokens.spacing.s8,
      ),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.controlAll,
        border: Border.all(
          color: showsOwnFocus ? colors.accentBase : colors.border,
        ),
        boxShadow: showsOwnFocus
            ? [
                BoxShadow(
                  color: colors.accentBase.withValues(
                    alpha: tokens.focus.glowOpacity,
                  ),
                  spreadRadius: tokens.focus.glowWidth,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.search, size: 18, color: colors.textTertiary),
          SizedBox(width: tokens.spacing.s8 + 2),
          Expanded(child: body),
          if (widget.shortcut != null && KeyHints.shownIn(context)) ...[
            SizedBox(width: tokens.spacing.s8),
            Kbd(widget.shortcut!),
          ],
        ],
      ),
    );

    if (!asButton) return box;

    // As a button the focus ring comes from FocusableSurface, which also
    // binds Enter and Space (hard rule 5).
    return FocusableSurface.child(
      onPressed: widget.onTap,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      borderRadius: tokens.radii.controlAll,
      semanticLabel: widget.hint,
      child: box,
    );
  }
}
