import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:logger/logger.dart';

/// What a pumped app gives a test: the router to assert on and the error
/// reporter to push a failure through.
class AppUnderTest {
  const new({required this.router, required this.errors});

  final GoRouter router;
  final ErrorReporter errors;

  /// The path the router is currently showing.
  String get location => router.state.uri.path;
}

/// Pumps the real app — router, shell and global shortcuts — at a desktop
/// window size.
///
/// [ErrorReporter] is built but deliberately not installed: a test must
/// not take over `FlutterError.onError`.
Future<AppUnderTest> pumpApp(
  WidgetTester tester, {
  String initialLocation = '/',
  Size size = const Size(1440, 900),
  List<Override> overrides = const [],
}) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final log = AppLog(output: _SilentOutput(), secrets: SecretRegistry());
  final errors = ErrorReporter(log);
  addTearDown(errors.dispose);
  final router = buildRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLogProvider.overrideWithValue(log),
        secretRegistryProvider.overrideWithValue(SecretRegistry()),
        errorReporterProvider.overrideWithValue(errors),
        routerProvider.overrideWithValue(router),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: router,
        builder: (context, child) =>
            AppGlobalShortcuts(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
  await settleApp(tester);

  return AppUnderTest(router: router, errors: errors);
}

/// Pumps past the shell's short transitions (the focus ring, the route
/// fade, the toast switcher) without waiting for the toast's own timer.
Future<void> settleApp(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Finds an icon-only control by the label it gives assistive
/// technology, which is the only name such a control has.
Finder findByLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is FocusableSurface && widget.semanticLabel == label,
  description: 'control labelled "$label"',
);

class _SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
