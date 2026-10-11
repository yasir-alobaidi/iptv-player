import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/system_trash.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/downloads/presentation/download_actions.dart';
import 'package:iptv_player/features/library/data/db_library_repository.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:path/path.dart' as p;

import '../../../app/app_harness.dart';
import '../../library/presentation/library_ui_support.dart';
import '../../vod/catalogue_screen_test.dart' show focusedLabel;
import '../../vod/vod_fakes.dart';

const _episodes = XtreamSeriesInfo(
  plot: 'A harbor inspector follows the tide logs.',
  episodes: [
    XtreamEpisode(id: '7101', season: 1, episode: 1, title: 'Low Water'),
    XtreamEpisode(id: '7102', season: 1, episode: 2, title: 'Ledger'),
    XtreamEpisode(id: '7201', season: 2, episode: 1, title: 'Undertow'),
  ],
);

DownloadTask _running(
  int id,
  String key,
  String title, {
  VodType type = VodType.movie,
}) => download(
  id,
  title,
  type: type,
  state: DownloadTaskState.downloading,
  downloaded: (1.03 * gb).round(),
  total: (2.1 * gb).round(),
  speed: 8.4 * 1024 * 1024,
).copyWith(remoteKey: key);

void main() {
  Future<(LibraryUi, AppUnderTest)> open(
    WidgetTester tester,
    String location, {
    FutureOr<void> Function(LibraryUi ui)? before,
    List<Override> overrides = const [],
  }) => openLibrary(
    tester,
    location: location,
    overrides: overrides,
    before: (ui) async {
      ui.vod.details.seriesAnswer = const Ok(_episodes);
      await before?.call(ui);
    },
  );

  group("a movie's page (sketch E)", () {
    testWidgets('Download queues it and says so; again, that it already '
        'is', (tester) async {
      final (ui, app) = await open(tester, '/movies/src-1/501');

      await tester.tap(find.widgetWithText(AppButton, 'Download'));
      await settle(tester);
      expect(ui.queue.calls, ['enqueue 501']);
      expect(find.text('Downloading The Quiet Harbor'), findsOneWidget);

      // The toast's Show opens Library → Downloads.
      await tester.tap(find.text('Show'));
      await settle(tester);
      expect(app.location, '/library');
      expect(
        ProviderScope.containerOf(tester.element(find.byType(CountTab).first))
            .read(libraryViewProvider)
            .tab,
        LibraryTab.downloads,
      );
    });

    testWidgets('D downloads the movie; D again says it is already '
        'downloading', (tester) async {
      final (ui, _) = await open(tester, '/movies/src-1/501');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);
      expect(ui.queue.calls, ['enqueue 501']);

      ui.queue.set([_running(1, '501', 'The Quiet Harbor')]);
      await tester.pump(AppToast.defaultDuration);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);
      expect(ui.queue.calls, hasLength(1));
      expect(
        find.text('The Quiet Harbor is already downloading.'),
        findsOneWidget,
      );
    });

    testWidgets('on its way: the button says how far, and its menu pauses, '
        'shows it in Downloads, or cancels', (tester) async {
      final (ui, _) = await open(
        tester,
        '/movies/src-1/501',
        before: (ui) => ui.queue.set([_running(1, '501', 'The Quiet Harbor')]),
      );

      final button = find.widgetWithText(AppButton, '49% · about 2 min left');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await settle(tester);
      expect(find.text('Cancel download'), findsOneWidget);
      expect(find.text('Show in Downloads'), findsOneWidget);
      await tester.tap(find.text('Pause'));
      await settle(tester);
      expect(ui.queue.calls, ['pause 1']);
      expect(find.widgetWithText(AppButton, 'Paused · 49%'), findsOneWidget);
    });

    testWidgets('stopped: the button says so, and its menu retries', (
      tester,
    ) async {
      final (ui, _) = await open(
        tester,
        '/movies/src-1/501',
        before: (ui) => ui.queue.set([
          download(
            1,
            'The Quiet Harbor',
            state: DownloadTaskState.failed,
            problem: DownloadProblem.network,
          ).copyWith(remoteKey: '501'),
        ]),
      );

      await tester.tap(find.widgetWithText(AppButton, 'Download stopped'));
      await settle(tester);
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(ui.queue.calls, ['retry 1']);
    });

    testWidgets('downloaded: the button says so; its menu shows the file '
        'or deletes it, asking first with Keep focused', (tester) async {
      final temp = Directory.systemTemp.createTempSync('download_ui_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final file = File(p.join(temp.path, 'Movies', 'The Quiet Harbor.mp4'))
        ..createSync(recursive: true)
        ..writeAsStringSync('video');
      late LibraryUi made;
      final (ui, _) = await open(
        tester,
        '/movies/src-1/501',
        before: (ui) async {
          made = ui;
          await ui.db.libraryDao.changeFolder(
            ui.downloads,
            LibraryFoldersCompanion(path: Value(temp.path)),
          );
          await ui.add(
            ui.downloads,
            'Movies/The Quiet Harbor.mp4',
            'The Quiet Harbor',
            provider: '501',
            bytes: (2.1 * gb).round(),
          );
        },
        overrides: [
          libraryRepositoryProvider.overrideWith(
            (ref) => DbLibraryRepository(
              made.db,
              scans: made.scans,
              trash: SystemTrash(
                environment: {'HOME': p.join(temp.path, 'home')},
                mountOf: (_) => temp.path,
              ),
            ),
          ),
        ],
      );

      await tester.tap(find.widgetWithText(AppButton, 'Downloaded'));
      await settle(tester);
      await tester.tap(find.text('Show in folder'));
      await settle(tester);
      expect(ui.revealed, [file.path]);

      await tester.tap(find.widgetWithText(AppButton, 'Downloaded'));
      await settle(tester);
      await tester.tap(find.text('Delete download…'));
      await settle(tester);
      expect(find.text('Delete "The Quiet Harbor.mp4"?'), findsOneWidget);
      expect(
        find.text('The video goes to the trash (2.1 GB).'),
        findsOneWidget,
      );
      expect(focusedLabel(), 'Keep');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(file.existsSync(), isTrue, reason: 'kept');

      await tester.tap(find.widgetWithText(AppButton, 'Downloaded'));
      await settle(tester);
      await tester.tap(find.text('Delete download…'));
      await settle(tester);
      await tester.tap(find.text('Move to trash'));
      await settle(tester);
      await settle(tester);
      expect(file.existsSync(), Platform.isLinux ? isFalse : anything);
      expect(find.widgetWithText(AppButton, 'Download'), findsOneWidget);
    }, skip: !Platform.isLinux);
  });

  group("a series' page", () {
    testWidgets('Download season queues its episodes that are not on '
        'this computer or on their way', (tester) async {
      final (ui, _) = await open(
        tester,
        '/series/src-1/77',
        before: (ui) => ui.queue.set([
          _running(1, '7102', 'Ledger', type: VodType.episode),
        ]),
      );

      await tester.tap(find.text('Download season'));
      await settle(tester);
      expect(ui.queue.calls, ['enqueue 7101']);
      expect(find.text('Downloading Glass Tide · S1 · E1'), findsOneWidget);
    });

    testWidgets('D on an episode downloads it; its row shows the download '
        'as it comes', (tester) async {
      final (ui, _) = await open(tester, '/series/src-1/77');
      expect(findByLabel('Download'), findsNWidgets(2));

      await tester.tap(find.text('Ledger'), buttons: 2);
      await settle(tester);
      expect(find.text('Download'), findsOneWidget, reason: "the row's menu");
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);

      final rows = find.byWidgetPredicate(
        (widget) =>
            widget is FocusableSurface &&
            widget.semanticLabel == 'Episode 2, Ledger',
      );
      tester.widget<FocusableSurface>(rows).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);
      expect(ui.queue.calls, ['enqueue 7102']);

      ui.queue.set([_running(1, '7102', 'Ledger', type: VodType.episode)]);
      await settle(tester);
      expect(findByLabel('49% · about 2 min left'), findsOneWidget);
    });
  });

  testWidgets('D on a movie in the Movies grid downloads it', (tester) async {
    final (ui, _) = await open(tester, '/movies');
    tester
        .widget<PosterCard>(find.widgetWithText(PosterCard, 'Copper Hollow'))
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await settle(tester);
    expect(ui.queue.calls, ['enqueue 502']);
    expect(find.text('Downloading Copper Hollow'), findsOneWidget);
  });

  testWidgets('the top bar: how many are on their way and how far, and a '
      'press opens Library → Downloads', (tester) async {
    final (ui, app) = await open(
      tester,
      '/movies',
      overrides: downloadShellOverrides,
      before: (ui) => ui.queue.set([
        _running(1, '501', 'The Quiet Harbor'),
        download(2, 'Copper Hollow', total: (2.1 * gb).round()),
        download(3, 'Ember Road'),
        download(
          4,
          'Kestrel Point',
          state: DownloadTaskState.completed,
          completedAt: ui.now,
        ),
      ]),
    );

    // 1.03 of 4.2 GB known; the one with no size yet counts for nothing.
    expect(find.text('3 · 25 %'), findsOneWidget);
    await tester.tap(find.text('3 · 25 %'));
    await settle(tester);
    expect(app.location, '/library');
    expect(find.text('IN PROGRESS'), findsOneWidget);

    ui.queue.set(const []);
    await settle(tester);
    expect(find.textContaining(' · 25 %'), findsNothing);
  });

  group('the queue speaks through toasts', () {
    Future<(LibraryUi, StreamController<DownloadNotice>, AppUnderTest)> open2(
      WidgetTester tester, {
      FutureOr<void> Function(LibraryUi ui)? before,
    }) async {
      final news = StreamController<DownloadNotice>.broadcast();
      addTearDown(news.close);
      final notices = AppNotices();
      addTearDown(notices.dispose);
      final (ui, app) = await open(
        tester,
        '/movies',
        before: before,
        overrides: [
          downloadNoticeStreamProvider.overrideWithValue(news.stream),
          appNoticesProvider.overrideWithValue(notices),
        ],
      );
      ProviderScope.containerOf(tester.element(find.byType(PosterCard).first))
          .read(downloadToastsProvider);
      await settle(tester);
      return (ui, news, app);
    }

    testWidgets('"Download finished · title" with Play, which plays the '
        'file', (tester) async {
      final (ui, news, _) = await open2(
        tester,
        before: (ui) => ui.add(
          ui.downloads,
          'Movies/Northwind Hotel.mp4',
          'Northwind Hotel',
        ),
      );

      news.add(
        DownloadFinishedNotice(
          download(
            4,
            'Northwind Hotel',
            state: DownloadTaskState.completed,
            libraryItemId: 1,
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Download finished · Northwind Hotel'), findsOneWidget);
      await tester.tap(find.text('Play'));
      await settle(tester);
      expect(ui.launcher.played, ['Northwind Hotel from 0']);
    });

    testWidgets('"Downloads paused while you watch", and a refused account '
        'with Edit source', (tester) async {
      final (_, news, app) = await open2(tester);

      news.add(const DownloadsWaitForPlayback('src-1', maxConnections: 1));
      await settle(tester);
      expect(
        find.text(
          'Downloads paused while you watch — your provider allows 1 '
          'connection.',
        ),
        findsOneWidget,
      );
      await tester.pump(AppToast.defaultDuration);
      await settle(tester);

      news.add(const DownloadsAccountRefused('src-1'));
      await settle(tester);
      expect(
        find.text('Downloads stopped: your provider refused the sign-in.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Edit source'));
      await settle(tester);
      expect(app.location, '/sources/src-1/edit');
    });
  });

  test('the top bar shows nothing when nothing is on its way', () {
    final container = ProviderContainer(
      overrides: [
        ...downloadShellOverrides,
        downloadTasksProvider.overrideWith(
          (ref) => Stream.value([
            download(
              1,
              'A',
              state: DownloadTaskState.failed,
              problem: DownloadProblem.notFound,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(shellDownloadsProvider), isNull);
  });
}
