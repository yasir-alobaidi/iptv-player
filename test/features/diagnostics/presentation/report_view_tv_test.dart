import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/features/diagnostics/data/diagnostics_providers.dart';
import 'package:iptv_player/features/diagnostics/data/report_share_providers.dart';
import 'package:iptv_player/features/diagnostics/presentation/report_view.dart';

import '../diagnostics_fakes.dart';

/// ADR-059: a TV has neither a clipboard nor a file to give, so its report
/// goes to a phone instead, with each run's own log.
void main() {
  late FakeDiagnostics diagnostics;
  late FakeReportSharer sharer;

  Future<void> pump(WidgetTester tester, FormFactor formFactor) async {
    diagnostics = FakeDiagnostics()..runLogs = '\nThe run before: 2 lines';
    sharer = FakeReportSharer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          formFactorProvider.overrideWithValue(formFactor),
          diagnosticsProvider.overrideWithValue(diagnostics),
          reportSharerProvider.overrideWithValue(sharer),
          appClockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 9)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SizedBox(width: 1200, height: 600, child: ReportView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('on a TV: Send to phone, no Copy or Save; it offers the report '
      "with each run's log under a dated name", (tester) async {
    await pump(tester, FormFactor.tv);
    expect(find.text('Copy diagnostics'), findsNothing);
    expect(find.text('Save to file…'), findsNothing);
    expect(find.textContaining('found on this TV'), findsOneWidget);

    await tester.tap(find.text('Send to phone'));
    await tester.pumpAndSettle();
    expect(find.text('Send the report to your phone'), findsOneWidget);
    expect(diagnostics.shareReports, 1);
    expect(sharer.offered.single, (
      '${diagnostics.text}\nThe run before: 2 lines',
      'bijou-diagnostics-2026-10-26.txt',
    ));
  });

  testWidgets('on a computer: Copy and Save as before, no Send to phone', (
    tester,
  ) async {
    await pump(tester, FormFactor.desktop);
    expect(find.text('Copy diagnostics'), findsOneWidget);
    expect(find.text('Save to file…'), findsOneWidget);
    expect(find.text('Send to phone'), findsNothing);
  });
}
