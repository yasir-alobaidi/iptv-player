import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_check.dart';

import '../../app/app_harness.dart';
import 'onboarding_fakes.dart';

void main() {
  late OnboardingFakes fakes;
  setUp(() => fakes = OnboardingFakes());

  Future<AppUnderTest> pump(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) => pumpApp(
    tester,
    initialLocation: addSourceRoutePath,
    overrides: fakes.overrides,
    size: size,
  );

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is AppTextField && w.label == label,
    description: 'field "$label"',
  );

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(
      find.descendant(of: field(label), matching: find.byType(EditableText)),
      text,
    );
    await tester.pump();
  }

  String? errorOf(WidgetTester tester, String label) =>
      tester.widget<AppTextField>(field(label)).errorText;

  Future<void> fillXtream(WidgetTester tester) async {
    await type(tester, 'Server address', 'line.northwind.test:8080');
    await type(tester, 'Username', 'living-room');
    await type(tester, 'Password', 'secret');
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settleApp(tester);
  }

  group('Xtream', () {
    testWidgets('starts on Xtream with the server field focused', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Connect your provider'), findsOneWidget);
      final xtream = tester.widget<ChoiceCard>(
        find.widgetWithText(ChoiceCard, 'Xtream Codes'),
      );
      expect(xtream.selected, isTrue);
      expect(focusIsOn(tester, field('Server address')), isTrue);
      expect(find.text('Test the connection'), findsOneWidget);
    });

    testWidgets('testing an empty form shows every error and tests '
        'nothing', (tester) async {
      await pump(tester);

      await press(tester, 'Test connection');

      expect(errorOf(tester, 'Server address'), 'Enter the server address.');
      expect(errorOf(tester, 'Username'), 'Enter your username.');
      expect(errorOf(tester, 'Password'), 'Enter your password.');
      expect(fakes.checker.checked, isEmpty);
      expect(focusIsOn(tester, field('Server address')), isTrue);

      // The errors follow the text once shown.
      await type(tester, 'Server address', 'ftp://nope');
      expect(errorOf(tester, 'Server address'), contains('web address'));
      await type(tester, 'Server address', 'line.northwind.test');
      expect(errorOf(tester, 'Server address'), isNull);
    });

    testWidgets('a passing test shows the account and offers Start sync', (
      tester,
    ) async {
      fakes.checker.hold();
      await pump(tester);
      await fillXtream(tester);

      await press(tester, 'Test connection');
      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.text('Trying line.northwind.test'), findsOneWidget);
      final testing = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Test connection'),
      );
      expect(testing.loading, isTrue);

      fakes.checker.release();
      await settleApp(tester);

      expect(find.text('Connected'), findsOneWidget);
      expect(
        find.text('line.northwind.test responded in 240 ms'),
        findsOneWidget,
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.textContaining('Nov 3, 2026'), findsOneWidget);
      expect(find.textContaining('in 50 days'), findsOneWidget);
      expect(find.textContaining('2 allowed'), findsOneWidget);
      expect(find.text('TS, HLS'), findsOneWidget);
      expect(find.text('Europe/London'), findsOneWidget);
      expect(focusIsOn(tester, find.text('Start sync')), isTrue);
      expect(find.text('Test again'), findsOneWidget);

      final draft = fakes.checker.checked.single;
      expect(draft.url, 'line.northwind.test:8080');
      expect(draft.username, 'living-room');
      expect(draft.password, 'secret');
      expect(draft.name, 'line.northwind.test');
    });

    testWidgets('an edit after a pass sends the user back to testing', (
      tester,
    ) async {
      await pump(tester);
      await fillXtream(tester);
      await press(tester, 'Test connection');
      expect(find.text('Start sync'), findsOneWidget);

      // Moving the cursor alone changes nothing.
      await tester.tap(field('Username'));
      await settleApp(tester);
      expect(find.text('Start sync'), findsOneWidget);

      await type(tester, 'Username', 'kitchen');
      expect(find.text('Start sync'), findsNothing);
      expect(find.text('Test connection'), findsOneWidget);
      expect(find.text('Test the connection'), findsOneWidget);
    });

    testWidgets('an expired account is shown, with a warning', (tester) async {
      fakes.checker.result = Ok(
        FakeSourceChecker.activeAccount.copyWith(
          account: ProviderAccount(
            status: 'Expired',
            expiresAt: DateTime.utc(2026, 9, 1, 12),
          ),
        ),
      );
      await pump(tester);
      await fillXtream(tester);

      await press(tester, 'Test connection');

      expect(find.textContaining('This account is expired'), findsOneWidget);
      expect(find.textContaining('expired'), findsWidgets);
      expect(find.text('Start sync'), findsOneWidget);
    });

    for (final (failure, title) in [
      (AuthFailure('auth 0'), 'Sign-in refused'),
      (NetworkFailure('refused'), "Can't reach the server"),
      (TimeoutFailure('slow'), "Can't reach the server"),
      (ParseFailure('html'), 'Not an Xtream panel'),
    ]) {
      testWidgets('a ${failure.runtimeType} says "$title"', (tester) async {
        fakes.checker.result = Err(failure);
        await pump(tester);
        await fillXtream(tester);

        await press(tester, 'Test connection');

        expect(find.text(title), findsOneWidget);
        expect(find.text('Start sync'), findsNothing);
        expect(focusIsOn(tester, find.text('Test again')), isTrue);
        // The technical detail is there, behind Details.
        expect(find.text(failure.detail!), findsNothing);
        await press(tester, 'Details');
        expect(find.text(failure.detail!), findsOneWidget);
      });
    }

    testWidgets('pasting a get.php link fills in all three fields', (
      tester,
    ) async {
      await pump(tester);

      await type(
        tester,
        'Server address',
        'http://line.northwind.test:8080/get.php?username=living'
            '&password=s3cret&type=m3u_plus',
      );

      expect(find.text('http://line.northwind.test:8080'), findsOneWidget);
      expect(find.text('living'), findsOneWidget);
      expect(
        find.text('Filled in the username and password from the link.'),
        findsOneWidget,
      );
      await press(tester, 'Test connection');
      expect(fakes.checker.checked.single.password, 's3cret');
    });

    testWidgets('Start sync adds the source, starts its sync and moves on', (
      tester,
    ) async {
      final app = await pump(tester);
      await fillXtream(tester);
      await press(tester, 'Test connection');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleApp(tester);

      final added = fakes.sources.added.single;
      expect(added.type, SourceType.xtream);
      expect(added.password, 'secret');
      expect(fakes.sync.syncCalls, ['new-1']);
      expect(app.location, sourceSyncPath('new-1'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(pendingSourceDraftProvider), added);
    });

    testWidgets('a locked keyring says so and stays on the form', (
      tester,
    ) async {
      fakes.sources.addFailure = SecureStorageFailure('locked');
      final app = await pump(tester);
      await fillXtream(tester);
      await press(tester, 'Test connection');

      await press(tester, 'Start sync');

      expect(app.location, addSourceRoutePath);
      expect(find.textContaining('password keyring'), findsOneWidget);
      expect(fakes.sync.syncCalls, isEmpty);
    });

    testWidgets('Enter in a field tests', (tester) async {
      await pump(tester);
      await fillXtream(tester);

      await tester.showKeyboard(
        find.descendant(
          of: field('Password'),
          matching: find.byType(EditableText),
        ),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleApp(tester);

      expect(fakes.checker.checked, hasLength(1));
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('Advanced holds the name, User-Agent, guide and format', (
      tester,
    ) async {
      await pump(tester);
      await fillXtream(tester);

      await press(
        tester,
        'Advanced: name, User-Agent, guide link, live format',
      );
      await type(tester, 'Name', 'Living room');
      await type(tester, 'User-Agent', 'Special/1.0');
      await type(tester, 'Guide (EPG) link', 'guide.xml');
      await tester.ensureVisible(find.text('HLS'));
      await tester.tap(find.text('HLS'));
      await press(tester, 'Test connection');

      expect(errorOf(tester, 'Guide (EPG) link'), contains('web address'));
      expect(fakes.checker.checked, isEmpty);

      await type(tester, 'Guide (EPG) link', 'http://epg.test/guide.xml');
      await press(tester, 'Test connection');
      final draft = fakes.checker.checked.single;
      expect(draft.name, 'Living room');
      expect(draft.userAgent, 'Special/1.0');
      expect(draft.epgUrl, 'http://epg.test/guide.xml');
      expect(draft.liveFormat, LiveFormat.hls);
    });

    testWidgets('comes back filled in after a cancelled sync', (tester) async {
      await pumpApp(
        tester,
        initialLocation: addSourceRoutePath,
        overrides: [
          ...fakes.overrides,
          pendingSourceDraftProvider.overrideWithBuild(
            (ref, notifier) => const SourceDraft(
              type: SourceType.xtream,
              name: 'Living room',
              url: 'line.northwind.test:8080',
              username: 'living-room',
              password: 'secret',
              liveFormat: LiveFormat.hls,
            ),
          ),
        ],
      );

      expect(find.text('line.northwind.test:8080'), findsOneWidget);
      expect(find.text('living-room'), findsOneWidget);
      // Advanced opens, since something in it was set.
      expect(find.text('Living room'), findsOneWidget);
    });
  });

  group('M3U', () {
    testWidgets('a link: its own field and messages', (tester) async {
      fakes.checker.result = const Ok(
        SourceCheck(
          where: 'lists.test',
          responseTime: Duration(milliseconds: 90),
          playlist: PlaylistPreview(
            complete: false,
            entries: 500,
            live: 480,
            movies: 20,
          ),
        ),
      );
      await pump(tester);
      await tester.tap(find.text('M3U link'));
      await settleApp(tester);

      expect(field('Username'), findsNothing);
      await press(tester, 'Test connection');
      expect(errorOf(tester, 'Playlist URL'), 'Enter the playlist URL.');

      await type(tester, 'Playlist URL', 'lists.test/get.php');
      expect(errorOf(tester, 'Playlist URL'), contains('http://'));

      await type(tester, 'Playlist URL', 'http://lists.test/get.php?t=1');
      await press(tester, 'Test connection');

      expect(find.text('Playlist found'), findsOneWidget);
      expect(find.textContaining('At least 500'), findsOneWidget);
      expect(find.text('480 channels · 20 movies'), findsOneWidget);
      expect(fakes.checker.checked.single.type, SourceType.m3uUrl);
    });

    testWidgets('a file: Choose file fills the path', (tester) async {
      fakes.pickedFile = '/home/me/list.m3u';
      fakes.checker.result = const Ok(
        SourceCheck(
          where: 'list.m3u',
          responseTime: Duration(milliseconds: 4),
          playlist: PlaylistPreview(complete: true, entries: 3, bytes: 2048),
        ),
      );
      await pump(tester);
      await tester.tap(find.text('M3U file'));
      await settleApp(tester);

      await press(tester, 'Choose file');
      expect(find.text('/home/me/list.m3u'), findsOneWidget);

      await press(tester, 'Test connection');
      expect(find.text('list.m3u opened in 4 ms'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(fakes.checker.checked.single.name, 'list');
    });

    testWidgets('a file that is gone says to choose it again', (tester) async {
      fakes.checker.result = Err(NotFoundFailure('playlist file'));
      await pump(tester);
      await tester.tap(find.text('M3U file'));
      await settleApp(tester);
      await type(tester, 'Playlist file', '/gone.m3u');

      await press(tester, 'Test connection');

      expect(find.text('File not found'), findsOneWidget);
    });
  });

  testWidgets('Back returns to Welcome when there is nothing behind', (
    tester,
  ) async {
    final app = await pump(tester);

    await press(tester, 'Back');

    expect(app.location, welcomeRoutePath);
  });

  testWidgets('a narrow window stacks the card under the form', (tester) async {
    fakes.checker.result = Err(AuthFailure('auth 0'));
    await pump(tester, size: const Size(1024, 768));
    await fillXtream(tester);

    await press(tester, 'Test connection');

    // Scrolled into view.
    final card = tester.getRect(find.text('Sign-in refused'));
    expect(card.top, greaterThan(0));
    expect(card.bottom, lessThan(768));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every control is reachable with Tab', (tester) async {
    await pump(tester);
    await fillXtream(tester);
    await press(tester, 'Test connection');

    final reached = <String>{};
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      final surface = context
          ?.findAncestorWidgetOfExactType<FocusableSurface>();
      if (surface?.semanticLabel case final label?) reached.add(label);
      final text = context?.findAncestorWidgetOfExactType<AppTextField>();
      if (text?.label case final label?) reached.add(label);
    }

    expect(
      reached,
      containsAll([
        'Xtream Codes. Server, username, password',
        'M3U link. Playlist URL',
        'M3U file. From this computer',
        'Server address',
        'Username',
        'Password',
        'Advanced: name, User-Agent, guide link, live format',
        'Back',
        'Test again',
        'Start sync',
      ]),
    );
  });
}
