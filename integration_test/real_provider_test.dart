// The keyboard-only walk of sources_keyboard_test.dart, against a real
// Xtream provider instead of the fake panel. Opt-in and local only: it is
// skipped unless a login file exists, so CI and ordinary runs skip it.
//
// The login file (outside the repository, readable only by you):
//   ~/.config/iptv-player-dev/real_provider.json, or the path in
//   $IPTV_REAL_PROVIDER, holding
//   {"server": "http://host:port", "username": "…", "password": "…"}
//
// Run: xvfb-run -a flutter test integration_test/real_provider_test.dart -d linux
//
// The app runs on a throwaway database and an in-memory keyring, so the
// installed app's data is untouched. The provider sees one wrong sign-in,
// one sync cancelled early, one full sync and one refresh, one request at
// a time. Findings go to build/real_provider_run/ (report.md, app.log),
// with the username and password masked everywhere.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:logger/logger.dart';

import 'support/keyboard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final login = _Login.read();

  testWidgets(
    'a real provider, with the keyboard only',
    (tester) async {
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);

      final report = _Report(login!);
      final app = (await tester.runAsync(() => _App.open(login, report)))!;
      addTearDown(() => tester.runAsync(app.close));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app.container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      final k = Keys(tester)..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      try {
        await _walk(tester, k, app, login, report);
        report.line('\n**Result: the whole walk passed.**');
      } on Object catch (error) {
        report.line('\n**Result: stopped.** ${report.scrub('$error')}');
        report.line('Screen: ${report.scrub(screenText(tester))}');
        await tester.runAsync(report.write);
        // The failure, masked: the raw one could quote the screen.
        fail(report.scrub('$error'));
      }
      await tester.runAsync(report.write);
      expect(tester.takeException(), isNull);
    },
    skip: login == null,
    timeout: const Timeout(Duration(minutes: 40)),
  );
}

