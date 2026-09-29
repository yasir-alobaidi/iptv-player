// Phase 6's exit measurement for search (plan step 8): the fake panel's
// `large` catalogue synced (50,000 channels, 30,000 movies, 3,000 series)
// and its guide imported, then Ctrl+K and several searches typed a letter
// at a time at a person's pace, each one cleared before the next. The
// frames the typing and the results cost are measured (docs/06: none
// over 16 ms), and the UI isolate's longest pause. The queries run on the
// database isolate; their own times are the search benchmark's.
//
// Meaningful in profile mode, on the real display:
//
//     flutter drive --profile -d linux \
//       --driver=test_driver/integration_test.dart \
//       --target=integration_test/search_typing_test.dart
//
// which writes the numbers to build/integration_response_data.json too.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';

import 'support/fake_panel.dart';
import 'support/frames.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

/// What is typed: short words that match much (one and two letters reach
/// only the channels, movies and series), whole names, and one with no
/// match.
const _texts = ['a', 'the', 'ironwood arena', 'compass', 'harbour', 'xq'];

/// A person's pace, about 8 keys a second.
const _keyGap = 120;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('typing into search on the large catalogue', (tester) async {
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    // The typing reaches the field through the test's text input.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);

    final panel = (await tester.runAsync(
      () => FakePanel.start(profile: 'large'),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    final app = (await tester.runAsync(
      () => PanelApp.open(panel, video: false),
    ))!;
    addTearDown(() => tester.runAsync(app.close));
    final imported = await tester.runAsync(
      () => app.container
          .read(guideImportServiceProvider)
          .importGuide(app.sourceId),
    );
    expect(imported!.isOk, isTrue, reason: '${imported.failureOrNull}');

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
    await waitReal(tester, 1500);

    final overlay = find.byType(SearchOverlay);
    final field = find.descendant(
      of: overlay,
      matching: find.byType(EditableText),
    );
    await k.chord(LogicalKeyboardKey.keyK);
    await k.waitFor(field);
    await k.waitUntil(() => k.focusIsOn(field), 'the focus in the field');

    /// What the overlay shows: its group headings, or its no-result line —
    /// so a run that measured an empty panel can't pass.
    List<String> shown() => [
      for (final heading in [
        'CHANNELS',
        'ON TV NOW & UPCOMING',
        'MOVIES',
        'SERIES',
      ])
        if (find
            .descendant(of: overlay, matching: find.text(heading))
            .evaluate()
            .isNotEmpty)
          heading,
      if (find
          .descendant(of: overlay, matching: find.textContaining('No results'))
          .evaluate()
          .isNotEmpty)
        'no results',
    ];

    final results = <String, FrameStats>{};
    final answers = <String, List<String>>{};
    for (final text in _texts) {
      results[text] = await measureFrames(tester, binding, () async {
        for (var i = 1; i <= text.length; i++) {
          await tester.enterText(field, text.substring(0, i));
          await waitReal(tester, _keyGap);
        }
        // The last search's answer and its rows.
        await waitReal(tester, 800);
      });
      expect(
        tester.widget<EditableText>(field).controller.text,
        text,
        reason: 'the typing landed',
      );
      answers[text] = shown();
      expect(answers[text], isNotEmpty, reason: '"$text" answered');
      await tester.enterText(field, '');
      await waitReal(tester, 400);
    }
    final all = await measureFrames(tester, binding, () async {
      for (final text in _texts) {
        for (var i = 1; i <= text.length; i++) {
          await tester.enterText(field, text.substring(0, i));
          await waitReal(tester, _keyGap);
        }
        await waitReal(tester, 300);
        await tester.enterText(field, '');
        await waitReal(tester, 200);
      }
    });

    expect(answers['xq'], ['no results']);
    binding.reportData = {
      'search_typing': {
        for (final MapEntry(:key, :value) in results.entries)
          key: {...value.toJson(), 'shown': answers[key]!},
        'all': all.toJson(),
      },
    };
    debugPrint('search typing, all: $all');
    for (final MapEntry(:key, :value) in results.entries) {
      debugPrint('search typing, "$key" (${answers[key]!.join(', ')}): $value');
    }
    await k.press(LogicalKeyboardKey.escape);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
