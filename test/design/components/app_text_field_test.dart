import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';

import '../design_harness.dart';

void main() {
  group('AppTextField', () {
    testWidgets('shows the label, hint and helper text', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(
          width: 320,
          child: AppTextField(
            label: 'Server URL',
            hint: 'http://example.com:8080',
            helperText: 'Include the port',
          ),
        ),
      );

      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text('http://example.com:8080'), findsOneWidget);
      expect(find.text('Include the port'), findsOneWidget);
    });

    testWidgets('an error message replaces the helper text', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(
          width: 320,
          child: AppTextField(
            label: 'Server URL',
            helperText: 'Include the port',
            errorText: "That server didn't answer.",
          ),
        ),
      );

      expect(find.text("That server didn't answer."), findsOneWidget);
      expect(find.text('Include the port'), findsNothing);
    });

    testWidgets('the clear button appears with text and empties it', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpDesign(
        tester,
        SizedBox(
          width: 320,
          child: AppTextField(controller: controller, label: 'Name'),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'Home provider');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(controller.text, isEmpty);
    });

    testWidgets('password reveal toggles obscuring', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(
          width: 320,
          child: AppTextField(label: 'Password', obscure: true),
        ),
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
    });

    testWidgets('a disabled field is dimmed and not editable', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(
          width: 320,
          child: AppTextField(label: 'User agent', enabled: false),
        ),
      );

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.4);
    });
  });

  group('SearchField', () {
    testWidgets('shows the hint and the Ctrl K keycap', (tester) async {
      await pumpDesign(tester, const SearchField(width: 360));

      expect(find.text('Ctrl K'), findsOneWidget);
      expect(find.text('Search channels, shows, movies'), findsOneWidget);
    });

    testWidgets('in button mode Enter opens the overlay', (tester) async {
      var opened = 0;
      await pumpDesign(
        tester,
        SearchField(width: 360, autofocus: true, onTap: () => opened++),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, 1);

      await tester.tap(find.byType(SearchField));
      await tester.pump();
      expect(opened, 2);
    });
  });
}
