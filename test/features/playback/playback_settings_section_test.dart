import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/presentation/playback_settings.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../../app/app_harness.dart';
import '../casting/support/cast_ui_harness.dart';
import '../live_tv/live_tv_fakes.dart';

void main() {
  Future<LiveTvFakes> open(
    WidgetTester tester, {
    FormFactor formFactor = FormFactor.desktop,
    Size? size,
  }) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      size: size ?? const Size(1440, 900),
      overrides: [
        ...live.overrides,
        formFactorProvider.overrideWithValue(formFactor),
      ],
    );
    await _settle(tester);
    await tester.tap(find.text('Playback').first);
    await _settle(tester);
    return live;
  }

  testWidgets("a preset chosen here is the next stream's preset", (
    tester,
  ) async {
    final live = await open(tester);
    expect(find.byType(SettingsPanel), findsOneWidget);
    expect(find.textContaining('About 8 s of buffer'), findsOneWidget);

    await tester.tap(find.text('Stable'));
    await _settle(tester);
    expect(find.textContaining('About 20 s of buffer'), findsOneWidget);

    final stored = await tester.runAsync(
      () => live.db.settingsDao.read('playback.settings'),
    );
    expect(stored, contains('"preset":"stable"'));
  });

  testWidgets('languages are saved as typed; Deinterlacing Off', (
    tester,
  ) async {
    final live = await open(tester);

    await tester.enterText(find.byType(EditableText).first, 'AR, en');
    await _settle(tester);
    // Deinterlacing's Off: Hardware decoding's is the second.
    await tester.tap(find.text('Off').first);
    await _settle(tester);

    final stored = await tester.runAsync(
      () => live.db.settingsDao.read('playback.settings'),
    );
    expect(stored, contains('"audio":["ar","en"]'));
    expect(stored, contains('"deinterlace":"off"'));
  });

  testWidgets('Hardware decoding: Automatic until Off is chosen, saved at '
      "once, and the next stream's request carries it", (tester) async {
    final live = await open(tester);
    expect(find.text('Hardware decoding'), findsOneWidget);
    expect(
      find.textContaining('a way round a faulty graphics driver'),
      findsOneWidget,
    );

    await tester.tap(find.text('Off').last);
    await _settle(tester);

    final stored = await tester.runAsync(
      () => live.db.settingsDao.read('playback.settings'),
    );
    expect(stored, contains('"hwdec":"off"'));

    await tester.tap(find.text('Automatic'));
    await _settle(tester);
    final again = await tester.runAsync(
      () => live.db.settingsDao.read('playback.settings'),
    );
    expect(again, contains('"hwdec":"auto"'));
  });

  testWidgets("Picture quality (the PC's): Standard until High is chosen "
      "from the keyboard, saved at once, and the next stream's request "
      'carries it', (tester) async {
    final live = await open(tester);
    expect(find.text('Picture quality'), findsOneWidget);
    expect(find.textContaining('sharper filters'), findsOneWidget);
    PlaybackSettings settings() => ProviderScope.containerOf(
      tester.element(find.byType(PlaybackSettingsSection)),
    ).read(playbackSettingsControllerProvider);
    expect(settings().pictureQuality, PictureQuality.standard);

    Future<String?> stored() => tester.runAsync<String?>(
      () => live.db.settingsDao.read('playback.settings'),
    );
    Future<void> tabTo(String label, {bool back = false}) async {
      for (var i = 0; i < 40; i++) {
        if (focusedLabelOf(tester) == label) return;
        if (back) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        if (back) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
      }
      fail('Tab never reached "$label" (on ${focusedLabelOf(tester)})');
    }

    Focus.of(tester.element(find.text('Automatic'))).requestFocus();
    await tester.pump();
    await tabTo('High');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);

    expect(await stored(), contains('"quality":"high"'));
    const stream = ResolvedStream(url: 'u', maxConnections: 1);
    expect(settings().request(stream).pictureQuality, PictureQuality.high);

    await tabTo('Standard', back: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _settle(tester);
    expect(await stored(), contains('"quality":"standard"'));
    expect(settings().request(stream).pictureQuality, PictureQuality.standard);
  });

  testWidgets('a TV has no Picture quality: its picture never goes '
      "through the player's scaler", (tester) async {
    await open(tester, formFactor: FormFactor.tv, size: const Size(960, 540));
    expect(find.text('Buffering'), findsOneWidget);
    expect(find.text('Picture quality'), findsNothing);
    expect(find.text('High'), findsNothing);
  });

  testWidgets("the source's live format is saved on the source", (
    tester,
  ) async {
    final live = await open(tester);
    expect(find.text('Live format · Northwind TV'), findsOneWidget);

    await tester.tap(find.text('HLS'));
    await _settle(tester);

    final (id, draft) = live.fakes.sources.updated.single;
    expect(id, 'src-1');
    expect(draft.liveFormat, LiveFormat.hls);
    expect(draft.password, isNull, reason: 'the stored one is kept');
  });

  group("Match frame rate: a TV's (ADR-035)", () {
    /// The row: its name and line, and its Off and On.
    Finder matchFrameRate() => find
        .ancestor(of: find.text('Match frame rate'), matching: find.byType(Row))
        .first;

    testWidgets('on a TV: Off until On is chosen, saved at once; its line '
        "says the screen goes dark, and that it follows the TV's own "
        'setting (ADR-042)', (tester) async {
      final live = await open(tester, formFactor: FormFactor.tv);
      expect(find.text('Match frame rate'), findsOneWidget);
      expect(
        find.textContaining(
          'The screen goes dark for a second or two when such a film '
          'starts and ends.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining("the TV's own Match content frame rate setting"),
        findsOneWidget,
      );
      final row = matchFrameRate();
      expect(row, findsOneWidget);
      expect(
        tester
            .widget<SegmentedControl<bool>>(
              find.descendant(
                of: row,
                matching: find.byType(SegmentedControl<bool>),
              ),
            )
            .value,
        isFalse,
      );

      await tester.tap(find.descendant(of: row, matching: find.text('On')));
      await _settle(tester);
      final stored = await tester.runAsync(
        () => live.db.settingsDao.read('playback.settings'),
      );
      expect(stored, contains('"matchRate":"on"'));

      await tester.tap(find.descendant(of: row, matching: find.text('Off')));
      await _settle(tester);
      final again = await tester.runAsync(
        () => live.db.settingsDao.read('playback.settings'),
      );
      expect(again, contains('"matchRate":"off"'));
    });

    testWidgets('the remote reaches it: Right into the page and along '
        'Buffering, Down to the row, Right to On, OK', (tester) async {
      final live = await open(tester, formFactor: FormFactor.tv);
      final control = tester.widget<SegmentedControl<bool>>(
        find.descendant(
          of: matchFrameRate(),
          matching: find.byType(SegmentedControl<bool>),
        ),
      );

      /// The focused segment's label, when it is one of the row's.
      String? onRow() {
        final context = FocusManager.instance.primaryFocus?.context;
        if (context == null) return null;
        if (!identical(
          context.findAncestorWidgetOfExactType<SegmentedControl<bool>>(),
          control,
        )) {
          return null;
        }
        return focusedLabelOf(tester);
      }

      // Into the page, on Buffering's Low latency, and along it.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await _settle(tester);
      }
      expect(focusedLabelOf(tester), 'Stable');
      for (var i = 0; i < 4 && onRow() == null; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await _settle(tester);
      }
      expect(onRow(), isNotNull, reason: 'Down reaches the row');
      if (onRow() != 'On') {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await _settle(tester);
      }
      expect(onRow(), 'On');

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _settle(tester);
      final stored = await tester.runAsync(
        () => live.db.settingsDao.read('playback.settings'),
      );
      expect(stored, contains('"matchRate":"on"'));
    });

    testWidgets('the desktop has no such row: its display is never '
        'switched', (tester) async {
      await open(tester);
      expect(find.text('Match frame rate'), findsNothing);
      expect(find.text('Hardware decoding'), findsOneWidget);
    });

    testWidgets('a TV has no Hardware decoding row (ADR-025)', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      expect(find.text('Hardware decoding'), findsNothing);
    });
  });

  group('Subtitle size (ADR-038), on a TV and a desktop', () {
    /// The row: its name and line, and its three sizes.
    Finder subtitleSize() => find
        .ancestor(of: find.text('Subtitle size'), matching: find.byType(Row))
        .first;

    SegmentedControl<SubtitleSize> control(WidgetTester tester) =>
        tester.widget<SegmentedControl<SubtitleSize>>(
          find.descendant(
            of: subtitleSize(),
            matching: find.byType(SegmentedControl<SubtitleSize>),
          ),
        );

    PlaybackSettings settings(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(PlaybackSettingsSection)),
    ).read(playbackSettingsControllerProvider);

    Future<String?> stored(WidgetTester tester, LiveTvFakes live) => tester
        .runAsync<String?>(() => live.db.settingsDao.read('playback.settings'));

    /// The focused segment's label, when it is one of the row's.
    String? onRow(WidgetTester tester) {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return null;
      if (!identical(
        context.findAncestorWidgetOfExactType<SegmentedControl<SubtitleSize>>(),
        control(tester),
      )) {
        return null;
      }
      return focusedLabelOf(tester);
    }

    testWidgets('the desktop: Medium until another is chosen, each saved at '
        'once; its line says it shows at once', (tester) async {
      final live = await open(tester);
      expect(find.text('Subtitle size'), findsOneWidget);
      expect(
        find.textContaining('Changes show at once, on what is playing too.'),
        findsOneWidget,
      );
      expect(control(tester).value, SubtitleSize.medium);
      expect(settings(tester).subtitleSize, SubtitleSize.medium);

      await tester.tap(
        find.descendant(of: subtitleSize(), matching: find.text('Large')),
      );
      await _settle(tester);
      expect(settings(tester).subtitleSize, SubtitleSize.large);
      expect(control(tester).value, SubtitleSize.large);
      expect(await stored(tester, live), contains('"subtitleSize":"large"'));

      await tester.tap(
        find.descendant(of: subtitleSize(), matching: find.text('Small')),
      );
      await _settle(tester);
      expect(await stored(tester, live), contains('"subtitleSize":"small"'));
    });

    testWidgets('the keyboard reaches it: Tab along the page to Large, '
        'Enter', (tester) async {
      final live = await open(tester);
      Focus.of(tester.element(find.text('Automatic'))).requestFocus();
      await tester.pump();
      for (var i = 0; i < 40 && onRow(tester) != 'Large'; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(onRow(tester), 'Large', reason: 'Tab reaches the row');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(settings(tester).subtitleSize, SubtitleSize.large);
      expect(await stored(tester, live), contains('"subtitleSize":"large"'));
    });

    testWidgets('a TV has it too: the remote reaches it, Down from '
        'Buffering, Right to Large, OK', (tester) async {
      final live = await open(tester, formFactor: FormFactor.tv);
      expect(find.text('Subtitle size'), findsOneWidget);
      expect(control(tester).value, SubtitleSize.medium);

      // Into the page, on Buffering's Low latency.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await _settle(tester);
      }
      expect(focusedLabelOf(tester), 'Stable');
      for (var i = 0; i < 8 && onRow(tester) == null; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await _settle(tester);
      }
      expect(onRow(tester), isNotNull, reason: 'Down reaches the row');
      for (var i = 0; i < 3 && onRow(tester) != 'Large'; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await _settle(tester);
      }
      expect(onRow(tester), 'Large');

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _settle(tester);
      expect(settings(tester).subtitleSize, SubtitleSize.large);
      expect(await stored(tester, live), contains('"subtitleSize":"large"'));
    });
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
