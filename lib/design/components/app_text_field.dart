import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/tokens.dart';

/// Single-line text input (canvas: 48 px tall, radius 10, surface1 on a
/// 1 px border). Supports a clear button, a password reveal and an inline
/// error message.
class AppTextField extends StatefulWidget {
  const new({
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.showClear = true,
    this.leading,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;

  /// Non-null puts the field in its error state (docs/05: human message,
  /// never raw exception text).
  final String? errorText;
  final String? helperText;

  /// Password field: hides the text and offers a reveal button.
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final bool showClear;
  final AppIcons? leading;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _focused = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() => _focused = _focusNode.hasFocus);
  void _onTextChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final hasError = widget.errorText != null;
    final obscured = widget.obscure && !_revealed;

    final borderColor = hasError
        ? colors.danger
        : _focused
        ? colors.accentBase
        : colors.border;

    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: obscured,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: tokens.text.body.copyWith(color: colors.textPrimary),
      cursorColor: colors.accentBase,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: tokens.text.body.copyWith(color: colors.textTertiary),
        contentPadding: EdgeInsets.zero,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: tokens.text.label.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: tokens.spacing.s8),
        ],
        Opacity(
          opacity: widget.enabled ? 1 : 0.4,
          child: AnimatedContainer(
            duration: tokens.motion.fast,
            curve: tokens.motion.fastCurve,
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12 + 2),
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: tokens.radii.controlAll,
              border: Border.all(color: borderColor),
              boxShadow: _focused && !hasError
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
                if (widget.leading != null) ...[
                  AppIcon(
                    widget.leading!,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                  SizedBox(width: tokens.spacing.s8 + 2),
                ],
                Expanded(child: field),
                if (widget.showClear && _controller.text.isNotEmpty)
                  _FieldAction(
                    icon: AppIcons.close,
                    tooltip: 'Clear',
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                    },
                  ),
                if (widget.obscure)
                  _FieldAction(
                    // The canvas has one eye icon, so the revealed
                    // state is shown with the accent color.
                    icon: AppIcons.eye,
                    active: _revealed,
                    tooltip: _revealed ? 'Hide' : 'Show',
                    onPressed: () => setState(() => _revealed = !_revealed),
                  ),
              ],
            ),
          ),
        ),
        if (hasError || widget.helperText != null) ...[
          SizedBox(height: tokens.spacing.s8 - 2),
          Text(
            widget.errorText ?? widget.helperText!,
            style: tokens.text.caption.copyWith(
              color: hasError ? colors.danger : colors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _FieldAction extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final AppIcons icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 16,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.s4),
          child: AppIcon(
            icon,
            size: 18,
            color: active
                ? tokens.colors.accentBase
                : tokens.colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
