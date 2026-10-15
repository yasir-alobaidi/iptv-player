import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/focus/tv_mode.dart';
import 'package:iptv_player/design/tokens.dart';

/// On a TV (`TvMode`), a text field the remote can use: Android's keyboard
/// never opens (the field asks for [TextInputType.none]; a keyboard
/// plugged in still types), the arrows move the focus out of the field as
/// from anything else, and OK ([ActivateIntent]) calls [onOpen]. Off a TV
/// it is [child] alone.
///
/// Why: Google TV's keyboard took no key from the remote in a Flutter
/// field on the Bedroom TV, not even Back (ADR-026).
class RemoteTextEntry extends StatelessWidget {
  const new({
    required this.onOpen,
    required this.child,
    this.arrowsLeave = true,
    super.key,
  });

  final VoidCallback onOpen;

  /// False where the screen moves its own cursor with the arrows while
  /// the field keeps the focus (Search's results).
  final bool arrowsLeave;

  /// The field, asking for [TextInputType.none] on a TV.
  final Widget child;

  static const Map<ShortcutActivator, Intent> _arrows = {
    SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
      TraversalDirection.up,
      ignoreTextFields: false,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
      TraversalDirection.down,
      ignoreTextFields: false,
    ),
    SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
      TraversalDirection.left,
      ignoreTextFields: false,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
      TraversalDirection.right,
      ignoreTextFields: false,
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (!TvMode.of(context)) return child;
    return Shortcuts(
      shortcuts: arrowsLeave ? _arrows : const {},
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onOpen();
              return null;
            },
          ),
          if (arrowsLeave) DirectionalFocusIntent: _LeaveField(),
        },
        child: child,
      ),
    );
  }
}

/// An arrow out of the field, when there is something that way; else the
/// key goes on (the shell takes Left at the screen's edge to the rail).
class _LeaveField extends Action<DirectionalFocusIntent> {
  @override
  Object? invoke(DirectionalFocusIntent intent) =>
      FocusManager.instance.primaryFocus?.focusInDirection(intent.direction) ??
      false;

  @override
  KeyEventResult toKeyEventResult(
    DirectionalFocusIntent intent,
    Object? invokeResult,
  ) => invokeResult == true ? KeyEventResult.handled : KeyEventResult.ignored;
}

/// Bijou's own keyboard for the remote (docs/07: Onboarding and Search
/// type on an on-screen keyboard): a panel at the bottom with the text so
/// far, ten keys a row, and the arrows and OK to type. It edits
/// [controller] as each key is pressed, calling [onChanged] (a search
/// shows results as the words come); Done closes it and calls
/// [onSubmitted]; Back closes it and keeps what was typed.
///
/// [keyboardType] chooses the extra row: an address's pieces for a URL,
/// and the digits first for a number.
Future<void> showRemoteKeyboard(
  BuildContext context, {
  required TextEditingController controller,
  String? label,
  bool obscure = false,
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) {
  final tokens = context.tokens;
  var submitted = false;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close keyboard',
    barrierColor: tokens.colors.scrim,
    transitionDuration: tokens.motion.fast,
    transitionBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (dialogContext, animation, secondary) => Material(
      type: MaterialType.transparency,
      child: RemoteKeyboard(
        controller: controller,
        label: label,
        obscure: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onDone: () {
          if (submitted) return;
          submitted = true;
          Navigator.of(dialogContext).pop();
          onSubmitted?.call(controller.text);
        },
      ),
    ),
  );
}

