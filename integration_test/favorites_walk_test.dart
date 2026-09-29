// Phase 6's exit walk (plan step 8), keys only, on the real app, database,
// sync and player against the fake panel:
//
// Ctrl+K → a channel's name → Enter plays it full screen → Esc; Live TV →
// F on the first three channels → Favorites → New group "Sport" → Alt+↑
// takes two of them into it → the app closed and opened again on the
// same database, and the source synced again: the order and the group are
// still there → Live TV → Favorites → Sport → Enter on its first channel,
// full screen → ↓ zaps through the group in its order, and round.
//
// The walk's last leg — hide a channel, gone from Live TV, the Guide,
// Search and Home, back from Settings — is hiding_walk_test.dart.
//
// The test reads state to check it; everything it does goes through the
// keyboard. Plays only with the stream samples (CI makes them).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/favorites/data/favorites_providers.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/categories_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets('search and play; favorites and a group, kept through a '
      'restart and a re-sync; the group zapped in its order', (tester) async {
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    final panel = (await tester.runAsync(
      () => FakePanel.start(streams: streamsAvailable),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    var app = (await tester.runAsync(
      () => PanelApp.open(panel, video: video),
    ))!;
    addTearDown(() => tester.runAsync(() => app.close()));
    final id = app.sourceId;

    // The first three channels in number order, where Live TV's list
    // starts (the ones with stream samples).
    final first = (await tester.runAsync(
      () => app.container
          .read(channelRepositoryProvider)
          .range(ChannelQuery(sourceId: id), 0, 3),
    ))!.valueOrNull!;
    final [one, two, three] = first;

    Future<Keys> show() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app.container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      final k = Keys(tester)..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return k;
    }

    var k = await show();
    Finder row(ChannelItem c) =>
        find.byWidgetPredicate((w) => w is ChannelRow && w.name == c.name);

    /// The favorites in their order: each group's, then those in none.
    Future<Map<String, List<String>>> favorites() async {
      final container = app.container;
      final channels = container.read(channelRepositoryProvider);
      final groups = await container
          .read(favoritesRepositoryProvider)
          .watchGroups(id)
          .first;
      final all = (await channels.range(
        ChannelQuery(sourceId: id, filter: const FavoriteChannels()),
        0,
        100,
      )).valueOrNull!;
      return {
        for (final group in groups)
          group.name: [
            for (final c in all)
              if (c.favoriteGroupId == group.id) c.name,
          ],
        'none': [
          for (final c in all)
            if (c.favoriteGroupId == null) c.name,
        ],
      };
    }

    // ── Ctrl+K → the first channel's name → Enter: full screen → Esc.
    final overlay = find.byType(SearchOverlay);
    final field = find.descendant(
      of: overlay,
      matching: find.byType(EditableText),
    );
    await k.waitFor(find.text('Start watching'), seconds: 30);
    await k.chord(LogicalKeyboardKey.keyK);
    await k.waitFor(field);
    await k.typeIn(field, one.name);
    await k.waitFor(
      find.descendant(of: overlay, matching: find.text('CHANNELS')),
      seconds: 10,
    );
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.byType(PlayerScreen));
    final coordinator = app.container.read(playbackCoordinatorProvider);
    expect(coordinator.current?.id, one.id);
    if (streamsAvailable) {
      await k.waitUntil(
        () => coordinator.state is PlaybackPlaying,
        'the channel playing (${coordinator.state})',
        seconds: 30,
      );
    }
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(() => app.location == '/', 'Home (${app.location})');
    await k.waitUntil(() => coordinator.current == null, 'the stream stopped');

    // ── Ctrl+2: Live TV → All channels → F on the first three.
    await k.chord(LogicalKeyboardKey.digit2);
    await k.waitFor(find.text('All channels'));
    await k.waitUntil(
      () => k.focusIsOn(find.text('Favorites').first),
      'the focus on Favorites',
    );
    await k.press(LogicalKeyboardKey.arrowDown);
    await k.press(LogicalKeyboardKey.enter);
    ChannelItem? selected() =>
        app.container.read(liveTvControllerProvider)?.selected;
    await k.waitUntil(
      () => selected()?.id == one.id,
      'the first row focused (${k.focusedLabel()})',
    );
    for (final channel in first) {
      await k.waitUntil(
        () => selected()?.id == channel.id,
        '${channel.name} focused',
      );
      await k.press(LogicalKeyboardKey.keyF);
      await k.press(LogicalKeyboardKey.arrowDown);
    }
    await k.waitUntil(
      () async => (await favorites())['none']!.length == 3,
      'three favorites',
    );
    expect((await tester.runAsync(favorites))!['none'], [
      one.name,
      two.name,
      three.name,
    ]);

    // ── Ctrl+6: Favorites → New group "Sport".
    await k.chord(LogicalKeyboardKey.digit6);
    await k.waitFor(row(three));
    await k.tabTo(find.text('New group'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(
      find.text(
        'Groups keep your favorite channels in the '
        'order you set.',
      ),
    );
    await k.type('Sport', into: 'Name');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('SPORT'));
    await k.waitFor(find.text('UNGROUPED'));

    // ── Into the list (one stop), ↓ to the first channel, Alt+↑ into the
    // group above; ↓ to the next one, Alt+↑ again.
    await k.tabTo(find.text('SPORT'));
    for (final channel in [one, two]) {
      for (var i = 0; i < 6 && !k.focusIsOn(row(channel)); i++) {
        await k.press(LogicalKeyboardKey.arrowDown);
      }
      expect(k.focusIsOn(row(channel)), isTrue, reason: channel.name);
      await k.alt(LogicalKeyboardKey.arrowUp);
      await k.waitUntil(
        () async => (await favorites())['Sport']!.contains(channel.name),
        '${channel.name} in Sport',
      );
      expect(k.focusIsOn(row(channel)), isTrue, reason: 'the focus follows');
    }
    final arranged = {
      'Sport': [one.name, two.name],
      'none': [three.name],
    };
    expect(await tester.runAsync(favorites), arranged);

    // ── Closed and opened again on the same database, then synced again.
    await tester.pumpWidget(const SizedBox.shrink());
    app = (await tester.runAsync(app.restart))!;
    final resynced = await tester.runAsync(
      () => app.container.read(syncServiceProvider).sync(id),
    );
    expect(resynced!.isOk, isTrue, reason: '${resynced.failureOrNull}');
    expect(await tester.runAsync(favorites), arranged);
    k = await show();
    await k.chord(LogicalKeyboardKey.digit6);
    await k.waitFor(find.text('SPORT'));
    await k.waitFor(row(three));
    final shown = [
      for (final r in tester.widgetList<ChannelRow>(find.byType(ChannelRow)))
        r.name,
    ];
    expect(shown, [one.name, two.name, three.name]);

    // ── Ctrl+2: Live TV → Favorites → Sport → Enter: its first channel
    // full screen; ↓ zaps through the group in its order, and round.
    await k.chord(LogicalKeyboardKey.digit2);
    final sport = find.descendant(
      of: find.byType(CategoriesPane),
      matching: find.text('Sport'),
    );
    await k.waitFor(sport);
    await k.waitUntil(
      () => k.focusIsOn(find.text('Favorites').first),
      'the focus on Favorites',
    );
    await k.press(LogicalKeyboardKey.arrowDown);
    expect(k.focusIsOn(sport), isTrue);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitUntil(
      () => selected()?.id == one.id,
      "the group's first channel (${k.focusedLabel()})",
    );
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.byType(PlayerScreen));
    final player = app.container.read(playbackCoordinatorProvider);
    Future<void> playing(ChannelItem channel) => k.waitUntil(
      () => player.current?.id == channel.id,
      'playing ${channel.name} (${player.current?.name})',
    );
    await playing(one);
    await k.press(LogicalKeyboardKey.arrowDown);
    await playing(two);
    // The group has two: ↓ goes round to its first.
    await k.press(LogicalKeyboardKey.arrowDown);
    await playing(one);
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(
      () => app.location == AppDestination.liveTv.path,
      'back on Live TV (${app.location})',
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