Future<void> _walk(
  WidgetTester tester,
  Keys k,
  _App app,
  _Login login,
  _Report report,
) async {
  // ── Welcome → Connect.
  await k.waitFor(find.text('Add your first source'));
  await k.press(LogicalKeyboardKey.enter);
  await k.waitFor(find.text('Connect your provider'));
  await k.type(login.server, into: 'Server address');
  await k.press(LogicalKeyboardKey.tab);
  await k.type(login.username, into: 'Username');
  await k.press(LogicalKeyboardKey.tab);

  // ── One wrong password.
  await k.type('${login.password}-wrong', into: 'Password');
  var watch = Stopwatch()..start();
  await k.press(LogicalKeyboardKey.enter);
  final wrong = await _outcome(k);
  report.step(
    'Wrong password',
    '"$wrong" after ${_s(watch.elapsed)}'
        '${wrong == 'Sign-in refused' ? '' : ' — expected "Sign-in refused"'}',
  );
  expect(
    screenText(tester),
    isNot(contains('${login.password}-wrong')),
    reason: 'the password showed outside its field',
  );

  // ── The right one.
  await k.tabTo(input('Password'), back: true);
  await k.replaceText(login.password, into: 'Password');
  watch = Stopwatch()..start();
  await k.press(LogicalKeyboardKey.enter);
  final right = await _outcome(k);
  report
    ..step('Right password', '"$right" after ${_s(watch.elapsed)}')
    ..block('Connect screen', screenText(tester));
  expect(right, 'Connected');
  expect(k.focusIsOn(find.text('Start sync')), isTrue);

  // ── Start the sync, Cancel it as soon as it can be.
  watch = Stopwatch()..start();
  await k.press(LogicalKeyboardKey.enter);
  bool done() => find.textContaining('Done in').evaluate().isNotEmpty;
  await k.waitUntil(
    () => done() || find.text('Cancel').evaluate().isNotEmpty,
    'the sync screen',
  );
  var cancelled = false;
  if (!done()) {
    try {
      await k.tabTo(find.text('Cancel'));
      cancelled = !done();
    } on TestFailure {
      if (!done()) rethrow;
    }
  }
  if (cancelled) {
    await k.press(LogicalKeyboardKey.enter);
    await k.waitUntil(
      () => app.location == addSourceRoutePath,
      'Connect after Cancel',
    );
    final left = await app.sourceCount();
    report.step(
      'Cancel',
      left == 0
          ? 'back on Connect, nothing kept, the form still filled in'
          : '$left source(s) left behind',
    );
    expect(left, 0);
    expect(k.textOf(field('Username')), login.username);

    // ── Test again, then the whole sync.
    await k.tabTo(find.text('Test connection'));
    await k.press(LogicalKeyboardKey.enter);
    expect(await _outcome(k), 'Connected');
    watch = Stopwatch()..start();
    await k.press(LogicalKeyboardKey.enter);
  } else {
    report.step('Cancel', 'not tried: the sync finished before Tab got there');
  }
  await k.waitUntil(
    () => done() || find.text('Retry').evaluate().isNotEmpty,
    'the sync to end',
    seconds: 30 * 60,
  );
  report
    ..step('First sync', 'ended after ${_s(watch.elapsed)}')
    ..block('Sync screen', screenText(tester));
  expect(find.text('Retry'), findsNothing, reason: 'the sync failed');
  expect(k.focusIsOn(find.text('Pick categories')), isTrue);
  await k.press(LogicalKeyboardKey.enter);

  // ── Pick categories: untick one, Finish.
  await k.waitFor(find.text('Pick what you watch'));
  report.step(
    'Pick categories',
    '${find.byType(AppCheckbox).evaluate().length} checkboxes on screen',
  );
  await k.tabTo(find.byType(AppCheckbox).last);
  await k.press(LogicalKeyboardKey.space);
  await k.tabTo(find.text('Finish'));
  await k.press(LogicalKeyboardKey.enter);
  expect(app.location, '/');
  final source = (await app.sources()).single;
  var name = source.name;
  report.step('Home', 'the top bar names the source "$name"');

  // ── Settings → Sources: the card, Refresh.
  await k.chord(LogicalKeyboardKey.comma);
  expect(app.location, '/settings');
  await k.waitFor(find.textContaining(' channels · '));
  report.block('Source card', _textsWith(tester, ' · '));
  await k.tabTo(find.text('Refresh'));
  final statuses = <SyncStatus>[];
  final watching = app.container
      .read(syncServiceProvider)
      .watch(source.id)
      .listen(statuses.add);
  watch = Stopwatch()..start();
  await k.press(LogicalKeyboardKey.enter);
  SyncStatus? ended;
  await k.waitUntil(
    () {
      final start = statuses.indexWhere((s) => s is SyncRunning);
      if (start < 0) return false;
      ended = statuses.skip(start).where((s) => s is! SyncRunning).firstOrNull;
      return ended != null;
    },
    'the refresh to finish',
    seconds: 30 * 60,
  );
  await watching.cancel();
  expect(ended, isA<SyncSucceeded>(), reason: 'the refresh ended $ended');
  report
    ..step('Refresh', 'ended after ${_s(watch.elapsed)}')
    ..block('Source card after Refresh', _textsWith(tester, ' · '));

  // ── ⋯ → Account details, then Esc.
  await _menu(k, name, 'Account details…');
  await k.waitFor(find.textContaining('Nothing here is secret'));
  report.block('Account details', _dialogRows(tester));
  await k.press(LogicalKeyboardKey.escape);
  await k.waitUntil(
    () => find.textContaining('Nothing here is secret').evaluate().isEmpty,
    'the dialog to close',
  );

  // ── Edit: rename it, password left empty.
  await k.tabTo(find.text('Edit'));
  await k.press(LogicalKeyboardKey.enter);
  await k.waitFor(find.text('Edit $name'));
  expect(k.textOf(field('Password')), isEmpty);
  await k.tabTo(input('Name'));
  await k.replaceText('My provider', into: 'Name');
  await k.press(LogicalKeyboardKey.enter);
  await k.waitUntil(() => app.location == '/settings', 'Settings');
  name = 'My provider';
  await k.waitFor(find.text(name));
  report.step('Edit', 'renamed without a new test or sync');

  // ── Categories: hide one, move it up, rename it.
  await k.tabTo(find.text('Sources').first, back: true);
  for (var i = 0; i < 5; i++) {
    await k.press(LogicalKeyboardKey.arrowDown);
  }
  expect(k.focusIsOn(find.text('Categories').first), isTrue);
  await k.press(LogicalKeyboardKey.enter);
  await k.waitFor(find.text('Show hidden'));
  final before = await app.liveNames(source.id);
  report.step(
    'Categories',
    '${before.length} live categories'
        '${before.length < 2 ? ', too few to move one' : ''}',
  );
  if (before.length >= 2) {
    final target = before[1];
    await k.tabTo(rowOf(target));
    await k.press(LogicalKeyboardKey.space);
    await k.waitUntil(
      () async => (await app.hiddenNames(source.id)).contains(target),
      'the hide to be saved',
    );
    await k.alt(LogicalKeyboardKey.arrowUp);
    await k.waitUntil(
      () async => (await app.liveNames(source.id)).first == target,
      'the move to be saved',
    );
    await k.press(LogicalKeyboardKey.tab);
    expect(k.focusedLabel(), 'Rename $target');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Rename category'));
    await k.replaceText('My favourites', into: 'Name');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('was $target'));
    expect((await app.liveNames(source.id)).first, 'My favourites');
    report.step('Categories', 'hid, moved up and renamed "$target"');
  }

  // ── Remove: Enter keeps it; Tab, Enter removes it.
  await k.tabTo(find.text('Sources').first, back: true);
  await k.press(LogicalKeyboardKey.enter);
  await _menu(k, name, 'Remove…');
  await k.waitFor(find.text('Remove $name?'));
  await k.press(LogicalKeyboardKey.enter);
  expect(await app.sourceCount(), 1);
  await _menu(k, name, 'Remove…');
  await k.waitFor(find.text('Remove $name?'));
  await k.press(LogicalKeyboardKey.tab);
  await k.press(LogicalKeyboardKey.enter);
  await k.waitUntil(
    () => app.location == welcomeRoutePath,
    'Welcome after the removal',
  );
  expect(await app.sourceCount(), 0);
  report.step(
    'Remove',
    'Enter kept it; Tab, Enter removed it; back on Welcome',
  );
}

