import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../../app/app_harness.dart';
import '../casting/support/cast_ui_harness.dart';
import '../live_tv/live_tv_fakes.dart';

void main() {
  Future<LiveTvFakes> open(
    WidgetTester tester, {
    FormFactor formFactor = FormFactor.desktop,
  }) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
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

    testWidgets('on a TV: On until Off is chosen, saved at once; its line '
        "says the screen goes dark, and that it follows the TV's own "
        'setting', (tester) async {
      final live = await open(tester, formFactor: FormFactor.tv);
      expect(find.text('Match frame rate'), findsOneWidget);
      expect(
        find.textContaining(
          'The screen goes dark for a second or two when a film starts '
          'and ends.',
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
        isTrue,
      );

      await tester.tap(find.descendant(of: row, matching: find.text('Off')));
      await _settle(tester);
      final stored = await tester.runAsync(
        () => live.db.settingsDao.read('playback.settings'),
      );
      expect(stored, contains('"matchFps":"off"'));

      await tester.tap(find.descendant(of: row, matching: find.text('On')));
      await _settle(tester);
      final again = await tester.runAsync(
        () => live.db.settingsDao.read('playback.settings'),
      );
      expect(again, contains('"matchFps":"on"'));
    });

    testWidgets('the remote reaches it: Right into the page and along '
        'Buffering, Down to the row, Left to Off, OK', (tester) async {
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
      if (onRow() != 'Off') {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await _settle(tester);
      }
      expect(onRow(), 'Off');

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _settle(tester);
      final stored = await tester.runAsync(
        () => live.db.settingsDao.read('playback.settings'),
      );
      expect(stored, contains('"matchFps":"off"'));
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
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
