// Launch smoke test: the real root widget, the real router, the real
// shell. It is what CI runs under xvfb on Linux (step 8), so it is kept
// deliberately small — the detailed keyboard and golden coverage lives
// in `test/`.
//
// `bootstrap()` itself is not called: it takes no overrides and resolves
// `AppPaths` itself, so it would write a log file and a database into the
// user's real application-support directory and hand
// `FlutterError.onError` to `ErrorReporter`, which the test binding owns.
// Instead this pumps the app's own [IptvPlayerApp] with the same
// ProviderScope overrides bootstrap passes, minus the disk-backed ones.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/desktop_shell.dart';
import 'package:iptv_player/app/shell/nav_rail.dart';
import 'package:iptv_player/app/shell/top_bar.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/home/presentation/home_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:logger/logger.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app launches, shows the shell, and navigates', (
    tester,
  ) async {
    // A fixed logical size, so the run depends neither on the window the
    // window manager happens to give us nor on xvfb's screen.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final log = AppLog(output: _SilentOutput(), secrets: SecretRegistry());
    // Built, never installed: the test binding owns FlutterError.onError.
    final errors = ErrorReporter(log);
    addTearDown(errors.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLogProvider.overrideWithValue(log),
          secretRegistryProvider.overrideWithValue(SecretRegistry()),
          errorReporterProvider.overrideWithValue(errors),
        ],
        child: const IptvPlayerApp(),
      ),
    );
    await _settle(tester);

    // It launched.
    expect(find.byType(IptvPlayerApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The desktop shell rendered: rail, top bar, and Home on top.
    expect(find.byType(DesktopShell), findsOneWidget);
    expect(find.byType(NavRail), findsOneWidget);
    expect(find.byType(ShellTopBar), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(DesktopShell)));
    expect(router.state.uri.path, AppDestination.home.path);

    // A second destination replaces the screen. The rail item is
    // icon-only while the rail is collapsed, so it is found by the label
    // it gives assistive technology.
    await tester.tap(_byLabel(AppDestination.liveTv.label));
    await _settle(tester);

    expect(router.state.uri.path, AppDestination.liveTv.path);
    expect(find.byType(LiveTvScreen), findsOneWidget);
    expect(
      find.byType(HomeScreen),
      findsNothing,
      reason: 'the indexed stack keeps Home alive but off stage',
    );

    // And back, to show the app is still running and still responding.
    await tester.tap(_byLabel(AppDestination.home.label));
    await _settle(tester);

    expect(router.state.uri.path, AppDestination.home.path);
    expect(find.byType(DesktopShell), findsOneWidget);
    expect(find.byType(NavRail), findsOneWidget);
    expect(find.byType(ShellTopBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Pumps past the shell's short transitions without waiting on the
/// toast's own timer. `pumpAndSettle` is deliberately avoided: it waits
/// for every animation to stop, which a repeating one never does.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Finds an icon-only control by the label it gives assistive
/// technology, which is the only name such a control has.
Finder _byLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is FocusableSurface && widget.semanticLabel == label,
  description: 'control labelled "$label"',
);

class _SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
