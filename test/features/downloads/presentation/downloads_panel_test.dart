import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/downloads/presentation/downloads_panel.dart';

import '../../../app/app_harness.dart';
import '../../library/presentation/library_ui_support.dart';
import '../../vod/catalogue_screen_test.dart' show focusedLabel;
import '../../vod/vod_fakes.dart';

/// The canvas's Downloads: one running, one queued behind it, one the
/// provider dropped, two finished today.
List<DownloadTask> _canvas(LibraryUi ui, {int? finishedItem}) => [
  download(
    1,
    'Copper Hollow',
    year: 2025,
    state: DownloadTaskState.downloading,
    downloaded: (1.03 * gb).round(),
    total: (2.1 * gb).round(),
    speed: 8.4 * 1024 * 1024,
  ),
  download(
    2,
    'Northbound',
    type: VodType.episode,
    show: 'Glass Tide',
    season: 2,
    episode: 5,
    total: (0.9 * gb).round(),
  ),
  download(
    3,
    'Tidelines',
    type: VodType.episode,
    show: 'Harbor Nine',
    season: 1,
    episode: 2,
    state: DownloadTaskState.failed,
    problem: DownloadProblem.notFound,
  ),
  download(
    4,
    'Northwind Hotel',
    state: DownloadTaskState.completed,
    total: (3.4 * gb).round(),
    downloaded: (3.4 * gb).round(),
    libraryItemId: finishedItem,
    completedAt: ui.now.subtract(const Duration(hours: 1)),
  ),
  download(
    5,
    'Undertow',
    type: VodType.episode,
    show: 'Glass Tide',
    season: 2,
    episode: 4,
    state: DownloadTaskState.completed,
    total: (1.1 * gb).round(),
    downloaded: (1.1 * gb).round(),
    completedAt: ui.now.subtract(const Duration(hours: 2)),
  ),
];

