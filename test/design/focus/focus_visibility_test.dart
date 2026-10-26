import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

import '../design_harness.dart';

/// Three tabs, Movies chosen, as the Library and Favorites have them.
class _Tabs extends StatefulWidget {
  const new({this.pane});

  final FocusPaneController? pane;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  var _chosen = 'Movies';

  @override
  Widget build(BuildContext context) => FocusPane(
    controller: widget.pane,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final label in const ['Movies', 'Series', 'Videos'])
          Padding(
            padding: const EdgeInsets.all(8),
            child: CountTab(
              label: label,
              selected: label == _chosen,
              onPressed: () => setState(() => _chosen = label),
            ),
          ),
      ],
    ),
  );
}

void main() {
  Finder tab(String label) => find.widgetWithText(CountTab, label);

  String? focusedTab() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<CountTab>()
      ?.label;

  List<String> ringed(WidgetTester tester) => [
    for (final label in const ['Movies', 'Series', 'Videos'])
      if (hasFocusRing(tester, of: tab(label))) label,
  ];

  /// The tabs whose underline shows.
  List<String> underlined(WidgetTester tester) {
    final accent = AppTokens.defaults().colors.accentBase;
    return [
      for (final label in const ['Movies', 'Series', 'Videos'])
        if (tester
            .widgetList<Container>(
              find.descendant(of: tab(label), matching: find.byType(Container)),
            )
            .any((container) => container.color == accent))
          label,
    ];
  }

  /// The desktop's rule, as bootstrap installs it.
  void onDesktop() {
    FocusVisibility.install();
    addTearDown(FocusVisibility.uninstall);
  }

  group('on a desktop', () {
    testWidgets('a click takes the focus and hides every ring; the next '
        'arrow rings again, moving on from the tab clicked', (tester) async {
      final pane = FocusPaneController();
      addTearDown(pane.dispose);
      await pumpDesign(tester, _Tabs(pane: pane));
      onDesktop();
      // The keyboard opened the screen: its first tab is ringed.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedTab(), 'Movies');
      expect(ringed(tester), ['Movies']);

      await tester.tap(tab('Series'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      // The user, in the Library: the ring stayed on Movies while the
      // click moved the underline.
      expect(focusedTab(), 'Series');
      expect(ringed(tester), isEmpty);
      expect(underlined(tester), ['Series']);
      expect(pane.lastFocused, FocusManager.instance.primaryFocus);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(focusedTab(), 'Videos');
      expect(ringed(tester), ['Videos']);
      expect(underlined(tester), ['Series']);
    });

    testWidgets('any key but a modifier on its own rings the control '
        'clicked', (tester) async {
      await pumpDesign(tester, const _Tabs());
      onDesktop();
      await tester.tap(tab('Videos'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(focusedTab(), 'Videos');
      expect(ringed(tester), isEmpty);

      // Shift and the wheel move the Guide through time, mouse in hand.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(ringed(tester), isEmpty);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(focusedTab(), 'Videos');
      expect(ringed(tester), ['Videos']);
    });

    testWidgets('a press anywhere hides the ring of the control the '
        'keyboard is on, and leaves it the focus', (tester) async {
      await pumpDesign(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Tabs(),
            SizedBox(key: Key('nothing'), width: 200, height: 100),
          ],
        ),
      );
      onDesktop();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringed(tester), ['Movies']);

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('nothing'))),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(focusedTab(), 'Movies');
      expect(ringed(tester), isEmpty);
    });

    testWidgets('a right-click takes the focus too, for the menu to give '
        'it back to', (tester) async {
      var menus = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpDesign(
        tester,
        FocusableSurface.child(
          focusNode: node,
          onPressed: () {},
          onMenu: () => menus++,
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      onDesktop();

      await tester.tap(
        find.byType(FocusableSurface),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(menus, 1);
      expect(node.hasPrimaryFocus, isTrue);
      expect(hasFocusRing(tester), isFalse);
    });

    testWidgets("the player's controls leave the focus where it was", (
      tester,
    ) async {
      final picture = FocusNode(debugLabel: 'picture');
      addTearDown(picture.dispose);
      var paused = 0;
      await pumpDesign(
        tester,
        Focus(
          focusNode: picture,
          autofocus: true,
          child: OsdButton(
            icon: AppIcons.pause,
            tooltip: 'Pause',
            onPressed: () => paused++,
          ),
        ),
      );
      onDesktop();
      await tester.pumpAndSettle();
      expect(picture.hasPrimaryFocus, isTrue);

      await tester.tap(find.byType(OsdButton), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(paused, 1);
      expect(picture.hasPrimaryFocus, isTrue);
    });

    testWidgets('a text field clicked keeps its focused look: the border '
        'and glow, and the caret', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Tabs(),
              AppTextField(hint: 'Name'),
            ],
          ),
        ),
      );
      onDesktop();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringed(tester), ['Movies']);

      await tester.tap(find.byType(TextField), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      final colors = AppTokens.defaults().colors;
      BoxDecoration field() =>
          tester
                  .widget<AnimatedContainer>(
                    find
                        .descendant(
                          of: find.byType(AppTextField),
                          matching: find.byType(AnimatedContainer),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode,
        isA<FocusNode>().having((node) => node.hasFocus, 'focused', isTrue),
      );
      expect((field().border! as Border).top.color, colors.accentBase);
      expect(field().boxShadow, isNotEmpty);
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable
            .showCursor
            .value,
        isTrue,
      );
      expect(ringed(tester), isEmpty);

      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect((field().border! as Border).top.color, colors.accentBase);
      expect(ringed(tester), isEmpty);
    });
  });

  group('on a TV', () {
    testWidgets('keys only: the ring follows the focus as it always has, '
        'and nothing hides it', (tester) async {
      // A TV never installs the desktop's rule (bootstrap).
      await pumpDesign(tester, const _Tabs(), tv: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedTab(), 'Movies');
      expect(ringed(tester), ['Movies']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusedTab(), 'Series');
      expect(ringed(tester), ['Series']);
      expect(underlined(tester), ['Movies']);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(underlined(tester), ['Series']);
      expect(ringed(tester), ['Series']);

      // A touch, were there one, moves no focus and hides no ring.
      await tester.tap(tab('Videos'));
      await tester.pumpAndSettle();
      expect(focusedTab(), 'Series');
      expect(ringed(tester), ['Series']);
      expect(underlined(tester), ['Videos']);
    });
  });
}
