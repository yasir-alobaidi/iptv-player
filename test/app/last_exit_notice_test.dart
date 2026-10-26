import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/last_exit_notice.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/features/diagnostics/data/diagnostics_providers.dart';
import 'package:iptv_player/features/diagnostics/data/report_share_providers.dart';
import 'package:logger/logger.dart';

import '../features/diagnostics/diagnostics_fakes.dart';

/// ADR-058: the first launch after the app closed by itself says so, once,
/// with what Android kept of why; the log keeps every such end.
void main() {
  final crashedAt = DateTime(2026, 10, 25, 6, 3);
  final earlier = DateTime(2026, 10, 25, 5, 50);

  const password = 'hunter2secret';

  AppExit drawingCrash(DateTime time) => AppExit(
    time: time,
    reason: ExitReason.crashNative,
    importance: 100,
    signal: 'SIGSEGV SEGV_MAPERR',
    thread: '1.raster',
    abort: 'opening http://panel.example:8080/live/me/$password/1.ts',
    frames: const ['pc 00000000000a1c2e libGLES_mali.so'],
    drawing: true,
  );

  final openGles = DrawingBackend(
    openGles: true,
    since: crashedAt,
    cause: 'SIGSEGV SEGV_MAPERR on 1.raster in libGLES_mali.so',
  );

  late MemoryOutput logged;
  late SecretRegistry secrets;
  late AppLog log;

  setUp(() {
    logged = MemoryOutput();
    secrets = SecretRegistry()..add(password);
    log = AppLog(output: logged, secrets: secrets);
  });

  List<String> logLines() => [
    for (final event in logged.buffer) ...event.lines,
  ];

  group('takeExitNews', () {
    test('nothing kept (the desktop): nothing read, nothing told', () async {
      final source = _FakeExits(null, available: false);
      expect(await takeExitNews(source, log), isNull);
      expect(source.reads, 0);
      expect(source.seenUpTo, isNull);
    });

    test('nothing new: nothing told, nothing marked', () async {
      final source = _FakeExits(
        LastExits(exits: [drawingCrash(crashedAt)], seenUpTo: crashedAt),
      );
      expect(await takeExitNews(source, log), isNull);
      expect(source.seenUpTo, isNull);
      expect(logLines().join('\n'), isNot(contains('ERROR')));
    });

    test('every new end is logged as an error, oldest first and redacted; '
        'the newest is marked told and given to show', () async {
      final source = _FakeExits(
        LastExits(
          exits: [
            drawingCrash(crashedAt),
            AppExit(
              time: crashedAt.subtract(const Duration(minutes: 1)),
              reason: ExitReason.userRequested,
            ),
            drawingCrash(earlier),
          ],
          drawing: openGles,
        ),
      );
      final news = (await takeExitNews(source, log))!;
      expect(news.newest.time, crashedAt);
      expect(news.count, 2);
      expect(news.drawing.openGles, isTrue);
      expect(news.switched, isTrue);
      expect(source.seenUpTo, crashedAt);

      final errors = logLines().where((line) => line.contains('ERROR'));
      expect(errors, hasLength(2));
      expect(errors.first, contains(earlier.toIso8601String()));
      expect(errors.first, contains('It crashed while drawing the screen.'));
      expect(errors.first, contains('thread 1.raster'));
      expect(errors.first, contains('libGLES_mali.so'));
      expect(logLines().join('\n'), isNot(contains(password)));
      expect(logLines().join('\n'), contains('Drawing with OpenGL ES'));
    });
  });

  group('the notice', () {
    late GoRouter router;
    late FakeDiagnostics diagnostics;
    late FakeReportSharer sharer;

    Future<_FakeExits> pumpApp(WidgetTester tester, LastExits? last) async {
      diagnostics = FakeDiagnostics()
        ..text = 'Bijou 0.1.0+344 · Android 12'
        ..runLogs = '\nThe run before: Key DPAD_LEFT down';
      sharer = FakeReportSharer();
      final source = _FakeExits(last);
      router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const Text('Home'))],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lastExitsProvider.overrideWithValue(source),
            appLogProvider.overrideWithValue(log),
            secretRegistryProvider.overrideWithValue(secrets),
            routerProvider.overrideWithValue(router),
            diagnosticsProvider.overrideWithValue(diagnostics),
            reportSharerProvider.overrideWithValue(sharer),
            appClockProvider.overrideWithValue(() => crashedAt),
          ],
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
            builder: (context, child) => LastExitNotice(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return source;
    }

    testWidgets('after a crash drawing: what happened, what was done about '
        'it, and the facts, with OK focused; marked told before it shows', (
      tester,
    ) async {
      final source = await pumpApp(
        tester,
        LastExits(exits: [drawingCrash(crashedAt)], drawing: openGles),
      );
      expect(source.seenUpTo, crashedAt);
      expect(find.text('Bijou closed by itself last time'), findsOneWidget);
      expect(
        find.textContaining('It crashed while drawing the screen.'),
        findsOneWidget,
      );
      expect(find.textContaining('(OpenGL ES)'), findsOneWidget);
      expect(find.textContaining('thread 1.raster'), findsOneWidget);
      expect(find.textContaining('libGLES_mali.so'), findsOneWidget);
      expect(find.textContaining(password), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Bijou closed by itself last time'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets("Send to phone offers the report with each run's own log "
        'over the notice, which stays for its photo (ADR-059)', (tester) async {
      await pumpApp(
        tester,
        LastExits(exits: [drawingCrash(crashedAt)], drawing: openGles),
      );
      expect(
        find.textContaining('Send to phone gives the whole report'),
        findsOneWidget,
      );

      await tester.tap(find.text('Send to phone'));
      await tester.pumpAndSettle();
      expect(find.text('Send the report to your phone'), findsOneWidget);
      expect(diagnostics.shareReports, 1);
      expect(sharer.offered.single, (
        'Bijou 0.1.0+344 · Android 12\nThe run before: Key DPAD_LEFT down',
        'bijou-diagnostics-2026-10-25.txt',
      ));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Send the report to your phone'), findsNothing);
      expect(sharer.offers.single.closed, 1);
      expect(find.text('Bijou closed by itself last time'), findsOneWidget);
    });

    testWidgets('a crash elsewhere says nothing of the drawing, and how many '
        'times it happened', (tester) async {
      await pumpApp(
        tester,
        LastExits(
          exits: [
            AppExit(
              time: crashedAt,
              reason: ExitReason.anr,
              trace: '"main" prio=5 tid=1 Native',
            ),
            AppExit(time: earlier, reason: ExitReason.anr),
          ],
        ),
      );
      expect(
        find.textContaining(
          'It stopped responding, and Android closed it. '
          'It happened 2 times.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('OpenGL ES'), findsNothing);
      expect(find.textContaining('"main" prio=5'), findsOneWidget);
    });

    testWidgets('a native crash Android kept nothing of: the switch it made '
        'is said too', (tester) async {
      await pumpApp(
        tester,
        LastExits(
          exits: [
            AppExit(
              time: crashedAt,
              reason: ExitReason.crashNative,
              importance: 100,
            ),
          ],
          drawing: DrawingBackend(
            openGles: true,
            since: crashedAt,
            cause: 'a native crash Android kept no details of',
          ),
        ),
      );
      expect(
        find.textContaining('It crashed in its native code. From now on'),
        findsOneWidget,
      );
    });

    testWidgets('a crash already under OpenGL ES: no promise it is fixed, '
        'and the facts say how it was drawn', (tester) async {
      await pumpApp(
        tester,
        LastExits(
          exits: [
            AppExit(
              time: crashedAt,
              reason: ExitReason.crashNative,
              importance: 100,
              thread: '1.raster',
              drawing: true,
            ),
          ],
          drawing: DrawingBackend(openGles: true, since: earlier),
        ),
      );
      expect(
        find.textContaining('It crashed while drawing the screen.'),
        findsOneWidget,
      );
      expect(find.textContaining('From now on'), findsNothing);
      expect(
        find.textContaining('drawn with OpenGL ES since 2026-10-25 05:50'),
        findsOneWidget,
      );
    });

    testWidgets('nothing new: no notice', (tester) async {
      await pumpApp(
        tester,
        LastExits(
          exits: [
            AppExit(
              time: crashedAt,
              reason: ExitReason.signaled,
              importance: 400,
            ),
          ],
        ),
      );
      expect(find.text('Bijou closed by itself last time'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('nothing could be read: no notice', (tester) async {
      await pumpApp(tester, null);
      expect(find.text('Bijou closed by itself last time'), findsNothing);
    });
  });
}

final class _FakeExits implements LastExitsSource {
  new(this.last, {this.available = true});

  final LastExits? last;
  int reads = 0;
  DateTime? seenUpTo;

  @override
  final bool available;

  @override
  Future<LastExits?> read() async {
    reads++;
    return last;
  }

  @override
  Future<void> seen(DateTime upTo) async => seenUpTo = upTo;
}
