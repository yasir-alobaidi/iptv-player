import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/app_toasts.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/data/library_scans.dart';
import 'package:logger/logger.dart';

import '../audit/audit_look.dart';
import '../features/settings/appearance_fakes.dart';

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
///
/// [withAppearance] pumps the root widget itself ([IptvPlayerApp]), so
/// Settings → Appearance applies: the accent, the density, reduce motion
/// and the clock through the theme, the text size above the router. Give
/// the look through `appearanceStoreProvider` and
/// `desktopAppearanceProvider`. Without it the default theme is used,
/// as before Phase 9. [settle] false stops after the first frame.
///
/// While the audit draws a scene (`currentAuditLook`), the window is the
/// look's and the root widget is always pumped, at the look's text size:
/// every test's own way of opening a screen is then an audit scene.
Future<AppUnderTest> pumpApp(
  WidgetTester tester, {
  String initialLocation = '/',
  Size size = const Size(1440, 900),
  List<Override> overrides = const [],
  bool withAppearance = false,
  bool settle = true,
}) async {
  final look = currentAuditLook;
  final rootWidget = withAppearance || look != null;
  final all = [
    ...overrides,
    // A test that brings its own appearance has the look in it already
    // (`appearanceOverrides` reads it too).
    if (look != null && !withAppearance) ...appearanceOverrides(),
  ];
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  tester.view.physicalSize = look?.size ?? size;
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
        ...all,
      ],
      child: rootWidget
          ? const IptvPlayerApp()
          : MaterialApp.router(
              theme: buildAppTheme(),
              routerConfig: router,
              // As the app has it (lib/app/app.dart): a TV's remote OK
              // and the design system's TV mode.
              builder: (context, child) => Consumer(
                builder: (context, ref, _) {
                  final onTv = ref.watch(formFactorProvider) == FormFactor.tv;
                  final app = AppGlobalShortcuts(
                    child: AppToasts(child: child ?? const SizedBox.shrink()),
                  );
                  return TvMode(
                    on: onTv,
                    child: onTv ? TvSelectKey(child: app) : app,
                  );
                },
              ),
            ),
    ),
  );
  if (settle) await settleApp(tester);

  return AppUnderTest(router: router, errors: errors);
}

/// Pumps past the shell's short transitions (the focus ring, the route
/// fade, the toast switcher) without waiting for the toast's own timer.
Future<void> settleApp(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  // What ran as an animation ended (a menu's item, once the menu has
  // faded out) gets its frame.
  await tester.pump();
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

/// The Library with nothing in it, for tests of the shell that pass
/// through it with no database: it is the one destination that reads its
/// lists whether or not there is a source.
final List<Override> emptyLibraryOverrides = [
  libraryRepositoryProvider.overrideWithValue(const _EmptyLibrary()),
  libraryScanStateProvider.overrideWith(
    (ref) => Stream.value(const LibraryScanState()),
  ),
  downloadTasksProvider.overrideWith((ref) => Stream.value(const [])),
];

final class _EmptyLibrary implements LibraryRepository {
  const new();

  @override
  Stream<LibraryCount> watchCount(LibraryQuery query) =>
      Stream.value(const LibraryCount(count: 0, bytes: 0));

  @override
  Stream<List<LibraryShow>> watchShows({
    LibraryOrigin origin = LibraryOrigin.all,
  }) => Stream.value(const []);

  @override
  Stream<List<LibraryFolder>> watchFolders() => Stream.value(const []);

  @override
  Stream<Set<String>> watchDownloadedKeys(VodType type, String sourceId) =>
      Stream.value(const {});

  @override
  Stream<Map<int, LibraryFolderTotals>> watchFolderTotals() =>
      Stream.value(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
