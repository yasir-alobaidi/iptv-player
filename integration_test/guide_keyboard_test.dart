// Phase 4 step 6 end to end, with the keyboard only: the real app,
// database, sync and guide import, against the fake panel (in its own
// process) and its xmltv.php.
//
// G from Home → the Guide, the focus on what is on now on the first
// channel → → and ↓ move through programmes → Enter opens the detail
// sheet on Watch channel → Esc closes it → Home comes back to now →
// Shift+Tab to the toolbar → Tomorrow → Jump to now → back into the grid
// → ↓ to a channel with no guide → Enter opens the Match… picker → Esc.
//
// No taps.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/presentation/guide_match_picker.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_sheet.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Guide with the keyboard only', (tester) async {
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);

    final panel = (await tester.runAsync(FakePanel.start))!;
    addTearDown(() => tester.runAsync(panel.stop));
    final app = (await tester.runAsync(() => _App.open(panel)))!;
    addTearDown(() => tester.runAsync(app.close));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: app.container,
        child: const IptvPlayerApp(),
      ),
    );
    // Under xvfb no window manager gives the window focus; the test holds
    // it focused, as a desktop session does while the user types.
    SystemChannels.lifecycle.setMessageHandler((message) async => null);
    tester.binding.platformDispatcher.onViewFocusChange = (_) {};
    final k = Keys(tester)..resume();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    bool gridHasFocus() =>
        FocusManager.instance.primaryFocus?.debugLabel == 'guide grid';

    // ── G from Home: the Guide, the focus in the grid, on what is on now.
    await k.press(LogicalKeyboardKey.keyG);
    await k.waitUntil(
      () => app.location == AppDestination.guide.path,
      'the Guide',
    );
    await k.waitUntil(gridHasFocus, 'the focus in the grid');
    await k.waitUntil(() => _ringed() != null, 'a programme under the ring');
    final first = _ringed()!;

    // ── → the next programme; ↓ the next channel at that time; ← back.
    await k.press(LogicalKeyboardKey.arrowRight);
    final next = _ringed();
    expect(next, isNot(first));
    await k.press(LogicalKeyboardKey.arrowDown);
    expect(_ringed(), isNotNull);
    await k.press(LogicalKeyboardKey.arrowUp);
    expect(_ringed(), next);

    // ── Enter: the sheet, Watch channel first; Esc: back in the grid.
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.byType(GuideProgrammeSheet));
    expect(
      find.descendant(
        of: find.byType(GuideProgrammeSheet),
        matching: find.text(next!),
      ),
      findsOneWidget,
    );
    expect(k.focusedLabel(), 'Watch channel');
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(
      () => find.byType(GuideProgrammeSheet).evaluate().isEmpty,
      'the sheet to close',
    );
    expect(gridHasFocus(), isTrue);

    // ── Home: back to now.
    await k.press(LogicalKeyboardKey.home);
    expect(_ringed(), first);

    // ── Shift+Tab to the toolbar; Tomorrow; Jump to now.
    await k.tabTo(find.text('Tomorrow'), back: true);
    await k.press(LogicalKeyboardKey.enter);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await k.waitFor(
      find.text('${formatWeekday(tomorrow)} ${tomorrow.day}'.toUpperCase()),
    );
    await k.tabTo(find.text('Jump to now'));
    await k.press(LogicalKeyboardKey.enter);
    final today = DateTime.now();
    await k.waitFor(
      find.text('${formatWeekday(today)} ${today.day}'.toUpperCase()),
    );

    // ── Back into the grid; ↓ to a channel with no guide (the fake
    // panel gives every ninth none); Enter opens the Match… picker.
    await k.tabTo(
      find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
      ),
    );
    await k.waitUntil(gridHasFocus, 'the focus back in the grid');
    for (var i = 0; i < 20 && _ringed() != 'No guide information'; i++) {
      await k.press(LogicalKeyboardKey.arrowDown);
    }
    expect(_ringed(), 'No guide information');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.byType(GuideMatchPicker));
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(
      () => find.byType(GuideMatchPicker).evaluate().isEmpty,
      'the picker to close',
    );
    expect(gridHasFocus(), isTrue);
  });
}

/// The title under the grid's focus ring, or "No guide information";
/// null with no ring in the grid.
String? _ringed() {
  final grid = find.byWidgetPredicate(
    (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
  );
  final rings = find.descendant(
    of: grid,
    matching: find.byWidgetPredicate((w) => w is FocusRing && w.visible),
  );
  if (rings.evaluate().isEmpty) return null;
  // The focused cell is the one its semantics call selected.
  final selected = find
      .descendant(
        of: grid,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.selected ?? false),
        ),
      )
      .evaluate();
  if (selected.isEmpty) return null;
  final label = (selected.first.widget as Semantics).properties.label ?? '';
  if (label.startsWith('No guide information')) return 'No guide information';
  return label.split(', ').first;
}

final class _App {
  new _(this.container, this._directory, this._db);

  static Future<_App> open(FakePanel panel) async {
    final directory = await Directory.systemTemp.createTemp('iptv_grid');
    final db = AppDatabase(await openAppDatabase(directory));
    final log = AppLog(output: SilentOutput(), secrets: SecretRegistry());
    final container = ProviderContainer(
      overrides: [
        appLogProvider.overrideWithValue(log),
        secretRegistryProvider.overrideWithValue(SecretRegistry()),
        errorReporterProvider.overrideWithValue(ErrorReporter(log)),
        appDatabaseProvider.overrideWithValue(db),
        credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
        startLocationProvider.overrideWithValue('/'),
        ...sourceShellOverrides,
      ],
    );
    final added = await container
        .read(sourceRepositoryProvider)
        .add(
          SourceDraft(
            type: SourceType.xtream,
            name: 'Fake panel',
            url: panel.url,
            username: 'test',
            password: 'test',
          ),
        );
    final id = added.valueOrNull!.id;
    final synced = await container.read(syncServiceProvider).sync(id);
    if (!synced.isOk) throw StateError('sync failed: ${synced.failureOrNull}');
    // The guide comes in first: the walk is about the grid, not the
    // import (Settings → Guide's walk covers that).
    final imported = await container
        .read(guideImportServiceProvider)
        .importGuide(id);
    if (!imported.isOk) {
      throw StateError('import failed: ${imported.failureOrNull}');
    }
    return _App._(container, directory, db);
  }

  final ProviderContainer container;
  final Directory _directory;
  final AppDatabase _db;

  String get location => container.read(routerProvider).state.uri.path;

  Future<void> close() async {
    container.dispose();
    await _db.close();
    await _directory.delete(recursive: true);
  }
}
