// Phase 4 step 5 end to end, with the keyboard only: the real app,
// database, sync, guide import and match jobs, against the fake panel
// (in its own process) and its xmltv.php.
//
// Ctrl+, → Settings → Guide → Import guide → Keep: 3 days (re-imports) →
// Time offset +1 h (re-imports once) → the Unmatched list → Enter opens
// the Match… picker → type a guide channel's name → Enter maps it → the
// channel leaves Unmatched and the focus stays in the list.
//
// Text goes in through the text-input channel, as a keyboard's does;
// everything else is keys. No taps.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/presentation/guide_match_picker.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings → Guide with the keyboard only', (tester) async {
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

    Finder inSettings(String text) => find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.text(text),
    );
    Future<void> importFinished() async {
      await k.waitFor(find.text('Refresh guide'), seconds: 90);
      await k.waitFor(find.textContaining('updated just now'));
    }

    // ── Ctrl+, → Settings; Tab to Guide in its list; Enter.
    await k.chord(LogicalKeyboardKey.comma);
    await k.waitFor(find.byType(SettingsScreen));
    await k.tabTo(inSettings('Guide'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(
      find.text(
        'No guide imported yet. '
        "From your provider's XMLTV.",
      ),
    );
    expect(find.text('No guide to match against yet'), findsOneWidget);

    // ── Import guide.
    await k.tabTo(find.text('Import guide'));
    await k.press(LogicalKeyboardKey.enter);
    await importFinished();
    expect(find.textContaining('channels matched'), findsOneWidget);
    final imports = app.container.read(epgRepositoryProvider);
    final first = (await tester.runAsync(() => imports.coverage(app.sourceId)))!
        .valueOrNull!;
    expect(first.hasGuide, isTrue);

    // ── Keep: Enter opens the menu on "1 day"; ↓↓ is 3 days; Enter saves
    // and re-imports.
    await k.tabTo(find.text('7 days'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('14 days'));
    await k.press(LogicalKeyboardKey.arrowDown);
    await k.press(LogicalKeyboardKey.arrowDown);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('3 days'));
    await k.waitUntil(
      () => app.container
          .read(guideImportServiceProvider)
          .isImporting(app.sourceId),
      'the re-import after Keep changed',
    );
    await k.waitUntil(
      () => !app.container
          .read(guideImportServiceProvider)
          .isImporting(app.sourceId),
      'the re-import to finish',
      seconds: 90,
    );
    await importFinished();
    final kept = (await tester.runAsync(() => imports.coverage(app.sourceId)))!
        .valueOrNull!;
    expect(kept.lastImport!.id, greaterThan(first.lastImport!.id));
    // Three days ahead, plus the day behind: never past four days away.
    expect(
      kept.lastEnd!.difference(DateTime.now()).inHours,
      lessThanOrEqualTo(3 * 24 + 24),
    );

    // ── Time offset: Tab to it, → → is +1 h; saved once it settles.
    await k.tabTo(find.text('None'));
    await k.press(LogicalKeyboardKey.arrowRight);
    await k.press(LogicalKeyboardKey.arrowRight);
    expect(find.text('+1 h'), findsOneWidget);
    await k.waitUntil(
      () => app.offsetMinutes() == 60,
      'the offset saved on the source',
    );
    await k.waitUntil(
      () => !app.container
          .read(guideImportServiceProvider)
          .isImporting(app.sourceId),
      'the offset re-import to finish',
      seconds: 90,
    );
    await importFinished();

    // ── The Unmatched list: one Tab stop; Enter on its first row opens
    // the picker with the focus in its search field.
    final unmatched = (await tester.runAsync(
      () => imports.channelMatches(app.sourceId),
    ))!.valueOrNull!;
    expect(unmatched, isNotEmpty, reason: 'the fake leaves some unmatched');
    final target = unmatched.first;
    await k.tabTo(
      find.byWidgetPredicate(
        (widget) =>
            widget is FocusableSurface &&
            (widget.semanticLabel?.contains('${target.name}, ') ?? false),
        description: 'the row of ${target.name}',
      ),
    );
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.byType(GuideMatchPicker));
    await k.waitFor(find.text('Match ${target.name}'));

    // Type a guide channel's name; the first candidate is it; Enter maps.
    final guideChannels = (await tester.runAsync(
      () => imports.guideChannels(app.sourceId, limit: 1),
    ))!.valueOrNull!;
    final chosen = guideChannels.single;
    await k.type(chosen.label, into: "Search the guide's channels");
    await k.waitFor(find.text(chosen.xmltvId));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await k.waitUntil(
      () => find.byType(GuideMatchPicker).evaluate().isEmpty,
      'the picker to close',
    );

    // Mapped and matched: the channel leaves Unmatched, the focus stays
    // in the list.
    await k.waitUntil(
      () => find.text(target.name).evaluate().isEmpty,
      'the channel to leave the Unmatched list',
    );
    final matched = (await tester.runAsync(
      () => imports.channelMatch(target.channelId),
    ))!.valueOrNull!;
    expect(matched.xmltvId, chosen.xmltvId);
    expect(matched.rule, GuideMatchRule.manual);
    if (unmatched.length > 1) {
      await k.waitUntil(
        () => k.focusedLabel()?.contains(unmatched[1].name) ?? false,
        'the focus on the next unmatched channel (${k.focusedLabel()})',
      );
    }
    final counts = (await tester.runAsync(
      () => imports.watchChannelMatchCounts(app.sourceId).first,
    ))!;
    expect(counts.manual, 1);
  });
}

final class _App {
  new _(this.container, this._directory, this._db, this.sourceId);

  static Future<_App> open(FakePanel panel) async {
    final directory = await Directory.systemTemp.createTemp('iptv_guide');
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
    return _App._(container, directory, db, id);
  }

  final ProviderContainer container;
  final Directory _directory;
  final AppDatabase _db;
  final String sourceId;

  String get location => container.read(routerProvider).state.uri.path;

  int? offsetMinutes() => container
      .read(sourcesProvider)
      .value
      ?.where((s) => s.id == sourceId)
      .firstOrNull
      ?.epgOffsetMinutes;

  Future<void> close() async {
    container.dispose();
    await _db.close();
    await _directory.delete(recursive: true);
  }
}
