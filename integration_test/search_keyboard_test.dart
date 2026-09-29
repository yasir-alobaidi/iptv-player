// Phase 6 step 4's walk, keys only, on the real app, database, sync and
// player against the fake panel's `large` catalogue (50,000 channels,
// 30,000 movies, 3,000 series): Ctrl+K → a movie's name → Tab into
// Movies → Enter opens its page; `/` → a channel's name → Enter plays it
// full screen → Esc; Ctrl+K → a word → Show all in Movies → the grid,
// filtered by it; Ctrl+K again → the recent searches.
//
// Plays a channel only with the stream samples (CI makes them); without,
// it checks the player was asked to.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets('search the large catalogue by keyboard: a movie, a channel, '
      'Show all', (tester) async {
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    final panel = (await tester.runAsync(
      () => FakePanel.start(profile: 'large', streams: streamsAvailable),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    final app = (await tester.runAsync(
      () => PanelApp.open(panel, video: video),
    ))!;
    addTearDown(() => tester.runAsync(app.close));

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
    final coordinator = app.container.read(playbackCoordinatorProvider);

    final movie = (await tester.runAsync(
      () => app.container
          .read(movieRepositoryProvider)
          .byRemoteKey(app.sourceId, '$firstMovieId'),
    ))!.valueOrNull!;
    final channel = (await tester.runAsync(
      () => app.container
          .read(channelRepositoryProvider)
          .range(ChannelQuery(sourceId: app.sourceId), 0, 1),
    ))!.valueOrNull!.single;

    final overlay = find.byType(SearchOverlay);
    final field = find.descendant(
      of: overlay,
      matching: find.byType(EditableText),
    );

    /// The name on the row the cursor is on (the one with the Enter
    /// keycap).
    String? cursor() {
      for (final element
          in find
              .ancestor(
                of: find.descendant(
                  of: overlay,
                  matching: find.widgetWithText(Kbd, 'Enter'),
                ),
                matching: find.byType(Row),
              )
              .evaluate()) {
        final texts = find
            .descendant(
              of: find.byWidget(element.widget),
              matching: find.byType(Text),
            )
            .evaluate()
            .map((e) => e.widget as Text)
            .map((t) => t.data ?? t.textSpan?.toPlainText())
            .whereType<String>()
            .where((t) => t != 'Enter' && t.length > 2);
        if (texts.isNotEmpty) return texts.first;
      }
      return null;
    }

    Future<void> search(String text, {required String heading}) async {
      await k.waitFor(field);
      await k.typeIn(field, text);
      await k.waitFor(
        find.descendant(of: overlay, matching: find.text(heading)),
        seconds: 10,
      );
    }

    // 1. Ctrl+K → the movie's name → Movies → Enter: its page.
    await k.chord(LogicalKeyboardKey.keyK);
    await search(movie.name, heading: 'MOVIES');
    for (var i = 0; i < 3 && cursor() != movie.name; i++) {
      await k.press(LogicalKeyboardKey.tab);
    }
    expect(cursor(), movie.name);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitUntil(
      () => app.location.startsWith('/movies/'),
      "a movie's page (${app.location})",
    );
    expect(overlay, findsNothing, reason: 'search closes on any action');
    await k.waitFor(find.text(movie.name));

    // 2. `/` → the channel → Enter plays it full screen → Esc.
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(
      () => app.location == AppDestination.movies.path,
      'back on Movies (${app.location})',
    );
    await k.press(LogicalKeyboardKey.slash);
    await search(channel.name, heading: 'CHANNELS');
    expect(cursor(), channel.name);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitUntil(
      () => app.location == '/player',
      'the player (${app.location})',
    );
    expect(coordinator.current?.id, channel.id);
    if (streamsAvailable) {
      await k.waitUntil(
        () => coordinator.state is PlaybackPlaying,
        'the channel playing (${coordinator.state})',
        seconds: 30,
      );
    }
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(
      () => app.location == AppDestination.movies.path,
      'back where search was opened (${app.location})',
    );
    await k.waitUntil(
      () => coordinator.current == null,
      'the stream stopped (${coordinator.state})',
    );

    // 3. Ctrl+K → a word of the movie's name → Show all in Movies.
    // A word of it, which many titles share (its name may be written
    // release-style, "Compass.of.the.Iron.Meridian.2022…").
    final word = RegExp('[A-Za-z]{4,}').firstMatch(movie.name)![0]!;
    await k.chord(LogicalKeyboardKey.keyK);
    await search(word, heading: 'MOVIES');
    // Down through the channels that match, if any, to the movies' end.
    for (var i = 0; i < 20 && cursor() != 'Show all in Movies'; i++) {
      await k.press(LogicalKeyboardKey.arrowDown);
    }
    expect(cursor(), 'Show all in Movies');
    await k.press(LogicalKeyboardKey.enter);
    await k.waitUntil(
      () =>
          app.location == AppDestination.movies.path &&
          app.container
                  .read(catalogueControllerProvider(CatalogueKind.movie))
                  ?.text ==
              word,
      'Movies filtered by "$word" (${app.location})',
    );
    await k.waitFor(
      find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == word,
      ),
    );

    // 4. Ctrl+K: what was opened is in the recent searches.
    await k.chord(LogicalKeyboardKey.keyK);
    await k.waitFor(find.text('RECENT SEARCHES'));
    for (final text in [word, channel.name, movie.name]) {
      expect(
        find.descendant(of: overlay, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(() => overlay.evaluate().isEmpty, 'search closed');
  });
}
