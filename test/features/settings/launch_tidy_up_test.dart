import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/settings/domain/data_upkeep.dart';
import 'package:logger/logger.dart';

import 'data_fakes.dart';

const int _mb = 1024 * 1024;

/// The launch's tidy-up (ADR-031): prunes, then compacts only a file with
/// a lot of free room and only while nothing is at work; never throws.
void main() {
  late FakeDataUpkeep upkeep;
  late MemoryOutput logged;
  UpkeepBlocker? atWork;
  final now = DateTime.utc(2026, 10, 17, 9);

  setUp(() {
    upkeep = FakeDataUpkeep();
    logged = MemoryOutput();
    atWork = null;
  });

  Future<void> run() => LaunchTidyUp(
    upkeep: upkeep,
    blocker: () async => atWork,
    log: AppLog(output: logged, secrets: SecretRegistry()),
    clock: () => now,
  ).run();

  String log() => logged.buffer.expand((e) => e.lines).join('\n');

  test('prunes as at now and says how much went', () async {
    await run();

    expect(upkeep.pruned, [now]);
    expect(
      log(),
      contains(
        'Pruned 4 channel(s) and 2 title(s) from the history, 7 sync '
        'run(s), 3 guide import(s)',
      ),
    );
  });

  test('a lot of free room, nothing at work: compacted, before and after '
      'logged', () async {
    await run();

    expect(upkeep.compactions, 1);
    expect(log(), contains('77.0 MB → 52.0 MB'));
  });

  for (final blocker in UpkeepBlocker.values) {
    test('${blocker.name}: left to the next launch', () async {
      atWork = blocker;

      await run();

      expect(upkeep.compactions, 0);
      expect(upkeep.trims, 0);
      expect(
        log(),
        contains('Compaction left to the next launch: ${blocker.name}'),
      );
    });
  }

  test(
    'little free room: no compaction; a long log alone is emptied',
    () async {
      upkeep.room = const DatabaseRoom(
        bytes: 40 * _mb,
        pagesBytes: 40 * _mb,
        freeBytes: 2 * _mb,
      );
      await run();
      expect(upkeep.compactions + upkeep.trims, 0);

      upkeep.room = const DatabaseRoom(
        bytes: 104 * _mb,
        pagesBytes: 40 * _mb,
        freeBytes: 2 * _mb,
        logBytes: 64 * _mb,
      );
      await run();
      expect(upkeep.compactions, 0);
      expect(upkeep.trims, 1);
    },
  );

  test('a guide in place: the room its last import left is not rewritten '
      'every launch (the next import takes it again)', () async {
    upkeep.room = const DatabaseRoom(
      bytes: 77 * _mb,
      pagesBytes: 77 * _mb,
      freeBytes: 30 * _mb,
      hasGuide: true,
    );

    await run();

    expect(upkeep.compactions + upkeep.trims, 0);

    // The guide switched off and cleared: the same room is for good.
    upkeep.room = const DatabaseRoom(
      bytes: 77 * _mb,
      pagesBytes: 77 * _mb,
      freeBytes: 30 * _mb,
    );
    await run();
    expect(upkeep.compactions, 1);
  });

  test('failures are logged and go no further; nothing is thrown', () async {
    upkeep
      ..pruneFailure = StorageFailure('disk I/O error')
      ..measureFailure = StorageFailure('locked');

    await run();

    expect(upkeep.compactions, 0);
    expect(log(), contains('Pruning failed (storage)'));
    expect(log(), contains('could not be measured (storage)'));

    upkeep.pruneThrows = StateError('a bug');
    await expectLater(run(), completes);
    expect(log(), contains('The tidy-up failed'));
  });
}
