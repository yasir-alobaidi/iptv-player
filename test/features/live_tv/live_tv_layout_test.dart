import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/presentation/categories_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_list_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/preview_pane.dart';

import '../../app/app_harness.dart';
import 'live_tv_fakes.dart';

/// Live TV's three panes in windows other than the canvas's (ADR-017).
void main() {
  const layout = AppLayoutTokens();

  Future<LiveTvFakes> open(WidgetTester tester, Size size) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    await pumpApp(
      tester,
      size: size,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.overrides,
    );
    await _settle(tester);
    return live;
  }

  double width(WidgetTester tester, Type pane) =>
      tester.getSize(find.byType(pane)).width;

  /// Whether [text] is drawn whole: one line, nothing cut with "…".
  bool whole(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(text).first,
    );
    return paragraph.getMaxIntrinsicWidth(double.infinity) <=
        paragraph.size.width + 0.5;
  }

  testWidgets('the smallest window: the list keeps the width a name needs, '
      'and the other two give way', (tester) async {
    await open(tester, const Size(1024, 640));

    expect(width(tester, ChannelListPane), layout.channelListMin);
    expect(width(tester, CategoriesPane), lessThan(layout.categoriesWidth));
    expect(width(tester, PreviewPane), greaterThanOrEqualTo(layout.previewMin));
    for (final name in [
      'Arena Sports 1',
      'Arena Sports 2',
      'Velocity Motors',
    ]) {
      expect(whole(tester, name), isTrue, reason: '$name is cut');
    }
  });

  testWidgets("the canvas's window: 248, the list, 540", (tester) async {
    await open(tester, const Size(1440, 900));

    expect(width(tester, CategoriesPane), layout.categoriesWidth);
    expect(width(tester, PreviewPane), closeTo(PreviewPane.width, 2));
  });

  testWidgets('a large window: the preview takes the room, and its picture '
      'leaves room under it', (tester) async {
    await open(tester, const Size(1920, 1080));

    final preview = tester.getSize(find.byType(PreviewPane));
    expect(preview.width, greaterThan(PreviewPane.width + 200));
    expect(width(tester, ChannelListPane), lessThan(layout.channelListMax));
    expect(
      preview.width * 9 / 16,
      lessThan(preview.height - layout.previewDetailsRoom + 1),
    );
  });

  testWidgets('a very wide window: the list stops at its widest, the preview '
      'at what its height allows, and the rest stays empty', (tester) async {
    final live = await open(tester, const Size(3440, 1440));
    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);

    expect(width(tester, ChannelListPane), layout.channelListMax);
    final preview = tester.getRect(find.byType(PreviewPane));
    expect(
      preview.width,
      closeTo((preview.height - layout.previewDetailsRoom) * 16 / 9, 1),
    );
    expect(preview.right, lessThan(3440 - 100));
    // Under a picture that wide, the words keep to a line's length.
    final watch = tester.getRect(find.text('Watch full screen'));
    expect(watch.right - preview.left, lessThan(layout.previewTextMax));

    await tester.pump(const Duration(seconds: 1));
    await live.rig.coordinator.stop();
    await _settle(tester);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 60));
  }
}
