import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/focus/tv_mode.dart';
import 'package:iptv_player/design/text_scale.dart';
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

  /// The arrows as an intent of our own: the field's EditableText answers
  /// [DirectionalFocusIntent] itself and keeps the key even with nothing
  /// that way, so at a screen's edge the shell never heard it (Up from
  /// Movies' filter stayed there, on the Bedroom TV).
  static const Map<ShortcutActivator, Intent> _arrows = {
    SingleActivator(LogicalKeyboardKey.arrowUp): _FieldArrowIntent(
      TraversalDirection.up,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown): _FieldArrowIntent(
      TraversalDirection.down,
    ),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _FieldArrowIntent(
      TraversalDirection.left,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight): _FieldArrowIntent(
      TraversalDirection.right,
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
          if (arrowsLeave) _FieldArrowIntent: _LeaveField(),
        },
        child: child,
      ),
    );
  }
}

/// An arrow out of the field, when there is something that way; else the
/// key goes on (the shell takes Left at the screen's edge to the rail).
class _FieldArrowIntent extends Intent {
  const new(this.direction);

  final TraversalDirection direction;
}

class _LeaveField extends Action<_FieldArrowIntent> {
  @override
  Object? invoke(_FieldArrowIntent intent) =>
      FocusManager.instance.primaryFocus?.focusInDirection(intent.direction) ??
      false;

  @override
  KeyEventResult toKeyEventResult(
    _FieldArrowIntent intent,
    Object? invokeResult,
  ) => invokeResult == true ? KeyEventResult.handled : KeyEventResult.ignored;
}

/// The keyboard's letters: English's QWERTY, or Arabic's phone layout.
enum KeyboardLanguage {
  english('en'),
  arabic('ar');

  new(this.code);

  /// How a preference stores it.
  final String code;

  /// [code]'s language; English for anything else.
  static KeyboardLanguage fromCode(String? code) => values.firstWhere(
    (language) => language.code == code,
    orElse: () => english,
  );
}

/// The language [RemoteKeyboard] opens in, and where a change of it goes:
/// the app keeps the last one chosen (ADR-027). Above the router, so the
/// keyboard's dialog sees it; with none above, English, not kept.
class RemoteKeyboardLanguage extends InheritedWidget {
  const new({
    required this.language,
    required this.onChanged,
    required super.child,
    super.key,
  });

  final KeyboardLanguage language;
  final ValueChanged<KeyboardLanguage> onChanged;

  static RemoteKeyboardLanguage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RemoteKeyboardLanguage>();

  @override
  bool updateShouldNotify(RemoteKeyboardLanguage oldWidget) =>
      oldWidget.language != language;
}

/// Bijou's own keyboard for the remote (docs/07: Onboarding and Search
/// type on an on-screen keyboard), as a panel down the screen's left side:
/// the screen stays in view beside it, undimmed, so what the words find
/// (Search's results, a filtered grid) shows as they are typed. The panel
/// shows the text itself, its end when it is long, after a blinking caret.
/// It edits [controller] as each key is pressed, calling [onChanged]; Done
/// closes it and calls [onSubmitted]; Back closes it and keeps the text.
///
/// [keyboardType] chooses the extra row: an address's pieces for a URL,
/// and the digits first for a number. ADR-026.
///
/// Its letters are English's or Arabic's (the key at the bottom row's
/// start switches them; [RemoteKeyboardLanguage] keeps the choice). Arabic
/// is laid out as phones lay it out, with a row of its own for the alef's
/// hamza and madda and the yeh's hamza, which a phone puts under a long
/// press a remote can't make; Arabic words show right to left, the caret
/// at their left. ADR-027.
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
    // The screen beside the panel is what the words find: not dimmed.
    barrierColor: Colors.transparent,
    transitionDuration: tokens.motion.fast,
    transitionBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (dialogContext, animation, secondary) => Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.centerLeft,
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
    ),
  );
}

