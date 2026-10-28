import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/search/data/search_providers.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/presentation/search_state.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';
import '../settings/appearance_fakes.dart';
import 'search_fakes.dart';

/// ADR-068: Search on a phone is the whole screen — ‹ and the field at
/// the top, the system's keyboard, the results in one column, no Library
/// (a phone has none), the recent searches a tap away.
void main() {
  const phone = Size(390, 844);
  final now = DateTime(2026, 9, 14, 8);

  SearchResults harbor() => SearchResults(
    text: 'harbor',
    channels: const SearchGroup([
      ChannelHit(
        channel: ChannelItem(
          id: 118,
          sourceId: 'src-1',
          remoteKey: '118',
          name: 'Harbor City Local',
          number: 118,
        ),
        sourceName: 'Northwind TV',
      ),
    ]),
    movies: const SearchGroup([
      MovieHit(
        movie: MovieItem(
          id: 1,
          sourceId: 'src-1',
          remoteKey: '501',
          name: 'The Quiet Harbor',
          year: 2024,
        ),
        sourceName: 'Northwind TV',
        genre: 'Drama',
      ),
    ]),
    library: SearchGroup([
      LibraryItemHit(
        LibraryItem(
          id: 1,
          folderId: 1,
          relPath: 'Harbor Walk (2021).mkv',
          sizeBytes: 640 * 1024 * 1024,
          modifiedAt: now,
          quickHash: 'harbor-walk',
          kind: LibraryKind.movie,
          title: 'Harbor Walk',
          addedAt: now,
          year: 2021,
          duration: const Duration(minutes: 12),
        ),
        folderLabel: 'Home videos',
      ),
    ]),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<ScriptedSearch> open(WidgetTester tester) async {
    final search = ScriptedSearch()
      ..recent = ['tennis open']
      ..answers['harbor'] = harbor();
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    await pumpApp(
      tester,
      size: phone,
      withAppearance: true,
      overrides: [
        ...live.overrides,
        ...sourceShellOverrides,
        searchRepositoryProvider.overrideWithValue(search),
        libraryThumbnailProvider.overrideWith((ref, id) async => null),
        ...appearanceOverrides(),
        formFactorProvider.overrideWithValue(FormFactor.mobile),
      ],
    );
    await settle(tester);
    // The compact top bar's Search.
    await tester.tap(findByLabel('Search'));
    await settle(tester);
    return search;
  }

  testWidgets('the whole screen: ‹ and the field across the top, the '
      'recent searches, a tap searching again', (tester) async {
    final search = await open(tester);

    final field = tester.getRect(find.byType(EditableText));
    expect(field.top, lessThan(80));
    expect(find.byTooltip('Close search'), findsOneWidget);
    expect(find.text('Esc'), findsNothing);
    expect(find.text('tennis open'), findsOneWidget);

    await tester.tap(find.text('tennis open'));
    await tester.pump(searchDelay);
    await settle(tester);
    expect(search.asked, contains('tennis open'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed: the results in one column the width of the screen, '
      'without the Library; ‹ closes', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(EditableText), 'harbor');
    await tester.pump(searchDelay);
    await settle(tester);

    expect(find.text('CHANNELS'), findsOneWidget);
    expect(find.text('MOVIES'), findsOneWidget);
    expect(find.text('LIBRARY'), findsNothing);
    expect(find.text('Harbor Walk (2021)'), findsNothing);
    expect(find.text('2 results'), findsOneWidget);
    final row = tester.getRect(find.textContaining('Quiet').first);
    expect(row.right, lessThan(phone.width));

    await tester.tap(find.byTooltip('Close search'));
    await settle(tester);
    expect(find.byType(EditableText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a held row opens its menu', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(EditableText), 'harbor');
    await tester.pump(searchDelay);
    await settle(tester);

    await tester.longPress(find.textContaining('Quiet').first);
    await settle(tester);
    expect(find.text('Add to favorites'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
