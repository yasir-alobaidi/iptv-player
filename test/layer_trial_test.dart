// The throwaway T0 trial screen (lib/main_layer_trial.dart): D-pad focus,
// Hide OSD, and the speed sent to Android.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/main_layer_trial.dart';

const _channel = MethodChannel('bijou/layer_trial');

/// Whether the focused node is the button showing [label].
bool _focusedOn(String label) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  return find
      .descendant(
        of: find.byElementPredicate((element) => identical(element, focused)),
        matching: find.textContaining(label),
      )
      .evaluate()
      .isNotEmpty;
}

/// The test font draws every glyph a full em wide, so the buttons get a
/// wide screen to stay on one row (on the TV they fit in 960 x 540).
Future<void> _pumpTrial(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const LayerTrialApp());
  await tester.pump();
}

double _osdOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.byKey(const ValueKey('trial-osd')))
    .opacity;

void main() {
  testWidgets('arrows move focus along the OSD row', (tester) async {
    await _pumpTrial(tester);
    expect(_focusedOn('Hide OSD'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_focusedOn('Opaque Flutter'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_focusedOn('Pattern speed'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_focusedOn('Opaque Flutter'), isTrue);
  });

  testWidgets('Select hides the OSD; any key only brings it back', (
    tester,
  ) async {
    await _pumpTrial(tester);
    expect(_osdOpacity(tester), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.select, platform: 'android');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_osdOpacity(tester), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_osdOpacity(tester), 1);
    // The key showed the OSD and did nothing else.
    expect(_focusedOn('Hide OSD'), isTrue);
  });

  testWidgets('Pattern speed sends the next speed to Android', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
    await _pumpTrial(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Pattern speed: 4'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls.single.method, 'setSpeed');
    expect(calls.single.arguments, 16);
    expect(find.text('Pattern speed: 16'), findsOneWidget);
  });

  testWidgets("Log state shows Android's reply", (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async =>
          call.method == 'logState' ? 'surfaceView 1920x1080' : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
    await _pumpTrial(tester);
    await tester.tap(find.text('Log state'));
    await tester.pump();
    expect(find.text('Log state: surfaceView 1920x1080'), findsOneWidget);
  });
}
