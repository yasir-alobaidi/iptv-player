import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';
import '../settings/appearance_fakes.dart';

/// ADR-068: Favorites on a phone held upright — the tabs, then New group
/// under them, the channels in one column without their time left, and
/// a finger's way to reorder: the grip, or the row's menu's Move up and
/// Move down (a phone has no Alt+↑/↓).
void main() {
  const phone = Size(390, 844);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(() async {
      await live.seed();
      final channels = DbChannelRepository(live.db);
      for (final key in ['203', '900']) {
        final channel = (await channels.byRemoteKey('src-1', key)).valueOrNull!;
        await channels.setFavorite(channel, on: true);
      }
    });
    await pumpApp(
      tester,
      size: phone,
      withAppearance: true,
      initialLocation: AppDestination.favorites.path,
      overrides: [
        ...live.overrides,
        ...sourceShellOverrides,
        ...appearanceOverrides(),
        formFactorProvider.overrideWithValue(FormFactor.mobile),
      ],
    );
    await settle(tester);
  }

  Finder row(String name) => find.byWidgetPredicate(
    (widget) =>
        widget is FocusableSurface &&
        (widget.semanticLabel?.startsWith(name) ?? false),
  );

  testWidgets('one column: New group under the tabs, the rows the width of '
      "the screen, the hint in a phone's words", (tester) async {
    await open(tester);

    final tabs = tester.getRect(find.text('Channels'));
    final newGroup = tester.getRect(findByLabel('New group'));
    expect(newGroup.top, greaterThan(tabs.bottom));
    expect(newGroup.height, greaterThanOrEqualTo(44));
    final zebra = tester.getRect(row('Zebra'));
    expect(zebra.width, greaterThan(phone.width - 64));
    expect(find.textContaining('Touch and hold any channel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the row's menu moves a channel up", (tester) async {
    await open(tester);
    expect(
      tester.getRect(row('Zebra')).top,
      greaterThan(tester.getRect(row('Velocity')).top),
    );

    tester.widget<FocusableSurface>(row('Zebra')).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settle(tester);
    expect(find.text('Move down'), findsOneWidget);
    await tester.tap(find.text('Move up'));
    await settle(tester);

    expect(
      tester.getRect(row('Zebra')).top,
      lessThan(tester.getRect(row('Velocity')).top),
    );
    expect(tester.takeException(), isNull);
  });
}
