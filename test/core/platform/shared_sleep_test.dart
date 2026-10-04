import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/shared_sleep.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';

void main() {
  late _System system;
  late SharedSleep shared;

  setUp(() {
    system = _System();
    shared = SharedSleep(system);
  });

  test('held while either holds, released when neither does', () async {
    final cast = shared.view('cast');
    final downloads = shared.view('downloads');

    expect(await cast.hold('Casting to Living Room TV'), isTrue);
    expect(await downloads.hold('Downloading'), isTrue);
    expect(system.log, ['hold Casting to Living Room TV']);

    await cast.release();
    expect(shared.held, isTrue);
    expect(system.log, hasLength(1));

    await downloads.release();
    expect(shared.held, isFalse);
    expect(system.log, ['hold Casting to Living Room TV', 'release']);
  });

  test('releasing what was never held, or twice, does nothing', () async {
    final cast = shared.view('cast');
    final downloads = shared.view('downloads');
    await cast.release();
    await downloads.hold('Downloading');
    await cast.release();
    await cast.release();
    expect(system.log, ['hold Downloading']);
    await downloads.release();
    await downloads.release();
    expect(system.log, ['hold Downloading', 'release']);
  });

  test(
    'a hold let go while the system was still asked ends released',
    () async {
      system.slow = true;
      final downloads = shared.view('downloads');
      final holding = downloads.hold('Downloading');
      await downloads.release();
      system.answer();
      expect(await holding, isFalse);
      expect(shared.held, isFalse);
      expect(system.log, ['hold Downloading', 'release']);
    },
  );
}

final class _System implements SleepInhibitor {
  final log = <String>[];
  bool slow = false;
  final _waiting = <void Function()>[];

  void answer() {
    for (final done in _waiting) {
      done();
    }
    _waiting.clear();
  }

  @override
  Future<bool> hold(String why) async {
    log.add('hold $why');
    if (slow) {
      final waited = Future<void>.sync(() {});
      var answered = false;
      _waiting.add(() => answered = true);
      await waited;
      while (!answered) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return true;
  }

  @override
  Future<void> release() async => log.add('release');
}
