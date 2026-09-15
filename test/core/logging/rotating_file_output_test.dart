import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/rotating_file_output.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

OutputEvent _event(String line, [Level level = Level.info]) =>
    OutputEvent(LogEvent(level, line), [line]);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rotating_log_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  File file(String name) => File(p.join(dir.path, name));

  List<String> logFiles() =>
      dir.listSync().map((e) => p.basename(e.path)).toList()..sort();

  test('writes lines in order', () async {
    final output = RotatingFileOutput(directory: dir);
    await output.init();
    for (var i = 0; i < 3; i++) {
      output.output(_event('line $i'));
    }
    await output.destroy();

    expect(file('app.log').readAsStringSync(), 'line 0\nline 1\nline 2\n');
  });

  test(
    'rotates before a file passes maxFileBytes and keeps maxFiles',
    () async {
      // Each line is 8 bytes ("line NN\n"): 6 lines fit in 50 bytes.
      final output = RotatingFileOutput(
        directory: dir,
        maxFileBytes: 50,
        maxFiles: 3,
      );
      await output.init();
      for (var i = 0; i < 40; i++) {
        output.output(_event('line ${i.toString().padLeft(2, '0')}'));
      }
      await output.destroy();

      expect(logFiles(), ['app.1.log', 'app.2.log', 'app.log']);
      for (final name in logFiles()) {
        expect(file(name).lengthSync(), lessThanOrEqualTo(50));
      }
      final kept = [
        file('app.2.log'),
        file('app.1.log'),
        file('app.log'),
      ].map((f) => f.readAsStringSync()).join();
      final expected = [
        for (var i = 0; i < 40; i++) 'line ${i.toString().padLeft(2, '0')}\n',
      ].join();
      expect(expected.endsWith(kept), isTrue);
      expect(kept, endsWith('line 39\n'));
    },
  );

  test('counts an existing file toward the limit', () async {
    file('app.log').writeAsStringSync('x' * 45);
    final output = RotatingFileOutput(directory: dir, maxFileBytes: 50);
    await output.init();
    output.output(_event('0123456789'));
    await output.destroy();

    expect(file('app.1.log').readAsStringSync(), 'x' * 45);
    expect(file('app.log').readAsStringSync(), '0123456789\n');
  });

  test('writes a line longer than maxFileBytes to its own file', () async {
    final output = RotatingFileOutput(directory: dir, maxFileBytes: 10);
    await output.init();
    output
      ..output(_event('short'))
      ..output(_event('a line much longer than ten bytes'));
    await output.destroy();

    expect(file('app.1.log').readAsStringSync(), 'short\n');
    expect(
      file('app.log').readAsStringSync(),
      'a line much longer than ten bytes\n',
    );
  });

  test('writes warnings without waiting for the flush delay', () async {
    final output = RotatingFileOutput(
      directory: dir,
      flushDelay: const Duration(hours: 1),
    );
    await output.init();
    output.output(_event('something broke', Level.warning));
    await output.flush();

    expect(file('app.log').readAsStringSync(), 'something broke\n');
    await output.destroy();
  });

  test('ignores output after destroy', () async {
    final output = RotatingFileOutput(directory: dir);
    await output.init();
    await output.destroy();
    output.output(_event('late'));
    await output.flush();

    expect(file('app.log').readAsStringSync(), isEmpty);
  });
}