/// The keyboard's panel ([showRemoteKeyboard] opens it). Public for the
/// Component Gallery and tests.
class RemoteKeyboard extends StatefulWidget {
  const new({
    required this.controller,
    required this.onDone,
    this.label,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onDone;
  final String? label;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  static const _digits = '1234567890';
  static const _letters = ['qwertyuiop', 'asdfghjkl@', 'zxcvbnm.-_'];
  static const _symbols = [r'!#$%^&*()?', '/:;\'",+=~`', r'[]{}<>\|·€'];

  /// An address's pieces, and how wide each key is (of ten).
  static const _addressRow = [
    ('http://', 2),
    ('https://', 2),
    (':', 1),
    ('/', 1),
    ('.com', 2),
    ('.net', 2),
  ];

  @override
  State<RemoteKeyboard> createState() => _RemoteKeyboardState();
}

class _RemoteKeyboardState extends State<RemoteKeyboard> {
  bool _upper = false;
  bool _symbols = false;
  bool _revealed = false;

  bool get _number => widget.keyboardType == TextInputType.number;
  bool get _url => widget.keyboardType == TextInputType.url;

  void _edit(String text) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
    setState(() {});
  }

  void _type(String piece) => _edit(widget.controller.text + piece);

  void _delete() {
    final text = widget.controller.text;
    if (text.isEmpty) return;
    // One character, even one outside the basic plane.
    _edit(text.characters.skipLast(1).toString());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final text = widget.controller.text;
    final shown = widget.obscure && !_revealed
        ? '•' * text.characters.length
        : text;
    final letters = _symbols
        ? RemoteKeyboard._symbols
        : RemoteKeyboard._letters;

    Widget row(List<Widget> keys) => Padding(
      padding: EdgeInsets.only(top: tokens.spacing.s8),
      child: Row(children: keys),
    );

    _Key char(String c, {bool autofocus = false}) {
      final typed = _upper && !_symbols ? c.toUpperCase() : c;
      return _Key(
        label: typed,
        autofocus: autofocus,
        onPressed: () => _type(typed),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Container(
          margin: EdgeInsets.all(tokens.spacing.s16),
          padding: EdgeInsets.all(tokens.spacing.s16),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: tokens.radii.lgAll,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.label case final label?)
                          Text(
                            label,
                            style: tokens.text.label.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        Text(
                          // A caret after the text: where the next key goes.
                          '$shown|',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.text.h3.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.obscure)
                    SizedBox(
                      width: 120,
                      child: Row(
                        children: [
                          _Key(
                            label: _revealed ? 'Hide' : 'Show',
                            onPressed: () =>
                                setState(() => _revealed = !_revealed),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_url && !_symbols)
                row([
                  for (final (piece, width) in RemoteKeyboard._addressRow)
                    _Key(
                      label: piece,
                      flex: width,
                      onPressed: () => _type(piece),
                    ),
                ]),
              row([
                for (final (i, c) in RemoteKeyboard._digits.characters.indexed)
                  char(c, autofocus: _number && i == 0),
              ]),
              for (final (r, keys) in letters.indexed)
                row([
                  for (final (i, c) in keys.characters.indexed)
                    char(c, autofocus: !_number && r == 0 && i == 0),
                ]),
              row([
                _Key(
                  label: _upper ? 'abc' : 'ABC',
                  selected: _upper,
                  enabled: !_symbols,
                  onPressed: () => setState(() => _upper = !_upper),
                ),
                _Key(
                  label: _symbols ? 'abc' : '#+=',
                  selected: _symbols,
                  onPressed: () => setState(() => _symbols = !_symbols),
                ),
                _Key(label: 'Space', flex: 3, onPressed: () => _type(' ')),
                _Key(label: 'Delete', flex: 2, onPressed: _delete),
                _Key(label: 'Clear', onPressed: () => _edit('')),
                _Key(
                  label: 'Done',
                  flex: 2,
                  primary: true,
                  onPressed: widget.onDone,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// One key: [flex] tenths of the row.
class _Key extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.flex = 1,
    this.autofocus = false,
    this.selected = false,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final int flex;
  final bool autofocus;
  final bool selected;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final key = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s4 / 2),
      child: FocusableSurface(
        onPressed: onPressed,
        autofocus: autofocus,
        enabled: enabled,
        onAccent: primary,
        borderRadius: tokens.radii.smAll,
        background: primary
            ? colors.accentBase
            : selected
            ? colors.accentSoft
            : colors.surface2,
        hoverBackground: primary ? colors.accentHover : colors.surface3,
        semanticLabel: label,
        builder: (context, states) => SizedBox(
          height: tokens.spacing.s40,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: tokens.text.bodyStrong.copyWith(
                color: primary
                    ? colors.onAccent
                    : enabled
                    ? colors.textPrimary
                    : colors.textDisabled,
              ),
            ),
          ),
        ),
      ),
    );
    return Expanded(flex: flex, child: key);
  }
}
