import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

import '../design_harness.dart';

void main() {
  const loading = AppLoadingTokens();
  const short = 'Press F to add a favorite.';
  const long =
      'While watching, A and S change the audio and the subtitles, and '
      'Backspace goes back to the last channel you were on.';

  /// Waits out a tip's time on screen and the fade into the next: the
  /// fade's clock starts on the frame after the change, it ends on a frame
  /// past its length, and the old tip leaves on the frame after that.
  Future<void> nextTip(WidgetTester tester) async {
    await tester.pump(loading.tipInterval);
    await tester.pump();
    await tester.pump(loading.tipFade + const Duration(milliseconds: 1));
    await tester.pump();
  }

  /// The tips whose text is on screen now.
  List<String> shownTips(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(RotatingTip),
        matching: find.byType(Text),
      ),
    ))
      text.textSpan!.toPlainText(),
  ];

  group('LoadingStage', () {
    testWidgets('the title, how far it has come, the bar and a tip', (
      tester,
    ) async {
      await pumpDesign(
        tester,
        const LoadingStage(
          title: 'Getting your channels…',
          detail: '12,340 of 20,000 channels',
          progress: 0.62,
          tips: [short, long],
        ),
      );
      await tester.pump(loading.barGlide);

      expect(find.text('Getting your channels…'), findsOneWidget);
      expect(find.text('12,340 of 20,000 channels'), findsOneWidget);
      final bar = tester.widget<ProgressBar>(find.byType(ProgressBar));
      expect(bar.value, closeTo(0.62, 0.001));
      expect(shownTips(tester), ['Tip · $short']);
      expect(find.byType(AppIcon), findsNothing, reason: 'the jewel, not');
    });

    testWidgets('a bar with no progress sweeps; none unless asked', (
      tester,
    ) async {
      await pumpDesign(tester, const LoadingStage(title: 'Getting', bar: true));
      final bar = tester.widget<ProgressBar>(find.byType(ProgressBar));
      expect(bar.value, isNull);

      await pumpDesign(tester, const LoadingStage(title: 'Getting'));
      expect(find.byType(ProgressBar), findsNothing);
      expect(find.byType(RotatingTip), findsNothing);
    });

    testWidgets('a new count changes the line in place, and the bar glides '
        'to it', (tester) async {
      Widget stage(String detail, double progress) => LoadingStage(
        title: 'Getting your channels…',
        detail: detail,
        progress: progress,
      );
      await pumpDesign(tester, stage('9,999 of 20,000 channels', 0.5));
      final title = tester.getTopLeft(find.text('Getting your channels…'));

      await pumpDesign(tester, stage('10,000 of 20,000 channels', 0.6));
      expect(find.text('10,000 of 20,000 channels'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Getting your channels…')),
        title,
        reason: 'nothing above the line moves',
      );
      final midway = tester.widget<ProgressBar>(find.byType(ProgressBar));
      expect(midway.value, closeTo(0.5, 0.001), reason: 'it starts gliding');

      await tester.pump(loading.barGlide ~/ 2);
      final value = tester.widget<ProgressBar>(find.byType(ProgressBar)).value;
      expect(value, inExclusiveRange(0.5, 0.6));

      await tester.pump(loading.barGlide);
      expect(
        tester.widget<ProgressBar>(find.byType(ProgressBar)).value,
        closeTo(0.6, 0.001),
      );
    });

    testWidgets('moves with full motion', (tester) async {
      await pumpDesign(
        tester,
        const LoadingStage(title: 'Getting', bar: true, tips: [short, long]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
    });

    testWidgets('is still with reduce motion on', (tester) async {
      await pumpDesign(
        tester,
        const LoadingStage(title: 'Getting', bar: true, tips: [short, long]),
        reduceMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);

      // A tip still changes, at once, without a fade.
      await tester.pump(loading.tipInterval);
      expect(shownTips(tester), ['Tip · $long']);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('fits a narrow, short pane at 130 %: it scrolls, nothing '
        'overflows or is cut', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(
          width: 300,
          height: 240,
          child: LoadingStage(
            title: 'Getting your channels…',
            detail: 'Downloading the channel list',
            bar: true,
            tips: [short, long],
          ),
        ),
        textScale: 1.3,
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(LoadingStage),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      for (final element
          in find
              .descendant(
                of: find.byType(LoadingStage),
                matching: find.byType(RichText),
              )
              .evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(
          paragraph.textSize.height,
          lessThanOrEqualTo(paragraph.size.height + 0.5),
          reason: paragraph.text.toPlainText(),
        );
        expect(
          paragraph.size.width,
          lessThanOrEqualTo(300),
          reason: paragraph.text.toPlainText(),
        );
      }
    });

    testWidgets('takes no focus: Tab goes past it', (tester) async {
      final after = FocusNode(debugLabel: 'after');
      addTearDown(after.dispose);
      await pumpDesign(
        tester,
        SizedBox(
          width: 500,
          height: 600,
          child: Column(
            children: [
              AppButton(label: 'Before', onPressed: () {}),
              const Expanded(
                child: LoadingStage(
                  title: 'Getting',
                  bar: true,
                  tips: [short, long],
                ),
              ),
              AppButton(label: 'After', focusNode: after, onPressed: () {}),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(after.hasPrimaryFocus, isTrue);
    });
  });

  group('RotatingTip', () {
    testWidgets('the next tip every interval, crossfading, then round again', (
      tester,
    ) async {
      await pumpDesign(
        tester,
        const SizedBox(width: 400, child: RotatingTip(tips: [short, long])),
      );
      expect(shownTips(tester), ['Tip · $short']);

      await tester.pump(loading.tipInterval - const Duration(milliseconds: 1));
      expect(shownTips(tester), ['Tip · $short'], reason: 'not yet');

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump(loading.tipFade ~/ 2);
      expect(
        shownTips(tester),
        unorderedEquals(['Tip · $short', 'Tip · $long']),
        reason: 'one fades into the other',
      );
      final fading = tester.widgetList<FadeTransition>(
        find.descendant(
          of: find.byType(RotatingTip),
          matching: find.byType(FadeTransition),
        ),
      );
      expect([
        for (final fade in fading) fade.opacity.value,
      ], everyElement(inExclusiveRange(0, 1)));

      await tester.pump(loading.tipFade);
      await tester.pump();
      expect(shownTips(tester), ['Tip · $long']);

      await nextTip(tester);
      expect(shownTips(tester), ['Tip · $short'], reason: 'round again');
    });

    testWidgets('as tall as its tallest tip: nothing round it moves when a '
        'short tip follows a long one', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(width: 260, child: RotatingTip(tips: [short, long])),
      );
      final first = tester.getSize(find.byType(RotatingTip));
      final line = tester.getSize(find.textContaining(short)).height;
      expect(first.height, greaterThan(line * 2), reason: 'the long tip wraps');

      await nextTip(tester);
      expect(shownTips(tester), ['Tip · $long']);
      expect(tester.getSize(find.byType(RotatingTip)), first);
    });

    testWidgets('one tip stays; none draws nothing', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(width: 400, child: RotatingTip(tips: [short])),
      );
      await tester.pump(loading.tipInterval * 3);
      expect(shownTips(tester), ['Tip · $short']);

      await pumpDesign(
        tester,
        const SizedBox(width: 400, child: RotatingTip(tips: [])),
      );
      expect(find.byType(Text), findsNothing);
    });
  });
}