/// What the Connect card settled on: its title.
Future<String> _outcome(Keys k) async {
  const titles = [
    'Connected',
    'Sign-in refused',
    'Access refused',
    'Not an Xtream panel',
    'Not found',
  ];
  await k.waitUntil(
    () => find.text('Connecting…').evaluate().isEmpty,
    'the connection test to end',
    seconds: 90,
  );
  for (final title in titles) {
    if (find.text(title).evaluate().isNotEmpty) return title;
  }
  return 'something else';
}

Future<void> _menu(Keys k, String name, String item) async {
  await k.tabTo(byLabel('More for $name'));
  await k.press(LogicalKeyboardKey.enter);
  await k.waitFor(find.text(item));
  for (var i = 0; i < 8 && !k.focusIsOn(find.text(item)); i++) {
    await k.press(LogicalKeyboardKey.arrowDown);
  }
  await k.press(LogicalKeyboardKey.enter);
}

String _s(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

String _dialogRows(WidgetTester tester) => _texts(
  tester,
  find.ancestor(
    of: find.textContaining('Nothing here is secret'),
    matching: find.byType(AppDialog),
  ),
);

String _texts(WidgetTester tester, Finder within) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: within, matching: find.byType(Text)),
  ))
    if (text.data case final data? when data.trim().isNotEmpty) data,
].join(' | ');

String _textsWith(WidgetTester tester, String part) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (text.data case final data? when data.contains(part)) data,
].join(' | ');

final class _Login {
  const new(this.server, this.username, this.password);

  final String server;
  final String username;
  final String password;

