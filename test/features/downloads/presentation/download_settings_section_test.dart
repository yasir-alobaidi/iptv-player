import 'dart:io';
import 'dart:ui' show Size;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/presentation/download_settings_section.dart';
import 'package:path/path.dart' as p;

import '../../../app/app_harness.dart';
import '../../library/presentation/library_ui_support.dart';
import '../../vod/vod_fakes.dart';

void main() {
  Future<(LibraryUi, AppUnderTest)> open(
    WidgetTester tester, {
    Future<void> Function(LibraryUi ui)? before,
  }) async {
    final opened = await openLibrary(
      tester,
      location: '/settings',
      before: before,
      // Tall enough for the whole section: its list builds what shows.
      size: const Size(1440, 1400),
    );
    await tester.tap(find.text('Downloads & library'));
    await settle(tester);
    return opened;
  }

  DownloadSettings settings(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(DownloadSettingsSection)),
  ).read(downloadSettingsControllerProvider);

  testWidgets('the section as the canvas lists it: the folder and its free '
      "space, the queue's settings, and the library's folders", (tester) async {
    await open(tester);

    expect(find.text('DOWNLOADS'), findsOneWidget);
    expect(
      find.text('${p.join('~', 'Videos', 'IPTV Player')} · 118 GB free'),
      findsOneWidget,
    );
    expect(find.text('Downloads at a time'), findsOneWidget);
    expect(
      find.text(
        "Never more than your provider's free connections. Watching "
        'always comes first.',
      ),
      findsOneWidget,
    );
    for (final limit in ['Unlimited', '50 Mbps', '20 Mbps', '10 Mbps']) {
      expect(find.text(limit), findsOneWidget, reason: limit);
    }
    expect(find.text('Resume downloads when the app opens'), findsOneWidget);
    expect(
      find.text('Keep the computer awake while downloading'),
      findsOneWidget,
    );
    expect(find.text('LIBRARY FOLDERS'), findsOneWidget);
    expect(find.text('/media/hdd/Movies'), findsOneWidget);
    expect(find.text('Hidden videos'), findsOneWidget);
    expect(find.textContaining('comes in Phase'), findsNothing);
  });

  testWidgets('each choice is kept: how many at a time, the speed limit, '
      'and the two switches', (tester) async {
    await open(tester);
    expect(settings(tester).atATime, 1);

    await tester.tap(find.text('3'));
    await settle(tester);
    await tester.tap(find.text('20 Mbps'));
    await settle(tester);
    expect(settings(tester).atATime, 3);
    expect(settings(tester).speedLimit, DownloadSpeedLimit.mbps20);

    // Resume at launch, then Keep awake: each Off.
    await tester.tap(find.text('Off').first);
    await settle(tester);
    expect(settings(tester).resumeOnLaunch, isFalse);
    expect(settings(tester).keepAwake, isTrue);
    await tester.tap(find.text('Off').last);
    await settle(tester);
    expect(settings(tester).keepAwake, isFalse);
  });

  testWidgets('Change… asks for a folder and says what happens to what '
      'was downloaded', (tester) async {
    final temp = Directory.systemTemp.createTempSync('download_settings_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final (ui, _) = await open(tester);

    ui.picked = temp.path;
    await tester.tap(find.widgetWithText(AppButton, 'Change…'));
    await settle(tester);
    expect(ui.downloadFolders, [temp.path]);
    expect(
      find.textContaining('What you downloaded stays where it is.'),
      findsOneWidget,
    );
  });

  testWidgets('Hidden videos (sketch H): how many, the list with where '
      'each is, and Show puts one back', (tester) async {
    await open(
      tester,
      before: (ui) async {
        await ui.add(ui.hdd, 'Lamplight (2015).mkv', 'Lamplight', year: 2015);
        final hidden = await ui.add(
          ui.home,
          'Garden timelapse.mp4',
          'Garden timelapse',
        );
        await ui.db.libraryDao.changeItem(
          hidden,
          const LibraryItemsCompanion(isHidden: Value(true)),
        );
      },
    );

    expect(find.text('Hidden videos · 1'), findsOneWidget);
    expect(find.text('Garden timelapse'), findsNothing, reason: 'closed');

    await tester.ensureVisible(find.widgetWithText(AppButton, 'Show'));
    await tester.tap(find.widgetWithText(AppButton, 'Show'));
    await settle(tester);
    expect(find.text('Garden timelapse'), findsOneWidget);
    expect(
      find.text('Home videos · Garden timelapse.mp4 · 1.0 GB'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.widgetWithText(AppButton, 'Show'));
    await tester.tap(find.widgetWithText(AppButton, 'Show'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Hidden videos'), findsOneWidget, reason: 'none left');
    expect(find.text('Garden timelapse'), findsNothing);
  });
}
