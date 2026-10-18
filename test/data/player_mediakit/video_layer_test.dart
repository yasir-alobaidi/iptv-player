import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/player_mediakit/video_layer.dart';

/// MainActivity's VideoLayer over its channel (T1, ADR-035 §1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bijou/video_layer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  // The review before dev went to main (2026-10-18): the layer kept the
  // TV awake from a film's start to its end, paused or not; media_kit's
  // Video lets the TV sleep while a film is paused.
  test('keepAwake tells the layer whether the screen stays on', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final layer = VideoLayer();

    await layer.keepAwake(awake: false);
    await layer.keepAwake(awake: true);

    expect(calls.map((c) => (c.method, c.arguments)), [
      ('keepAwake', false),
      ('keepAwake', true),
    ]);
  });

  test('a layer that can not answer is no error', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'gone'),
    );
    final layer = VideoLayer();

    await expectLater(layer.keepAwake(awake: false), completes);
    await expectLater(layer.show(), completion(isNull));
  });
}
