import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/relay/relay_folders.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// The launch sweep's second half: the relay's folders of runs that are
/// gone, deleted with their segments; a running copy's, and this run's,
/// left alone.
void main() {
  late Directory root;
  late MemoryOutput logged;
  late AppLog log;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('relay_folders');
    logged = MemoryOutput();
    log = AppLog(output: logged, secrets: SecretRegistry());
  });

  tearDown(() => root.delete(recursive: true));

  Directory folder(String name) {
    final made = Directory(p.join(root.path, name, 'cast-1-0'))
      ..createSync(recursive: true);
    File(p.join(made.path, 'seg00001.ts')).writeAsBytesSync([71]);
    return made.parent;
  }

  test('a run that is gone: its folder, segments and all', () async {
    final gone = folder('40001');
    final reused = folder('40002');
    final running = folder('40003');
    final ours = folder('$pid');
    final notOurs = folder('downloads');
    final deleted = await sweepRelayFolders(
      root,
      log: log,
      executable: '/app/iptv_player',
      image: (id) => switch (id) {
        // A process id reused by something else.
        40002 => '/usr/bin/bash',
        // Another copy of the app, still running.
        40003 => '/app/iptv_player',
        _ => null,
      },
    );
    expect(deleted, 2);
    expect(gone.existsSync(), isFalse);
    expect(reused.existsSync(), isFalse);
    expect(running.existsSync(), isTrue);
    expect(ours.existsSync(), isTrue);
    expect(notOurs.existsSync(), isTrue);
    expect(
      logged.buffer.expand((e) => e.lines).last,
      contains('Deleted 2 relay folder(s) from earlier runs'),
    );
  });

  test('no folder yet: nothing to do', () async {
    final missing = Directory(p.join(root.path, 'never'));
    expect(await sweepRelayFolders(missing, log: log), 0);
  });
}
