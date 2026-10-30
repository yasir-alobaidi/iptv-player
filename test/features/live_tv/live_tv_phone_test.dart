import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/presentation/categories_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_list_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/preview_pane.dart';

import '../../app/app_harness.dart';
import 'live_tv_fakes.dart';

/// Live TV on a phone and a tablet (ADR-068): one pane below 600 px, its
/// title the button to the categories' sheet; no preview where it has no
/// room, so a press plays full screen; a finger held opens a row's menu.
void main() {
  Future<(LiveTvFakes, AppUnderTest)> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    final app = await pumpApp(
      tester,
      size: size,
      initialLocation: AppDestination.liveTv.path,
      overrides: [
        ...live.overrides,
        formFactorProvider.overrideWithValue(FormFactor.mobile),
      ],
    );
    await _settle(tester);
    return (live, app);
  }

  Finder categoryButton() => find.byWidgetPredicate(
    (widget) =>
        widget is FocusableSurface &&
        (widget.semanticLabel?.startsWith('Category: ') ?? false),
  );

  testWidgets('a phone held upright: the list alone, the width of the '
      'screen; its title opens the categories in a sheet, and a choice '
      'shows that category', (tester) async {
    await open(tester);

    expect(find.byType(CategoriesPane), findsNothing);
    expect(find.byType(PreviewPane), findsNothing);
    expect(tester.getSize(find.byType(ChannelListPane)).width, 390);
    expect(find.text('Zebra TV'), findsOneWidget);
    expect(
      tester.widget<FocusableSurface>(categoryButton()).semanticLabel,
      'Category: All channels, 4 channels',
    );

    await tester.tap(categoryButton());
    await _settle(tester);
    expect(find.byType(AppBottomSheet), findsOneWidget);
    expect(find.byType(CategoriesPane), findsOneWidget);

    // The filter keeps the categories that match.
    await tester.enterText(
      find.descendant(
        of: find.byType(AppBottomSheet),
        matching: find.byType(EditableText),
      ),
      'spo',
    );
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byType(CategoriesPane),
        matching: find.text('All channels'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(CategoriesPane),
        matching: find.text('Sports'),
      ),
    );
    await _settle(tester);
    expect(find.byType(AppBottomSheet), findsNothing);
    expect(
      tester.widget<FocusableSurface>(categoryButton()).semanticLabel,
      'Category: Sports, 3 channels',
    );
    expect(find.text('Zebra TV'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // In a tablet's window: the player's own phone layout is another
  // step's (ADR-068), and what is tested here is Live TV's.
  testWidgets('a press on a channel plays it full screen; back on Live TV '
      'the stream stops', (tester) async {
    final (live, app) = await open(tester, size: const Size(800, 1280));

    await tester.tap(find.text('Arena Sports 1'));
    await _settle(tester);
    expect(app.location, '/player');
    expect(live.rig.coordinator.current?.name, 'Arena Sports 1');

    app.router.pop();
    await _settle(tester);
    expect(app.location, AppDestination.liveTv.path);
    expect(live.rig.coordinator.current, isNull);
  });

  testWidgets("a finger held on a row opens the channel's menu; a mouse "
      'held down is still a click', (tester) async {
    final (live, app) = await open(tester, size: const Size(800, 1280));

    await tester.longPress(find.text('Velocity Motors'));
    await _settle(tester);
    expect(find.text('Hide channel'), findsOneWidget);
    expect(find.text('Rename…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.text('Hide channel'), findsNothing);

    await tester.longPress(
      find.text('Velocity Motors'),
      kind: PointerDeviceKind.mouse,
    );
    await _settle(tester);
    expect(find.text('Hide channel'), findsNothing);
    expect(app.location, '/player');
    await live.rig.coordinator.stop();
    await _settle(tester);
  });

  testWidgets('a tablet held upright: the categories beside the list, no '
      'preview, and a press plays full screen', (tester) async {
    final (live, app) = await open(tester, size: const Size(800, 1280));

    expect(find.byType(CategoriesPane), findsOneWidget);
    expect(find.byType(PreviewPane), findsNothing);
    expect(categoryButton(), findsNothing);

    await tester.tap(find.text('Arena Sports 2'));
    await _settle(tester);
    expect(app.location, '/player');
    await live.rig.coordinator.stop();
    await _settle(tester);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
