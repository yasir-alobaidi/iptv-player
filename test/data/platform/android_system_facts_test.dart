import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/data/platform/android_system_facts.dart';

/// A TV's facts over `bijou/system` (SystemInfo.kt, ADR-059): the answer
/// becomes the report's lines, read tolerantly; a channel that fails is
/// no facts, never a throw.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bijou/system');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final value = reply(call);
      if (value is Exception) throw value;
      return value;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  // As a TCL TV on Android 12 might say it.
  const tcl = {
    'manufacturer': 'TCL',
    'brand': 'TCL',
    'model': '43V8C',
    'device': 'mt9612',
    'board': 'm7332',
    'hardware': 'm7332',
    'release': '12',
    'sdk': 31,
    'securityPatch': '2024-05-05',
    'build': 'V8C-R.0.0.1',
    'kernel': '5.4.274+',
    'abis': 'armeabi-v7a,armeabi',
    'socManufacturer': 'Mediatek',
    'socModel': 'MT9612',
    'prop:ro.board.platform': 'm7332',
    'prop:ro.hardware.egl': 'mali',
    'prop:ro.hardware.vulkan': 'mali',
    'totalMb': 1946,
    'availableMb': 612,
    'lowMemoryMb': 216,
    'lowRam': true,
    'heapMb': 192,
    'largeHeapMb': 512,
    'glEs': '3.2',
    'vulkan': '1.1',
    'freeStorageMb': 3277,
  };

  test("read asks for the facts and says the TV's model, chip, drivers and "
      'memory', () async {
    late MethodCall asked;
    answer((call) {
      asked = call;
      return tcl;
    });
    final facts = await const AndroidSystemFacts().read();
    expect(asked.method, 'facts');
    expect(facts.os, 'Android 12 (API 31, 2024-05-05)');
    expect(facts.kernel, 'Linux 5.4.274+');
    expect(
      facts.device,
      'TCL 43V8C · device mt9612 · board m7332 · hardware m7332 · '
      'platform m7332 · chip Mediatek MT9612 · armeabi-v7a,armeabi · '
      'build V8C-R.0.0.1',
    );
    expect(facts.graphics, [
      const GraphicsCard(name: 'EGL mali · Vulkan 1.1 (mali) · OpenGL ES 3.2'),
    ]);
    expect(
      facts.memory,
      '1.9 GB, 0.6 GB free, low at 0.2 GB · a low-RAM device · the app may '
      'use 192 MB (large 512 MB) · storage 3.2 GB free',
    );
  });

  test('the brand is said once when the model already starts with it; a TV '
      'without Vulkan says so', () {
    final facts = androidSystemFactsFrom({
      'manufacturer': 'Google',
      'model': 'Google TV Streamer',
      'vulkan': null,
    });
    expect(facts.device, 'Google TV Streamer');
    expect(facts.graphics.single.name, 'no Vulkan');
  });

  test('read tolerantly: wrong kinds and blanks are as if missing, and an '
      'answer that is no map is no facts', () {
    final facts = androidSystemFactsFrom({
      'model': 7,
      'release': '  ',
      'sdk': '31',
      'totalMb': 'a lot',
      'prop:ro.hardware.egl': ['mali'],
    });
    expect(facts.os, isNull);
    expect(facts.device, isNull);
    expect(facts.memory, isNull);
    // No `vulkan` key at all: nothing said of it.
    expect(facts.graphics, isEmpty);
    expect(androidSystemFactsFrom('facts').os, isNull);
    expect(androidSystemFactsFrom(null).graphics, isEmpty);
  });

  test("the version is the package's (an APK has no version.json), and "
      "unknown when it can't be read", () async {
    answer((call) {
      expect(call.method, 'version');
      return {'version': '0.1.0', 'build_number': '344'};
    });
    expect(
      await androidAppVersion(),
      const AppVersion(version: '0.1.0', build: '344'),
    );
    answer((_) => PlatformException(code: 'error'));
    expect(await androidAppVersion(), AppVersion.unknown);
  });

  test('a channel that fails is no facts', () async {
    answer((_) => PlatformException(code: 'error'));
    final facts = await const AndroidSystemFacts().read();
    expect(facts.os, isNull);
    expect(facts.device, isNull);
  });
}