  static _Login? read() {
    final home = Platform.environment['HOME'] ?? '';
    final file = File(
      Platform.environment['IPTV_REAL_PROVIDER'] ??
          '$home/.config/iptv-player-dev/real_provider.json',
    );
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final login = _Login(
      '${json['server'] ?? ''}'.trim(),
      '${json['username'] ?? ''}'.trim(),
      '${json['password'] ?? ''}',
    );
    if ([login.server, login.username, login.password].any((v) => v.isEmpty)) {
      return null;
    }
    return login;
  }
}

/// The findings, masked, in build/real_provider_run/report.md.
final class _Report {
  new(this._login);

  final _Login _login;
  final _lines = <String>[
    '# Real provider run — ${DateTime.now().toIso8601String()}',
    '',
  ];
  int warnings = 0;

  String scrub(String text) =>
      redact(text, secrets: [_login.password, _login.username]);

  void line(String text) => _lines.add(scrub(text));

  void step(String name, String what) => line('- **$name:** $what');

  void block(String name, String text) =>
      line('- **$name:** `${text.replaceAll('`', "'")}`');

  static final directory = Directory('build/real_provider_run');

  Future<void> write() async {
    await directory.create(recursive: true);
    final all = [..._lines, '', 'Log warnings and errors: $warnings (app.log)'];
    await File('${directory.path}/report.md')
        .writeAsString('${all.join('\n')}\n');
  }
}

/// The app as `bootstrap()` builds it, on a throwaway database and an
/// in-memory keyring, logging (masked) to build/real_provider_run/app.log.
final class _App {
  new(this.container, this._directory, this._db, this._log);

  static Future<_App> open(_Login login, _Report report) async {
    final directory = await Directory.systemTemp.createTemp('iptv_real');
    final db = AppDatabase(await openAppDatabase(directory));
    await _Report.directory.create(recursive: true);
    final secrets = SecretRegistry()
      ..add(login.password)
      ..add(login.username);
    final log = AppLog(
      output: _FileOutput(File('${_Report.directory.path}/app.log'), report),
      secrets: secrets,
      level: Level.debug,
    );
    final container = ProviderContainer(
      overrides: [
        appLogProvider.overrideWithValue(log),
        secretRegistryProvider.overrideWithValue(secrets),
        errorReporterProvider.overrideWithValue(ErrorReporter(log)),
        appDatabaseProvider.overrideWithValue(db),
        credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
        startLocationProvider.overrideWithValue(welcomeRoutePath),
        ...sourceShellOverrides,
      ],
    );
    return _App(container, directory, db, log);
  }

  final ProviderContainer container;
  final Directory _directory;
  final AppDatabase _db;
  final AppLog _log;

  GoRouter get _router => container.read(routerProvider);

  String get location => _router.state.uri.path;

  Future<List<({String id, String name})>> sources() async => [
    for (final s
        in (await container.read(sourceRepositoryProvider).all()).valueOrNull!)
      (id: s.id, name: s.name),
  ];

  Future<int> sourceCount() async => (await sources()).length;

  bool syncing(String id) =>
      container.read(syncServiceProvider).statusOf(id) is SyncRunning;

  Future<List<String>> liveNames(String id) async => [
    for (final c
        in (await container
                .read(categoryRepositoryProvider)
                .watch(id, CatalogueKind.live)
                .first)
            .categories)
      c.name,
  ];

  Future<Set<String>> hiddenNames(String id) async => {
    for (final kind in CatalogueKind.values)
      for (final c
          in (await container
                  .read(categoryRepositoryProvider)
                  .watch(id, kind)
                  .first)
              .categories)
        if (c.isHidden) c.providerName ?? c.name,
  };

  Future<void> close() async {
    container.dispose();
    await _db.close();
    await _log.close();
    await _directory.delete(recursive: true);
  }
}

/// Appends the (already masked) log lines to a file and counts warnings.
final class _FileOutput extends LogOutput {
  new(this._file, this._report) {
    _file.writeAsStringSync('');
  }

  final File _file;
  final _Report _report;

  @override
  void output(OutputEvent event) {
    if (event.level.index >= Level.warning.index) _report.warnings++;
    _file.writeAsStringSync(
      '${event.lines.join('\n')}\n',
      mode: FileMode.append,
    );
  }
}