void main() {
  Future<(LibraryUi, AppUnderTest)> open(
    WidgetTester tester, {
    List<DownloadTask> Function(LibraryUi ui)? tasks,
    Future<void> Function(LibraryUi ui)? before,
  }) async {
    final opened = await openLibrary(
      tester,
      before: (ui) async {
        await before?.call(ui);
        ui.queue.set((tasks ?? _canvas)(ui));
      },
    );
    await tester.tap(find.widgetWithText(CountTab, 'Downloads'));
    await settle(tester);
    return opened;
  }

  /// Puts the keyboard on the row whose label starts with [name].
  Future<void> focusRow(WidgetTester tester, String name) async {
    final row = find.byWidgetPredicate(
      (widget) =>
          widget is FocusableSurface &&
          (widget.semanticLabel?.startsWith(name) ?? false),
    );
    tester.widget<FocusableSurface>(row).focusNode!.requestFocus();
    await tester.pump();
  }

  testWidgets('the tab as the canvas draws it: the count lit, the three '
      'sections, what each download is doing, and the meter', (tester) async {
    await open(tester);

    final tab = tester.widget<CountTab>(
      find.widgetWithText(CountTab, 'Downloads'),
    );
    expect(tab.count, 2, reason: 'what is still on its way');
    expect(tab.highlightCount, isTrue);
    expect(find.text('Pause all'), findsOneWidget);
    expect(find.text('Add folder'), findsNothing);
    expect(find.textContaining('on this computer'), findsNothing);

    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('Copper Hollow'), findsOneWidget);
    expect(find.text('Movie · 2025'), findsOneWidget);
    expect(find.text('49%'), findsOneWidget);
    expect(find.text('1.0 GB of 2.1 GB'), findsOneWidget);
    expect(find.text('8.4 MB/s'), findsOneWidget);
    expect(find.text('about 2 min left'), findsOneWidget);
    expect(find.text('S2 · E5 · Northbound'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
    expect(find.text('starts after Copper Hollow'), findsOneWidget);

    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(
      find.text('This episode is no longer available from your provider.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    expect(find.text('FINISHED TODAY'), findsOneWidget);
    expect(find.textContaining('3.4 GB · finished at'), findsOneWidget);
    expect(find.text('Play'), findsNWidgets(2));
    expect(find.text('Clear list'), findsOneWidget);

    expect(find.text('Downloads 0 bytes'), findsOneWidget);
    expect(find.text('118 GB free of 512 GB'), findsOneWidget);
    expect(find.text('~/Videos/IPTV Player'), findsOneWidget);
    expect(find.text('Change folder'), findsOneWidget);
  });

  testWidgets('nothing downloading: says how to start one, and the tab has '
      'no count', (tester) async {
    await open(tester, tasks: (_) => const []);

    expect(find.text('Nothing downloading'), findsOneWidget);
    expect(
      find.text('Press D on a movie or episode to download it.'),
      findsOneWidget,
    );
    expect(
      tester.widget<CountTab>(find.widgetWithText(CountTab, 'Downloads')).count,
      isNull,
    );
    expect(find.text('Pause all'), findsNothing);
    expect(find.text('Change folder'), findsOneWidget, reason: 'the meter');
  });

  testWidgets("a list that can't be read: says so, with Retry", (tester) async {
    await openLibrary(
      tester,
      before: (ui) => ui.queue.failure = StateError('disk I/O error'),
    );
    await tester.tap(find.widgetWithText(CountTab, 'Downloads'));
    await settle(tester);

    expect(find.text("Couldn't load your downloads"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Pause all, then Resume all', (tester) async {
    final (ui, _) = await open(tester);

    await tester.tap(find.text('Pause all'));
    await settle(tester);
    expect(ui.queue.calls, ['pauseAll']);
    expect(find.text('Paused'), findsNWidgets(2));
    expect(find.text('Resume all'), findsOneWidget);

    await tester.tap(find.text('Resume all'));
    await settle(tester);
    expect(ui.queue.calls, ['pauseAll', 'resumeAll']);
    expect(find.text('Pause all'), findsOneWidget);
  });

  testWidgets('by keys: one Tab stop, the arrows between the rows, Enter '
      "does each row's main thing", (tester) async {
    final (ui, _) = await open(
      tester,
      before: (ui) =>
          ui.add(ui.downloads, 'Movies/Northwind Hotel.mp4', 'Northwind Hotel'),
      tasks: (ui) => _canvas(ui, finishedItem: 1),
    );
    await focusRow(tester, 'Copper Hollow');

    // Enter pauses, and resumes.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(ui.queue.calls, ['pause 1', 'resume 1']);

    final walked = <String?>[];
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      walked.add(focusedLabel());
    }
    expect(walked, [
      startsWith('Glass Tide · S2 · E5 · Northbound'),
      startsWith('Harbor Nine · S1 · E2 · Tidelines'),
      startsWith('Northwind Hotel'),
      startsWith('Glass Tide · S2 · E4 · Undertow'),
    ]);

    // Enter on a finished one plays it; on the failed one, tries again.
    await focusRow(tester, 'Northwind Hotel');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(ui.launcher.played, ['Northwind Hotel from 0']);

    await focusRow(tester, 'Harbor Nine');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(ui.queue.calls.last, 'retry 3');

    // The buttons inside the rows are the mouse's: Tab leaves the list.
    await focusRow(tester, 'Copper Hollow');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusedLabel(), 'Change folder');
  });

  testWidgets('Alt+↓ and Alt+↑ move a download in the queue, the keyboard '
      'staying on it', (tester) async {
    final (ui, _) = await open(
      tester,
      tasks: (ui) => [
        download(1, 'Copper Hollow', state: DownloadTaskState.downloading),
        download(2, 'Ember Road'),
        download(3, 'Quarry Lake'),
      ],
    );
    await focusRow(tester, 'Copper Hollow');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    expect(
      [for (final t in ui.queue.list) t.title],
      ['Ember Road', 'Copper Hollow', 'Quarry Lake'],
    );
    expect(focusedLabel(), startsWith('Copper Hollow'));
    expect(find.text('starts after Copper Hollow'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    expect(ui.queue.list.first.title, 'Copper Hollow', reason: 'at the top');
  });

  testWidgets('Cancel asks before it throws away what was downloaded, '
      'with Keep downloading focused; a queued one just goes', (tester) async {
    final (ui, _) = await open(tester);

    await tester.tap(findByLabel('Cancel download').first);
    await settle(tester);
    expect(find.text('Cancel this download?'), findsOneWidget);
    expect(
      find.textContaining('The 1.0 GB of Copper Hollow downloaded so far'),
      findsOneWidget,
    );
    expect(focusedLabel(), 'Keep downloading');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(ui.queue.calls, isEmpty);

    await focusRow(tester, 'Glass Tide · S2 · E5');
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(ui.queue.calls, ['cancel 2']);
    expect(find.text('Cancel this download?'), findsNothing);
    expect(
      focusedLabel(),
      startsWith('Harbor Nine'),
      reason: 'the keyboard goes to the row that took its place',
    );
  });

  testWidgets('needs attention: Remove takes it off; an account the '
      'provider refused offers Edit source', (tester) async {
    final (ui, app) = await open(
      tester,
      tasks: (ui) => [
        ..._canvas(ui),
        download(
          6,
          'Ember Road',
          state: DownloadTaskState.paused,
          problem: DownloadProblem.auth,
        ),
      ],
    );

    expect(find.textContaining('refused the sign-in'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await settle(tester);
    expect(ui.queue.calls, ['remove 3']);

    await tester.tap(find.text('Edit source'));
    await settle(tester);
    expect(app.location, '/sources/src-1/edit');
  });

  testWidgets('finished: Show in folder, the menu, and Clear list', (
    tester,
  ) async {
    final (ui, _) = await open(tester);

    await tester.tap(findByLabel('Show in folder').first);
    await settle(tester);
    expect(ui.revealed, ['/home/me/Videos/IPTV Player/Northwind Hotel.mp4']);

    // A finished download whose file left the library says so.
    await tester.tap(find.text('Play').first);
    await settle(tester);
    expect(ui.launcher.played, isEmpty);
    expect(
      find.text('Northwind Hotel is no longer in your library.'),
      findsOneWidget,
    );

    await focusRow(tester, 'Glass Tide · S2 · E4');
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settle(tester);
    expect(find.text('Remove from this list'), findsOneWidget);
    await tester.tap(find.text('Clear list').last);
    await settle(tester);
    expect(ui.queue.calls, ['clearFinished']);
    expect(find.text('FINISHED TODAY'), findsNothing);
  });

  testWidgets('Change folder: new downloads go there, and the meter '
      'follows; a drive nearly full is amber', (tester) async {
    final temp = Directory.systemTemp.createTempSync('downloads_ui_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final (ui, _) = await open(
      tester,
      before: (ui) async => ui.disk = (free: 3 * gb, total: 512 * gb),
    );
    final free = tester.widget<Text>(find.text('3.0 GB free of 512 GB'));
    expect(
      free.style!.color,
      isNot(tester.widget<Text>(find.text('49%')).style!.color),
    );

    // Closed without a choice: nothing changes.
    await tester.tap(find.text('Change folder'));
    await settle(tester);
    expect(ui.downloadFolders, isEmpty);

    ui.picked = temp.path;
    await tester.tap(find.text('Change folder'));
    await settle(tester);
    expect(ui.downloadFolders, [temp.path]);
    expect(find.textContaining('New downloads go to'), findsOneWidget);
    expect(
      find.textContaining('What you downloaded stays where it is.'),
      findsOneWidget,
    );
  });

  test('a download finished yesterday is not listed', () {
    final sections = downloadSections([
      download(
        1,
        'A',
        state: DownloadTaskState.completed,
        completedAt: DateTime(2026, 10, 10, 20),
      ),
    ], DateTime(2026, 10, 11, 9));
    expect(sections.finished, isEmpty);
  });
}
