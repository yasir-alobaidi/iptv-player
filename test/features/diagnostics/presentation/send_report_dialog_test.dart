import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/diagnostics/data/report_share_providers.dart';
import 'package:iptv_player/features/diagnostics/presentation/send_report_dialog.dart';

import '../diagnostics_fakes.dart';

/// ADR-059: the report offered to a phone on the same Wi-Fi, by a code
/// on the screen; on a TV's canvas, keyboard only.
void main() {
  const report = 'Bijou 0.1.0+343 · Android 12 · TCL 43V8C\n';
  const fileName = 'bijou-diagnostics-2026-10-26.txt';
  const address = 'http://192.168.1.50:41234/k3v9q2mx7p/';
  const title = 'Send the report to your phone';

  late FakeReportSharer sharer;
  late Result<String> loaded;
  Completer<void>? loadGate;
  var loads = 0;

  setUp(() {
    sharer = FakeReportSharer();
    loaded = const Ok(report);
    loadGate = null;
    loads = 0;
  });

  Future<Result<String>> load() async {
    loads++;
    if (loadGate case final gate?) await gate.future;
    return loaded;
  }

  Future<void> open(WidgetTester tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    // A TV's canvas (ADR-026).
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reportSharerProvider.overrideWithValue(sharer)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: AppButton(
                  label: 'Send',
                  onPressed: () => unawaited(
                    showSendReportDialog(
                      context,
                      load: load,
                      fileName: fileName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    // The route, then its fade; the placeholder shimmers, so never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  String? focused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    final surface = context.widget is FocusableSurface
        ? context.widget as FocusableSurface
        : context.findAncestorWidgetOfExactType<FocusableSurface>();
    return surface?.semanticLabel;
  }

  Future<void> focus(WidgetTester tester, String label) async {
    for (var i = 0; i < 6; i++) {
      if (focused() == label) return;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    fail('Tab never reached "$label" (on ${focused()})');
  }

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('preparing: a placeholder the size of the code, and Done '
      'focused', (tester) async {
    loadGate = Completer();
    await open(tester);
    expect(find.text(title), findsOneWidget);
    expect(find.text('Getting the report ready…'), findsOneWidget);
    expect(find.byType(QrCodeView), findsNothing);
    expect(tester.getSize(find.byType(Skeleton)), const Size(240, 240));
    expect(find.text('Try again'), findsNothing);
    expect(focused(), 'Done');

    loadGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byType(QrCodeView), findsOneWidget);
  });

  testWidgets('ready: the code holds the address, the steps and the address '
      'in words, waiting for the phone; Done focused', (tester) async {
    await open(tester);
    await tester.pump();
    expect(loads, 1);
    expect(sharer.offered, [(report, fileName)]);
    expect(tester.widget<QrCodeView>(find.byType(QrCodeView)).data, address);
    expect(tester.getSize(find.byType(QrCodeView)), const Size(240, 240));
    expect(find.text(address), findsOneWidget);
    expect(
      find.text('Connect your phone to the same Wi-Fi as this TV.'),
      findsOneWidget,
    );
    expect(
      find.text("Point the phone's camera at the code and open the link."),
      findsOneWidget,
    );
    expect(
      find.text('Tap Download the report, then send the file.'),
      findsOneWidget,
    );
    expect(
      find.text("Or type this address in the phone's browser:"),
      findsOneWidget,
    );
    expect(find.text('Waiting for your phone…'), findsOneWidget);
    expect(
      find.text(
        'No passwords or server addresses are in it. The address works '
        'while this window is open.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
    expect(focused(), 'Done');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone downloads it: the status says so, in the success '
      'color', (tester) async {
    await open(tester);
    await tester.pump();
    sharer.offers.single.fetch();
    await tester.pump();
    expect(find.text('Waiting for your phone…'), findsNothing);
    expect(find.text('Your phone has the report.'), findsOneWidget);
    expect(
      colorOf(tester, 'Your phone has the report.'),
      AppTokens.defaults().colors.success,
    );
    // Again: still said once.
    sharer.offers.single.fetch();
    await tester.pump();
    expect(find.text('Your phone has the report.'), findsOneWidget);
  });

  testWidgets('no network: says so, and Try again offers it again', (
    tester,
  ) async {
    sharer.failure = NetworkFailure('no network address');
    await open(tester);
    await tester.pump();
    expect(
      find.text("This TV isn't on a network a phone can reach."),
      findsOneWidget,
    );
    expect(
      find.text('Connect it to Wi-Fi or a cable and try again.'),
      findsOneWidget,
    );
    expect(find.byType(QrCodeView), findsNothing);
    expect(focused(), 'Done');

    sharer.failure = null;
    await focus(tester, 'Try again');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(sharer.offered, hasLength(2));
    expect(find.byType(QrCodeView), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(focused(), 'Done');
  });

  testWidgets("the report couldn't be made: says why, and Try again makes "
      'it again', (tester) async {
    loaded = Err(StorageFailure('disk full'));
    await open(tester);
    await tester.pump();
    expect(find.text("The report couldn't be made"), findsOneWidget);
    expect(find.text(failureMessage(StorageFailure())), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
    expect(sharer.offered, isEmpty);
    expect(focused(), 'Done');

    loaded = const Ok(report);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(loads, 2);
    expect(sharer.offered, [(report, fileName)]);
    expect(find.text(address), findsOneWidget);
  });

  testWidgets('Done closes the dialog, and the offer with it', (tester) async {
    await open(tester);
    await tester.pump();
    final offer = sharer.offers.single;
    expect(offer.closed, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
    expect(offer.closed, 1);
  });

  testWidgets('an offer that comes after the dialog closed is closed', (
    tester,
  ) async {
    sharer.gate = Completer();
    await open(tester);
    await tester.pump();
    expect(find.text('Getting the report ready…'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);

    sharer.gate!.complete();
    await tester.pump();
    expect(sharer.offers.single.closed, 1);
  });
}
