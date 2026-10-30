import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/picture_in_picture.dart';
import 'package:iptv_player/data/platform/android_picture_in_picture.dart';
import 'package:logger/logger.dart';

/// A phone's small window over `bijou/pip` (PictureInPicture.kt): what the
/// player wishes goes as the activity reads it, what the activity says
/// becomes events, and what can't be read or sent is logged, never thrown
/// (hard rule 1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bijou/pip');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MemoryOutput logged;
  late List<MethodCall> calls;

  List<String> logLines() => [
    for (final event in logged.buffer) ...event.lines,
  ];

  AndroidPictureInPicture pip({Object? Function(MethodCall call)? answer}) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final reply = answer?.call(call);
      if (reply is Exception) throw reply;
      return reply;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    logged = MemoryOutput();
    return AndroidPictureInPicture(
      log: AppLog(output: logged, secrets: SecretRegistry()),
    );
  }

  Future<void> platformSays(String method, Object? arguments) async {
    final done = Completer<void>();
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  test('a wish goes as the activity reads it; none is off', () async {
    final window = pip();

    await window.allow(
      const PictureInPictureWish(
        size: (1920, 800),
        pauseButton: true,
        paused: true,
      ),
    );
    await window.allow(null);

    expect(calls.map((call) => call.method), ['allow', 'allow']);
    expect(calls.first.arguments, {
      'on': true,
      'width': 1920,
      'height': 800,
      'pauseButton': true,
      'paused': true,
    });
    expect(calls.last.arguments, {
      'on': false,
      'width': null,
      'height': null,
      'pauseButton': false,
      'paused': false,
    });
  });

  test("a wish the activity can't take is logged, not thrown", () async {
    final window = pip(answer: (_) => PlatformException(code: 'nope'));

    await window.allow(const PictureInPictureWish());

    expect(
      logLines(),
      contains(contains("Picture-in-picture couldn't be set")),
    );
  });

  test('what the activity says becomes events, in order', () async {
    final window = pip();
    final seen = <PictureInPictureEvent>[];
    window.events.listen(seen.add);

    await platformSays('changed', {'inPip': true, 'closed': false});
    await platformSays('action', {'name': 'playPause'});
    await platformSays('changed', {'inPip': false, 'closed': false});
    await platformSays('changed', {'inPip': true, 'closed': false});
    await platformSays('changed', {'inPip': false, 'closed': true});
    await pumpEventQueue();

    expect(seen.map((event) => event.runtimeType), [
      PictureInPictureEntered,
      PictureInPicturePlayPause,
      PictureInPictureExpanded,
      PictureInPictureEntered,
      PictureInPictureClosed,
    ]);
  });

  test("what can't be read is passed over", () async {
    final window = pip();
    final seen = <PictureInPictureEvent>[];
    window.events.listen(seen.add);

    await platformSays('changed', null);
    await platformSays('changed', {'inPip': 'yes'});
    await platformSays('action', {'name': 'rewind'});
    await platformSays('somethingElse', {'inPip': true});
    await platformSays('changed', {'inPip': false});
    await pumpEventQueue();

    expect(seen.map((event) => event.runtimeType), [PictureInPictureExpanded]);
    expect(logLines(), contains(contains("A call that couldn't be read")));
  });
}