/// The keyboard's panel ([showRemoteKeyboard] opens it). Public for the
/// Component Gallery, tests, and the screens that make room for it;
/// Search shows it itself, beside its results, so the remote moves
/// between the two.
class RemoteKeyboard extends StatefulWidget {
  const new({
    required this.controller,
    required this.onDone,
    this.label,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
    this.exits = const {},
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onDone;
  final String? label;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  /// The edges the screen beside the keyboard takes: an arrow there goes
  /// on to it (Search's results, to the right) where the others go round.
  final Set<TraversalDirection> exits;

  /// The panel's width: a screen that shows results beside it (Search)
  /// starts them after this.
  static const width = 460.0;

  static const _digits = '1234567890';
  static const _letters = ['qwertyuiop', 'asdfghjkl@', 'zxcvbnm.-_'];
  static const _symbols = [r'!#$%^&*()?', '/:;\'",+=~`', r'[]{}<>\|·€'];

  /// A phone's Arabic layout, then what it puts under a long press, the
  /// lam-alef, and Arabic's comma and question mark.
  static const _arabic = [
    ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج'],
    ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك', 'ط'],
    ['ذ', 'ء', 'ؤ', 'ر', 'ى', 'ة', 'و', 'ز', 'ظ', 'د'],
    ['أ', 'إ', 'آ', 'ئ', 'لا', '،', '؟', '.', '-', '_'],
  ];

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
  /// Above the keys: their arrows reach it when nothing is that way.
  final _panel = FocusNode(
    debugLabel: 'RemoteKeyboard',
    canRequestFocus: false,
    skipTraversal: true,
  );

  bool _upper = false;
  bool _symbols = false;
  bool _revealed = false;

  /// Null until the scope above is read.
  KeyboardLanguage? _language;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(RemoteKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _panel.dispose();
    super.dispose();
  }

  /// The arrows go round at the keyboard's edges, as Google TV's own
  /// keyboard does (ADR-036): the next key that way, else the other end.
  /// A held arrow stops at the edge and the next press goes round, so a
  /// hold never spins past the key it was going for. An edge in
  /// [RemoteKeyboard.exits] lets the key go on to the screen.
  KeyEventResult _onKey(FocusNode panel, KeyEvent event) {
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    final from = FocusManager.instance.primaryFocus;
    if (direction == null || event is KeyUpEvent || from == null) {
      return KeyEventResult.ignored;
    }
    if (from.focusInDirection(direction)) return KeyEventResult.handled;
    if (widget.exits.contains(direction)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      final to = _roundFrom(from, direction);
      if (to == null) return KeyEventResult.handled;
      // Flutter's arrows retrace a vertical move when the next goes back
      // the other way: after going round, that went back to before the
      // edge (↑ from q to 1, round to Delete, ↓ gave q, not 1).
      final scope = from.nearestScope;
      if (from.context case final context? when scope != null) {
        FocusTraversalGroup.maybeOf(context)?.invalidateScopeData(scope);
      }
      to.requestFocus();
    }
    return KeyEventResult.handled;
  }

  /// The key an arrow goes round to from [from], at the keyboard's edge:
  /// the other end of its row for ← and →; for ↑ and ↓ the other end's
  /// row, the key there nearest [from] across. Null with none.
  FocusNode? _roundFrom(FocusNode from, TraversalDirection direction) {
    final keys = [
      for (final node in _panel.traversalDescendants)
        if (node != from) node,
    ];
    if (keys.isEmpty) return null;
    final at = from.rect.center;
    Iterable<FocusNode> rowAt(double y) => keys.where(
      (node) => (node.rect.center.dy - y).abs() < from.rect.height / 2,
    );
    FocusNode most(Iterable<FocusNode> nodes, double Function(Offset) by) =>
        nodes.reduce((a, b) => by(a.rect.center) >= by(b.rect.center) ? a : b);
    switch (direction) {
      case TraversalDirection.left || TraversalDirection.right:
        final row = rowAt(at.dy);
        if (row.isEmpty) return null;
        return direction == TraversalDirection.left
            ? most(row, (c) => c.dx)
            : most(row, (c) => -c.dx);
      case TraversalDirection.up || TraversalDirection.down:
        final end = direction == TraversalDirection.up
            ? most(keys, (c) => c.dy)
            : most(keys, (c) => -c.dy);
        return most(rowAt(end.rect.center.dy), (c) => -(c.dx - at.dx).abs());
    }
  }

  /// The box shows the field's words whoever changes them: Search puts a
  /// recent search chosen beside the keyboard in them.
  void _onText() {
    if (mounted) setState(() {});
  }

  bool get _arabic => _language == KeyboardLanguage.arabic;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _language ??=
        RemoteKeyboardLanguage.maybeOf(context)?.language ??
        KeyboardLanguage.english;
  }

  void _switchLanguage() {
    final next = _arabic ? KeyboardLanguage.english : KeyboardLanguage.arabic;
    setState(() {
      _language = next;
      _symbols = false;
      _upper = false;
    });
    RemoteKeyboardLanguage.maybeOf(context)?.onChanged(next);
  }

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
        ? [for (final keys in RemoteKeyboard._symbols) keys.characters.toList()]
        : _arabic
        ? RemoteKeyboard._arabic
        : [
            for (final keys in RemoteKeyboard._letters)
              keys.characters.toList(),
          ];
    final gap = tokens.spacing.s8 - 2;

    // Each row keyed: Arabic has a row more, and the focus on the
    // language key stayed in its place, a letter of the new row (OK on
    // عربي by remote left it on أ).
    Widget row(String name, List<Widget> keys) => Padding(
      key: ValueKey(name),
      padding: EdgeInsets.only(top: gap),
      child: Row(children: keys),
    );

    _Key char(String c, {bool autofocus = false}) {
      final typed = _upper && !_symbols && !_arabic ? c.toUpperCase() : c;
      return _Key(
        label: typed,
        autofocus: autofocus,
        onPressed: () => _type(typed),
      );
    }

    final panel = Container(
      width: RemoteKeyboard.width,
      height: double.infinity,
      padding: EdgeInsets.all(tokens.spacing.s20),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(right: BorderSide(color: colors.border)),
        boxShadow: tokens.elevation.overlay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.label.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              if (widget.obscure)
                SizedBox(
                  width: tokens.spacing.s64 + tokens.spacing.s16,
                  child: Row(
                    children: [
                      _Key(
                        label: _revealed ? 'Hide' : 'Show',
                        onPressed: () => setState(() => _revealed = !_revealed),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.s8),
          // The words so far, in a box like the field's: where the
          // next key goes, the caret blinks. Its border is a field's at
          // rest: the focus is on the keys, and a TV's focus is white
          // (ADR-029); the accent border read as a second, blue focus.
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.s12,
              vertical: tokens.spacing.s8,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: tokens.radii.controlAll,
              border: Border.all(color: colors.border),
            ),
            child: _Typed(
              text: shown,
              // An empty box takes the keyboard's direction; words, their
              // own (Arabic right to left).
              direction:
                  _directionOf(shown) ??
                  (_arabic ? TextDirection.rtl : TextDirection.ltr),
              style: tokens.text.h3.copyWith(color: colors.textPrimary),
            ),
          ),
          SizedBox(height: tokens.spacing.s8),
          if (_url && !_symbols)
            row('address', [
              for (final (piece, width) in RemoteKeyboard._addressRow)
                _Key(label: piece, flex: width, onPressed: () => _type(piece)),
            ]),
          row('digits', [
            for (final (i, c) in RemoteKeyboard._digits.characters.indexed)
              char(c, autofocus: _number && i == 0),
          ]),
          for (final (r, keys) in letters.indexed)
            row('letters $r', [
              for (final (i, c) in keys.indexed)
                char(c, autofocus: !_number && r == 0 && i == 0),
            ]),
          row('switches', [
            // Each language's key says it in its own words.
            _Key(
              label: _arabic ? 'English' : 'عربي',
              flex: 2,
              onPressed: _switchLanguage,
            ),
            if (!_arabic)
              _Key(
                label: _upper ? 'abc' : 'ABC',
                flex: 2,
                selected: _upper,
                enabled: !_symbols,
                onPressed: () => setState(() => _upper = !_upper),
              ),
            _Key(
              label: _symbols ? (_arabic ? 'أبت' : 'abc') : '#+=',
              flex: 2,
              selected: _symbols,
              onPressed: () => setState(() => _symbols = !_symbols),
            ),
            _Key(
              label: 'Space',
              flex: _arabic ? 6 : 4,
              onPressed: () => _type(' '),
            ),
          ]),
          row('actions', [
            _Key(label: 'Delete', flex: 3, onPressed: _delete),
            _Key(label: 'Clear', flex: 3, onPressed: () => _edit('')),
            _Key(
              label: 'Done',
              flex: 4,
              primary: true,
              onPressed: widget.onDone,
            ),
          ]),
        ],
      ),
    );
    return Focus(focusNode: _panel, onKeyEvent: _onKey, child: panel);
  }
}

