import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/sync_wait.dart';
import 'package:iptv_player/features/sources/presentation/wait_tips.dart';

import '../../../design/design_harness.dart';

void main() {
  group('syncWaitDetail', () {
    String detail(SyncProgress progress, SyncWaitFor waitFor) =>
        syncWaitDetail(progress, waitFor);

    test('signing in and the categories, for every screen', () {
      for (final waitFor in SyncWaitFor.values) {
        expect(
          detail(const SyncProgress(stage: SyncStage.account), waitFor),
          'Signing in to your provider',
        );
        expect(
          detail(const SyncProgress(stage: SyncStage.categories), waitFor),
          'Getting the categories',
        );
        expect(
          detail(const SyncProgress(stage: SyncStage.finishing), waitFor),
          'Almost done',
        );
      }
    });

    test('the list a screen waits for: downloading, then counted', () {
      expect(
        detail(const SyncProgress(stage: SyncStage.live), SyncWaitFor.channels),
        'Downloading the channel list',
      );
      expect(
        detail(
          const SyncProgress(
            stage: SyncStage.live,
            channels: 12340,
            stageTotal: 20000,
          ),
          SyncWaitFor.channels,
        ),
        '12,340 of 20,000 channels',
      );
      expect(
        detail(
          const SyncProgress(stage: SyncStage.movies, movies: 1),
          SyncWaitFor.movies,
        ),
        '1 movie so far',
      );
      expect(
        detail(const SyncProgress(stage: SyncStage.series), SyncWaitFor.series),
        'Downloading the series list',
      );
      expect(
        detail(
          const SyncProgress(stage: SyncStage.movies, movies: 8021),
          SyncWaitFor.catalogue,
        ),
        '8,021 movies so far',
      );
    });

    test('a list that comes first says so, or the wait looks stuck', () {
      expect(
        detail(const SyncProgress(stage: SyncStage.live), SyncWaitFor.movies),
        'Channels first',
      );
      expect(
        detail(
          const SyncProgress(
            stage: SyncStage.live,
            channels: 12340,
            stageTotal: 20000,
          ),
          SyncWaitFor.series,
        ),
        'Channels first · 12,340 so far',
      );
      expect(
        detail(
          const SyncProgress(stage: SyncStage.movies, movies: 8021),
          SyncWaitFor.series,
        ),
        'Movies first · 8,021 so far',
      );
    });

    test("a playlist: what it has found so far of the screen's kind", () {
      const reading = SyncProgress(stage: SyncStage.playlist);
      expect(detail(reading, SyncWaitFor.channels), 'Reading the playlist');
      const found = SyncProgress(
        stage: SyncStage.playlist,
        channels: 12340,
        movies: 1,
      );
      expect(detail(found, SyncWaitFor.channels), '12,340 channels so far');
      expect(detail(found, SyncWaitFor.movies), '1 movie so far');
      expect(detail(found, SyncWaitFor.series), 'Reading the playlist');
      expect(
        detail(found, SyncWaitFor.catalogue),
        '12,340 channels · 1 movie so far',
      );
    });
  });

  group('syncWaitFraction', () {
    test('only once the list is in, and only for what the screen waits '
        'for', () {
      const downloading = SyncProgress(stage: SyncStage.live);
      expect(syncWaitFraction(downloading, SyncWaitFor.channels), isNull);
      const saving = SyncProgress(
        stage: SyncStage.live,
        channels: 5000,
        stageTotal: 20000,
      );
      expect(syncWaitFraction(saving, SyncWaitFor.channels), 0.25);
      expect(syncWaitFraction(saving, SyncWaitFor.catalogue), 0.25);
      expect(syncWaitFraction(saving, SyncWaitFor.movies), isNull);
      expect(
        syncWaitFraction(
          const SyncProgress(stage: SyncStage.series, stageTotal: 0),
          SyncWaitFor.series,
        ),
        1,
      );
      expect(
        syncWaitFraction(
          const SyncProgress(stage: SyncStage.movies, movies: 9, stageTotal: 8),
          SyncWaitFor.movies,
        ),
        1,
        reason: 'never past the end',
      );
    });
  });

  group('wait tips', () {
    Future<List<String>> tipsOn(
      WidgetTester tester, {
      required bool tv,
      int from = 0,
    }) async {
      late List<String> tips;
      await pumpDesign(
        tester,
        Builder(
          builder: (context) {
            tips = waitTips(context, from: from);
            return const SizedBox.shrink();
          },
        ),
        around: (app) => KeyHints(shown: !tv, child: app),
      );
      return tips;
    }

    testWidgets("a computer's name keys; a TV's are the remote's", (
      tester,
    ) async {
      expect(await tipsOn(tester, tv: false), desktopWaitTips);
      expect(await tipsOn(tester, tv: true), tvWaitTips);
    });

    testWidgets('from a given tip, and round again', (tester) async {
      final tips = await tipsOn(tester, tv: false, from: 2);
      expect(tips.first, desktopWaitTips[2]);
      expect(tips.last, desktopWaitTips[1]);
      expect(tips, unorderedEquals(desktopWaitTips));
      expect(
        await tipsOn(tester, tv: false, from: desktopWaitTips.length),
        desktopWaitTips,
      );
    });

    test("a TV's never mention keys, casting, windows or downloads", () {
      final keys = RegExp(
        r'\b[A-Z]\b|\bF\d+\b|Ctrl|Shift|Alt\b|Esc|Enter|Tab\b|Space|'
        'Backspace|Delete|Press|[Kk]ey|[Cc]ast|[Ww]indow|[Dd]ownload|'
        '[Cc]omputer|[Mm]ouse|[Cc]lick',
      );
      for (final tip in tvWaitTips) {
        expect(keys.hasMatch(tip), isFalse, reason: tip);
      }
    });

    test('between six and ten each, one short line or two', () {
      for (final tips in [desktopWaitTips, tvWaitTips]) {
        expect(tips.length, inInclusiveRange(6, 10));
        expect(tips.toSet(), hasLength(tips.length), reason: 'no repeats');
        for (final tip in tips) {
          expect(tip.length, lessThanOrEqualTo(64), reason: tip);
        }
      }
    });
  });

  testWidgets('the stage says how far the sync has come, with the tips', (
    tester,
  ) async {
    await pumpDesign(
      tester,
      const SyncWaitStage(
        title: 'Getting your channels…',
        progress: SyncProgress(
          stage: SyncStage.live,
          channels: 12340,
          stageTotal: 20000,
        ),
        waitFor: SyncWaitFor.channels,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Getting your channels…'), findsOneWidget);
    expect(find.text('12,340 of 20,000 channels'), findsOneWidget);
    final bar = tester.widget<ProgressBar>(find.byType(ProgressBar));
    expect(bar.value, closeTo(0.617, 0.001));
    expect(find.text('Tip · ${desktopWaitTips.first}'), findsOneWidget);
  });
}
