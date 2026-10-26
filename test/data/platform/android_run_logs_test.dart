import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/run_logs.dart';
import 'package:iptv_player/data/platform/android_run_logs.dart';
import 'package:logger/logger.dart';

/// Each run's own log over `bijou/system` (RunLog.kt, ADR-059): asked
/// with its size, read into lines; a channel that fails is logged and
/// answered null, never thrown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bijou/system');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MemoryOutput logged;
  late List<MethodCall> calls;

  AndroidRunLogs logs(Object? Function(MethodCall call) answer) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final reply = answer(call);
      if (reply is Exception) throw reply;
      return reply;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    logged = MemoryOutput();
    return AndroidRunLogs(
      log: AppLog(output: logged, secrets: SecretRegistry()),
    );
  }

  test('read asks for each run with its size and splits them into lines, '
      'blank ones left out', () async {
    final source = logs(
      (_) => {
        'older': 'crashed\n',
        'previous': 'a\n\nb  \nFatal signal 11\n',
        'current': 'started\n',
      },
    );
    expect(source.available, isTrue);
    final runs = await source.read(maxBytes: 1000);
    expect(calls.single.method, 'runLogs');
    expect(calls.single.arguments, {'maxBytes': 1000});
    expect(runs!.older, ['crashed']);
    expect(runs.previous, ['a', 'b', 'Fatal signal 11']);
    expect(runs.current, ['started']);
    expect(runs.isEmpty, isFalse);
  });

  test('a run with nothing kept is empty, and an answer that is no map is '
      'null', () {
    expect(
      runLogsFrom({'older': <Object?>[], 'previous': null, 'current': 3})!
          .isEmpty,
      isTrue,
    );
    expect(runLogsFrom('logs'), isNull);
  });

  test("the renderer is the engine's own word in a run's log (ADR-060): "
      'none where it said none', () {
    expect(
      rendererIn([
        '10-26 11:45:58.101  4120  4120 I Bijou   : Activity ON_CREATE',
        'I flutter : Using the Impeller rendering backend (Vulkan).',
      ]),
      'Impeller (Vulkan)',
    );
    // The TCL's PowerVR: Vulkan tried, refused, then OpenGL ES.
    expect(
      rendererIn([
        'I flutter : Using the Impeller rendering backend (Vulkan).',
        'E IMGSRV  : :2445: albert-tex LOSSY set to: 75',
        'I flutter : Using the Impeller rendering backend (OpenGLES).',
      ]),
      'Impeller (OpenGLES)',
    );
    expect(
      rendererIn([
        'I flutter : [Action Required]: Impeller opt-out deprecated.',
      ]),
      'Skia',
    );
    expect(rendererIn(['I Bijou   : Drawing with Skia on OpenGL ES']), isNull);
    expect(rendererIn(const []), isNull);
  });

  test('a channel that fails is logged and answered null', () async {
    final source = logs((_) => PlatformException(code: 'error'));
    expect(await source.read(), isNull);
    expect(
      [for (final event in logged.buffer) ...event.lines].join('\n'),
      contains("The runs' own logs couldn't be read"),
    );
  });

  test('the desktop keeps none', () async {
    expect(const NoRunLogs().available, isFalse);
    expect(await const NoRunLogs().read(), isNull);
  });
}
