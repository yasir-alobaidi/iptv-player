import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/player_mediakit/layer_picture.dart';

/// The picture's layer under a channel's preview and its full screen (T2,
/// ADR-045): the one on screen places the layer, in physical pixels, and
/// the preview takes it back when the player's page closes over it.
void main() {
  /// Every place told, in order.
  late List<Rect> told;

  setUp(() => told = []);

  Widget picture(List<Rect> into) =>
      LayerPicture(onPlaced: into.add, child: const SizedBox.expand());

  /// A preview of 320×180 logical pixels at (40, 60).
  Widget preview({List<Rect>? into}) => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 40,
            top: 60,
            width: 320,
            height: 180,
            child: picture(into ?? told),
          ),
        ],
      ),
    ),
  );

  testWidgets('tells its place in physical pixels after its first frame, '
      'and again only when it moves', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(preview());
    await tester.pump();
    expect(told, [const Rect.fromLTWH(80, 120, 640, 360)]);

    await tester.pump();
    await tester.pump();
    expect(told, hasLength(1), reason: 'the same place is told once');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 400,
                height: 300,
                child: picture(told),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(told.last, const Rect.fromLTWH(0, 0, 800, 600));
  });

  testWidgets("the player's page over it places the layer; closed, the "
      'preview takes it back', (tester) async {
    final full = <Rect>[];
    await tester.pumpWidget(preview());
    await tester.pump();
    expect(told, hasLength(1));
    final previewPlace = told.single;

    final navigator = tester.state<NavigatorState>(find.byType(Navigator))
      ..push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => picture(full),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final screen = tester.view.physicalSize;
    expect(full, [Offset.zero & screen]);
    expect(told, hasLength(1), reason: 'covered: the preview says nothing');

    navigator.pop();
    await tester.pump();
    await tester.pump();
    expect(told, [previewPlace, previewPlace], reason: 'told anew');
  });

  testWidgets('says nothing while its destination is kept off stage', (
    tester,
  ) async {
    await tester.pumpWidget(TickerMode(enabled: false, child: preview()));
    await tester.pump();
    await tester.pump();
    expect(told, isEmpty);

    await tester.pumpWidget(TickerMode(enabled: true, child: preview()));
    await tester.pump();
    expect(told, hasLength(1));
  });

  testWidgets('clears what the app painted under it, so the layer shows', (
    tester,
  ) async {
    await tester.pumpWidget(preview());
    final hole = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is LayerHole,
    );
    expect(hole, findsOneWidget);
    expect(
      hole,
      paints..something((method, arguments) {
        if (method != #drawRect) return false;
        final paint = arguments[1] as Paint;
        return paint.blendMode == BlendMode.clear;
      }),
    );
  });
}
