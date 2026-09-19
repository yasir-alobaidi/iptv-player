// The keyboard and the finders the keyboard-only integration tests share.
// Keys press real key events and type through the text-input channel, as
// a keyboard does, and wait in real time.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:logger/logger.dart';

/// Key presses and waits, in real time.
final class Keys {
  new(this.tester);

  final WidgetTester tester;

  /// Under xvfb there is no window manager to give the window focus, so
  /// the engine keeps reporting the app as inactive, and Flutter parks
  /// keyboard focus while it is. A desktop session is resumed while the
  /// user types; this puts the test in the same state before each key.
  ///
  /// It also forgets keys held on the real keyboard: on a real desktop the
  /// engine reports its modifiers (an Alt+Tab away from the test window
  /// left Alt "held"), and a held Alt turns the test's Enter into
  /// Alt+Enter, which activates nothing.
  void resume() {
    if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    if (HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty) {
      HardwareKeyboard.instance.clearState();
    }
  }

  // flutter_test finds a key's physical key by its debug name, which a
  // profile build doesn't have (the frame measurement runs in profile
  // mode), so the keys the tests press say theirs.
  static final Map<LogicalKeyboardKey, PhysicalKeyboardKey> _physical = {
    LogicalKeyboardKey.enter: PhysicalKeyboardKey.enter,
    LogicalKeyboardKey.tab: PhysicalKeyboardKey.tab,
    LogicalKeyboardKey.space: PhysicalKeyboardKey.space,
    LogicalKeyboardKey.escape: PhysicalKeyboardKey.escape,
    LogicalKeyboardKey.arrowUp: PhysicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown: PhysicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft: PhysicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight: PhysicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.comma: PhysicalKeyboardKey.comma,
    LogicalKeyboardKey.shiftLeft: PhysicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.controlLeft: PhysicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.altLeft: PhysicalKeyboardKey.altLeft,
  };

  Future<void> _down(LogicalKeyboardKey key, {bool up = false}) async {
    await tester.sendKeyDownEvent(key, physicalKey: _physical[key]);
    if (up) await _up(key);
  }

  Future<void> _up(LogicalKeyboardKey key) =>
      tester.sendKeyUpEvent(key, physicalKey: _physical[key]);

  Future<void> _frames() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> press(LogicalKeyboardKey key) async {
    resume();
    if (key == LogicalKeyboardKey.enter && _focusedField != null) {
      // In a text field the platform's text input turns Enter into the
      // field's action (GTK does); the test channel stands in for it.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _frames();
      return;
    }
    await _down(key, up: true);
    await _frames();
  }

  /// Ctrl + [key].
  Future<void> chord(LogicalKeyboardKey key) async {
    resume();
    await _down(LogicalKeyboardKey.controlLeft);
    await _down(key, up: true);
    await _up(LogicalKeyboardKey.controlLeft);
    await _frames();
  }

  /// Alt + [key].
  Future<void> alt(LogicalKeyboardKey key) async {
    resume();
    await _down(LogicalKeyboardKey.altLeft);
    await _down(key, up: true);
    await _up(LogicalKeyboardKey.altLeft);
    await _frames();
  }

  EditableText? get _focusedField {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    if (context.widget is EditableText) return context.widget as EditableText;
    return context.findAncestorWidgetOfExactType<EditableText>();
  }

  /// Types [text] after what is in the field labelled [into], once the
  /// keyboard focus is in it.
  Future<void> type(String text, {required String into}) async {
    final field = await _focused(into);
    await _enter(field, field.controller.text + text);
  }

  /// Types over everything in the field labelled [into].
  Future<void> replaceText(String text, {required String into}) =>
      _focused(into).then((field) => _enter(field, text));

  Future<EditableText> _focused(String label) async {
    await waitUntil(
      () {
        resume();
        return focusIsOn(input(label));
      },
      'focus in the $label field (${focusPath()})',
      seconds: 5,
    );
    return tester.widget<EditableText>(input(label));
  }

  Future<void> _enter(EditableText field, String value) async {
    await tester.enterText(find.byWidget(field), value);
    await _frames();
    expect(field.controller.text, value, reason: 'typing did not land');
  }

  String textOf(Finder field) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  bool focusIsOn(Finder finder) {
    final primary = FocusManager.instance.primaryFocus;
    // A focused scope is no control, and its element is an ancestor of
    // everything in it.
    if (primary == null || primary is FocusScopeNode) return false;
    final focused = primary.context;
    if (focused == null) return false;
    for (final target in finder.evaluate()) {
      if (target == focused) return true;
      var found = false;
      target.visitAncestorElements((e) {
        found = e == focused;
        return !found;
      });
      if (found) return true;
      focused.visitAncestorElements((e) {
        found = e == target;
        return !found;
      });
      if (found) return true;
    }
    return false;
  }

  /// The semantic label of the focused control, when it has one.
  String? focusedLabel() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    final surface = context.widget is FocusableSurface
        ? context.widget as FocusableSurface
        : context.findAncestorWidgetOfExactType<FocusableSurface>();
    return surface?.semanticLabel;
  }

  /// Tab (or Shift+Tab) until [finder] has focus.
  Future<void> tabTo(Finder finder, {bool back = false, int max = 60}) async {
    final visited = <String>[];
    for (var i = 0; i < max; i++) {
      resume();
      if (focusIsOn(finder)) return;
      visited.add(
        focusedLabel() ?? '${FocusManager.instance.primaryFocus?.debugLabel}',
      );
      if (back) {
        await _down(LogicalKeyboardKey.shiftLeft);
        await _down(LogicalKeyboardKey.tab, up: true);
        await _up(LogicalKeyboardKey.shiftLeft);
      } else {
        await _down(LogicalKeyboardKey.tab, up: true);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (focusIsOn(finder)) return;
    fail(
      'Tab never reached $finder; focus went ${visited.join(' → ')}; '
      'on screen: ${screenText(tester)}',
    );
  }

  Future<void> waitFor(Finder finder, {int seconds = 20}) => waitUntil(
    () => finder.evaluate().isNotEmpty,
    '$finder',
    seconds: seconds,
  );

  Future<void> waitUntil(
    FutureOr<bool> Function() done,
    String what, {
    int seconds = 20,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(deadline)) {
      final ready = await tester.runAsync(() async => await done());
      if (ready ?? false) {
        await _frames();
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    fail('Timed out waiting for $what. On screen: ${screenText(tester)}');
  }
}

Finder field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(AppTextField));

/// The text box of the field labelled [label], not its buttons.
Finder input(String label) =>
    find.descendant(of: field(label), matching: find.byType(EditableText));

Finder byLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is FocusableSurface && widget.semanticLabel == label,
  description: 'control labelled "$label"',
);

/// A category row in the manager, by the category's name.
Finder rowOf(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is FocusableSurface &&
      (widget.semanticLabel?.startsWith('$name, ') ?? false),
  description: 'category row "$name"',
);

class SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

/// Where the focus is, for failure messages: the focused node and the
/// widgets above it.
String focusPath() {
  final node = FocusManager.instance.primaryFocus;
  final types = <String>[];
  node?.context?.visitAncestorElements((e) {
    final name = e.widget.runtimeType.toString();
    if (!name.startsWith('_') && types.length < 25) types.add(name);
    return true;
  });
  return '$node ← ${types.join(' ← ')}';
}

String screenText(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (text.data case final data? when data.trim().isNotEmpty) data,
].join(' | ');