/// Which way [text] reads: its first letter's script's way; null with no
/// letter. Arabic and Hebrew (and their presentation forms) read right to
/// left.
TextDirection? _directionOf(String text) {
  for (final rune in text.runes) {
    final rtl =
        (rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
    if (rtl) return TextDirection.rtl;
    final letter = String.fromCharCode(rune);
    if (letter.toLowerCase() != letter.toUpperCase()) return TextDirection.ltr;
  }
  return null;
}

/// The words typed so far and the caret after them; when they are wider
/// than the box, their end shows (where the typing is), cut at its start:
/// the left for English, the right for Arabic, whose end is at the left.
class _Typed extends StatelessWidget {
  const new({required this.text, required this.direction, required this.style});

  final String text;
  final TextDirection direction;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale(style.fontSize!) * (style.height ?? 1.2);
    // A new caret each time the text changes: it shows at once, then
    // blinks, as a text field's does.
    final rtl = direction == TextDirection.rtl;
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: direction,
      children: [
        Text(
          text,
          maxLines: 1,
          softWrap: false,
          textDirection: direction,
          style: style,
        ),
        _Caret(key: ValueKey(text), height: lineHeight, before: rtl),
      ],
    );
    return SizedBox(
      height: lineHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final wide = painter.width + _Caret.width * 2 > constraints.maxWidth;
          painter.dispose();
          // Clipped either way: a text a hair from the edge never
          // overflows.
          return ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              // The end in view: the right of English, the left of Arabic.
              alignment: wide == rtl
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: line,
            ),
          );
        },
      ),
    );
  }
}

