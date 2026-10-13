import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';
import 'package:iptv_player/features/diagnostics/presentation/log_view.dart';
import 'package:iptv_player/features/diagnostics/presentation/report_view.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../../app/app_harness.dart';
import '../../../design/design_harness.dart';
import '../../casting/support/cast_ui_harness.dart' show focusedLabelOf;
import '../../onboarding/onboarding_fakes.dart';
import '../../settings/appearance_fakes.dart';
import '../diagnostics_fakes.dart';

void main() {
  late FakeDiagnostics diagnostics;
  late FakeLogReader log;
  late FakeFileReveal reveal;
  String? savePath;
  final saveNames = <String>[];
  final clipboard = <String>[];
  var clipboardWorks = true;

  setUp(() {
    diagnostics = FakeDiagnostics();
    log = FakeLogReader([for (var i = 0; i < 6; i++) logRow(i)]);
    reveal = FakeFileReveal();
    savePath = '/home/me/Documents/report.txt';
    saveNames.clear();
    clipboard.clear();
    clipboardWorks = true;
  });

  /// Settings → About & diagnostics, at 9 in the morning of October 13.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    AppearanceSettings appearance = const AppearanceSettings(),
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          if (!clipboardWorks) throw PlatformException(code: 'no clipboard');
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final fakes = OnboardingFakes()
      ..sources.seed()
      ..now = DateTime(2026, 10, 13, 9);
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      size: size,
      withAppearance: true,
      overrides: [
        ...fakes.overrides,
        ...sourceShellOverrides,
        ...appearanceOverrides(settings: appearance),
        ...diagnosticsOverrides(
          diagnostics: diagnostics,
          log: log,
          reveal: reveal,
          savePicker: (name) async {
            saveNames.add(name);
            return savePath;
          },
        ),
      ],
    );
    // The last of the sections: at 130 % in the smallest window the list
    // scrolls to it.
    await tester.ensureVisible(find.text('About & diagnostics').first);
    await tester.pump();
    await tester.tap(find.text('About & diagnostics').first);
    await settleApp(tester);
    await settleApp(tester);
  }

  Future<void> openLog(WidgetTester tester) async {
    await tester.tap(find.text('Log'));
    await settleApp(tester);
    await settleApp(tester);
  }

  Future<void> tabTo(WidgetTester tester, String label) async {
    for (var i = 0; i < 40; i++) {
      if (focusedLabelOf(tester) == label) return;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    fail('Tab never reached "$label" (on ${focusedLabelOf(tester)})');
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await settleApp(tester);
  }

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, label))
          .onPressed !=
      null;

  /// The log's lines that are in view, top to bottom (a list also
  /// builds a few rows beyond each edge).
  List<String> shown(WidgetTester tester) {
    final lines = find.descendant(
      of: find.byType(LogView),
      matching: find.textContaining(RegExp(r'^line \d+$')),
    );
    final panes = find.descendant(
      of: find.byType(LogView),
      matching: find.byType(ScrollPane),
    );
    if (lines.evaluate().isEmpty) return const [];
    final view = tester.getRect(panes);
    final byTop = <(double, String)>[];
    for (final element in lines.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      if (rect.center.dy < view.top || rect.center.dy > view.bottom) continue;
      byTop.add((rect.top, (element.widget as Text).data!));
    }
    byTop.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, text) in byTop) text];
  }

  // The lines' own scrolling: the filter's text field scrolls too.
  ScrollPosition logScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.descendant(
            of: find.byType(LogView),
            matching: find.byType(ScrollPane),
          ),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  group('the report', () {
    testWidgets('is shown whole, so the user sees what they are about to '
        'paste', (tester) async {
      await open(tester);

      expect(find.byType(ReportView), findsOneWidget);
      expect(find.text(diagnostics.text), findsOneWidget);
      expect(
        find.textContaining('No passwords, usernames or server addresses.'),
        findsOneWidget,
      );
      expect(enabled(tester, 'Copy diagnostics'), isTrue);
      expect(enabled(tester, 'Save to file…'), isTrue);
    });

    testWidgets('while it is made the page says so, and there is nothing to '
        'copy yet', (tester) async {
      diagnostics.gate = Completer<void>();
      await open(tester);

      expect(find.bySemanticsLabel('Making the report'), findsOneWidget);
      expect(enabled(tester, 'Copy diagnostics'), isFalse);
      expect(enabled(tester, 'Save to file…'), isFalse);

      diagnostics.gate!.complete();
      await settleApp(tester);
      expect(find.text(diagnostics.text), findsOneWidget);
    });

    testWidgets("a report that can't be made: plain words, the detail behind "
        'Details, and Try again makes it', (tester) async {
      diagnostics.failure = StorageFailure('SQLITE_CORRUPT');
      await open(tester);

      expect(find.text("The report couldn't be made"), findsOneWidget);
      expect(find.textContaining('SQLITE_CORRUPT'), findsNothing);
      expect(enabled(tester, 'Copy diagnostics'), isFalse);

      diagnostics.failure = null;
      await tabTo(tester, 'Try again');
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.text(diagnostics.text), findsOneWidget);
      expect(diagnostics.reports, 2);
    });

    testWidgets('Copy diagnostics, by keyboard, puts exactly that text on the '
        'clipboard and says so', (tester) async {
      await open(tester);
      await tabTo(tester, 'Copy diagnostics');
      await press(tester, LogicalKeyboardKey.enter);

      expect(clipboard, [diagnostics.text]);
      expect(find.text('Diagnostics copied'), findsOneWidget);
    });

    testWidgets('a clipboard that can’t be reached says so and points at '
        'Save', (tester) async {
      clipboardWorks = false;
      await open(tester);
      await tabTo(tester, 'Copy diagnostics');
      await press(tester, LogicalKeyboardKey.enter);

      expect(
        find.textContaining("Couldn't reach the clipboard."),
        findsOneWidget,
      );
      expect(find.text('Diagnostics copied'), findsNothing);
    });

    testWidgets('Save to file… asks where, with a dated name, and writes the '
        'text there', (tester) async {
      await open(tester);
      await tabTo(tester, 'Save to file…');
      await press(tester, LogicalKeyboardKey.enter);

      expect(saveNames, ['iptv-player-diagnostics-2026-10-13.txt']);
      expect(diagnostics.saved, [
        ('/home/me/Documents/report.txt', diagnostics.text),
      ]);
      expect(find.text('Diagnostics saved'), findsOneWidget);
    });

    testWidgets('a dialog closed without choosing writes nothing; a file '
        "that can't be written says so", (tester) async {
      savePath = null;
      await open(tester);
      await tabTo(tester, 'Save to file…');
      await press(tester, LogicalKeyboardKey.enter);
      expect(diagnostics.saved, isEmpty);

      savePath = '/media/usb/report.txt';
      diagnostics.saveFailure = StorageFailure('EROFS');
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.textContaining("Couldn't write that file."), findsOneWidget);
      expect(find.textContaining('EROFS'), findsNothing);
    });

    testWidgets('the text is one Tab stop with the focus ring, and the '
        'keyboard scrolls it', (tester) async {
      diagnostics.text = [for (var i = 0; i < 80; i++) 'Report line $i']
          .join('\n');
      await open(tester, size: const Size(1024, 640));
      await tabTo(tester, 'Save to file…');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final pane = find.descendant(
        of: find.byType(ReportView),
        matching: find.byType(ScrollPane),
      );
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<ScrollPane>(),
        isNotNull,
      );
      expect(hasFocusRing(tester, of: pane), isTrue);

      final position = tester
          .state<ScrollableState>(
            find.descendant(of: pane, matching: find.byType(Scrollable)),
          )
          .position;
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(position.pixels, position.maxScrollExtent);
      expect(position.maxScrollExtent, greaterThan(0));
    });
  });

  group('the log', () {
    testWidgets('shows the newest lines, the newest at the bottom, each '
        'with its time, level and tag', (tester) async {
      await open(tester);
      await openLog(tester);

      expect(find.byType(LogView), findsOneWidget);
      expect(shown(tester), [for (var i = 0; i < 6; i++) 'line $i']);
      expect(find.text('09:00:05.000'), findsOneWidget);
      expect(find.text('INFO'), findsNWidgets(6));
      expect(find.text('playback'), findsNWidgets(6));
      expect(logScroll(tester).pixels, 0, reason: 'at the newest line');
    });

    testWidgets('while it is read, when it is empty, and when this run keeps '
        'no file: each says so', (tester) async {
      log.gate = Completer<void>();
      await open(tester);
      await openLog(tester);
      expect(find.bySemanticsLabel('Reading the log'), findsOneWidget);
      log.gate!.complete();
      await settleApp(tester);
      expect(shown(tester), hasLength(6));

      log
        ..gate = null
        ..rows.clear();
      await open(tester);
      await openLog(tester);
      expect(find.text('The log is empty'), findsOneWidget);
      expect(enabled(tester, 'Copy shown'), isFalse);

      log.currentFile = null;
      await open(tester);
      await openLog(tester);
      expect(find.text('This run keeps no log file'), findsOneWidget);
      expect(enabled(tester, 'Open log folder'), isFalse);
    });

    testWidgets("a log that can't be read: plain words, and Try again reads "
        'it', (tester) async {
      log.failure = StorageFailure('EACCES');
      await open(tester);
      await openLog(tester);

      expect(find.text("The log couldn't be read"), findsOneWidget);
      expect(find.textContaining('EACCES'), findsNothing);

      log.failure = null;
      await tabTo(tester, 'Try again');
      await press(tester, LogicalKeyboardKey.enter);
      expect(shown(tester), hasLength(6));
    });

    testWidgets('Warnings and errors, chosen by keyboard, shows only those; '
        'All brings the rest back', (tester) async {
      log.rows
        ..add(
          logRow(6, level: LogLevel.warning, tag: 'watchdog', text: 'Stalled'),
        )
        ..add(
          logRow(7, level: LogLevel.error, tag: 'sync', text: 'Sync failed'),
        );
      await open(tester);
      await openLog(tester);

      await tabTo(tester, 'Warnings and errors');
      await press(tester, LogicalKeyboardKey.enter);

      expect(shown(tester), isEmpty);
      expect(find.text('Stalled'), findsOneWidget);
      expect(find.text('Sync failed'), findsOneWidget);
      expect(find.text('WARN'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);

      await tabTo(tester, 'All');
      await press(tester, LogicalKeyboardKey.enter);
      expect(shown(tester), hasLength(6));
    });

    testWidgets('the filter narrows as it is typed, after a moment; nothing '
        'matching says so, and Show everything clears it', (tester) async {
      log.rows.add(logRow(6, tag: 'epg', text: 'Guide updated'));
      await open(tester);
      await openLog(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(LogView),
          matching: find.byType(EditableText),
        ),
        'GUIDE',
      );
      // Not on every key: after the typing pauses.
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown(tester), hasLength(6));
      await tester.pump(const Duration(milliseconds: 200));
      await settleApp(tester);
      expect(shown(tester), isEmpty);
      expect(find.text('Guide updated'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(LogView),
          matching: find.byType(EditableText),
        ),
        'no line holds this',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await settleApp(tester);
      expect(find.text('Nothing in the log matches'), findsOneWidget);

      await tabTo(tester, 'Show everything');
      await press(tester, LogicalKeyboardKey.enter);
      expect(shown(tester), hasLength(6));
      expect(find.text('Guide updated'), findsOneWidget);
    });

    testWidgets('at the bottom it follows new lines as they are written', (
      tester,
    ) async {
      await open(tester);
      await openLog(tester);

      log.rows.add(logRow(6));
      await tester.pump(LogView.pollEvery);
      await settleApp(tester);

      expect(shown(tester).last, 'line 6');
      expect(logScroll(tester).pixels, 0);
    });

    testWidgets('scrolled up it holds still: new lines arrive below, out of '
        'sight, and End brings them into view', (tester) async {
      log.rows
        ..clear()
        ..addAll([for (var i = 0; i < 200; i++) logRow(i)]);
      await open(tester, size: const Size(1024, 640));
      await openLog(tester);
      final position = logScroll(tester)..jumpTo(600);
      await tester.pump();
      final before = shown(tester);
      expect(before, isNot(contains('line 199')));

      log.rows.addAll([for (var i = 200; i < 205; i++) logRow(i)]);
      await tester.pump(LogView.pollEvery);
      await settleApp(tester);

      expect(shown(tester), before, reason: 'nothing on screen moved');
      expect(position.pixels, 600 + 5 * LogView.rowHeight);

      position.jumpTo(0);
      await tester.pump();
      expect(shown(tester).last, 'line 204');
    });

    testWidgets('older lines are read as the top comes near, and nothing on '
        'screen moves when they arrive', (tester) async {
      log.rows
        ..clear()
        ..addAll([for (var i = 0; i < 5000; i++) logRow(i)]);
      await open(tester, size: const Size(1024, 640));
      await openLog(tester);
      final position = logScroll(tester);
      final firstPage = position.maxScrollExtent;
      expect(shown(tester).last, 'line 4999');
      expect(log.queries, hasLength(1), reason: '2,000 lines at once');

      // To the top of what was read: line 3000 is the oldest of it.
      position.jumpTo(firstPage);
      await tester.pump();
      final atTop = shown(tester);
      expect(atTop.first, 'line 3000');
      await settleApp(tester);

      // The page before it has arrived, above; the same lines are in view.
      expect(log.queries, hasLength(2));
      expect(shown(tester), atTop);
      expect(position.pixels, firstPage);
      expect(position.maxScrollExtent, greaterThan(firstPage * 1.9));

      // And the keyboard can go on up into it.
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await settleApp(tester);
      expect(shown(tester).first, anyOf('line 1000', 'line 0'));
    });

    testWidgets('a log file that filled up and was replaced is read from the '
        'end again', (tester) async {
      await open(tester);
      await openLog(tester);
      final reads = log.queries.length;

      log
        ..rows.clear()
        ..rows.add(logRow(50))
        ..rotated = true;
      await tester.pump(LogView.pollEvery);
      await settleApp(tester);

      expect(log.queries.length, reads + 1);
      expect(shown(tester), ['line 50']);
    });

    testWidgets('Copy shown copies the lines as the file has them, and says '
        'how many', (tester) async {
      log.rows
        ..clear()
        ..add(
          LogRow(
            time: DateTime.utc(2026, 10, 13, 9),
            level: LogLevel.error,
            tag: 'sync',
            text: 'The sync failed',
          ),
        )
        ..add(
          const LogRow(
            level: LogLevel.error,
            text: 'error: TimeoutException',
            continuation: true,
          ),
        );
      await open(tester);
      await openLog(tester);
      await tabTo(tester, 'Copy shown');
      await press(tester, LogicalKeyboardKey.enter);

      expect(
        clipboard.single,
        '2026-10-13T09:00:00.000Z ERROR [sync] The sync failed\n'
        '  error: TimeoutException',
      );
      expect(find.text('Copied 2 lines'), findsOneWidget);
    });

    testWidgets('Open log folder shows the log file in the file manager, and '
        'says so when it can’t', (tester) async {
      await open(tester);
      await openLog(tester);
      await tabTo(tester, 'Open log folder');
      await press(tester, LogicalKeyboardKey.enter);

      expect(reveal.shown, ['/home/me/.local/share/app/logs/app.log']);

      reveal.opens = false;
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text("Couldn't open the log folder"), findsOneWidget);
    });

    testWidgets('by keyboard: every control in order, the lines as one Tab '
        'stop with the focus ring, and ↑ scrolls to older lines', (
      tester,
    ) async {
      log.rows
        ..clear()
        ..addAll([for (var i = 0; i < 300; i++) logRow(i)]);
      await open(tester, size: const Size(1024, 640));
      await openLog(tester);
      await tabTo(tester, 'All');

      final walked = <String?>['All'];
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        walked.add(focusedLabelOf(tester));
      }
      // The filter field is between the two pairs: it has no label of a
      // surface's.
      expect(walked, [
        'All',
        'Warnings and errors',
        null,
        'Copy shown',
        'Open log folder',
      ]);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final pane = find.descendant(
        of: find.byType(LogView),
        matching: find.byType(ScrollPane),
      );
      expect(hasFocusRing(tester, of: pane), isTrue);

      final position = logScroll(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(position.pixels, ScrollPane.lineStep, reason: 'towards the top');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(position.pixels, position.maxScrollExtent);
      expect(shown(tester).first, 'line 0');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(position.pixels, 0);
    });
  });

  testWidgets('the report and the log are two views of one space: the '
      'choice is made by keyboard and each fills it', (tester) async {
    await open(tester, size: const Size(1024, 640));
    expect(find.byType(ReportView), findsOneWidget);
    expect(find.byType(LogView), findsNothing);

    await tabTo(tester, 'Log');
    await press(tester, LogicalKeyboardKey.enter);

    expect(find.byType(LogView), findsOneWidget);
    expect(find.byType(ReportView), findsNothing);
    expect(focusedLabelOf(tester), 'Log');
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 130 % in the smallest window nothing overflows, in either '
      'view', (tester) async {
    await open(
      tester,
      size: const Size(1024, 640),
      appearance: const AppearanceSettings(textSize: TextSizeChoice.s130),
    );
    expect(tester.takeException(), isNull);

    await openLog(tester);
    expect(tester.takeException(), isNull);
    expect(shown(tester), isNotEmpty);
  });
}
