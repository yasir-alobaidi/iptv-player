import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/data/platform/android_display_modes.dart';
import 'package:logger/logger.dart';

/// The TV's display over `bijou/display` (DisplayModes.kt): what the
/// channel answers becomes the display's facts, and an answer it can't
/// read is a display it can't read, never a throw (hard rule 1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bijou/display');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MemoryOutput logged;
  late List<MethodCall> calls;

  List<String> logLines() => [
    for (final event in logged.buffer) ...event.lines,
  ];

  /// The display, with the channel answering [answer] (or throwing it,
  /// when it is an exception).
  AndroidDisplayModes display(Object? Function(MethodCall call) answer) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final reply = answer(call);
      if (reply is Exception) throw reply;
      return reply;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    logged = MemoryOutput();
    return AndroidDisplayModes(
      log: AppLog(output: logged, secrets: SecretRegistry()),
    );
  }

  Map<String, Object?> mode(int id, int width, int height, num rate) => {
    'id': id,
    'width': width,
    'height': height,
    'refreshRate': rate,
  };

  /// As DisplayModes.kt answers `read` on the Bedroom TV.
  final tv = <String, Object?>{
    'apiLevel': 34,
    'current': mode(1, 3840, 2160, 59.94006),
    'modes': [
      mode(1, 3840, 2160, 59.94006),
      mode(5, 3840, 2160, 23.976025),
      mode(6, 3840, 2160, 24),
    ],
    'alternativeRefreshRates': <Object?>[],
    'matchContentFrameRate': 'always',
  };

  /// The platform telling Dart of a change, as the listener does.
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

  test('is there to ask: a TV', () {
    expect(display((_) => null).available, isTrue);
  });

  group('read', () {
    test("the display's current mode, its modes, the rates it reaches "
        "seamlessly, the TV's own setting and the API level", () async {
      final facts = await display((_) => tv).read();

      expect(calls.single.method, 'read');
      expect(
        facts?.current,
        const DisplayMode(
          id: 1,
          width: 3840,
          height: 2160,
          refreshRate: 59.94006,
        ),
      );
      expect(facts?.modes.map((m) => m.id), [1, 5, 6]);
      expect(facts?.modes.last.refreshRate, 24.0, reason: 'an int is a rate');
      expect(facts?.alternativeRefreshRates, isEmpty);
      expect(facts?.matchContentFrameRate, MatchContentFrameRate.always);
      expect(facts?.apiLevel, 34);
    });

    test("the TV's own setting, each way it can be said", () async {
      for (final (said, meant) in [
        ('always', MatchContentFrameRate.always),
        ('seamlessOnly', MatchContentFrameRate.seamlessOnly),
        ('never', MatchContentFrameRate.never),
        ('unknown', MatchContentFrameRate.unknown),
        ('sometimes', MatchContentFrameRate.unknown),
        (null, MatchContentFrameRate.unknown),
        (2, MatchContentFrameRate.always),
        (1, MatchContentFrameRate.seamlessOnly),
        (0, MatchContentFrameRate.never),
        (-1, MatchContentFrameRate.unknown),
      ]) {
        final facts = await display(
          (_) => {...tv, 'matchContentFrameRate': said},
        ).read();
        expect(facts?.matchContentFrameRate, meant, reason: '$said');
      }
    });

    test('Android 11: no alternative rates and no setting', () async {
      final facts = await display(
        (_) => {
          ...tv,
          'apiLevel': 30,
          'alternativeRefreshRates': null,
          'matchContentFrameRate': 'unknown',
        },
      ).read();

      expect(facts?.alternativeRefreshRates, isEmpty);
      expect(facts?.matchContentFrameRate, MatchContentFrameRate.unknown);
      expect(facts?.apiLevel, 30);
    });

    test('a mode it cannot read is left out; the rest are kept', () async {
      final facts = await display(
        (_) => {
          ...tv,
          'apiLevel': 'thirty-four',
          'modes': [
            mode(1, 3840, 2160, 59.94006),
            null,
            'a mode',
            [1, 2, 3],
            {'id': 2, 'width': 1920, 'height': 1080},
            mode(0, 1920, 1080, 60),
            mode(3, -1920, 1080, 60),
            mode(4, 1920, 0, 60),
            {...mode(7, 1920, 1080, 60), 'refreshRate': 'fast'},
            {...mode(8, 1920, 1080, 60), 'refreshRate': double.nan},
            {...mode(9, 1920, 1080, 60), 'refreshRate': double.infinity},
            mode(10, 1920, 1080, 0),
            {...mode(11, 1920, 1080, 60), 'id': 11.5},
            {...mode(12, 1920, 1080, 24), 'width': 1920.0, 'id': '12'},
          ],
          'alternativeRefreshRates': [24.0, 'x', null, -1, 23.976025],
        },
      ).read();

      expect(facts?.modes.map((m) => m.id), [1, 12]);
      expect(facts?.modes.last.width, 1920);
      expect(facts?.alternativeRefreshRates, [24.0, 23.976025]);
      expect(facts?.apiLevel, isNull);
    });

    test(
      'a current mode it cannot read is none; the modes still are',
      () async {
        final facts = await display((_) => {...tv, 'current': 'the 4K one'})
            .read();

        expect(facts?.current, isNull);
        expect(facts?.modes, hasLength(3));
      },
    );

    test('an answer with no display in it reads as none', () async {
      for (final answer in <Object?>[
        null,
        'no display',
        42,
        <Object?>[tv],
        <String, Object?>{},
        {'current': null, 'modes': 'none'},
      ]) {
        expect(await display((_) => answer).read(), isNull, reason: '$answer');
      }
    });

    test("a failure on the TV's side reads as none, and is logged", () async {
      final modes = display(
        (_) => PlatformException(code: 'error', message: 'no window'),
      );

      expect(await modes.read(), isNull);
      expect(logLines(), anyElement(contains('no window')));
    });

    test('no channel at all (an app built without it) reads as none', () async {
      final modes = display((_) => null);
      messenger.setMockMethodCallHandler(channel, null);

      expect(await modes.read(), isNull);
    });
  });

  group('request', () {
    test("asks for the mode's id; 0 for none", () async {
      final modes = display((_) => true);

      expect(await modes.request(5), isTrue);
      expect(await modes.request(0), isTrue);
      expect(calls.map((c) => c.method), ['request', 'request']);
      expect(calls.map((c) => c.arguments), [
        {'id': 5},
        {'id': 0},
      ]);
    });

    test(
      "anything but a yes is a no, and a failure is a no that's logged",
      () async {
        for (final answer in <Object?>[false, null, 'true', 1]) {
          expect(
            await display((_) => answer).request(5),
            isFalse,
            reason: '$answer',
          );
        }
        final failing = display(
          (_) => PlatformException(code: 'error', message: 'window gone'),
        );
        expect(await failing.request(5), isFalse);
        expect(logLines(), anyElement(contains('window gone')));
      },
    );
  });

  group('changes', () {
    test("the display's new mode, as the TV tells it", () async {
      final modes = display((_) => null);
      final seen = <DisplayMode>[];
      modes.changes.listen(seen.add);

      await platformSays('modeChanged', mode(5, 3840, 2160, 23.976025));
      await pumpEventQueue();

      expect(seen, [
        const DisplayMode(
          id: 5,
          width: 3840,
          height: 2160,
          refreshRate: 23.976025,
        ),
      ]);
    });

    test('a change it cannot read, or a call it does not know, is passed '
        'over', () async {
      final modes = display((_) => null);
      final seen = <DisplayMode>[];
      modes.changes.listen(seen.add);

      await platformSays('modeChanged', null);
      await platformSays('modeChanged', {'id': 'five'});
      await platformSays('somethingElse', mode(5, 3840, 2160, 24));
      await platformSays('modeChanged', mode(6, 3840, 2160, 24));
      await pumpEventQueue();

      expect(seen.map((m) => m.id), [6]);
    });
  });
}
