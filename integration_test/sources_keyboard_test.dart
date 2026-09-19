// Phase 2 end to end, with the keyboard only: the real app, a real file
// database opened the way the app opens it, the real sync isolate, and
// the fake Xtream panel (docs/06) behind a small proxy that can hold a
// sync open, so Cancel can be pressed half-way.
//
// Welcome → Connect (a wrong password, then the right one) → Sync →
// Cancel → Connect again, filled in → Sync → Pick categories → Home →
// Settings → Sources (Refresh, Edit) → Categories (hide, reorder, rename)
// → a second source (M3U link) → the switcher → Remove both → Welcome.
//
// Text goes in through the text-input channel, as a keyboard's does;
// everything else is Tab, Shift+Tab, arrows, Enter, Space, Esc and the
// app's shortcuts. No taps.

import 'dart:async';
import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
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
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:logger/logger.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add, sync, manage and remove sources with the keyboard only', (
    tester,
  ) async {
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    // The integration binding leaves text input to the platform; typing
    // goes through the test channel instead, as in widget tests.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);

    final panel = (await tester.runAsync(_Panel.start))!;
    addTearDown(() => tester.runAsync(panel.close));
    final app = (await tester.runAsync(_App.open))!;
    addTearDown(() => tester.runAsync(app.close));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: app.container,
        child: const IptvPlayerApp(),
      ),
    );
    // Under xvfb no window manager gives the window focus, so the engine
    // keeps flipping it between focused and not, and Flutter parks or
    // moves keyboard focus each time. A desktop session keeps the window
    // focused while the user types; the test holds it there.
    SystemChannels.lifecycle.setMessageHandler((message) async => null);
    tester.binding.platformDispatcher.onViewFocusChange = (_) {};
    final k = _Keys(tester)..resume();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // ── Welcome: "Add your first source" has focus.
    expect(find.text('Add your first source'), findsOneWidget);
    expect(k.focusIsOn(find.text('Add your first source')), isTrue);
    await k.press(LogicalKeyboardKey.enter);
    expect(app.location, addSourceRoutePath);

    // ── Connect: focus starts in the server field.
    await k.waitFor(find.text('Connect your provider'));
    await k.waitUntil(
      () => k.focusIsOn(_input('Server address')),
      'focus in the server field',
    );
    await k.type('http://127.0.0.1:${panel.port}', into: 'Server address');
    await k.press(LogicalKeyboardKey.tab);
    await k.type('test', into: 'Username');
    await k.press(LogicalKeyboardKey.tab);
    await k.type('wrong', into: 'Password');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Sign-in refused'));
    // The password shows nowhere but in its own (obscured) field.
    expect(_screenText(tester), isNot(contains('wrong')));

    await k.tabTo(_input('Password'), back: true);
    await k.replaceText('test', into: 'Password');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Connected'));
    expect(k.focusIsOn(find.text('Start sync')), isTrue);

    // ── Sync, held open at the channel list; Cancel half-way.
    panel.holdLive = true;
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Cancel'));
    await k.waitUntil(() => panel.liveRequested, 'the channel request');
    await k.tabTo(find.text('Cancel'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitUntil(
      () => app.location == addSourceRoutePath,
      'Connect after Cancel',
    );
    // The half-added source is gone; the form is as it was.
    expect(await app.sourceCount(), 0);
    expect(k.textOf(_field('Username')), 'test');
    panel.release();

    // ── Test again, then the whole sync.
    await k.tabTo(find.text('Test connection'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Connected'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.textContaining('Done in'), seconds: 60);
    expect(k.focusIsOn(find.text('Pick categories')), isTrue);
    await k.press(LogicalKeyboardKey.enter);

    // ── Pick categories: Space on the first tile, Finish.
    await k.waitFor(find.text('Pick what you watch'));
    await k.tabTo(find.byType(AppCheckbox).last);
    final picked = k.focusedLabel();
    await k.press(LogicalKeyboardKey.space);
    await k.tabTo(find.text('Finish'));
    await k.press(LogicalKeyboardKey.enter);
    expect(app.location, '/');
    final source = (await app.sources()).single;
    expect(
      await app.hiddenNames(source.id),
      contains(picked!.split(',').first),
    );
    // The chip names the source.
    expect(_byLabel('Source: 127.0.0.1'), findsOneWidget);

    // ── Settings → Sources with Ctrl+,.
    await k.chord(LogicalKeyboardKey.comma);
    expect(app.location, '/settings');
    expect(
      find.text(
        '240 channels · 120 movies · 24 series · synced '
        'just now',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Xtream · Active · exp'), findsOneWidget);

    final requestsBefore = panel.liveRequests;
    await k.tabTo(find.text('Refresh'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitUntil(
      () => panel.liveRequests > requestsBefore,
      'the refresh to fetch the channels',
    );
    await k.waitUntil(
      () => !app.syncing(source.id),
      'the refresh to finish',
      seconds: 60,
    );

    // ── Edit: rename it; no test needed, no sync.
    await k.tabTo(find.text('Edit'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Edit 127.0.0.1'));
    await k.tabTo(_input('Name'));
    await k.replaceText('Fake panel', into: 'Name');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitUntil(() => app.location == '/settings', 'Settings');
    await k.waitFor(find.text('Fake panel'));
    expect(_byLabel('Source: Fake panel'), findsOneWidget);

    // ── Categories: arrows to the section, hide one, move one, rename.
    await k.tabTo(find.text('Sources').first, back: true);
    for (var i = 0; i < 5; i++) {
      await k.press(LogicalKeyboardKey.arrowDown);
    }
    expect(k.focusIsOn(find.text('Categories').first), isTrue);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Show hidden'));
    final before = await app.liveNames(source.id);
    await k.tabTo(_rowOf(before[1]));
    await k.press(LogicalKeyboardKey.space);
    await k.waitUntil(
      () async => (await app.hiddenNames(source.id)).contains(before[1]),
      'the hide to be saved',
    );
    await k.alt(LogicalKeyboardKey.arrowUp);
    await k.waitUntil(
      () async => (await app.liveNames(source.id)).first == before[1],
      'the move to be saved',
    );
    await k.press(LogicalKeyboardKey.tab);
    expect(k.focusedLabel(), 'Rename ${before[1]}');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Rename category'));
    await k.replaceText('My favourites', into: 'Name');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('was ${before[1]}'));
    expect((await app.liveNames(source.id)).first, 'My favourites');

    // ── A second source: an M3U link to the same panel.
    await k.tabTo(find.text('Sources').first, back: true);
    await k.press(LogicalKeyboardKey.enter);
    await k.tabTo(find.text('Add source'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Connect your provider'));
    await k.tabTo(find.textContaining('M3U link'), back: true);
    await k.press(LogicalKeyboardKey.enter);
    await k.tabTo(_input('Playlist URL'));
    await k.type(
      'http://127.0.0.1:${panel.port}/get.php?username=test&password=test'
      '&type=m3u_plus&output=ts',
      into: 'Playlist URL',
    );
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Playlist found'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.textContaining('Done in'), seconds: 60);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Pick what you watch'));
    await k.tabTo(find.text('Finish'));
    await k.press(LogicalKeyboardKey.enter);
    // Added from Settings, so it ends in Settings.
    expect(app.location, '/settings');
    expect(await app.sourceCount(), 2);

    // ── The switcher: Enter on the chip, Down, Enter.
    await k.tabTo(_byLabel('Source: Fake panel'), back: true);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Manage sources…'));
    await k.press(LogicalKeyboardKey.arrowDown);
    await k.press(LogicalKeyboardKey.enter);
    final second = (await app.sources()).last;
    expect(app.container.read(currentSourceProvider)?.id, second.id);
    expect(_byLabel('Source: 127.0.0.1'), findsOneWidget);

    // ── Remove both. Enter on the confirmation keeps; Tab, Enter removes.
    for (final name in ['Fake panel', '127.0.0.1']) {
      await k.tabTo(_byLabel('More for $name'));
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text('Remove…'));
      for (var i = 0; i < 8 && !k.focusIsOn(find.text('Remove…')); i++) {
        await k.press(LogicalKeyboardKey.arrowDown);
      }
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text('Remove $name?'));
      await k.press(LogicalKeyboardKey.enter);
      expect(find.text('Remove $name?'), findsNothing);
      expect(await app.sourceCount(), name == 'Fake panel' ? 2 : 1);

      await k.tabTo(_byLabel('More for $name'));
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text('Remove…'));
      for (var i = 0; i < 8 && !k.focusIsOn(find.text('Remove…')); i++) {
        await k.press(LogicalKeyboardKey.arrowDown);
      }
      await k.press(LogicalKeyboardKey.enter);
      await k.waitFor(find.text('Remove $name?'));
      await k.press(LogicalKeyboardKey.tab);
      await k.press(LogicalKeyboardKey.enter);
      await k.waitUntil(
        () async => await app.sourceCount() == (name == 'Fake panel' ? 1 : 0),
        'the removal of $name',
      );
    }
    await k.waitUntil(
      () => app.location == welcomeRoutePath,
      'Welcome after the last source',
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// The fake panel behind a proxy that can hold `get_live_streams` open.
final class _Panel {
  new _(this._server, this._proxy, this._client);

  static Future<_Panel> start() async {
    final runDir = await Directory.systemTemp.createTemp('fake_provider');
    final server = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!,
        samplesDir: runDir.path,
        ffmpegPath: 'ffmpeg',
        runDir: runDir.path,
      ),
      port: 0,
    );
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final panel = _Panel._(server, proxy, HttpClient()).._runDir = runDir;
    proxy.listen(panel._forward);
    return panel;
  }

  final FakeProviderServer _server;
  final HttpServer _proxy;
  final HttpClient _client;
  late final Directory _runDir;

  bool holdLive = false;
  bool liveRequested = false;

  /// `get_live_streams` requests so far.
  int liveRequests = 0;
  final _held = <Completer<void>>[];

  int get port => _proxy.port;

  void release() {
    holdLive = false;
    for (final hold in _held) {
      if (!hold.isCompleted) hold.complete();
    }
  }

  Future<void> _forward(HttpRequest request) async {
    final response = request.response;
    try {
      final live = request.uri.queryParameters['action'] == 'get_live_streams';
      if (live) liveRequests++;
      if (live && holdLive) {
        liveRequested = true;
        final hold = Completer<void>();
        _held.add(hold);
        await hold.future;
      }
      final forwarded = await _client.getUrl(
        _server.url.replace(path: request.uri.path, query: request.uri.query),
      );
      final answer = await forwarded.close();
      response.statusCode = answer.statusCode;
      answer.headers.forEach((name, values) {
        if (name == HttpHeaders.transferEncodingHeader) return;
        for (final value in values) {
          response.headers.add(name, value);
        }
      });
      await response.addStream(answer);
      await response.close();
    } on Object {
      // The client went away (a cancelled sync): nothing to answer.
      try {
        await response.close();
      } on Object {
        // Already closed.
      }
    }
  }

  Future<void> close() async {
    release();
    _client.close(force: true);
    await _proxy.close(force: true);
    await _server.close();
    await _runDir.delete(recursive: true);
  }
}

/// The app as `bootstrap()` builds it, minus the real app-support
/// directory, the keyring and the global error handlers.
final class _App {
  new _(this.container, this._directory, this._db);

  static Future<_App> open() async {
    final directory = await Directory.systemTemp.createTemp('iptv_e2e');
    final db = AppDatabase(await openAppDatabase(directory));
    final log = AppLog(output: _SilentOutput(), secrets: SecretRegistry());
    final container = ProviderContainer(
      overrides: [
        appLogProvider.overrideWithValue(log),
        secretRegistryProvider.overrideWithValue(SecretRegistry()),
        errorReporterProvider.overrideWithValue(ErrorReporter(log)),
        appDatabaseProvider.overrideWithValue(db),
        credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
        startLocationProvider.overrideWithValue(welcomeRoutePath),
        ...sourceShellOverrides,
      ],
    );
    return _App._(container, directory, db);
  }

  final ProviderContainer container;
  final Directory _directory;
  final AppDatabase _db;

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
    await _directory.delete(recursive: true);
  }
}

/// Key presses and waits, in real time.
final class _Keys {
  new(this.tester);

  final WidgetTester tester;

  /// Under xvfb there is no window manager to give the window focus, so
  /// the engine keeps reporting the app as inactive, and Flutter parks
  /// keyboard focus while it is. A desktop session is resumed while the
  /// user types; this puts the test in the same state before each key.
  void resume() {
    if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  }

  Future<void> _frames() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> press(LogicalKeyboardKey key) async {
    resume();
    if (key == LogicalKeyboardKey.enter && _focusedField != null) {
      // In a text field the platform's text input turns Enter into the
      // field's action (GTK does); the test channel stands in for it.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _frames();
      return;
    }
    await tester.sendKeyEvent(key);
    await _frames();
  }

  /// Ctrl + [key].
  Future<void> chord(LogicalKeyboardKey key) async {
    resume();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _frames();
  }

  /// Alt + [key].
  Future<void> alt(LogicalKeyboardKey key) async {
    resume();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await _frames();
  }

  EditableText? get _focusedField {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    if (context.widget is EditableText) return context.widget as EditableText;
    return context.findAncestorWidgetOfExactType<EditableText>();
  }

  /// Types [text] after what is in the field labelled [into], once the
  /// keyboard focus is in it.
  Future<void> type(String text, {required String into}) async {
    final field = await _focused(into);
    await _enter(field, field.controller.text + text);
  }

  /// Types over everything in the field labelled [into].
  Future<void> replaceText(String text, {required String into}) =>
      _focused(into).then((field) => _enter(field, text));

  Future<EditableText> _focused(String label) async {
    await waitUntil(
      () {
        resume();
        return focusIsOn(_input(label));
      },
      'focus in the $label field (${_focusPath()})',
      seconds: 5,
    );
    return tester.widget<EditableText>(_input(label));
  }

  Future<void> _enter(EditableText field, String value) async {
    await tester.enterText(find.byWidget(field), value);
    await _frames();
    expect(field.controller.text, value, reason: 'typing did not land');
  }

  String textOf(Finder field) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  bool focusIsOn(Finder finder) {
    final primary = FocusManager.instance.primaryFocus;
    // A focused scope is no control, and its element is an ancestor of
    // everything in it.
    if (primary == null || primary is FocusScopeNode) return false;
    final focused = primary.context;
    if (focused == null) return false;
    for (final target in finder.evaluate()) {
      if (target == focused) return true;
      var found = false;
      target.visitAncestorElements((e) {
        found = e == focused;
        return !found;
      });
      if (found) return true;
      focused.visitAncestorElements((e) {
        found = e == target;
        return !found;
      });
      if (found) return true;
    }
    return false;
  }

  /// The semantic label of the focused control, when it has one.
  String? focusedLabel() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    final surface = context.widget is FocusableSurface
        ? context.widget as FocusableSurface
        : context.findAncestorWidgetOfExactType<FocusableSurface>();
    return surface?.semanticLabel;
  }

  /// Tab (or Shift+Tab) until [finder] has focus.
  Future<void> tabTo(Finder finder, {bool back = false, int max = 60}) async {
    final visited = <String>[];
    for (var i = 0; i < max; i++) {
      resume();
      if (focusIsOn(finder)) return;
      visited.add(
        focusedLabel() ?? '${FocusManager.instance.primaryFocus?.debugLabel}',
      );
      if (back) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (focusIsOn(finder)) return;
    fail(
      'Tab never reached $finder; focus went ${visited.join(' → ')}; '
      'on screen: ${_screenText(tester)}',
    );
  }

  Future<void> waitFor(Finder finder, {int seconds = 20}) => waitUntil(
    () => finder.evaluate().isNotEmpty,
    '$finder',
    seconds: seconds,
  );

  Future<void> waitUntil(
    FutureOr<bool> Function() done,
    String what, {
    int seconds = 20,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(deadline)) {
      final ready = await tester.runAsync(() async => await done());
      if (ready ?? false) {
        await _frames();
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    fail('Timed out waiting for $what. On screen: ${_screenText(tester)}');
  }
}

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(AppTextField));

/// The text box of the field labelled [label], not its buttons.
Finder _input(String label) =>
    find.descendant(of: _field(label), matching: find.byType(EditableText));

Finder _byLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is FocusableSurface && widget.semanticLabel == label,
  description: 'control labelled "$label"',
);

/// A category row in the manager, by the category's name.
Finder _rowOf(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is FocusableSurface &&
      (widget.semanticLabel?.startsWith('$name, ') ?? false),
  description: 'category row "$name"',
);

class _SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

/// Where the focus is, for failure messages: the focused node and the
/// widgets above it.
String _focusPath() {
  final node = FocusManager.instance.primaryFocus;
  final types = <String>[];
  node?.context?.visitAncestorElements((e) {
    final name = e.widget.runtimeType.toString();
    if (!name.startsWith('_') && types.length < 25) types.add(name);
    return true;
  });
  return '$node ← ${types.join(' ← ')}';
}

String _screenText(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (text.data case final data? when data.trim().isNotEmpty) data,
].join(' | ');
