import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/data/platform/android_last_exits.dart';
import 'package:logger/logger.dart';

/// A TV's last ends over `bijou/exits` (LastExits.kt, ADR-058): the
/// answer becomes the ends, and a channel that fails is logged and
/// answered null, never thrown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bijou/exits');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MemoryOutput logged;
  late List<MethodCall> calls;

  List<String> logLines() => [
    for (final event in logged.buffer) ...event.lines,
  ];

  AndroidLastExits exits(Object? Function(MethodCall call) answer) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final reply = answer(call);
      if (reply is Exception) throw reply;
      return reply;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    logged = MemoryOutput();
    return AndroidLastExits(
      log: AppLog(output: logged, secrets: SecretRegistry()),
    );
  }

  test('read asks the channel and reads its answer', () async {
    final source = exits(
      (_) => {
        'exits': [
          {
            'time': 1792922624560,
            'reason': 'crashNative',
            'importance': 100,
            'thread': '1.raster',
            'drawing': true,
          },
        ],
        'seenUpTo': 0,
        'drawing': {'backend': 'opengles', 'since': 1792922624560},
      },
    );
    expect(source.available, isTrue);
    final last = await source.read();
    expect(calls.single.method, 'read');
    expect(last!.untold.single.thread, '1.raster');
    expect(last.drawing.openGles, isTrue);
  });

  test("an answer it can't read is null, and says so in the log", () async {
    final source = exits((_) => 'nothing');
    expect(await source.read(), isNull);
    expect(logLines().join('\n'), contains('The last ends said nothing'));
  });

  test('a channel that fails is null, logged, never thrown', () async {
    final source = exits((_) => PlatformException(code: 'boom'));
    expect(await source.read(), isNull);
    expect(logLines().join('\n'), contains("The last ends couldn't be read"));
  });

  test('seen sends the newest end told, in milliseconds', () async {
    final source = exits((_) => true);
    await source.seen(DateTime.fromMillisecondsSinceEpoch(1792922624560));
    expect(calls.single.method, 'seen');
    expect(calls.single.arguments, {'upTo': 1792922624560});
  });

  test('seen failing is logged, never thrown', () async {
    final source = exits((_) => PlatformException(code: 'boom'));
    await source.seen(DateTime.fromMillisecondsSinceEpoch(1));
    expect(
      logLines().join('\n'),
      contains("The last end told couldn't be kept"),
    );
  });

  test('the desktop has none: nothing to read, nothing to keep', () async {
    const none = NoLastExits();
    expect(none.available, isFalse);
    expect(await none.read(), isNull);
    await none.seen(DateTime(2026));
  });
}