/// A text field's caret: on for half a second, off for half, steady when
/// motion is reduced.
class _Caret extends StatefulWidget {
  const new({required this.height, this.before = false, super.key});

  final double height;

  /// Its gap on the right: it comes before the words on screen (at the
  /// left of right-to-left ones).
  final bool before;

  static const width = 2.0;

  /// One on-and-off: a text field's rhythm.
  static const period = Duration(milliseconds: 1060);

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(vsync: this, duration: _Caret.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.tokens.motion.reduceMotion) {
      _blink.stop();
    } else if (!_blink.isAnimating) {
      _blink.repeat();
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) => Opacity(
        opacity: _blink.isAnimating && _blink.value >= 0.5 ? 0 : 1,
        child: Container(
          width: _Caret.width,
          height: widget.height,
          margin: widget.before
              ? const EdgeInsets.only(right: _Caret.width)
              : const EdgeInsets.only(left: _Caret.width),
          color: tokens.colors.accentBase,
        ),
      ),
    );
  }
}

/// One key: [flex] tenths of the row. Focused, it fills white with dark
/// letters — the TV's keyboards' highlight — in place of the design
/// system's ring, which its neighbours, a few pixels away, painted over.
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
      padding: EdgeInsets.symmetric(horizontal: (tokens.spacing.s8 - 2) / 2),
      child: FocusableSurface(
        onPressed: onPressed,
        autofocus: autofocus,
        enabled: enabled,
        ring: false,
        borderRadius: tokens.radii.smAll,
        semanticLabel: label,
        builder: (context, states) {
          final (fill, ink) = switch (states) {
            SurfaceStates(focused: true) => (colors.textPrimary, colors.bg),
            _ when primary => (colors.accentBase, colors.onAccent),
            SurfaceStates(hovered: true) => (
              colors.surface3,
              colors.textPrimary,
            ),
            _ when selected => (colors.accentSoft, colors.textPrimary),
            _ when !enabled => (colors.surface2, colors.textDisabled),
            _ => (colors.surface2, colors.textPrimary),
          };
          return AnimatedContainer(
            duration: tokens.motion.fast,
            height: context.scaled(tokens.spacing.s40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: tokens.radii.smAll,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: tokens.text.bodyStrong.copyWith(color: ink),
            ),
          );
        },
      ),
    );
    return Expanded(flex: flex, child: key);
  }
}
